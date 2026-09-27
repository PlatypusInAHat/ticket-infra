# TicketStage Kubernetes

## Secrets

`k8s/base/secrets.example.yaml` is a template only. Do not apply it directly in production.

Create the real secret before applying an overlay:

```bash
kubectl apply -f k8s/base/namespace.yaml
kubectl create secret generic ticketstage-secrets \
  --namespace ticketstage \
  --from-literal=JWT_SECRET="replace-with-real-value" \
  --from-literal=INTERNAL_API_KEY="replace-with-real-value" \
  --from-literal=SECRET_HASH_KEY="replace-with-real-value" \
  --from-literal=DEVICE_FINGERPRINT_SECRET="replace-with-real-value" \
  --from-literal=TURNSTILE_SECRET_KEY="replace-with-real-value" \
  --from-literal=PASSWORD_PEPPER="replace-with-real-value" \
  --from-literal=AUTH_MONGODB_URI="replace-with-real-value" \
  --from-literal=CATALOG_MONGODB_URI="replace-with-real-value" \
  --from-literal=BOOKING_MONGODB_URI="replace-with-real-value" \
  --from-literal=CHECKIN_MONGODB_URI="replace-with-real-value" \
  --from-literal=EVENT_BROKER_URL="replace-with-real-value" \
  --from-literal=REDIS_URL="redis://replace-with-elasticache-endpoint:6379"
```

Prefer External Secrets or Sealed Secrets for real deployments.

## HPA prerequisites

HPA needs `metrics-server` in the cluster. After deploying the infra layer, verify it with:

```bash
kubectl get deployment -n kube-system metrics-server
kubectl get apiservices | findstr metrics.k8s.io
kubectl top pods -n ticketstage
kubectl get hpa -n ticketstage
```

If `kubectl top` returns data, HPA can read metrics and scale services.

## High-volume inventory

General-admission tickets can use bucket inventory to distribute concurrent
atomic writes. The application image contains the migration scripts, but the
CI migration is opt-in through the GitHub repository variable
`ENABLE_INVENTORY_BUCKET_MIGRATION=true`. Benchmark a dedicated event first;
the migration changes all active general-admission tickets in the catalog
database.

For multi-pod rate limiting, provision Redis/ElastiCache and store its URL in
`ticketstage-secrets`. Only then change `RATE_LIMIT_STORE` from `mongo` to
`redis`; do not use the placeholder endpoint in the example secret.

The Terraform data layer creates ElastiCache only when `enable_redis=true` and
requires a sensitive `redis_auth_token`. Apply layer `02-data` before layer
`03-storage`; the latter stores the generated TLS URL in Secrets Manager. The
Kubernetes secret still needs to be synchronized from Secrets Manager by the
chosen secret delivery process before switching the ConfigMap to Redis.

`inventory-summary-sync` runs every minute with `concurrencyPolicy: Forbid`.
It uses the catalog-service image and performs aggregate/bulk updates for
bucket inventory, so it does not need Kubernetes API permissions.

## Images

Use overlays to replace the base placeholder image:

```bash
kubectl apply -k k8s/overlays/dev
kubectl apply -k k8s/overlays/staging
kubectl apply -k k8s/overlays/prod
```

Before deployment, replace the placeholder account and region in the overlay image names with your real ECR registry. Backend services use independent repositories, for example:

```text
123456789012.dkr.ecr.us-east-1.amazonaws.com/dev/api-gateway
123456789012.dkr.ecr.us-east-1.amazonaws.com/dev/auth-service
123456789012.dkr.ecr.us-east-1.amazonaws.com/dev/catalog-service
123456789012.dkr.ecr.us-east-1.amazonaws.com/dev/booking-service
123456789012.dkr.ecr.us-east-1.amazonaws.com/dev/checkin-service
123456789012.dkr.ecr.us-east-1.amazonaws.com/dev/notification-service
```

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
  --from-literal=PASSWORD_PEPPER="replace-with-real-value" \
  --from-literal=AUTH_MONGODB_URI="replace-with-real-value" \
  --from-literal=CATALOG_MONGODB_URI="replace-with-real-value" \
  --from-literal=BOOKING_MONGODB_URI="replace-with-real-value" \
  --from-literal=CHECKIN_MONGODB_URI="replace-with-real-value" \
  --from-literal=EVENT_BROKER_URL="replace-with-real-value"
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

## Images

Use overlays to replace the base placeholder image:

```bash
kubectl apply -k k8s/overlays/dev
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

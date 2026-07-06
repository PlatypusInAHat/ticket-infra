# TicketStage Argo CD

This folder bootstraps GitOps delivery for TicketStage.

## Structure

- `bootstrap/`: apply these manifests once after installing Argo CD.
- `applications/`: child Argo CD Applications managed by `ticketstage-root`.
- `../k8s/overlays/dev`: dev workload source, auto-sync enabled from branch `dev`.
- `../k8s/overlays/prod`: prod workload source, manual sync from branch `main`.

## Install Argo CD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server
```

## Bootstrap TicketStage GitOps

```bash
kubectl apply -k argocd/bootstrap
```

After bootstrap, `ticketstage-root` creates:

- `ticketstage-dev`
- `ticketstage-prod`

## Sync Behavior

- Dev uses automated sync with prune and self-heal.
- Prod is intentionally manual. Promote by merging to `main`, then sync `ticketstage-prod` from the Argo CD UI or CLI.

## Required Runtime Secrets

Argo CD will not create real application secrets. Create `ticketstage-secrets` before syncing workloads:

```bash
kubectl apply -f k8s/base/namespace.yaml
kubectl create secret generic ticketstage-secrets --namespace ticketstage \
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

Prefer External Secrets, Sealed Secrets, or AWS Secrets Manager integration before production.

# TicketStage Cloud Infrastructure

Tài liệu này mô tả toàn bộ kiến trúc hạ tầng (Infrastructure) cho hệ thống **TicketStage** (Ứng dụng đặt vé), bao gồm cấu hình AWS bằng Terraform, Kubernetes manifests, Argo CD và cấu hình bảo mật trên Cloudflare.

---

## 0. Cách Vận Hành Để Tiết Kiệm Chi Phí

Phần lớn chi phí của stack EKS là phí cố định (control plane EKS, NAT Gateway, ALB, Amazon MQ), không phải EC2. Vì vậy repo hỗ trợ hai chế độ:

| Chế độ | Dùng khi | Thành phần | Ước tính |
| --- | --- | --- | --- |
| **Compose host** (`aws/terraform/standalone/compose-host`) | Chạy thường trực để dev/test, cần URL public | 1 EC2 `t4g.medium` chạy `docker compose` của repo app + Cloudflare Tunnel; không ALB, không NAT, không mở port | ~$30/tháng |
| **EKS on-demand** (`scripts/stack.ps1`) | Demo, load test, thử autoscale/GitOps | Toàn bộ layer `00`–`04` + Argo CD, dựng bằng `up`, xóa bằng `down` | ~$0.3–0.5/giờ khi đang chạy |

Không có môi trường nào nên để EKS chạy liên tục khi không dùng. Số liệu chi phí là ước tính cho us-east-1; kiểm tra lại bằng AWS Pricing Calculator.

### Dựng / xóa EKS bằng một lệnh

```powershell
# Biến bắt buộc (giống secrets của infra-cd)
$env:TF_STATE_BUCKET = "..."; $env:TF_STATE_REGION = "us-east-1"; $env:TF_LOCK_TABLE = "..."
$env:TF_VAR_mongodb_public_key = "..."; $env:TF_VAR_mongodb_private_key = "..."; $env:TF_VAR_mongodb_org_id = "..."
$env:TF_VAR_mongodb_username = "..."; $env:TF_VAR_mongodb_password = "..."
$env:TF_VAR_mq_admin_username = "..."; $env:TF_VAR_mq_admin_password = "..."
# cùng các TF_VAR_* khác mà layer yêu cầu (jwt_secret, rabbitmq_*, mongodb_connection_string, ...)

pwsh ./scripts/stack.ps1 -Action up -Environment dev            # apply 00..04, kubeconfig, secret, Argo CD
pwsh ./scripts/stack.ps1 -Action status -Environment dev        # số resource trong state từng layer
pwsh ./scripts/stack.ps1 -Action down -Environment dev          # xóa app Argo CD/Ingress/ALB rồi destroy 04, 02, 01, 00
```

- `up` tự sinh `k8s/secrets/<env>.env` ở lần chạy đầu (JWT/HMAC/pepper/device-fingerprint/waiting-room token ngẫu nhiên, URI Atlas, URL Amazon MQ, `REDIS_URL` nếu `enable_redis = true`) và tạo Secret `ticketstage-secrets` từ đó. File này bị `.gitignore` chặn; **giữ lại file** giữa các lần `up`/`down`, vì đổi `SECRET_HASH_KEY` hoặc `PASSWORD_PEPPER` sẽ làm hỏng hash vé và mật khẩu đã lưu. Thêm khóa thanh toán/email/`TURNSTILE_SECRET_KEY` vào file rồi chạy lại `up`.
- `up` cài Argo CD rồi apply `ticketstage-project.yaml` và root Application của đúng môi trường (`ticketstage-root` cho dev, `ticketstage-root-<env>` cho staging/prod).
- `down` giữ `03-storage` (ECR, S3/CloudFront, Secrets Manager; gần như không tốn tiền khi rảnh). Dùng `-IncludeStorage` để xóa cả layer này, `-KeepData` để chỉ xóa cluster và giữ VPC + Atlas + Amazon MQ (+ Redis nếu bật).
- `-AutoApprove` bỏ qua bước xác nhận `yes` của Terraform.
- Với `enable_redis = false` (mặc định ở dev), `waiting-room-service` không có Redis nên readiness fail; các service còn lại vẫn chạy.

### Compose host

1. Tạo tunnel trong Cloudflare Zero Trust → Networks → Tunnels, thêm public hostname (ví dụ `api-trial.example.com`) trỏ tới `http://localhost:5000`, copy token.
2. Lưu hai SSM SecureString:
   - `/ticketstage/trial/cloudflare-tunnel-token`: token ở bước 1.
   - `/ticketstage/trial/compose-env`: nội dung `.env` theo mẫu `aws/terraform/standalone/compose-host/compose.env.example`.
   - (repo app private) một token GitHub chỉ đọc, truyền tên tham số qua `git_token_parameter`.
3. Apply:
   ```powershell
   cd aws/terraform/standalone/compose-host
   terraform init -backend-config="bucket=$env:TF_STATE_BUCKET" -backend-config="key=trial/compose-host/terraform.tfstate" `
     -backend-config="region=$env:TF_STATE_REGION" -backend-config="dynamodb_table=$env:TF_LOCK_TABLE" -backend-config="encrypt=true"
   terraform apply -var="app_repo_url=https://github.com/<org>/<app-repo>.git"
   ```
4. Máy tự cài Docker, clone repo app, build và chạy compose, seed dữ liệu demo (chỉ lần đầu), chạy `cloudflared`. Theo dõi bằng lệnh trong output `bootstrap_log_command`; vào máy bằng `ssm_session_command` (không có SSH).

Dùng default VPC của tài khoản, IMDSv2, EBS mã hóa, security group chỉ có egress. Dữ liệu MongoDB/RabbitMQ nằm trên ổ root, nên Terraform cố ý bỏ qua thay đổi AMI và `user_data`; muốn dựng lại máy thì `terraform apply -replace=aws_instance.host`. Frontend không chạy trên máy này: build với `VITE_API_URL=https://api-trial.example.com/api` rồi host trên S3/CloudFront hoặc Cloudflare Pages. Máy chạy đúng những gì `docker-compose.yml` của repo app định nghĩa; nếu compose chưa có Redis/waiting room thì các tính năng đó không có trên máy này.

---

## 1. Kiến Trúc Tổng Quan (Architecture)

Hệ thống được thiết kế theo mô hình microservices, chạy trên nền tảng AWS và được bảo vệ bởi Cloudflare:

1. **Cloudflare**: Hoạt động như lớp bảo mật đầu tiên (DNS proxy), cung cấp DDoS Protection, Web Application Firewall (WAF), Bot Management và Rate Limiting.
2. **Frontend**: Các static assets (React/Vite) được lưu trữ trên **Amazon S3** và phân phối qua **Amazon CloudFront**.
3. **Backend Microservices**: Deployment trong namespace `ticketstage` trên **Amazon EKS**: `api-gateway`, `auth-service`, `catalog-service`, `booking-service`, `checkin-service`, `notification-service`, `waiting-room-service`, cùng CronJob `inventory-summary-sync`. Mỗi service có HPA (CPU/memory), PDB, NetworkPolicy, ServiceMonitor.
4. **Networking**: Public traffic đi từ Cloudflare vào Kubernetes qua Ingress `ticketstage-api` (class `alb`) → `api-gateway`. ALB được tạo bởi **AWS Load Balancer Controller**, cài bằng Terraform ở layer `01-kubernetes` (IRSA role trong module EKS + Helm chart).
5. **Database (MongoDB Atlas)**: database riêng cho từng service. Kết nối riêng tư qua **AWS PrivateLink** khi `mongodb_enable_private_endpoint = true` (hiện chỉ `staging`; tier M0 không hỗ trợ). Khi không dùng PrivateLink, Terraform tự thêm IP public của NAT Gateway vào access list của Atlas, vì pod đi ra Internet qua NAT chứ không bằng IP private của VPC.
6. **Message Queue (RabbitMQ)**: Amazon MQ làm event broker cho domain event giữa các service (outbox → exchange `ticket-booking.events` → queue `<service>.events`). Output `mq_amqp_endpoint` của layer `02-data` là endpoint `amqps://...:5671`.
7. **Virtual Waiting Room**: `waiting-room-service` trên EKS dùng Redis/ElastiCache để giữ FIFO, active checkout lease và admission rate. API Gateway là bouncer kiểm tra signed token trước khi chuyển request tạo booking.
8. **Observability**: CloudWatch Log Groups, Alarms, Dashboard và SNS. Trên Kubernetes, layer `04-observability` cài `kube-prometheus-stack` (Prometheus, Grafana), Tempo và OpenTelemetry Collector bằng Helm.

---

## 2. Terraform Structure (Infrastructure as Code)

Cấu trúc mã Terraform (`infra/aws/terraform`) được tổ chức theo mô hình **Layered Architecture** để dễ quản lý state và giảm thiểu rủi ro khi apply:

### Các Layers
- **`00-networking`**: VPC, Subnets, NAT Gateway (một chung hoặc một mỗi AZ, theo `single_nat_gateway`), Security Groups, VPC Flow Logs.
- **`01-kubernetes`**: EKS Cluster, Node Groups (System On-Demand, App Spot, App Critical On-Demand), VPC CNI (bật prefix delegation), EBS CSI, OIDC, IAM Roles, Helm release `metrics-server`, `cluster-autoscaler`, `aws-load-balancer-controller`.
- **`02-data`**: MongoDB Atlas, Amazon MQ (RabbitMQ) và ElastiCache Redis tùy chọn (`enable_redis`) cho waiting room/rate limit shared store.
- **`03-storage`**: Amazon S3, CloudFront (Frontend hosting), ECR (Container Registry) và AWS Secrets Manager (kèm KMS key).
- **`04-observability`**: CloudWatch Dashboards, Log Groups, Metric Alarms, SNS Topics; Helm release `kube-prometheus-stack`, `tempo`, `opentelemetry-collector` (namespace `monitoring`) và secret mật khẩu admin Grafana.
- **`standalone/compose-host`**: không thuộc chuỗi layer; xem mục 0.

### Các Môi Trường (Environments)
3 môi trường, quản lý bằng `aws/terraform/environments/<env>/terraform.tfvars`. Mỗi môi trường có cluster riêng `<env>-eks`. Cấu hình **hiện tại** trong repo:

| | `dev` | `staging` | `prod` |
| --- | --- | --- | --- |
| NAT Gateway | 1 (dùng chung) | 1 mỗi AZ (3) | 1 mỗi AZ (2) |
| System node group (on-demand) | 1× `t4g.medium` (max 2), **không taint** | 2× `t4g.large` (max 3) | 1× `t4g.small` (max 2) |
| App node group (spot) | 1× `t4g.medium`/`m6g.medium`/`m7g.medium` (max 4) | 2× `t4g.large`/`m7g.large` (max 5) | 1× `t4g.small` (max 2) |
| App critical node group (on-demand, `workload=critical`) | 1× `t4g.medium` (max 2) | mặc định module: 2× `m7g.medium`/`m7g.large`/`t4g.large` (max 6) | mặc định module (như staging) |
| MongoDB Atlas | M0 (free) | M20, PrivateLink | M0 (free), không PrivateLink |
| Amazon MQ | `mq.t3.micro`, single instance | `mq.m5.large`, active/standby Multi-AZ | `mq.t3.micro`, single instance |
| Redis (ElastiCache) | tắt | theo tfvars | theo tfvars |

Ghi chú:
- Mọi node group dùng Graviton với `node_ami_type = "AL2023_ARM_64_STANDARD"`, và CI build image backend cho `linux/arm64`. Nếu đổi sang instance x86, phải đổi đồng thời `node_ami_type` (ví dụ `AL2023_x86_64_STANDARD`) và repository variable `BACKEND_IMAGE_PLATFORM=linux/amd64` ở repo app. Đổi `ami_type` trên cluster đang chạy sẽ khiến Terraform tạo lại node group.
- Prefix delegation của VPC CNI nâng giới hạn pod mỗi node (`t4g.small` 11 → 98, `t4g.medium` 17 → 110). Chỉ node tạo **sau** khi bật mới được giới hạn mới.
- Taint `system=true:NoSchedule` của node system được giữ ở staging/prod (`system_node_taint_enabled`, mặc định `true`); chỉ add-on hệ thống như AWS Load Balancer Controller tolerate nó. Ở cluster nhỏ (dev) taint được tắt để node system chạy được cả monitoring, Argo CD và app.
- `prod` đang dùng cấu hình tiết kiệm, **chưa** HA. Module Atlas có precondition bắt buộc prod dùng M10+ với backup và PITR, nên `prod/terraform.tfvars` hiện tại (M0) sẽ bị chặn khi plan; cần nâng Atlas, Amazon MQ `ACTIVE_STANDBY_MULTI_AZ` và số node trước khi chạy thật.
- `kubernetes_version = "1.29"` trong tfvars đã hết hạn hỗ trợ trên EKS (biến trong layer mặc định `1.35`). Cluster mới nên dùng phiên bản đang được hỗ trợ; cluster cũ chỉ nâng được mỗi lần một minor version.

---

## 3. Kubernetes Structure (K8s)

Cấu trúc thư mục `infra/k8s/`:

- **Base (`k8s/base`)**: Namespace, ServiceAccount, ConfigMap, Deployment/Service cho các service backend, `waiting-room-service`, CronJob `inventory-summary-sync`, StorageClass, HPA, PDB, NetworkPolicy, Ingress ALB, ServiceMonitor, PrometheusRule và dashboard Grafana. Image trong base là placeholder; không apply base trực tiếp.
- **Overlays (`k8s/overlays/dev`, `staging`, `prod`)**: thay image sang ECR theo môi trường (tag do CI của repo app ghi vào), đổi `FRONTEND_URL`, `PUBLIC_API_URL` và host Ingress. Overlay `dev` còn đặt mỗi service 1 pod, HPA `minReplicas: 1` và PDB `minAvailable: 0` cho cluster nhỏ.
- **Components tùy chọn** (cần cài KEDA: `helm install keda kedacore/keda --namespace keda --create-namespace`), bật bằng `components:` trong overlay:
  - `k8s/components/keda`: scale `notification-service` theo số message trong queue `notification-service.events` + CPU/memory.
  - `k8s/components/keda-presale`: scale `booking-service` theo lịch (trigger `cron`, múi giờ `Asia/Ho_Chi_Minh`) + CPU/memory. Đặt cửa sổ mở bán bằng patch (ví dụ trong `kustomization.yaml` của Component) để pod được tăng sẵn khoảng 15 phút trước giờ bán, thay vì chờ HPA phản ứng khi pod đã quá tải.

  Mỗi Component xóa HPA thường của service mà nó scale, vì KEDA tự tạo HPA và hai HPA cùng target sẽ tranh nhau. CI của infra render thử cả hai Component trên overlay dev.
- **Ingress**: `ingress-aws-alb.yaml` trỏ về Service `api-gateway`; ALB được tạo bởi AWS Load Balancer Controller.

---

## 4. Cloudflare Security

Cấu hình Cloudflare được lưu tại `infra/cloudflare`:
- **WAF Custom Rules**: Chặn các requests rác (scanner paths như `/.env`, `/wp-admin`). Challenge bằng CAPTCHA đối với các endpoint nhạy cảm (như `/api/payment`).
- **Rate Limiting**: Hạn chế số lượng requests để chống Brute-force Login và Spam Booking API.

Additional hot-sale controls:
- **Bot Score Challenge**: Set `bot_score_challenge_enabled=true` to challenge checkout traffic with low `cf.bot_management.score`. Enable only on zones with Cloudflare Bot Management.
- **Waiting Room**: Waiting room chính nằm trong ứng dụng và không phụ thuộc Cloudflare entitlement. Cloudflare Waiting Room trả phí chỉ là phương án edge dự phòng nếu sau này cần chặn traffic trước origin.

---

## 5. Deployment Thủ Công & Checklist

`scripts/stack.ps1` (mục 0) làm tất cả các bước dưới đây. Phần này để chạy từng bước khi cần.

### Yêu cầu cài đặt
- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5.0
- [AWS CLI](https://aws.amazon.com/cli/) đã được config credentials.
- [kubectl](https://kubernetes.io/docs/tasks/tools/). Helm chỉ cần nếu cài KEDA.

### Trình tự Deploy Terraform
Do thiết kế Layered, bạn **bắt buộc** phải deploy theo thứ tự từ `00` đến `04`:

1. Init từng layer: `pwsh .\aws\terraform\scripts\init-layer.ps1 -Environment dev -Layer <layer>` (hoặc `-Layer all`).
2. Trong thư mục layer: `terraform apply -var-file="../../environments/dev/terraform.tfvars"`.

### Trình tự Deploy K8s
Chạy từ thư mục gốc repo `infra/`. `metrics-server`, `cluster-autoscaler`, `aws-load-balancer-controller` (layer `01`) và `kube-prometheus-stack` (layer `04`) đã được Terraform cài, không cần `helm install` lại; layer `04` phải apply trước vì base dùng CRD `ServiceMonitor`/`PrometheusRule`.

1. Cập nhật kubeconfig: `aws eks update-kubeconfig --name <env>-eks --region <region>`
2. Tạo secret `ticketstage-secrets` (xem `k8s/README.md`).
3. Bootstrap Argo CD theo mục 7; không apply trực tiếp `k8s/base` song song với GitOps.

### Checklist Trước Khi Lên Production
- [ ] AWS Secrets Manager: Đảm bảo đã cập nhật đầy đủ thông tin credentials (MongoDB, JWT, Payment, Email).
- [ ] MongoDB Atlas: PrivateLink ở trạng thái *Available* (hoặc access list đã có IP NAT nếu không dùng PrivateLink).
- [ ] Cloudflare: Bật `Proxy (Orange Cloud)` cho tất cả DNS records của Web và API. Nâng Security Level lên `High` nếu chuẩn bị mở bán vé lớn.
- [ ] Terraform `prod`: đã nâng tier Atlas, Amazon MQ và node group (hiện đang là cấu hình free/cheap, xem mục 2).
- [ ] Load Testing: Đã kiểm chứng waiting-room admission rate/capacity, atomic inventory p95/p99, HPA, `keda-presale` và cluster-autoscaler trước giờ mở bán.

---

## 6. CI/CD Separation

- Branch flow: `feature/* -> dev -> release/* -> main`; `hotfix/*` tach tu `main` va phai merge ngược ve `dev` sau khi phat hanh.
- `dev` la overlay/moi truong phat trien; `release/*` dung cho staging/UAT; `main` la production.
- `.github/workflows/infra-cd.yml` chi tu dong validate/audit tren push va pull request.
- Terraform `plan`, `apply` va `destroy` chi chay khi khoi dong `workflow_dispatch` thu cong.
- Chon `layer=all` de apply theo thu tu `00-networking -> 01-kubernetes -> 02-data -> 03-storage -> 04-observability -> cloudflare`.
- Chon `action=destroy` va `layer=all` de huy theo thu tu nguoc lai.
- Pipeline app nam trong repo `ticket-booking-app`; pipeline do khong chay Terraform. Backend chi cap nhat image tag trong Kustomize overlay, sau do Argo CD dong bo workload.
- Phai apply infra va bootstrap Argo CD truoc lan deploy app dau tien. Push GitOps tiep theo co the kich hoat validate repo infra, nhung khong tu dong apply cloud resources.
- Khong dung `kubectl apply -k k8s/base` song song voi Argo CD vi se tao hai nguon desired state.

## 7. Argo CD GitOps

Argo CD manifests live in `argocd/`.

- `argocd/bootstrap`: project and environment-specific root Applications (`ticketstage-root` for dev, `ticketstage-root-staging`, `ticketstage-root-prod`).
- `argocd/applications/dev`, `staging`, `prod`: one child Application per cluster environment.
- `ticketstage-dev`: syncs `k8s/overlays/dev` from branch `dev` with automated prune and self-heal.
- `ticketstage-staging`: syncs `k8s/overlays/staging` from branch `dev` with automated prune and self-heal.
- `ticketstage-prod`: syncs `k8s/overlays/prod` from branch `main` with manual sync.

Each environment has its own cluster; apply only that environment's root. All child Applications ignore `spec.replicas` on Deployments (`ignoreDifferences` + `RespectIgnoreDifferences=true`) so self-heal does not undo HPA/KEDA scaling.

```bash
kubectl create namespace argocd
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.3/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server
# Default bootstrap is dev. For staging/prod, apply ticketstage-project.yaml
# and the matching ticketstage-root-<environment>.yaml instead.
kubectl apply -k argocd/bootstrap
```

Application runtime secrets are intentionally not stored in Git. Create `ticketstage-secrets` or connect External Secrets before the first sync.

**How backend releases reach the cluster.** The app repo's backend pipeline never touches the cluster directly. After pushing images to ECR it checks out this repo and runs `kustomize edit set image` on `k8s/overlays/<env>/kustomization.yaml` (branch `dev` for dev and staging, `main` for prod), then commits and pushes. Argo CD rolls dev/staging out automatically; prod waits for a manual sync. Rollback = revert that commit. `kustomize edit` rewrites the file and drops YAML comments in it.

Required on the app repo: secret `INFRA_REPO_TOKEN` (fine-grained token with `contents: write` on this repo; branch protection on `dev`/`main` must allow it to push) and optionally variable `INFRA_REPOSITORY` (default `PlatypusInAHat/ticket-infra`).

---

## 8. Local Terraform Init Helper

To initialize a specific AWS Terraform layer with the correct remote backend values, run:

```powershell
pwsh .\aws\terraform\scripts\init-layer.ps1 -Environment dev -Layer 01-kubernetes
pwsh .\aws\terraform\scripts\init-layer.ps1 -Environment dev -Layer all
```

The script reads `TF_STATE_BUCKET`, `TF_STATE_REGION`, and `TF_LOCK_TABLE` from your environment if you do not pass them explicitly, then runs `terraform init` and `terraform validate` for each layer (failing fast if either fails).

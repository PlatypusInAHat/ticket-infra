# TicketStage Cloud Infrastructure

Tài liệu này mô tả toàn bộ kiến trúc hạ tầng (Infrastructure) cho hệ thống **TicketStage** (Ứng dụng đặt vé), bao gồm cấu hình AWS bằng Terraform, Kubernetes manifests, và cấu hình bảo mật trên Cloudflare.

---

## 1. Kiến Trúc Tổng Quan (Architecture)

Hệ thống được thiết kế theo mô hình microservices, chạy trên nền tảng AWS và được bảo vệ bởi Cloudflare:

1. **Cloudflare**: Hoạt động như lớp bảo mật đầu tiên (DNS proxy), cung cấp DDoS Protection, Web Application Firewall (WAF), Bot Management và Rate Limiting.
2. **Frontend**: Các static assets (React/Vite) được lưu trữ trên **Amazon S3** và phân phối toàn cầu qua **Amazon CloudFront** với độ trễ cực thấp.
3. **Backend Microservices**: Triển khai dưới dạng các container bên trong **Amazon EKS (Elastic Kubernetes Service)**.
4. **Networking**: Public traffic đi từ Cloudflare vào Kubernetes qua **AWS Load Balancer Controller** và Ingress, không còn ALB Terraform riêng.
5. **Database (MongoDB Atlas)**: Lưu trữ dữ liệu chính. Có thiết lập Private Endpoint (VPC Peering) để đảm bảo kết nối bảo mật từ EKS.
6. **Message Queue (RabbitMQ)**: Amazon MQ xử lý hàng đợi tin nhắn bất đồng bộ, đặc biệt là trong luồng Đặt vé (Booking) có lưu lượng truy cập cao. KEDA được sử dụng để tự động scale (HPA) các worker pods dựa trên chiều dài của queue.
7. **Observability**: CloudWatch Log Groups, Alarms, và Metrics để giám sát toàn hệ thống. Trên Kubernetes có cài đặt `kube-prometheus-stack` (Prometheus, Grafana).

---

## 2. Terraform Structure (Infrastructure as Code)

Cấu trúc mã Terraform (`infra/aws/terraform`) được tổ chức theo mô hình **Layered Architecture** để dễ quản lý state và giảm thiểu rủi ro khi apply:

### Các Layers
- **`00-networking`**: VPC, Subnets, NAT Gateways, và Security Groups.
- **`01-kubernetes`**: EKS Cluster, Node Groups (System On-Demand & App Spot instances), OIDC, và IAM Roles.
- **`02-data`**: MongoDB Atlas (Database) và Amazon MQ (RabbitMQ).
- **`03-storage`**: Amazon S3, CloudFront (Frontend hosting), và ECR (Container Registry). Các cấu hình bảo mật ứng dụng được quản lý qua AWS Secrets Manager.
- **`04-observability`**: CloudWatch Dashboards, Log Groups, Metric Alarms, và SNS Topics để nhận cảnh báo.

### Các Môi Trường (Environments)
Chúng tôi sử dụng 3 môi trường chính, quản lý bằng các file `.tfvars`:
- `dev`: Dành cho phát triển. Chạy 1 node duy nhất, database nhỏ.
- `staging`: Môi trường kiểm thử. Sử dụng Multi-AZ, cấu hình tương đồng production nhưng scale nhỏ hơn.
- `prod`: Môi trường thực tế. HA hoàn toàn, sử dụng Mix On-Demand và Spot instances để tối ưu chi phí nhưng vẫn đảm bảo hiệu năng cao với KEDA autoscaling.

---

## 3. Kubernetes Structure (K8s)

Cấu trúc thư mục `infra/k8s/`:

- **Base (`k8s/base`)**: Chứa manifests tiêu chuẩn (Deployment, Service, ConfigMap, HPA, PDB) cho các microservices backend.
- **Autoscaling (`k8s/autoscaling`)**: Định nghĩa `ScaledObject` của KEDA để scale dãn pods dựa trên RabbitMQ queue depth. 
- **Ingress**: Định nghĩa Ingress rule trỏ về Service trong Kubernetes; AWS ALB được tạo tự động bởi Load Balancer Controller.

---

## 4. Cloudflare Security

Cấu hình Cloudflare được lưu tại `infra/cloudflare`:
- **WAF Custom Rules**: Chặn các requests rác (scanner paths như `/.env`, `/wp-admin`). Challenge bằng CAPTCHA đối với các endpoint nhạy cảm (như `/api/payment`).
- **Rate Limiting**: Hạn chế số lượng requests để chống Brute-force Login và Spam Booking API.

---

## 5. Deployment Quickstart & Checklist

### Yêu cầu cài đặt
- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5.0
- [AWS CLI](https://aws.amazon.com/cli/) đã được config credentials.
- [kubectl](https://kubernetes.io/docs/tasks/tools/) và [Helm](https://helm.sh/docs/intro/install/).

### Trình tự Deploy Terraform
Do thiết kế Layered, bạn **bắt buộc** phải deploy theo thứ tự từ `00` đến `04`:

1. Chạy helper init cho từng layer:
   - `pwsh .\aws\terraform\scripts\init-layer.ps1 -Environment dev -Layer 00-networking`
   - `pwsh .\aws\terraform\scripts\init-layer.ps1 -Environment dev -Layer 01-kubernetes`
   - `pwsh .\aws\terraform\scripts\init-layer.ps1 -Environment dev -Layer 02-data`
   - `pwsh .\aws\terraform\scripts\init-layer.ps1 -Environment dev -Layer 03-storage`
   - `pwsh .\aws\terraform\scripts\init-layer.ps1 -Environment dev -Layer 04-observability`
2. Sau khi init xong, chạy `terraform apply -var-file="../../environments/dev/terraform.tfvars"` trong đúng thư mục layer tương ứng.

### Trình tự Deploy K8s
1. Cập nhật kubeconfig: `aws eks update-kubeconfig --name <cluster-name> --region <region>`
2. Cài đặt KEDA: `helm install keda kedacore/keda --namespace keda --create-namespace`
3. Cài đặt Prometheus Stack: `helm install prometheus prometheus-community/kube-prometheus-stack`
4. Apply ứng dụng: `kubectl apply -k infra/k8s/base`

### Checklist Trước Khi Lên Production
- [ ] AWS Secrets Manager: Đảm bảo đã cập nhật đầy đủ thông tin credentials (MongoDB, JWT, Payment, Email).
- [ ] MongoDB Atlas: Kiểm tra lại IP Whitelist và VPC Peering trạng thái *Active*.
- [ ] Cloudflare: Bật `Proxy (Orange Cloud)` cho tất cả DNS records của Web và API. Nâng Security Level lên `High` nếu chuẩn bị mở bán vé lớn.
- [ ] Load Testing: Đã chạy kịch bản K6/JMeter để kiểm chứng KEDA scale-out worker pods khi RabbitMQ queue tăng đột biến.

---

## 6. Argo CD GitOps

Argo CD manifests live in `argocd/`.

- `argocd/bootstrap`: one-time bootstrap resources for the Argo CD namespace.
- `argocd/applications`: app-of-apps child Applications.
- `ticketstage-dev`: syncs `k8s/overlays/dev` from branch `dev` with automated prune and self-heal.
- `ticketstage-prod`: syncs `k8s/overlays/prod` from branch `main` with manual sync.

Bootstrap after installing Argo CD:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server
kubectl apply -k argocd/bootstrap
```

Application runtime secrets are intentionally not stored in Git. Create `ticketstage-secrets` or connect External Secrets before the first sync.

---

## 7. Local Terraform Init Helper

To initialize a specific AWS Terraform layer with the correct remote backend values, run:

```powershell
pwsh .\aws\terraform\scripts\init-layer.ps1 -Environment dev -Layer 01-kubernetes
pwsh .\aws\terraform\scripts\init-layer.ps1 -Environment dev -Layer all
```

The script reads `TF_STATE_BUCKET`, `TF_STATE_REGION`, and `TF_LOCK_TABLE` from your environment if you do not pass them explicitly, then runs `terraform init` and `terraform validate` for each layer.

# modules/eks

Provisions the EKS control plane and everything tightly coupled to it:

- **Cluster** (`cluster.tf`) — Kubernetes `1.34`, private-only API endpoint,
  control-plane logging, KMS envelope encryption of secrets, cluster IAM role
  (with `AmazonEKSClusterPolicy` + `AmazonEKSVPCResourceController`).
- **Managed node group** (`nodes.tf`) — EC2 nodes in the private subnets, node
  IAM role (worker + CNI + ECR-readonly), and the node security group.
- **IRSA** (`irsa.tf`) — the cluster OIDC provider so service accounts can
  assume IAM roles.
- **SSM bastion** (`bastion.tf`) — reach the private API via Session Manager;
  no key pair, no inbound SSH.
- **EBS CSI driver** (`ebs_csi.tf`) — managed add-on + IRSA role for
  EBS-backed PersistentVolumes.
- **AWS Load Balancer Controller IRSA** (`lb_controller.tf`) — the IAM role +
  policy the controller assumes. **The controller itself is NOT installed by
  Terraform** (see below).

## Infra layer vs. Kubernetes layer

Terraform provisions the **infrastructure prerequisites** only. The controllers,
CRDs, and routing objects live at the **Kubernetes layer** and are installed
with Helm/kubectl (or GitOps) **after** `terraform apply`.

| Concern | Created by Terraform? |
| ------- | --------------------- |
| EKS cluster, nodes, IRSA/OIDC, KMS, bastion | ✅ yes |
| EBS CSI driver add-on + its IRSA role | ✅ yes |
| LB Controller **IRSA role + IAM policy** | ✅ yes |
| LB Controller **install (pods)** | ❌ no — Helm |
| Gateway API CRDs | ❌ no — kubectl/Helm |
| `GatewayClass` / `Gateway` / `HTTPRoute` | ❌ no — kubectl |
| Application `Deployment` / `Service` (ClusterIP) | ❌ no — kubectl |

## Ingress strategy: Kubernetes Gateway API (not nginx-ingress)

Gateway API is a **specification** (CRDs); it needs a **controller** to
implement it. On AWS that controller is the **AWS Load Balancer Controller
(LBC)** — it replaces nginx-ingress, and it provisions a real **ALB** from a
`Gateway` resource. Backend Services are **`ClusterIP`**; the ALB sends traffic
directly to pod IPs (IP target mode), and the LBC manages the backend security
group ingress at runtime (which is why the node SG needs no static NodePort
rule).

LBC Gateway API support is GA since **v3.0.0**, so install a v3.x chart.

## Post-provision sequence (run once per cluster, after `terraform apply`)

Use the module outputs for the role ARNs.

### 0. Point kubectl at the cluster

The API is private-only, so reach it through the SSM bastion (Session Manager
port-forward / SSM tunnel), then:

```bash
aws eks update-kubeconfig --name <cluster_name> --region ap-south-1
```

### 1. Install the AWS Load Balancer Controller (Helm, v3.x)

Annotate its service account with the IRSA role ARN from the
`lb_controller_role_arn` output:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<cluster_name> \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<lb_controller_role_arn> \
  --set region=ap-south-1 \
  --set vpcId=<vpc_id>
```

> The service account name must match `var.lb_controller_service_account`
> (default `aws-load-balancer-controller`), since the IRSA trust policy is
> scoped to `system:serviceaccount:kube-system:aws-load-balancer-controller`.

### 2. Install the Gateway API CRDs

```bash
kubectl apply -f \
  "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml"
```

### 3. Create a GatewayClass backed by the LBC

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: alb
spec:
  controllerName: gateway.k8s.aws/alb
```

### 4. Create a Gateway (provisions the ALB) and HTTPRoutes

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: shopverse
  namespace: shopverse
spec:
  gatewayClassName: alb
  listeners:
    - name: http
      protocol: HTTP
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: shopverse-routes
  namespace: shopverse
spec:
  parentRefs:
    - name: shopverse
  rules:
    - matches:
        - path: { type: PathPrefix, value: / }
      backendRefs:
        - name: shopverse-frontend   # ClusterIP Service
          port: 80
    - matches:
        - path: { type: PathPrefix, value: /api }
      backendRefs:
        - name: shopverse-backend    # ClusterIP Service
          port: 80
```

For HTTPS, add a `443` listener referencing an ACM certificate ARN (an ACM cert
+ DNS validation can optionally be added to the Terraform infra layer later).

## EBS storage

The EBS CSI driver is installed, but EKS still defaults to a `gp2`
StorageClass. Most teams add a `gp3` StorageClass (often marked default) via a
Kubernetes manifest — a cluster-config step, not Terraform.

## Toggles

| Variable | Default | Effect |
| -------- | ------- | ------ |
| `enable_irsa` | `true` | create the cluster OIDC provider (required by the two toggles below) |
| `enable_ebs_csi` | `true` | install the EBS CSI driver add-on + IRSA role |
| `enable_lb_controller` | `true` | create the LB Controller IRSA role + IAM policy |

> Keep `lb_controller_iam_policy.json` in sync with the controller version you
> install: refresh it from that release tag's `docs/install/iam_policy.json`.

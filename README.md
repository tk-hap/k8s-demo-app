## Kubernetes Demo App Overview

This fork/repo demonstrates packaging and operating the Petclinic application on Kubernetes using a GitOps-friendly, layered manifest structure.

### Repository Structure (K8s Assets)
```
k8s/
  app/
    base/          # Kustomize base (deployment, service, ingress, hpa, db cluster, network policy)
    envs/
      dev/         # Dev overlays 
      prod/        # Prod overlays
  addons/          # Cluster level addons (ingress-nginx, metrics-server, cloudnative-pg operator)
  argocd/          # ArgoCD ApplicationSets for deploying Petclinic app and addons
```

| Requirement | Implementation | Key Manifests |
|-------------|----------------|---------------|
| Define containers/pods | Deployment for web app | `k8s/app/base/frontend/deployment.yaml` |
| Expose service | ClusterIP Service | `k8s/app/base/frontend/service.yaml` |
| External access | NGINX Ingress | `k8s/app/base/frontend/ingress.yaml` |
| Persistent database | CloudNativePG Cluster (PostgreSQL) | `k8s/app/base/db/cluster.yaml` + operator via `k8s/argocd/cluster-addons-appset.yaml` |
| Configuration / Env | Spring profile + JDBC secret reference | `deployment.yaml` (env vars) |
| Layered configuration | Base + env overlays (dev/prod) | `k8s/app/envs/*` |
| Best practices | Readiness probe, resource requests/limits, separate Service/Ingress | `deployment.yaml`, `service.yaml`, `ingress.yaml` |
| Attach Persistent Database | Managed PostgreSQL via CloudNativePG; PVC implicit through operator | `k8s/app/base/db/cluster.yaml` |
| Implement Autoscaling | HPA (CPU-based) with env-specific thresholds | `k8s/app/base/frontend/hpa.yaml`, `envs/dev/prod/hpa.yaml` |
| Implement Load Balancing | Ingress with class `nginx` + ingress-nginx controller addon | `frontend/ingress.yaml`, `addons/cluster-addons-appset.yaml` |
| Rolling Updates & Rollbacks | Native Deployment strategy (RollingUpdate default) + image tag overlay for progressive releases | `deployment.yaml`, `envs/dev/version.yaml` |
| Network Policies | Fine-grained ingress/egress limiting app->DB & DNS only | `frontend/networkpolicy.yaml` |
| Enable Monitoring (metrics) | Metrics-server + HPA; Postgres PodMonitor enabled | `addons/applicationset.yaml`, `db/cluster.yaml` |
| GitOps Automation | Argo CD ApplicationSet manages addons; (app overlays compatible with Argo CD / Kustomize) | `k8s/argocd/cluster-addons-appset.yaml`, `k8s/argocd/petclinic-appset.yaml` |

### Not (Yet) Implemented (Future Enhancements)
| Area | Potential Next Step |
|------|---------------------|
| Logging and Metrics | kube-prometheus-stack + Fluent Bit DaemonSet |
| Secrets Management | External Secrets Operator |
| Progressive Delivery | Argo Rollouts for canary / blue‑green |


### Quick Start (Local / Minikube)
```bash
# Start minikube with the calico driver for network policies 
minikube start --cni=calico

# Install argocd
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply addons
kubectl apply -n argocd -f k8s/argocd/cluster-addons-appset.yaml

# Apply app envs
kubectl apply -n argocd -f k8s/argocd/petclinic-appset.yaml

# Once synced, start minikube tunnel to get ingress IP
minikube tunnel
kubectl get service -n ingress-nginx


# Update /etc/hosts with ingress-nginx EXTERNAL IP and check the endpoint

```


## CI/CD Overview (GitHub Actions)

GitOps-style workflow using GithubActions and ArgoCD

### 1. Continuous Integration & Dev Image Update (`.github/workflows/ci.yaml`)
Triggers:
- Push to `main` (excluding `.github/workflows/**` and `k8s/**`)
- Manual dispatch

Pipeline steps:
1. Checkout source
2. Login to GHCR
3. Generate image metadata (short SHA tag)  
4. Build & push image: `ghcr.io/<owner>/petclinic:<short-sha>`
5. Patch `k8s/app/envs/dev/version.yaml` with new image tag
6. Commit the updated dev version file back to `main`

 Dev environment always tracks the latest successful build via ArgoCD autosync.

### 2. Manual Promotion to Prod (`.github/workflows/promote-to-prod.yaml`)
Trigger: Manual (`workflow_dispatch`) with optional `image_tag` input.

Steps:
1. Copy `k8s/app/envs/dev/version.yaml` → `k8s/app/envs/prod/version.yaml`
2. (Optional) Overwrite tag if `image_tag` provided
3. Commit the prod version file back to `main`

Promotion is and decoupled from build events an easily auditable.

### Rollback
Two options:
- `git revert` the commit that changed the `version.yaml` in the target env
- Manually edit `version.yaml` to a previous immutable SHA tag and commit

Kubernetes `Deployment` handles rolling back to the prior ReplicaSet automatically.

### License / Attribution
Original application copyright per upstream. Kubernetes deployment manifests authored for this demo.

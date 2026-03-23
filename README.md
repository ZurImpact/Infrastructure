# K8s Infrastructure Repo
The K8s Infrastructure repository for the PM4 project ZürImpact

## Branching Rules
* **Features:** `feature/<initials>/<jira-ticket-nr>/<name>`
* **Bugfixes:** `bugfix/<initials>/<jira-ticket-nr>/<name>`
* **Releases:** `release/<version>`

## Repo Structure
We organize this repository by component. Each application has its own dedicated folder containing the necessary deployment configurations.
```bash
.
├── README.md
├── backend/              # Internal app: Plain YAML + Kustomize overlays
│   ├── base/               # Core manifests (Deployment, Service)
│   └── overlays/           # Environment patches
│       ├── staging/
│       └── prod/
└── postgres/             # External app: Helm values files
    ├── Chart.yaml           # Defines the upstream dependency
    ├── values.yaml          # Shared base configuration
    ├── values_zi-prod.yaml  # Prod-specific overrides
    └── values_zi-staging.yaml # Staging-specific overrides
```
## Deploying Applications
We use two different strategies for deploying applications depending on whether they are external third-party services or our own internal applications.

### ArgoCD

The ArgoCD applications need to be created via the UI (we don't have access via the kubernetes API).

ArgoCD UI: https://argocd.pm4.init-lab.ch

How to fetch the login credentials:
```bash
$ k get secret bamc-zi-student-credentials -n zi-prod -o jsonpath='{.data.username}' | base64 --decode
```
```bash
$ k get secret bamc-zi-student-credentials -n zi-prod -o jsonpath='{.data.password}' | base64 --decode
```
**Example Application using Kustomize**
```yaml
project: bamc-zi
source:
  repoURL: https://github.zhaw.ch/ZurImpact/Infrastructure.git
  path: myapp/overlays/staging
  targetRevision: main
destination:
  server: https://kubernetes.default.svc
  namespace: zi-staging
```
**Example Application using Helm**
```yaml
project: bamc-zi
source:
  repoURL: https://github.zhaw.ch/ZurImpact/Infrastructure.git
  path: myapp
  targetRevision: main
  helm:
    valueFiles:
      - values.yaml
      - values_zi-staging.yaml
destination:
  server: https://kubernetes.default.svc
  namespace: zi-staging

```
### External Services (Using Helm)
For third-party services (e.g., databases, monitoring), we utilize **Helm**. You can find upstream charts on [ArtifactHub](https://artifacthub.io/).

Instead of storing the entire Helm chart in this repository, ArgoCD pulls the chart directly from the official registry and merges it with our custom values files stored here.

**Configuration Rules:**
For each Helm-based application, create the following files in its dedicated folder:
* `values.yaml`: The global configuration that applies to all environments.
* `values_zi-<env>.yaml`: The environment-specific overrides (e.g., increasing storage or replicas for production).
* `Chart.yaml`: The HelmChart which the application uses

### Internal Applications (Using Kustomize)

For our own applications (Frontend, Backend), we use plain Kubernetes YAML manifests managed by **Kustomize**.

To adhere to DRY (Don't Repeat Yourself) principles and minimize configuration drift between environments, Kustomize allows us to define a standard set of resources and patch them with environment-specific changes, rather than copying and pasting YAML files.

**How Kustomize Works:**
Our Kustomize setup is divided into two main concepts: **Base** and **Overlays**.

```bash
my-app/
├── base/
│   ├── deployment.yaml
│   └── kustomization.yaml
└── overlays/
    └── prod/
        └── kustomization.yaml
```
* **Base (`/base`):** This folder contains the core Kubernetes manifests (`Deployment`, `Service`, `Ingress`) that are identical across all environments.
* **Overlays (`/overlays/<env>`):** This folder contains environment-specific modifications. The `kustomization.yaml` here inherits everything from the base folder and applies specific patches (e.g., changing resource limits, updating image tags, or increasing replica counts).

## Local Development Setup
## Local Development Setup

We use [Minikube](https://minikube.sigs.k8s.io/docs/start/) to spin up a local Kubernetes environment.

In the `tools` folder, you can find the setup scripts which you can run on your machine to configure the local Kubernetes setup and spin up the required applications (like our PostgreSQL database).

### Running the Setup Scripts

The scripts will automatically verify your dependencies, create an isolated `zi-staging` namespace, securely prompt you for a database password, and deploy the required Helm charts.

**On Windows (PowerShell):**
If you run into execution policy errors, use the following command to bypass them temporarily:
```ps1
powershell.exe -ExecutionPolicy Bypass -File .\tools\setup-dev-env.ps1`
```

**On Linux (Bash):**
Make sure the script is executable, then run it:
```bash
chmod +x ./tools/setup-dev-env.sh
./tools/setup-dev-env.sh
```

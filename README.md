# n8n GCP Platform Accelerator

This repository is a Terraform accelerator for deploying **enterprise-grade n8n** on Google Cloud Platform. It is engineered for security-first, always-on operation with full Infrastructure-as-Code governance—ideal for platform teams that want n8n living natively inside their cloud footprint.

## 🏗️ System Architecture

Terraform orchestrates the entire surface: Cloud Run, Cloud SQL (private IP), Secret Manager, IAM, and the Serverless VPC connector. The platform follows isolation and least-privilege patterns end to end.

```text
                 +------------------+
    (User)   --->|     INTERNET     |---> (HTTPS) ---> [ Cloud Run: n8n Service ]
                 +------------------+                    |
                                                         | (1) Auth via SA + Secret Manager
                                                         v
    +----------------------------------------------------v---------------------------------------------------+
    | GCP Project: agents-workforce                                                                         |
    |                                                                                                       |
    |                               +---------------------------+                                           |
    |                               |  IAM: Service Account     |                                           |
    |                               |         (n8n-sa)          |                                           |
    |                               +-------------+-------------+                                           |
    |                                             |     (4) Least Privilege                                 |
    |           +---------------------------------+---------------------------------+                       |
    |           | (2) Access Secrets              | (3) Reach Private Database       |                       |
    |           v                                 v                                 v                       |
    | +---------------------+           +---------------------+           +--------------------------+      |
    | |   Secret Manager    |           |   Cloud SQL         |           |   Logging / Monitoring   |      |
    | | (Passwords, Keys)   |           |   (Private IP)      |           |   Artifact Registry      |      |
    | +---------------------+           +----------+----------+           +--------------------------+      |
    |                                       ^  Serverless VPC Connector                                   |
    |                                       |                                                             |
    |  (Engineer) --> [Cloud SQL Auth Proxy] (TLS admin path)                                             |
    +-------------------------------------------------------------------------------------------------------+
```

- **`Google Cloud Run`**: Hosts n8n with `min_instances = 1`, `timeout = 600s`, `startup_cpu_boost = true`, 1 vCPU and 2 GiB RAM. The container listens on port 5678 (official image default).
- **`Google Cloud SQL`**: PostgreSQL (`db-f1-micro`) with *no public IP*. Only reachable through a private address inside the `default` VPC; external admins connect via Cloud SQL Auth Proxy.
- **`Google Secret Manager`**: Owns every secret—passwords, encryption keys, Basic Auth credentials—fetched dynamically at runtime.
- **`Serverless VPC Access`**: Dedicated connector (`n8n-connector`, CIDR `10.8.0.0/28`) that routes Cloud Run traffic into the private subnet without exposing Cloud SQL publicly.
- **`IAM & Service Accounts`**: The `n8n-sa` account carries only `cloudsql.client`, `secretmanager.secretAccessor`, and `logging.logWriter`.

## ✨ Design Principles

This repository encodes platform-grade patterns—not one-off scripts.

1. **Security by Design**
   - **No hardcoded credentials**: Every secret lives in Secret Manager.
   - **Least Privilege**: Minimal IAM surface for runtime operations.
   - **Network Isolation**: Database uses private IP only; all productive traffic flows through the serverless connector.

2. **Infrastructure as Code**
   - Everything is declared in Terraform—repeatable, auditable, versioned.
   - No console-driven drift required for future changes.

3. **Modularity & Reuse**
   - Logical separation (`run.tf`, `sql.tf`, `network.tf`, `secrets.tf`) makes this codebase a drop-in accelerator for other teams.

---

## 🚀 Deployment Workflow

Provisioning is fully automated with Terraform. Expect ~10–15 minutes on first run (Cloud SQL boot dominates).

### 1. Prime your shell (≈1 min)

```bash
cd n8n-gcp-tf

# Replace with your GCP project
export TF_VAR_project_id="your-project-id"
export TF_VAR_region="us-central1"
```

### 2. Authenticate with Google Cloud (≈1 min)

```bash
gcloud auth login
gcloud auth application-default login

gcloud config set project $TF_VAR_project_id
```

### 3. Provision the stack (≈8–13 min)

```bash
terraform init
terraform plan
terraform apply
```

**Deployment order under the hood**
1. Required APIs are enabled.
2. Cloud SQL (Postgres) provisions with PITR backups.
3. Secrets are generated in Secret Manager.
4. Cloud Run deploys the container, wires secrets, and enables startup probes plus the VPC connector.

### 4. Retrieve credentials & log in (≈1 min)

Terraform outputs the Cloud Run URL and the Basic Auth user. Fetch the password from Secret Manager:

```bash
gcloud secrets versions access latest --secret="N8N_BASIC_AUTH_PASSWORD"
```

Open the `run_url`, sign in, and complete the n8n bootstrap wizard.

---

## 💰 Cost Architecture (Estimated Monthly)

| Component | Specification | Cost (USD) | Notes |
| --------- | ------------- | ---------- | ----- |
| **Cloud Run** | 1 instance (1 vCPU, 2 GiB RAM) 24/7 | ~$90.00 | Always-on workloads with CPU boost and higher RAM for ETL spikes. |
| **Cloud SQL** | `db-f1-micro`, 10 GB SSD, PITR enabled | ~$11.58 | Managed Postgres with private IP only. |
| **Support Services** | Secret Manager, Logging, Artifact Registry | ~$0.00 | Fits comfortably in the free tier under this profile. |
| **Network Egress** | Outbound traffic from Cloud Run | <$1.00 | Usage dependent; negligible for dev/test. |
| **Total** | | **~$102 USD / month** | ≈ 1,734 MXN @ 17 MXN/USD. |

## 📂 Project Structure

```
├── versions.tf       # Provider pinning
├── variables.tf      # User-configurable parameters
├── main.tf           # Core IAM + API enablement
├── sql.tf            # Cloud SQL (private IP, backups)
├── network.tf        # Serverless VPC Access connector
├── run.tf            # Cloud Run service definition
├── secrets.tf        # Secret Manager setup
└── outputs.tf        # URLs and sensitive outputs
```

## 🔧 Configuration Surface

Key variables in `variables.tf`:

- `project_id`: Target GCP project (required).
- `region`: Region (default `us-central1`).
- `min_instances`, `max_instances`: Cloud Run scaling floor/ceiling (default `1`/`1`).
- `db_tier`: Cloud SQL tier (`db-f1-micro` default).
- `timezone`: n8n timezone (`America/Mexico_City` default).
- `webhook_url`: External URL for editor & webhooks (`https://n8n.edgardo.com.mx/` default).
- `n8n_user_management_disabled`: Disables additional-user wizard (`true` default).
- `vpc_connector_name`, `vpc_connector_cidr`: Serverless VPC Access connector parameters.

### Optional public URL alignment

After the first deploy you can explicitly align the public URLs:

```bash
RUN_URL="https://n8n-xxxxx-uc.a.run.app"

gcloud run services update n8n \
  --region "$TF_VAR_region" \
  --set-env-vars N8N_PUBLIC_URL="$RUN_URL",N8N_EDITOR_BASE_URL="$RUN_URL",WEBHOOK_URL="$RUN_URL"
```

## 🔐 Security Surface

- **Basic Auth** guards the UI out of the box.
- **TLS** covers every hop (Cloud Run enforces HTTPS, the connector speaks TLS to Cloud SQL).
- **Private Database** means no public IP exposure.
- **Secrets** are centralized (Secret Manager) and rotated via Terraform.
- **IAM** is tightly scoped—no wildcard roles.

## 🛠️ Useful Commands

```bash
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=n8n" --limit 50
```

Manual scaling:

```bash
gcloud run services update n8n --min-instances=1 --max-instances=3 --region=$TF_VAR_region
```

Destroy everything:

```bash
terraform destroy
```

## ⚙️ Lifecycle Management

Operate the platform with the same rigor you deployed it.

### Upgrade n8n

```terraform
variable "n8n_image" {
  description = "n8n Docker image"
  type        = string
  default     = "docker.io/n8nio/n8n:latest" # e.g. docker.io/n8nio/n8n:1.45.1
}
```

```bash
terraform apply
```

Cloud Run performs a rolling update—no downtime.

### Scale the footprint

- **Compute**: adjust `min_instances`, `max_instances`, or CPU/RAM limits.
- **Networking**: adapt `vpc_connector_cidr` or provision a new connector if your VPC map evolves.
- **Database**: bump `db_tier`, storage size, or add high availability as workloads grow.

### Decommission

```bash
terraform destroy
```

Destroys Cloud Run, Cloud SQL, secrets, and IAM bindings (irreversible).

## 📞 Support & References

- [n8n Documentation](https://docs.n8n.io/)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Secret Manager Documentation](https://cloud.google.com/secret-manager/docs)
- [Cloud SQL Private IP Guide](https://cloud.google.com/sql/docs/postgres/private-ip)

## ⚖️ Build vs Buy: Self-Hosted vs n8n Enterprise Cloud

| Criterion | Self-Hosted on GCP (This Template) | n8n Enterprise Cloud (SaaS) |
| :--- | :--- | :--- |
| **Control & Customization** | Full control over runtime, networking, IAM, observability. | Managed abstraction; limited deep customization. |
| **Cost Model** | Pay only for the GCP resources consumed. | Subscription covers infra, platform, and support. |
| **Operational Overhead** | Your team owns upgrades, monitoring, incident response. | Managed by n8n SRE with SLA-backed support. |
| **Security & Compliance** | Tailor to your policies (private IP, custom VPC, IAM hardening). | Vendor-managed compliance posture. |
| **Enterprise Features** | OSS feature set; community support only. | Add-ons (SSO, RBAC, audit logs) plus enterprise support. |

**Verdict:**  
This accelerator is for platform architects who want n8n embedded inside their GCP estate with precision control over security, networking, and automation. If your priority is a turnkey experience with managed SLAs, n8n Enterprise Cloud remains the alternative.

## Troubleshooting

- **Cloud Run fails with `PORT` / database errors**  
  - Confirm the Serverless VPC connector (`n8n-connector`) is attached.
  - Allow the connector CIDR (`10.8.0.0/28`) to reach Cloud SQL via firewall.
  - Ensure `run.googleapis.com/cloudsql-instances` matches `project:region:instance`.
  - Verify secrets exist and the service account owns `secretmanager.secretAccessor`.

- **APIs not enabled yet**  
  - API enablement can lag a couple of minutes. Retry `terraform apply` once they finish propagating.

- **Drift detected after console edits**  
  - Run `terraform plan` to inspect; either revert manually or codify the change in Terraform to keep the state clean.
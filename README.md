# DevOps Infrastructure Automation Task — GCP Flask Stack

## Overview

This project demonstrates an end-to-end **Infrastructure as Code (IaC)** deployment using **Terraform**, **Docker**, and **GitHub Actions**, hosted on **Google Cloud Platform (GCP)**.

It provisions a **three-tier web application stack** consisting of:
- **NGINX Load Balancer**
- **Flask Web Application**
- **PostgreSQL Database**

Each component runs in its own **Compute Engine instance** built on **Container-Optimized OS (Container-Optimized OS)** for security, performance, and self-healing capability.

---

##  Repository Structure

```
.
├── .git-crypt/
│   └── keys/
│       └── default/
│           └── <GPG key files>
├── .github/
│   └── workflows/
│       ├── docker-build.yml
│       └── terraform.yml
├── terraform/
│   ├── database_server.tf
│   ├── load_balancer.tf
│   ├── network.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── web_server.tf
│   ├── terraform.tfstate
│   └── terraform.tfstate.backup
├── .gitattributes
├── .gitignore
├── Dockerfile
├── requirements.txt
├── web_app.py
├── git-crypt-key.b64
└── README.md
```

---

##  CI/CD Workflows

###  Build and Push Docker Image  
**File:** `.github/workflows/docker-build.yml`  
**Trigger:** When a Pull Request is merged and labeled `CI:Build`

This workflow builds the Flask Docker image and pushes it to GitHub Container Registry (`ghcr.io/<username>/gcp-flask-app`) with both `:latest` and commit-SHA tags.

---

### Terraform Deployment  
**File:** `.github/workflows/terraform.yml`  
**Trigger:** Manual workflow dispatch  
**Inputs:** `plan`, `apply`, or `destroy`

This workflow:
- Unlocks encrypted state with **git-crypt**
- Authenticates to GCP via `GOOGLE_CREDENTIALS`
- Runs Terraform plan/apply/destroy
- Commits updated encrypted state files back to GitHub

---

## Running Terraform Locally or via CI/CD

Terraform can be executed in two ways:

### From GitHub Actions (CI/CD)

Run it from the **Actions** tab:
1. Select **Terraform Deploy**  
2. Click **Run workflow**  
3. Choose one of the options:
   - `plan` → Preview changes  
   - `apply` → Deploy infrastructure  
   - `destroy` → Tear down resources  

---

### From Local Machine

1. Update your branch:
   ```bash
   git checkout master
   git pull
   ```

2. Unlock **git-crypt** to access Terraform state:
   ```bash
   git-crypt unlock
   ```

3. Move to the Terraform directory:
   ```bash
   cd terraform
   ```

4. Either create a **terraform.tfvars** file:
   ```hcl
   project_id  = ""
   region      = ""
   db_user     = ""
   db_password = ""
   db_name     = ""
   alert_email = ""
   ```
   or export environment variables:
   ```bash
   export TF_VAR_project_id=<YOUR_PROJECT_ID>
   export TF_VAR_region=<YOUR_REGION>
   export TF_VAR_db_user=<USERNAME>
   export TF_VAR_db_password=<PASSWORD>
   export TF_VAR_db_name=<DB_NAME>
   export TF_VAR_alert_email=<EMAIL_FOR_RECIVING_ALERTS>
   ```

5. Authenticate to GCP:
   ```bash
   gcloud auth login
   ```

6. Run Terraform:
   ```bash
   terraform init
   terraform plan
   terraform apply
   terraform destroy
   ```

---

## git-crypt Integration

Sensitive Terraform state files are encrypted with **git-crypt** to ensure confidentiality, even in public repositories.

### Adding Users or Creating a Collaboration Key

Either:
```bash
git-crypt add-gpg-user your_pgp_email@something.com
```
or (if the collaborator’s key isn’t imported yet):

1. **Obtain the user’s public key** (`.asc`, `.gpg`, or `.txt` file)  
2. **Import the key**:
   ```bash
   gpg --import /path/to/filename.asc
   ```
3. **Set trust level**:
   ```bash
   gpg --edit-key your_pgp_email@something.com
   gpg> trust
   (choose 5 = ultimate)
   gpg> q
   ```
4. **Add user to git-crypt**:
   ```bash
   git-crypt add-gpg-user --trusted your_pgp_email@something.com
   ```
5. **Commit and push**:
   ```bash
   git add .git-crypt
   git commit -m "Add new git-crypt user"
   git push
   ```

  **Reference:**  
[git-crypt Official Documentation and Example Repository](https://github.com/OpeningDesign/encryption-test/tree/master)

---

## Failover, Self-Healing, and Backup Automation

This infrastructure implements multi-layer resilience, automatic fail-over, and data recovery automation using a combination of GCP features and Container-Optimized OS restart policies.

### VM-Level Self-Healing (Compute Engine)

Each Compute Engine VM (`web_server`, `load_balancer`, `postgres_database`) includes the following configuration:

```hcl
scheduling {
  automatic_restart   = true
  on_host_maintenance = "MIGRATE"
}
```

- `automatic_restart = true`  
  → Automatically restarts the VM if it crashes or stops unexpectedly.  
- `on_host_maintenance = "MIGRATE"`  
  → During GCP host maintenance, the instance live-migrates to another host without downtime.  

> **By default**, both of these properties are set to `true` in GCP instances, meaning that all newly created instances automatically benefit from these behaviors even if you don’t explicitly configure them.
[Official Documentation] (https://registry.terraform.io/providers/hashicorp/google/6.50.0/docs/resources/compute_instance)

---

### Container-Level Resilience (Container-Optimized OS)

Each Compute Engine VM runs Docker containers using **Container-Optimized OS (Container-Optimized OS)**.  
Container-Optimized OS provides automatic container restarts and lightweight isolation.

All containers (Flask app, PostgreSQL, NGINX) include:
```yaml
restartPolicy: Always
```

This ensures:
- Containers automatically restart if the application process crashes or exits unexpectedly.
- Flask containers define a Docker `HEALTHCHECK` that probes the `/healthz` endpoint every 30 seconds.
- If the health check fails repeatedly, Container-Optimized OS restarts the container automatically.

Example from Dockerfile:
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3   CMD curl -fsS http://localhost:${PORT}/healthz || exit 1
```

---

### Data Backup and Recovery (Automated Snapshots)

The PostgreSQL database instance is protected with an automated **daily snapshot policy**, ensuring data durability and simplified recovery in case of corruption or accidental loss.

```hcl
resource "google_compute_resource_policy" "daily_snapshots" {
  name   = "daily-snapshots"
  region = var.region

  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1
        start_time    = "03:00"
      }
    }

    retention_policy {
      max_retention_days    = 7
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"
    }
  }
}

resource "google_compute_disk_resource_policy_attachment" "snap_db_boot" {
  name = google_compute_resource_policy.daily_snapshots.name
  disk = google_compute_instance.postgres_database.name
  zone = "${var.region}-a"
}
```

---

### Cloud Monitoring and Alerting for Database Connectivity

To improve observability and ensure database connectivity, the infrastructure integrates **Google Cloud Monitoring** to track the availability of the Flask application's `/db-check` endpoint.

#### Features:
- **Uptime Check** — Periodically tests the `/db-check` HTTP endpoint exposed via the load balancer.  
- **Alert Policy** — Triggers an email alert if the Flask app cannot connect to the PostgreSQL database for over 2 minutes.  
- **Notification Channel** — Sends automated alerts to a configured email address defined in Terraform.  

This proactive monitoring approach ensures that both application health and database connectivity are continuously observed, and immediate alerts are delivered when failures occur.

---

### Testing the Deployment

After running `terraform apply`, verify deployment status:

```bash
gcloud compute instances list
```

Then test your endpoints:

```bash
curl http://<LOAD_BALANCER_EXTERNAL_IP>/
curl http://<LOAD_BALANCER_EXTERNAL_IP>/healthz
curl http://<LOAD_BALANCER_EXTERNAL_IP>/db-check
```

Expected responses:
- `/` → `{"message":"Hello from the app"}`
- `/healthz` → `ok`
- `/db-check` → PostgreSQL version output
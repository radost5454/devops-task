resource "google_compute_instance" "postgres_database" {
  name         = "postgres-database"
  machine_type = "e2-micro"
  zone         = "${var.region}-a"
  tags         = ["database"]

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
      size  = 10
    }
  }

  network_interface {
    network = google_compute_network.main_network.self_link
    access_config {}
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  metadata = {
    "gce-container-declaration" = <<-EOT
      spec:
        containers:
          - name: postgres
            image: postgres:15
            env:
              - name: POSTGRES_USER
                value: ${var.db_user}
              - name: POSTGRES_PASSWORD
                value: ${var.db_password}
              - name: POSTGRES_DB
                value: ${var.db_name}
            securityContext:
              privileged: true
            ports:
              - name: db
                hostPort: 5432
                containerPort: 5432
        restartPolicy: Always
    EOT
  }
}

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

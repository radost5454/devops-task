# PostgreSQL database VM using Container-Optimized OS
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

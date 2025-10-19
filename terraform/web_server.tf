resource "google_compute_instance" "web_server" {
  name         = "flask-web-server"
  machine_type = "e2-micro"
  zone         = "${var.region}-a"
  tags         = ["web"]

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
      size  = 10
    }
  }

  network_interface {
    network = google_compute_network.main_network.self_link
    # access_config {} 
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  metadata = {
    "gce-container-declaration" = <<-EOT
      spec:
        containers:
          - name: flask-app
            image: ghcr.io/radost5454/gcp-flask-app:latest
            env:
              - name: DB_HOST
                value: ${google_compute_instance.postgres_database.network_interface[0].network_ip}
              - name: DB_NAME
                value: ${var.db_name}
              - name: DB_USER
                value: ${var.db_user}
              - name: DB_PASS
                value: ${var.db_password}
              - name: DB_PORT
                value: "5432"
            ports:
              - name: http
                containerPort: 8080
        restartPolicy: Always
    EOT
  }


  depends_on = [google_compute_instance.postgres_database]
}

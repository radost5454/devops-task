resource "google_compute_instance" "load_balancer" {
  name         = "nginx-load-balancer"
  machine_type = "e2-micro"
  zone         = "${var.region}-a"
  tags         = ["load-balancer"]

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
      size  = 10
    }
  }

  network_interface {
    network = google_compute_network.main_network.self_link
    access_config {} # assign public IP
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  metadata = {
    "gce-container-declaration" = <<-EOT
      spec:
        containers:
          - name: nginx
            image: nginx:1.27
            command:
              - sh
              - -c
              - |
                cat <<'CONF' > /etc/nginx/conf.d/default.conf
                server {
                  listen 80;
                  location / {
                    proxy_pass http://${google_compute_instance.web_server.network_interface[0].network_ip}:8080;
                  }
                  location /healthz {
                    proxy_pass http://${google_compute_instance.web_server.network_interface[0].network_ip}:8080/healthz;
                  }
                  location /db-check {
                    proxy_pass http://${google_compute_instance.web_server.network_interface[0].network_ip}:8080/db-check;
                  }
                }
                CONF
                exec nginx -g 'daemon off;'
            ports:
              - hostPort: 80
                containerPort: 80
        restartPolicy: Always
    EOT
  }

  depends_on = [google_compute_instance.web_server]
}

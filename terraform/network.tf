resource "google_compute_network" "main_network" {
  name                    = "project-network"
  auto_create_subnetworks = true
}

# resource "google_compute_router" "nat_router" {
#   name    = "nat-router"
#   network = google_compute_network.main_network.name
#   region  = var.region
# }

# resource "google_compute_router_nat" "nat_config" {
#   name                               = "nat-config"
#   router                             = google_compute_router.nat_router.name
#   region                             = var.region

#   nat_ip_allocate_option             = "AUTO_ONLY"
#   source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
# }


resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.main_network.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  source_ranges = ["10.128.0.0/9"]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.main_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["load-balancer", "web", "database"]
}

resource "google_compute_firewall" "allow_http_lb" {
  name    = "allow-http-lb"
  network = google_compute_network.main_network.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["load-balancer"]
}


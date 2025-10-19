resource "google_compute_network" "main_network" {
  name                    = "project-network"
  auto_create_subnetworks = true
}

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

resource "google_compute_firewall" "allow_google_healthchecks" {
  name    = "allow-google-healthchecks"
  network = google_compute_network.main_network.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]

  target_tags = ["load-balancer"]
}
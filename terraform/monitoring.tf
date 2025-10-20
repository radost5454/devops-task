resource "google_monitoring_notification_channel" "email" {
  display_name = "DevOps Alerts Email"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }
}

resource "google_monitoring_uptime_check_config" "flask_dbcheck" {
  display_name = "Flask /db-check"
  timeout      = "10s"
  period       = "60s"

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = google_compute_instance.load_balancer.network_interface[0].access_config[0].nat_ip
    }
  }

  http_check {
    path           = "/db-check"
    port           = 80
    request_method = "GET"
    validate_ssl   = false
  }

  selected_regions = ["USA"]
}

resource "google_monitoring_alert_policy" "flask_db_alert" {
  display_name = "ALERT: Flask /db-check Failing"
  combiner     = "OR"

  notification_channels = [google_monitoring_notification_channel.email.id]

  conditions {
    display_name = "Database connectivity check failed"
    condition_threshold {
      filter = "resource.type=\"uptime_url\" AND metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "120s"

      trigger {
        count = 1
      }
    }
  }
}


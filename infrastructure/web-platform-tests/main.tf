# https://github.com/hashicorp/terraform/issues/17399
provider "google-beta" {}

module "wpt-servers" {
  # https://github.com/GoogleCloudPlatform/terraform-google-managed-instance-group/pull/39
  source            = "github.com/dcaba/terraform-google-managed-instance-group"
  providers {
    google-beta = "google-beta"
  }
  version           = "1.1.13"
  region            = "${var.region}"
  zone              = "${var.zone}"
  name              = "${var.network_name}-group1"
  size              = 2
  compute_image     = "${var.wpt_server_machine_image}"
  instance_labels   = "${var.wpt_server_instance_labels}"
  metadata          = "${var.wpt_server_instance_metadata}"
  service_port      = 80
  service_port_name = "http"
  ssh_fw_rule       = false
  http_health_check = false
  target_pools      = ["${module.wpt-server-balancer.target_pool}"]
  target_tags       = ["allow-service1"]
  network           = "${var.network_name}"
  subnetwork        = "${var.subnetwork_name}"
}

module "cert-renewers" {
  # https://github.com/GoogleCloudPlatform/terraform-google-managed-instance-group/pull/39
  source            = "github.com/dcaba/terraform-google-managed-instance-group"
  providers {
    google-beta = "google-beta"
  }
  region            = "${var.region}"
  zone              = "${var.zone}"
  name              = "${var.network_name}-group2"
  size              = 1
  compute_image     = "${var.cert_renewer_machine_image}"
  instance_labels   = "${var.cert_renewer_instance_labels}"
  metadata          = "${var.cert_renewer_instance_metadata}"
  service_port      = 8004
  service_port_name = "http"
  ssh_fw_rule       = false
  http_health_check = false
  target_pools      = ["${module.cert-renewer-balancer.target_pool}"]
  target_tags       = ["allow-service1"]
  network           = "${var.network_name}"
  subnetwork        = "${var.subnetwork_name}"
}

resource "google_storage_bucket" "persistance" {
  name = "${var.bucket_name}"
}

resource "google_compute_address" "web-platform-tests-live-address" {
  name = "web-platform-tests-live-address"
}

module "wpt-server-balancer" {
  source       = "../load-balancer"
  region       = "${var.region}"
  name         = "${var.network_name}-wpt"
  service_port = "${module.wpt-servers.service_port}"
  target_tags  = ["${module.wpt-servers.target_tags}"]
  network      = "${var.network_name}"
  ip_address   = "${google_compute_address.web-platform-tests-live-address.address}"
  session_affinity = "CLIENT_IP_PROTO"
}

module "cert-renewer-balancer" {
  source       = "../load-balancer"
  region       = "${var.region}"
  name         = "${var.network_name}-tls"
  service_port = "${module.cert-renewers.service_port}"
  target_tags  = ["${module.cert-renewers.target_tags}"]
  network      = "${var.network_name}"
  ip_address   = "${google_compute_address.web-platform-tests-live-address.address}"
  session_affinity = "CLIENT_IP_PROTO"
}

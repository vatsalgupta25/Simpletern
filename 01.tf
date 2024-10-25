provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "simpletern"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-south1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "asis-south1"
}

variable "cluster_name" {
  description = "GKE Cluster Name"
  type        = string
  default     = "simpletern-cluster"
}

variable "artifact_registry_name" {
  description = "Artifact Registry Repository Name"
  type        = string
  default     = "simpletern-repo"
}


resource "google_project_service" "container" {
  service = "container.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "artifactregistry" {
  service = "artifactregistry.googleapis.com"
  disable_dependent_services = true
}

resource "google_artifact_registry_repository" "docker_repo" {
  provider = google
  location = var.region
  repository_id = var.artifact_registry_name
  description = "Docker repository for Flask application"
  format = "DOCKER"
  depends_on = [google_project_service.artifactregistry]
}

resource "google_compute_network" "vpc" {
  name                    = "gke-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "gke-subnet"
  ip_cidr_range = "10.0.0.0/24"
  network       = google_compute_network.vpc.name
  region        = var.region

  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "192.168.1.0/24"
  }

  secondary_ip_range {
    range_name    = "pod-ranges"
    ip_cidr_range = "192.168.64.0/22"
  }
}

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone
  
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pod-ranges"
    services_secondary_range_name = "services-range"
  }

  depends_on = [google_project_service.container]
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "${google_container_cluster.primary.name}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 3

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      env = "dev"
    }

    machine_type = "e2-small"
    disk_size_gb = 30
    disk_type    = "pd-standard"

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

resource "google_service_account" "gke_sa" {
  account_id   = "gke-pull-sa"
  display_name = "GKE Pull Service Account"
}

resource "google_project_iam_member" "artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}

data "google_client_config" "default" {}

# Kubernetes Deployment
resource "kubernetes_deployment" "flask_app" {
  metadata {
    name = "flask-app"
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "flask-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "flask-app"
        }
      }

      spec {
        container {
          image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_name}/flask-app:latest"
          name  = "flask-app"

          port {
            container_port = 5000
          }
        }
      }
    }
  }

  depends_on = [google_container_node_pool.primary_nodes]
}

resource "kubernetes_service" "flask_app" {
  metadata {
    name = "flask-service"
  }

  spec {
    selector = {
      app = kubernetes_deployment.flask_app.spec.0.template.0.metadata.0.labels.app
    }

    port {
      port        = 80
      target_port = 5000
    }

    type = "LoadBalancer"
  }
}


output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "artifact_registry_repository" {
  value = google_artifact_registry_repository.docker_repo.name
}

output "load_balancer_ip" {
  value = kubernetes_service.flask_app.status.0.load_balancer.0.ingress.0.ip
}

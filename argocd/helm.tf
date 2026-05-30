locals {
  default_values = {
    global = {
      domain = null
    }

    configs = {
      params = {
        "server.insecure" = false
      }
    }

    server = {
      service = {
        type = var.server_service_type
      }
    }
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
  atomic           = true
  wait             = true
  timeout          = 600

  values = [
    yamlencode(merge(local.default_values, var.values)),
  ]
}

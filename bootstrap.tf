data "aws_partition" "current" {}

locals {
  argocd_repo_secret_id = var.argocd_repo_secret_id != "" ? var.argocd_repo_secret_id : "${var.name}/github/repo"
}

data "aws_secretsmanager_secret" "argocd_repo" {
  count = var.enable_bastion && var.enable_bastion_argocd_bootstrap ? 1 : 0

  name = local.argocd_repo_secret_id
}

resource "aws_eks_access_entry" "bastion_admin" {
  count = var.enable_bastion ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = module.bastion[0].role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion_admin" {
  count = var.enable_bastion ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = module.bastion[0].role_arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bastion_admin]
}

resource "aws_security_group_rule" "bastion_to_eks_api" {
  count = var.enable_bastion ? 1 : 0

  type                     = "ingress"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = module.bastion[0].security_group_id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "Allow private bastion kubectl access to the EKS API"
}

resource "aws_ssm_document" "argocd_bootstrap" {
  count = var.enable_bastion && var.enable_bastion_argocd_bootstrap ? 1 : 0

  name          = "${var.name}-argocd-bootstrap"
  document_type = "Command"
  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Install Argo CD on the private EKS cluster from the bastion host."
    parameters = {
      bootstrapRevision = {
        type        = "String"
        description = "Revision marker used to force State Manager reruns."
        default     = "1"
      }
    }
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "installArgoCD"
        inputs = {
          timeoutSeconds = "1200"
          runCommand = [
            "set -euo pipefail",
            "echo bootstrap revision '{{ bootstrapRevision }}'",
            "for attempt in $(seq 1 60); do if command -v aws >/dev/null 2>&1 && command -v kubectl >/dev/null 2>&1 && command -v helm >/dev/null 2>&1; then break; fi; echo \"waiting for aws, kubectl, and helm to be installed\"; sleep 10; done",
            "for binary in aws kubectl helm; do command -v \"$binary\" >/dev/null 2>&1 || { echo \"$binary was not installed after waiting\"; exit 1; }; done",
            "export KUBECONFIG=/root/.kube/config",
            "mkdir -p /root/.kube",
            "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}",
            "helm repo add argo https://argoproj.github.io/argo-helm || true",
            "helm repo update argo",
            "if helm -n ${var.argocd_namespace} status argocd >/dev/null 2>&1; then",
            "  echo 'Argo CD Helm release already exists; skipping Helm install/upgrade during bootstrap rerun'",
            "else",
            "  helm upgrade --install argocd argo/argo-cd --version ${var.argocd_chart_version} --namespace ${var.argocd_namespace} --create-namespace --wait --timeout 10m --set server.service.type=${var.argocd_server_service_type}",
            "fi",
            "kubectl -n ${var.argocd_namespace} rollout status deployment/argocd-server --timeout=300s",
            "if [ -n '${local.argocd_repo_secret_id}' ]; then",
            "  SECRET_JSON=$(aws secretsmanager get-secret-value --region ${var.aws_region} --secret-id '${local.argocd_repo_secret_id}' --query SecretString --output text)",
            "  REPO_URL='${var.argocd_repo_url}'",
            "  if [ -z \"$REPO_URL\" ]; then REPO_URL=$(printf '%s' \"$SECRET_JSON\" | jq -r '.${var.argocd_repo_url_key}'); fi",
            "  REPO_USERNAME=$(printf '%s' \"$SECRET_JSON\" | jq -r '.${var.argocd_repo_username_key} // \"x-access-token\"')",
            "  REPO_PASSWORD=$(printf '%s' \"$SECRET_JSON\" | jq -r '.${var.argocd_repo_password_key}')",
            "  test -n \"$REPO_URL\" && test \"$REPO_URL\" != \"null\"",
            "  test -n \"$REPO_PASSWORD\" && test \"$REPO_PASSWORD\" != \"null\"",
            "  kubectl -n ${var.argocd_namespace} create secret generic argocd-root-repo --dry-run=client -o yaml --from-literal=type=git --from-literal=url=\"$REPO_URL\" --from-literal=username=\"$REPO_USERNAME\" --from-literal=password=\"$REPO_PASSWORD\" | kubectl label --local -f - --dry-run=client -o yaml argocd.argoproj.io/secret-type=repository | kubectl apply -f -",
            "  if [ -n '${var.argocd_root_app_manifest_path}' ]; then",
            "    rm -rf /tmp/argocd-root-repo",
            "    cat >/tmp/argocd-git-askpass <<'ASKPASS'",
            "#!/bin/sh",
            "case \"$1\" in",
            "  *Username*) printf '%s\\n' \"$GIT_USERNAME\" ;;",
            "  *Password*) printf '%s\\n' \"$GIT_PASSWORD\" ;;",
            "esac",
            "ASKPASS",
            "    chmod 700 /tmp/argocd-git-askpass",
            "    if [ '${var.argocd_root_app_target_revision}' = 'HEAD' ]; then",
            "      GIT_ASKPASS=/tmp/argocd-git-askpass GIT_USERNAME=\"$REPO_USERNAME\" GIT_PASSWORD=\"$REPO_PASSWORD\" git clone --depth 1 \"$REPO_URL\" /tmp/argocd-root-repo",
            "    else",
            "      GIT_ASKPASS=/tmp/argocd-git-askpass GIT_USERNAME=\"$REPO_USERNAME\" GIT_PASSWORD=\"$REPO_PASSWORD\" git clone --depth 1 --branch ${var.argocd_root_app_target_revision} \"$REPO_URL\" /tmp/argocd-root-repo",
            "    fi",
            "    kubectl apply -f /tmp/argocd-root-repo/${var.argocd_root_app_manifest_path}",
            "  else",
            "  cat <<EOF | kubectl apply -f -",
            "apiVersion: argoproj.io/v1alpha1",
            "kind: Application",
            "metadata:",
            "  name: ${var.argocd_root_app_name}",
            "  namespace: ${var.argocd_namespace}",
            "spec:",
            "  project: default",
            "  source:",
            "    repoURL: $REPO_URL",
            "    targetRevision: ${var.argocd_root_app_target_revision}",
            "    path: ${var.argocd_root_app_path}",
            "  destination:",
            "    server: https://kubernetes.default.svc",
            "    namespace: ${var.argocd_root_app_destination_namespace}",
            "  syncPolicy:",
            "    automated:",
            "      prune: true",
            "      selfHeal: true",
            "    syncOptions:",
            "      - CreateNamespace=true",
            "EOF",
            "  fi",
            "fi",
          ]
        }
      }
    ]
  })
}

resource "aws_ssm_association" "argocd_bootstrap" {
  count = var.enable_bastion && var.enable_bastion_argocd_bootstrap ? 1 : 0

  name = aws_ssm_document.argocd_bootstrap[0].name

  parameters = {
    bootstrapRevision = var.argocd_bootstrap_revision
  }

  targets {
    key    = "InstanceIds"
    values = [module.bastion[0].instance_id]
  }

  wait_for_success_timeout_seconds = 1200

  depends_on = [
    aws_eks_access_policy_association.bastion_admin,
    aws_security_group_rule.bastion_to_eks_api,
    module.eks,
  ]
}

locals {
  karpenter_manifest_files = sort(fileset(path.module, "karpenter/*.yaml"))
  karpenter_manifests      = join("\n---\n", [for manifest in local.karpenter_manifest_files : file("${path.module}/${manifest}")])
}

resource "aws_ssm_document" "argocd_bootstrap" {
  count = var.enable_bastion_bootstrap ? 1 : 0

  name          = "${var.cluster_name}-argocd-bootstrap"
  document_type = "Command"
  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Bootstrap the private EKS cluster from the bastion host."
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
        name   = "bootstrapCluster"
        inputs = {
          timeoutSeconds = "1200"
          runCommand = concat(
            ["set -euo pipefail", "cat >/tmp/eks-bootstrap.sh <<'BOOTSTRAP_SCRIPT'"],
            split("\n", file("${path.module}/scripts/eks-bootstrap.sh")),
            ["BOOTSTRAP_SCRIPT", "cat >/tmp/karpenter-defaults.yaml <<'KARPENTER_DEFAULTS'"],
            split("\n", local.karpenter_manifests),
            [
              "KARPENTER_DEFAULTS",
              "chmod 700 /tmp/eks-bootstrap.sh",
              join(" ", [
                "BOOTSTRAP_REVISION='{{ bootstrapRevision }}'",
                "AWS_REGION='${var.aws_region}'",
                "CLUSTER_NAME='${aws_eks_cluster.this.name}'",
                "VPC_ID='${var.vpc_id}'",
                "ENABLE_BASTION_KARPENTER_BOOTSTRAP='${var.enable_bastion_karpenter_bootstrap}'",
                "ENABLE_BASTION_AWS_LOAD_BALANCER_CONTROLLER_BOOTSTRAP='${var.enable_bastion_aws_load_balancer_controller_bootstrap}'",
                "ENABLE_BASTION_ARGOCD_BOOTSTRAP='${var.enable_bastion_argocd_bootstrap}'",
                "ENABLE_DEFAULT_KARPENTER_NODEPOOLS='${var.enable_default_karpenter_nodepools}'",
                "KARPENTER_NAMESPACE='${var.karpenter_namespace}'",
                "KARPENTER_CHART_VERSION='${var.karpenter_chart_version}'",
                "KARPENTER_SERVICE_ACCOUNT_NAME='${var.karpenter_service_account_name}'",
                "KARPENTER_INTERRUPTION_QUEUE_NAME='${aws_sqs_queue.karpenter_interruption.name}'",
                "KARPENTER_NODE_ROLE_NAME='${aws_iam_role.karpenter_nodes.name}'",
                "AWS_LOAD_BALANCER_CONTROLLER_NAMESPACE='${var.aws_load_balancer_controller_namespace}'",
                "AWS_LOAD_BALANCER_CONTROLLER_CHART_VERSION='${var.aws_load_balancer_controller_chart_version}'",
                "AWS_LOAD_BALANCER_CONTROLLER_SERVICE_ACCOUNT_NAME='${var.aws_load_balancer_controller_service_account_name}'",
                "ARGOCD_NAMESPACE='${var.argocd_namespace}'",
                "ARGOCD_CHART_VERSION='${var.argocd_chart_version}'",
                "ARGOCD_SERVER_SERVICE_TYPE='${var.argocd_server_service_type}'",
                "ARGOCD_REPO_SECRET_ID='${var.argocd_repo_secret_id}'",
                "ARGOCD_REPO_URL='${var.argocd_repo_url}'",
                "ARGOCD_REPO_URL_KEY='${var.argocd_repo_url_key}'",
                "ARGOCD_REPO_USERNAME_KEY='${var.argocd_repo_username_key}'",
                "ARGOCD_REPO_PASSWORD_KEY='${var.argocd_repo_password_key}'",
                "ARGOCD_ROOT_APP_NAME='${var.argocd_root_app_name}'",
                "ARGOCD_ROOT_APP_PATH='${var.argocd_root_app_path}'",
                "ARGOCD_ROOT_APP_MANIFEST_PATH='${var.argocd_root_app_manifest_path}'",
                "ARGOCD_ROOT_APP_TARGET_REVISION='${var.argocd_root_app_target_revision}'",
                "ARGOCD_ROOT_APP_DESTINATION_NAMESPACE='${var.argocd_root_app_destination_namespace}'",
                "/tmp/eks-bootstrap.sh",
              ]),
            ]
          )
        }
      }
    ]
  })
}

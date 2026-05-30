data "aws_partition" "current" {}

locals {
  argocd_repo_secret_id = var.argocd_repo_secret_id != "" ? var.argocd_repo_secret_id : "${var.name}/github/repo"
  enable_bastion_bootstrap = var.enable_bastion && (
    var.enable_bastion_argocd_bootstrap ||
    var.enable_bastion_karpenter_bootstrap ||
    var.enable_bastion_aws_load_balancer_controller_bootstrap
  )
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
  count = local.enable_bastion_bootstrap ? 1 : 0

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
            "if [ '${var.enable_bastion_karpenter_bootstrap}' = 'true' ]; then",
            "  if helm -n ${var.karpenter_namespace} status karpenter >/dev/null 2>&1; then",
            "    echo 'Karpenter Helm release already exists; skipping Helm install/upgrade during bootstrap rerun'",
            "  else",
            "    helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter --version ${var.karpenter_chart_version} --namespace ${var.karpenter_namespace} --create-namespace --wait --timeout 10m --set settings.clusterName=${module.eks.cluster_name} --set settings.interruptionQueue=${module.eks.karpenter_interruption_queue_name} --set serviceAccount.name=${var.karpenter_service_account_name} --set replicas=1 --set controller.resources.requests.cpu=250m --set controller.resources.requests.memory=512Mi --set controller.resources.limits.cpu=500m --set controller.resources.limits.memory=512Mi",
            "  fi",
            "  kubectl -n ${var.karpenter_namespace} rollout status deployment/karpenter --timeout=300s",
            "  kubectl wait --for condition=Established crd/nodepools.karpenter.sh crd/ec2nodeclasses.karpenter.k8s.aws --timeout=300s",
            "  if [ '${var.enable_default_karpenter_nodepools}' = 'true' ]; then",
            "    cat <<'EOF' | kubectl apply -f -",
            "apiVersion: karpenter.k8s.aws/v1",
            "kind: EC2NodeClass",
            "metadata:",
            "  name: primary",
            "spec:",
            "  role: ${module.eks.karpenter_node_role_name}",
            "  amiFamily: AL2023",
            "  amiSelectorTerms:",
            "    - alias: al2023@latest",
            "  subnetSelectorTerms:",
            "    - tags:",
            "        karpenter.sh/discovery: ${module.eks.cluster_name}",
            "  securityGroupSelectorTerms:",
            "    - tags:",
            "        karpenter.sh/discovery: ${module.eks.cluster_name}",
            "  tags:",
            "    karpenter.sh/discovery: ${module.eks.cluster_name}",
            "    workload: primary",
            "---",
            "apiVersion: karpenter.sh/v1",
            "kind: NodePool",
            "metadata:",
            "  name: primary",
            "spec:",
            "  template:",
            "    metadata:",
            "      labels:",
            "        workload: primary",
            "    spec:",
            "      nodeClassRef:",
            "        group: karpenter.k8s.aws",
            "        kind: EC2NodeClass",
            "        name: primary",
            "      requirements:",
            "        - key: kubernetes.io/arch",
            "          operator: In",
            "          values: [\"amd64\"]",
            "        - key: karpenter.sh/capacity-type",
            "          operator: In",
            "          values: [\"on-demand\"]",
            "        - key: node.kubernetes.io/instance-type",
            "          operator: In",
            "          values: [\"m6i.large\", \"m6i.xlarge\", \"m7i.large\", \"m7i.xlarge\"]",
            "  limits:",
            "    cpu: \"32\"",
            "    memory: 128Gi",
            "  disruption:",
            "    consolidationPolicy: WhenEmptyOrUnderutilized",
            "    consolidateAfter: 5m",
            "---",
            "apiVersion: karpenter.k8s.aws/v1",
            "kind: EC2NodeClass",
            "metadata:",
            "  name: ml",
            "spec:",
            "  role: ${module.eks.karpenter_node_role_name}",
            "  amiFamily: AL2023",
            "  amiSelectorTerms:",
            "    - alias: al2023@latest",
            "  subnetSelectorTerms:",
            "    - tags:",
            "        karpenter.sh/discovery: ${module.eks.cluster_name}",
            "  securityGroupSelectorTerms:",
            "    - tags:",
            "        karpenter.sh/discovery: ${module.eks.cluster_name}",
            "  tags:",
            "    karpenter.sh/discovery: ${module.eks.cluster_name}",
            "    workload: ml",
            "---",
            "apiVersion: karpenter.sh/v1",
            "kind: NodePool",
            "metadata:",
            "  name: ml",
            "spec:",
            "  template:",
            "    metadata:",
            "      labels:",
            "        workload: ml",
            "        gpu: \"true\"",
            "    spec:",
            "      taints:",
            "        - key: workload",
            "          value: ml",
            "          effect: NoSchedule",
            "      nodeClassRef:",
            "        group: karpenter.k8s.aws",
            "        kind: EC2NodeClass",
            "        name: ml",
            "      requirements:",
            "        - key: kubernetes.io/arch",
            "          operator: In",
            "          values: [\"amd64\"]",
            "        - key: karpenter.sh/capacity-type",
            "          operator: In",
            "          values: [\"on-demand\"]",
            "        - key: node.kubernetes.io/instance-type",
            "          operator: In",
            "          values: [\"g5.xlarge\", \"g5.2xlarge\", \"g6.xlarge\", \"g6.2xlarge\"]",
            "  limits:",
            "    nvidia.com/gpu: \"4\"",
            "    cpu: \"64\"",
            "    memory: 256Gi",
            "  disruption:",
            "    consolidationPolicy: WhenEmptyOrUnderutilized",
            "    consolidateAfter: 5m",
            "EOF",
            "  fi",
            "fi",
            "if [ '${var.enable_bastion_aws_load_balancer_controller_bootstrap}' = 'true' ]; then",
            "  helm repo add eks https://aws.github.io/eks-charts || true",
            "  helm repo update eks",
            "  if helm -n ${var.aws_load_balancer_controller_namespace} status aws-load-balancer-controller >/dev/null 2>&1; then",
            "    echo 'AWS Load Balancer Controller Helm release already exists; skipping Helm install/upgrade during bootstrap rerun'",
            "  else",
            "    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller --version ${var.aws_load_balancer_controller_chart_version} --namespace ${var.aws_load_balancer_controller_namespace} --create-namespace --wait --timeout 10m --set clusterName=${module.eks.cluster_name} --set region=${var.aws_region} --set vpcId=${module.vpc.vpc_id} --set serviceAccount.create=true --set serviceAccount.name=${var.aws_load_balancer_controller_service_account_name} --set replicaCount=1",
            "  fi",
            "  kubectl -n ${var.aws_load_balancer_controller_namespace} rollout status deployment/aws-load-balancer-controller --timeout=300s",
            "fi",
            "if [ '${var.enable_bastion_argocd_bootstrap}' = 'true' ]; then",
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
            "fi",
          ]
        }
      }
    ]
  })
}

resource "aws_ssm_association" "argocd_bootstrap" {
  count = local.enable_bastion_bootstrap ? 1 : 0

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

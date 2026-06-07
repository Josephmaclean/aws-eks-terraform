#!/usr/bin/env bash
set -euo pipefail

echo "bootstrap revision ${BOOTSTRAP_REVISION}"

for attempt in $(seq 1 60); do
  if command -v aws >/dev/null 2>&1 && command -v kubectl >/dev/null 2>&1 && command -v helm >/dev/null 2>&1; then
    break
  fi
  echo "waiting for aws, kubectl, and helm to be installed"
  sleep 10
done

for binary in aws kubectl helm; do
  command -v "$binary" >/dev/null 2>&1 || {
    echo "$binary was not installed after waiting"
    exit 1
  }
done

export KUBECONFIG=/root/.kube/config
mkdir -p /root/.kube
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

install_karpenter() {
  if helm -n "$KARPENTER_NAMESPACE" status karpenter >/dev/null 2>&1; then
    echo "Karpenter Helm release already exists; skipping Helm install/upgrade during bootstrap rerun"
  else
    helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
      --version "$KARPENTER_CHART_VERSION" \
      --namespace "$KARPENTER_NAMESPACE" \
      --create-namespace \
      --wait \
      --timeout 10m \
      --set "settings.clusterName=$CLUSTER_NAME" \
      --set "settings.interruptionQueue=$KARPENTER_INTERRUPTION_QUEUE_NAME" \
      --set "serviceAccount.name=$KARPENTER_SERVICE_ACCOUNT_NAME" \
      --set replicas=1 \
      --set controller.resources.requests.cpu=250m \
      --set controller.resources.requests.memory=512Mi \
      --set controller.resources.limits.cpu=500m \
      --set controller.resources.limits.memory=512Mi
  fi

  kubectl -n "$KARPENTER_NAMESPACE" rollout status deployment/karpenter --timeout=300s
  kubectl wait --for condition=Established crd/nodepools.karpenter.sh crd/ec2nodeclasses.karpenter.k8s.aws --timeout=300s

  if [ "$ENABLE_DEFAULT_KARPENTER_NODEPOOLS" = "true" ]; then
    sed \
      -e "s|__CLUSTER_NAME__|$CLUSTER_NAME|g" \
      -e "s|__KARPENTER_NODE_ROLE_NAME__|$KARPENTER_NODE_ROLE_NAME|g" \
      /tmp/karpenter-defaults.yaml | kubectl apply -f -
  fi
}

patch_argocd_finalizers() {
  for app in $(kubectl -n "$ARGOCD_NAMESPACE" get applications.argoproj.io -o name); do
    kubectl -n "$ARGOCD_NAMESPACE" patch "$app" --type merge -p '{"metadata":{"finalizers":["resources-finalizer.argocd.argoproj.io"]}}' || true
  done
}

install_argocd() {
  helm repo add argo https://argoproj.github.io/argo-helm || true
  helm repo update argo

  helm upgrade --install argocd argo/argo-cd \
    --version "$ARGOCD_CHART_VERSION" \
    --namespace "$ARGOCD_NAMESPACE" \
    --create-namespace \
    --wait \
    --timeout 10m \
    --set "server.service.type=$ARGOCD_SERVER_SERVICE_TYPE" \
    --set "configs.params.server\\.insecure=true"

  kubectl -n "$ARGOCD_NAMESPACE" rollout status deployment/argocd-server --timeout=300s

  if [ -z "$ARGOCD_REPO_SECRET_ID" ]; then
    return
  fi

  SECRET_JSON=$(aws secretsmanager get-secret-value --region "$AWS_REGION" --secret-id "$ARGOCD_REPO_SECRET_ID" --query SecretString --output text)
  REPO_URL="$ARGOCD_REPO_URL"
  if [ -z "$REPO_URL" ]; then
    REPO_URL=$(printf '%s' "$SECRET_JSON" | jq -r --arg key "$ARGOCD_REPO_URL_KEY" '.[$key]')
  fi
  REPO_USERNAME=$(printf '%s' "$SECRET_JSON" | jq -r --arg key "$ARGOCD_REPO_USERNAME_KEY" '.[$key] // "x-access-token"')
  REPO_PASSWORD=$(printf '%s' "$SECRET_JSON" | jq -r --arg key "$ARGOCD_REPO_PASSWORD_KEY" '.[$key]')

  test -n "$REPO_URL" && test "$REPO_URL" != "null"
  test -n "$REPO_PASSWORD" && test "$REPO_PASSWORD" != "null"

  kubectl -n "$ARGOCD_NAMESPACE" create secret generic argocd-root-repo \
    --dry-run=client \
    -o yaml \
    --from-literal=type=git \
    --from-literal="url=$REPO_URL" \
    --from-literal="username=$REPO_USERNAME" \
    --from-literal="password=$REPO_PASSWORD" |
    kubectl label --local -f - --dry-run=client -o yaml argocd.argoproj.io/secret-type=repository |
    kubectl apply -f -

  if [ -n "$ARGOCD_ROOT_APP_MANIFEST_PATH" ]; then
    rm -rf /tmp/argocd-root-repo
    cat >/tmp/argocd-git-askpass <<'ASKPASS'
#!/bin/sh
case "$1" in
  *Username*) printf '%s\n' "$GIT_USERNAME" ;;
  *Password*) printf '%s\n' "$GIT_PASSWORD" ;;
esac
ASKPASS
    chmod 700 /tmp/argocd-git-askpass

    if [ "$ARGOCD_ROOT_APP_TARGET_REVISION" = "HEAD" ]; then
      GIT_ASKPASS=/tmp/argocd-git-askpass GIT_USERNAME="$REPO_USERNAME" GIT_PASSWORD="$REPO_PASSWORD" git clone --depth 1 "$REPO_URL" /tmp/argocd-root-repo
    else
      GIT_ASKPASS=/tmp/argocd-git-askpass GIT_USERNAME="$REPO_USERNAME" GIT_PASSWORD="$REPO_PASSWORD" git clone --depth 1 --branch "$ARGOCD_ROOT_APP_TARGET_REVISION" "$REPO_URL" /tmp/argocd-root-repo
    fi

    kubectl apply -f "/tmp/argocd-root-repo/$ARGOCD_ROOT_APP_MANIFEST_PATH"
    patch_argocd_finalizers
    return
  fi

  cat <<ROOT_APP | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $ARGOCD_ROOT_APP_NAME
  namespace: $ARGOCD_NAMESPACE
spec:
  project: default
  source:
    repoURL: $REPO_URL
    targetRevision: $ARGOCD_ROOT_APP_TARGET_REVISION
    path: $ARGOCD_ROOT_APP_PATH
  destination:
    server: https://kubernetes.default.svc
    namespace: $ARGOCD_ROOT_APP_DESTINATION_NAMESPACE
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
ROOT_APP

  kubectl -n "$ARGOCD_NAMESPACE" patch application "$ARGOCD_ROOT_APP_NAME" --type merge -p '{"metadata":{"finalizers":["resources-finalizer.argocd.argoproj.io"]}}' || true
}

if [ "$ENABLE_BASTION_KARPENTER_BOOTSTRAP" = "true" ]; then
  install_karpenter
fi

if [ "$ENABLE_BASTION_ARGOCD_BOOTSTRAP" = "true" ]; then
  install_argocd
fi

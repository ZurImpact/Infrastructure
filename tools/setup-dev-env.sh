#!/bin/bash

check_tool() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is not installed."
        echo "Please install $1 before running this script."
        exit 1
    fi
}

check_tool "kubectl"
check_tool "helm"

echo "Checking Kubernetes context..."
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null)

if [ "$CURRENT_CONTEXT" != "minikube" ]; then
    echo "Context is set to '$CURRENT_CONTEXT'. Switching to 'minikube'..."
    if ! kubectl config use-context minikube; then
        echo "Error: Could not switch to minikube context. Is minikube running?"
        exit 1
    fi
else
    echo "Already on minikube context."
fi

NAMESPACE="zi-staging"
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "Creating namespace: $NAMESPACE..."
    kubectl create namespace "$NAMESPACE"
else
    echo "Namespace '$NAMESPACE' already exists."
fi

SECRET_NAME="postgres-admin-secret"

if kubectl get secret "$SECRET_NAME" --namespace "$NAMESPACE" &> /dev/null; then
    echo "Secret '$SECRET_NAME' already exists in namespace '$NAMESPACE'."
    echo "Skipping password prompt and extracting existing password..."

    PG_PASSWORD=$(kubectl get secret "$SECRET_NAME" --namespace "$NAMESPACE" -o jsonpath="{.data.POSTGRES_PASSWORD}" | base64 --decode)
else
    echo "Secret '$SECRET_NAME' not found. We need to create it."
    read -s -p "Enter the PostgreSQL superuser password you want to set: " PG_PASSWORD
    echo ""
    read -s -p "Confirm password: " PG_PASSWORD_CONFIRM
    echo ""

    if [ "$PG_PASSWORD" != "$PG_PASSWORD_CONFIRM" ]; then
        echo "Error: Passwords do not match. Exiting."
        exit 1
    fi

    if [ -z "$PG_PASSWORD" ]; then
        echo "Error: Password cannot be empty. Exiting."
        exit 1
    fi

    echo "Creating secret '$SECRET_NAME'..."
    kubectl create secret generic "$SECRET_NAME" \
        --namespace "$NAMESPACE" \
        --from-literal=POSTGRES_USER="postgres" \
        --from-literal=POSTGRES_PASSWORD="$PG_PASSWORD"
fi

CHART_NAME="postgres"
RELEASE_NAME="postgres"
REPO_URL="https://groundhog2k.github.io/helm-charts/"
VERSION="1.6.1"

echo "Adding Helm repository..."
helm repo add groundhog2k "$REPO_URL" --force-update &> /dev/null
helm repo update &> /dev/null

echo "Installing/Upgrading $RELEASE_NAME in namespace $NAMESPACE..."
helm upgrade --install "$RELEASE_NAME" groundhog2k/"$CHART_NAME" \
    --namespace "$NAMESPACE" \
    --version "$VERSION" \
    --set settings.existingSecret="$SECRET_NAME"

echo "Deployment complete!"

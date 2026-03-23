function Test-Tool {
    param ([string]$ToolName)
    if (-not (Get-Command $ToolName -ErrorAction SilentlyContinue)) {
        Write-Error "Error: $ToolName is not installed.`nPlease install $ToolName before running this script."
        exit 1
    }
}

Test-Tool "kubectl"
Test-Tool "helm"

Write-Host "Checking Kubernetes context..."
$CURRENT_CONTEXT = kubectl config current-context 2>$null

if ($CURRENT_CONTEXT -ne "minikube") {
    Write-Host "Context is set to '$CURRENT_CONTEXT'. Switching to 'minikube'..."
    kubectl config use-context minikube 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Error: Could not switch to minikube context. Is minikube running?"
        exit 1
    }
} else {
    Write-Host "Already on minikube context."
}

$NAMESPACE = "zi-staging"
$nsCheck = kubectl get namespace $NAMESPACE 2>$null
if (-not $nsCheck) {
    Write-Host "Creating namespace: $NAMESPACE..."
    kubectl create namespace $NAMESPACE | Out-Null
} else {
    Write-Host "Namespace '$NAMESPACE' already exists."
}

$SECRET_NAME = "postgres-admin-secret"
$secretCheck = kubectl get secret $SECRET_NAME --namespace $NAMESPACE 2>$null

if ($secretCheck) {
    Write-Host "Secret '$SECRET_NAME' already exists in namespace '$NAMESPACE'."
    Write-Host "Skipping password prompt and extracting existing password..."

    $base64Pass = kubectl get secret $SECRET_NAME --namespace $NAMESPACE -o jsonpath="{.data.POSTGRES_PASSWORD}"
    $PG_PASSWORD = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($base64Pass))
} else {
    Write-Host "Secret '$SECRET_NAME' not found. We need to create it."

    $SecurePass1 = Read-Host "Enter the PostgreSQL superuser password you want to set" -AsSecureString
    $SecurePass2 = Read-Host "Confirm password" -AsSecureString

    $BSTR1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePass1)
    $PG_PASSWORD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR1)

    $BSTR2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePass2)
    $PG_PASSWORD_CONFIRM = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR2)

    if ($PG_PASSWORD -ne $PG_PASSWORD_CONFIRM) {
        Write-Error "Error: Passwords do not match. Exiting."
        exit 1
    }

    if ([string]::IsNullOrWhiteSpace($PG_PASSWORD)) {
        Write-Error "Error: Password cannot be empty. Exiting."
        exit 1
    }

    Write-Host "Creating secret '$SECRET_NAME'..."
    kubectl create secret generic $SECRET_NAME `
        --namespace $NAMESPACE `
        --from-literal=POSTGRES_USER="postgres" `
        --from-literal=POSTGRES_PASSWORD="$PG_PASSWORD" | Out-Null
}

$CHART_NAME = "postgres"
$RELEASE_NAME = "postgres"
$REPO_URL = "https://groundhog2k.github.io/helm-charts/"
$VERSION = "1.6.1"

Write-Host "Adding Helm repository..."
helm repo add groundhog2k $REPO_URL --force-update 2>&1 | Out-Null
helm repo update 2>&1 | Out-Null

Write-Host "Installing/Upgrading $RELEASE_NAME in namespace $NAMESPACE..."

helm upgrade --install $RELEASE_NAME groundhog2k/$CHART_NAME `
    --namespace $NAMESPACE `
    --version $VERSION `
    --set settings.existingSecret=$SECRET_NAME

Write-Host "Deployment complete!"

# Zero Trust Azure Container Registry - Deployment Guide

## Overview

This deployment guide provides step-by-step instructions for implementing a production-ready Zero Trust Azure Container Registry with comprehensive security controls, AKS integration, and compliance capabilities.

## Prerequisites

### Required Tools and Access

- **Azure CLI** (v2.45.0 or later)
- **Terraform** (v1.6.0 or later)
- **kubectl** (v1.28.0 or later)
- **Helm** (v3.12.0 or later)
- **Azure subscription** with appropriate permissions
- **Azure AD tenant** administrative access

### Required Permissions

```bash
# Azure subscription roles
- Owner or Contributor + User Access Administrator
- Application Administrator (for Azure AD applications)
- Cloud Application Administrator (for service principals)
```

### Network Planning

```bash
# IP Address Space Allocation
Hub VNet: 10.0.0.0/16
├── Firewall Subnet: 10.0.1.0/24
├── Gateway Subnet: 10.0.2.0/24
├── Bastion Subnet: 10.0.3.0/24
└── Private Endpoints: 10.0.10.0/24

AKS VNet: 10.1.0.0/16
├── System Pool: 10.1.1.0/24
├── User Pool: 10.1.2.0/24
├── GPU Pool: 10.1.3.0/24
├── Private Link: 10.1.10.0/24
└── Virtual Nodes: 10.1.11.0/24

CI/CD VNet: 10.2.0.0/16
├── Build Agents: 10.2.1.0/24
└── Private Endpoints: 10.2.10.0/24
```

## Phase 1: Infrastructure Deployment

### Step 1: Environment Preparation

```bash
# Set environment variables
export ENVIRONMENT="prod"
export LOCATION="eastus2"
export COMPANY_PREFIX="contoso"
export SUBSCRIPTION_ID="your-subscription-id"
export TENANT_ID="your-tenant-id"

# Login to Azure
az login --tenant $TENANT_ID
az account set --subscription $SUBSCRIPTION_ID

# Verify access
az account show
```

### Step 2: Terraform Infrastructure Deployment

```bash
# Clone the repository
git clone <repository-url>
cd zero-trust-acr

# Initialize Terraform
cd terraform
terraform init

# Create terraform.tfvars
cat > terraform.tfvars << EOF
# Basic Configuration
environment     = "$ENVIRONMENT"
location        = "$LOCATION"
company_prefix  = "$COMPANY_PREFIX"
owner          = "platform-team@company.com"
cost_center    = "IT-Infrastructure"

# Network Security
allowed_cidr_ranges = []

# ACR Configuration
retention_days_untagged     = 7
enable_zone_redundancy      = true
geo_replication_locations   = ["westus2", "centralus"]
cmk_enabled                = true

# AKS Configuration
kubernetes_version          = "1.28"
system_node_count          = 3
user_node_count_min        = 2
user_node_count_max        = 10
node_vm_size              = "Standard_D4s_v3"
enable_auto_scaling       = true

# Security Features
enable_azure_policy           = true
enable_secret_store_csi       = true
enable_workload_identity      = true
enable_defender_for_containers = true

# Monitoring
enable_container_insights = true
enable_prometheus        = true
enable_grafana          = true
EOF

# Plan deployment
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan

# Capture outputs
terraform output > ../outputs.json
```

### Step 3: Verify Infrastructure Deployment

```bash
# Verify ACR deployment
ACR_NAME=$(terraform output -raw acr_name)
az acr show --name $ACR_NAME --query "{name:name,sku:sku.name,publicAccess:publicNetworkAccess,privateEndpoint:privateEndpointConnections[0].privateLinkServiceConnectionState.status}"

# Verify AKS deployment
AKS_NAME=$(terraform output -raw aks_cluster_name)
AKS_RG=$(terraform output -raw aks_resource_group)
az aks show --name $AKS_NAME --resource-group $AKS_RG --query "{name:name,kubernetesVersion:kubernetesVersion,privateCluster:apiServerAccessProfile.enablePrivateCluster}"

# Get AKS credentials
az aks get-credentials --name $AKS_NAME --resource-group $AKS_RG --overwrite-existing

# Verify cluster access
kubectl get nodes
kubectl get namespaces
```

## Phase 2: Security Components Deployment

### Step 4: Deploy Namespace Configuration

```bash
# Apply namespace setup
envsubst < kubernetes/namespace-setup.yaml | kubectl apply -f -

# Verify namespaces
kubectl get namespaces --show-labels
```

### Step 5: Deploy Network Policies

```bash
# Apply network policies
kubectl apply -f kubernetes/network-policies.yaml

# Verify network policies
kubectl get networkpolicies -A
```

### Step 6: Deploy Security Scanning

```bash
# Create security-system namespace
kubectl create namespace security-system

# Deploy Trivy scanner
kubectl apply -f security/trivy-config.yaml

# Deploy SBOM generation
kubectl apply -f security/sbom-generation.yaml

# Verify deployments
kubectl get pods -n security-system
kubectl get services -n security-system
```

### Step 7: Deploy Image Signing Infrastructure

```bash
# Create notary-system namespace
kubectl create namespace notary-system

# Deploy Notary v2 setup
envsubst < security/notary-v2-setup.yaml | kubectl apply -f -

# Deploy Cosign setup
envsubst < security/cosign-setup.yaml | kubectl apply -f -

# Verify signing infrastructure
kubectl get pods -n notary-system
kubectl get services -n notary-system
```

## Phase 3: Policy Enforcement Deployment

### Step 8: Deploy Kyverno (Recommended) or Gatekeeper

#### Option A: Deploy Kyverno

```bash
# Add Kyverno Helm repository
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

# Install Kyverno
helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --values policies/kyverno-values.yaml \
  --wait

# Apply Kyverno policies
envsubst < policies/kyverno-policies.yaml | kubectl apply -f -

# Verify Kyverno installation
kubectl get pods -n kyverno
kubectl get cpol  # ClusterPolicies
```

#### Option B: Deploy OPA Gatekeeper

```bash
# Install Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

# Wait for Gatekeeper to be ready
kubectl wait --for=condition=Ready pod -l control-plane=controller-manager -n gatekeeper-system --timeout=300s

# Apply Gatekeeper policies
envsubst < policies/gatekeeper-policies.yaml | kubectl apply -f -

# Verify Gatekeeper installation
kubectl get pods -n gatekeeper-system
kubectl get constrainttemplates
kubectl get constraints
```

### Step 9: Verify Policy Enforcement

```bash
# Test policy enforcement with unauthorized image
kubectl run test-pod --image=nginx:latest --namespace=production --dry-run=server

# Expected: Should be blocked by registry policy

# Test with authorized image (after pushing to ACR)
kubectl run test-pod --image=$ACR_LOGIN_SERVER/nginx:latest --namespace=production --dry-run=server

# Clean up test
kubectl delete pod test-pod --namespace=production --ignore-not-found
```

## Phase 4: Monitoring and Logging

### Step 10: Deploy Monitoring Infrastructure

```bash
# Create monitoring namespace
kubectl create namespace monitoring

# Create Log Analytics secret
WORKSPACE_ID=$(az monitor log-analytics workspace show --name "$COMPANY_PREFIX-$ENVIRONMENT-logs" --resource-group "$COMPANY_PREFIX-$ENVIRONMENT-management-rg" --query customerId -o tsv)
WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys --name "$COMPANY_PREFIX-$ENVIRONMENT-logs" --resource-group "$COMPANY_PREFIX-$ENVIRONMENT-management-rg" --query primarySharedKey -o tsv)

kubectl create secret generic log-analytics-secret \
  --from-literal=workspace-id="$WORKSPACE_ID" \
  --from-literal=workspace-key="$WORKSPACE_KEY" \
  --namespace=monitoring

# Deploy logging configuration
envsubst < monitoring/logging-config.yaml | kubectl apply -f -

# Verify monitoring deployment
kubectl get pods -n monitoring
kubectl get daemonset -n monitoring
```

### Step 11: Deploy Security Monitoring

```bash
# Create security monitoring namespace
kubectl create namespace security-monitoring

# Deploy Falco and security monitoring
envsubst < monitoring/security-monitoring.yaml | kubectl apply -f -

# Verify security monitoring
kubectl get pods -n security-monitoring
kubectl logs -n security-monitoring deployment/security-webhook
```

## Phase 5: CI/CD Pipeline Configuration

### Step 12: Setup Private Build Agents

```bash
# Create CI/CD agents namespace
kubectl create namespace cicd-agents

# Create secrets for CI/CD integration
# For Azure DevOps
kubectl create secret generic azure-devops-secrets \
  --from-literal=organization-url="https://dev.azure.com/your-org" \
  --from-literal=pat-token="your-pat-token" \
  --namespace=cicd-agents

# For GitHub Actions
kubectl create secret generic github-secrets \
  --from-literal=repository-url="https://github.com/your-org/your-repo" \
  --from-literal=access-token="your-github-token" \
  --namespace=cicd-agents

# Deploy private build agents
envsubst < cicd/private-build-agents.yaml | kubectl apply -f -

# Verify build agents
kubectl get pods -n cicd-agents
kubectl get hpa -n cicd-agents
```

### Step 13: Configure CI/CD Pipelines

#### For GitHub Actions:

```bash
# Copy the GitHub Actions workflow
cp cicd/github-actions-secure.yaml .github/workflows/secure-build.yml

# Set repository secrets in GitHub:
# - ACR_NAME
# - ACR_LOGIN_SERVER
# - AKS_CLUSTER_NAME
# - AKS_RESOURCE_GROUP
# - AZURE_CLIENT_ID
# - AZURE_TENANT_ID
# - AZURE_SUBSCRIPTION_ID
```

#### For Azure DevOps:

```bash
# Copy the Azure DevOps pipeline
cp cicd/azure-devops-secure.yaml azure-pipelines.yml

# Create variable groups in Azure DevOps:
# - acr-variables (with ACR_NAME, ACR_LOGIN_SERVER, etc.)
# - aks-variables (with AKS_CLUSTER_NAME, AKS_RESOURCE_GROUP, etc.)
```

## Phase 6: Testing and Validation

### Step 14: End-to-End Testing

```bash
# Test image build and push
docker build -t test-app .
docker tag test-app $ACR_LOGIN_SERVER/test-app:v1.0.0

# Login to ACR using Azure AD
az acr login --name $ACR_NAME

# Push image
docker push $ACR_LOGIN_SERVER/test-app:v1.0.0

# Test image scanning
trivy image $ACR_LOGIN_SERVER/test-app:v1.0.0

# Test image signing (if CI/CD pipeline is configured)
cosign sign --yes $ACR_LOGIN_SERVER/test-app:v1.0.0

# Test deployment to AKS
cat > test-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: development
  labels:
    app: test-app
    version: v1.0.0
    environment: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
        version: v1.0.0
        environment: development
    spec:
      serviceAccountName: acr-service-account
      containers:
      - name: test-app
        image: $ACR_LOGIN_SERVER/test-app:v1.0.0
        ports:
        - containerPort: 8080
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 128Mi
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
            - ALL
EOF

kubectl apply -f test-deployment.yaml

# Verify deployment
kubectl get pods -n development
kubectl describe deployment test-app -n development
```

### Step 15: Security Validation

```bash
# Run compliance validation script
cat > compliance-check.sh << 'EOF'
#!/bin/bash
set -e

echo "=== Zero Trust ACR Compliance Check ==="

# Check ACR public access
PUBLIC_ACCESS=$(az acr show --name $ACR_NAME --query publicNetworkAccess -o tsv)
if [ "$PUBLIC_ACCESS" != "Disabled" ]; then
    echo "FAIL: ACR has public access enabled"
    exit 1
fi
echo "PASS: ACR public access disabled"

# Check private endpoints
PRIVATE_ENDPOINTS=$(az network private-endpoint list --query "[?privateLinkServiceConnections[0].privateLinkServiceId contains '$ACR_NAME']" --output tsv)
if [ -z "$PRIVATE_ENDPOINTS" ]; then
    echo "FAIL: No private endpoints configured"
    exit 1
fi
echo "PASS: Private endpoints configured"

# Check policy violations
VIOLATIONS=$(kubectl get policyreport -A -o json 2>/dev/null | jq '.items[] | select(.summary.fail > 0)' | wc -l || echo "0")
if [ "$VIOLATIONS" -gt 0 ]; then
    echo "FAIL: Policy violations detected: $VIOLATIONS"
    kubectl get policyreport -A
    exit 1
fi
echo "PASS: No policy violations"

# Check monitoring
MONITORING_PODS=$(kubectl get pods -n monitoring --field-selector=status.phase=Running --no-headers | wc -l)
if [ "$MONITORING_PODS" -eq 0 ]; then
    echo "FAIL: No monitoring pods running"
    exit 1
fi
echo "PASS: Monitoring infrastructure running"

echo "=== All compliance checks passed ==="
EOF

chmod +x compliance-check.sh
./compliance-check.sh
```

## Phase 7: Production Readiness

### Step 16: Enable Advanced Features

```bash
# Enable Microsoft Defender for Containers
az security pricing create --name Containers --tier Standard

# Configure backup for AKS (if using Azure Backup)
az backup vault create \
  --resource-group $AKS_RG \
  --name "$COMPANY_PREFIX-$ENVIRONMENT-backup-vault" \
  --location $LOCATION

# Setup geo-replication verification
az acr replication list --registry $ACR_NAME --output table
```

### Step 17: Documentation and Handover

```bash
# Generate deployment documentation
cat > deployment-summary.md << EOF
# Zero Trust ACR Deployment Summary

## Deployment Date
$(date)

## Infrastructure Components
- ACR Name: $ACR_NAME
- AKS Cluster: $AKS_NAME
- Resource Group: $AKS_RG
- Location: $LOCATION

## Security Features Enabled
- [x] Private endpoints
- [x] Azure AD authentication
- [x] Image scanning
- [x] Image signing (Notary v2/Cosign)
- [x] Policy enforcement (Kyverno/Gatekeeper)
- [x] Security monitoring
- [x] Audit logging

## Access Information
- ACR Login Server: $ACR_LOGIN_SERVER
- AKS API Server: $(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
- Monitoring Dashboard: [Azure Monitor]
- Security Dashboard: [Log Analytics]

## Next Steps
1. Configure production workload deployments
2. Setup backup and disaster recovery procedures
3. Conduct security assessment and penetration testing
4. Train operations team on procedures
5. Schedule regular compliance reviews
EOF

echo "Deployment completed successfully!"
echo "Review deployment-summary.md for next steps."
```

## Troubleshooting Common Issues

### Issue 1: ACR Login Failures

```bash
# Check Azure AD authentication
az acr check-health --name $ACR_NAME --yes

# Verify network connectivity
nslookup $ACR_LOGIN_SERVER
```

### Issue 2: AKS Pod Failures

```bash
# Check pod status and events
kubectl describe pod <pod-name> -n <namespace>

# Check policy violations
kubectl get policyreport -A
kubectl describe policyreport <report-name> -n <namespace>
```

### Issue 3: Image Pull Errors

```bash
# Verify service account and RBAC
kubectl get serviceaccount -n <namespace>
kubectl describe serviceaccount <service-account> -n <namespace>

# Check ACR permissions
az role assignment list --assignee <identity-id> --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$ACR_RG/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME
```

## Maintenance and Operations

### Regular Maintenance Tasks

1. **Weekly**:
   - Review security alerts and violations
   - Update container images for security patches
   - Validate backup and monitoring systems

2. **Monthly**:
   - Access review and cleanup
   - Security policy compliance check
   - Performance and capacity review

3. **Quarterly**:
   - Disaster recovery testing
   - Security assessment and penetration testing
   - Compliance audit and reporting

### Monitoring and Alerting

- **Azure Monitor**: Infrastructure and application metrics
- **Log Analytics**: Centralized logging and analysis
- **Microsoft Sentinel**: Security incident detection and response
- **Grafana**: Custom dashboards and visualizations

This deployment guide provides a comprehensive approach to implementing Zero Trust ACR with enterprise-grade security controls. Follow each phase carefully and validate successful completion before proceeding to the next phase.
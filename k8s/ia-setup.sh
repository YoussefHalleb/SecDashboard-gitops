#!/bin/bash
# ============================================================
# Workload Identity — lier le ServiceAccount K8s au compte GCP
# Remplace TON_PROJECT_ID par ton vrai project ID GCP
# ============================================================

PROJECT_ID="TON_PROJECT_ID"
GCP_SA="ia-agent@${PROJECT_ID}.iam.gserviceaccount.com"
K8S_SA="ia-agent"
NAMESPACE="production"

# 1. Créer le compte de service GCP
gcloud iam service-accounts create ia-agent \
  --display-name="Agent IA CI/CD" \
  --project="${PROJECT_ID}"

# 2. Donner les droits GCP au compte de service
#    - container.developer : accès au cluster GKE
#    - artifactregistry.writer : push des images Docker
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${GCP_SA}" \
  --role="roles/container.developer"

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${GCP_SA}" \
  --role="roles/artifactregistry.writer"

# 3. Lier le ServiceAccount Kubernetes au compte GCP (Workload Identity)
gcloud iam service-accounts add-iam-policy-binding "${GCP_SA}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${K8S_SA}]"

# 4. Appliquer les manifests RBAC dans le cluster
kubectl apply -f ia-serviceaccount.yaml
kubectl apply -f ia-role.yaml
kubectl apply -f ia-rolebinding.yaml

# 5. Vérifier
echo "--- ServiceAccount ---"
kubectl get serviceaccount ia-agent -n production

echo "--- RoleBinding ---"
kubectl get rolebinding ia-agent-deploy -n production

echo "--- Test : ce que ia-agent peut faire ---"
kubectl auth can-i update deployments --as=system:serviceaccount:production:ia-agent -n production
# → yes

echo "--- Test : ce que ia-agent NE PEUT PAS faire ---"
kubectl auth can-i delete pods --as=system:serviceaccount:production:ia-agent -n production
# → no

kubectl auth can-i get secrets --as=system:serviceaccount:production:ia-agent -n production
# → no

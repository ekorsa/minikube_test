#!/bin/bash
set -e # Stop execution if any command fails

echo "Deploying database..."
helm upgrade --install my-db oci://registry-1.docker.io/bitnamicharts/postgresql -f db-values.yaml
# Wait for the PostgreSQL pod to have the condition Ready=True with a 2-minute timeout
kubectl wait --namespace default \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=my-db \
  --timeout=120s


echo "Deploying web service..."
helm upgrade --install my-web oci://registry-1.docker.io/bitnamicharts/nginx -f web-values.yaml

echo "Done! Do not forget to run 'minikube tunnel' in a separate terminal window."


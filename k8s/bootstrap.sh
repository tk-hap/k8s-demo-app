#!/bin/bash

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply Cluster Addons
kubectl apply -n argocd -f ./argocd/cluster-addons-appset.yaml


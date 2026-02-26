#!/bin/bash

# Script para push a bitbucket

set -euo pipefail

# Actualizar referencias remotas primero
git fetch origin

# Verificar si la rama existe remotamente usando ls-remote (más confiable)
if git ls-remote --heads origin feature/karibu-mirror | grep -q feature/karibu-mirror; then
    echo "Branch feature/karibu-mirror exists remotely"
    # Cambiar a la rama existente
    git checkout feature/karibu-mirror
    # Hacer pull para obtener los últimos cambios
    git pull origin feature/karibu-mirror || true
else
    echo "Branch feature/karibu-mirror does not exist remotely, creating it"
    # Crear la rama desde master
    git checkout -b feature/karibu-mirror
fi

# Sincronizar archivos desde el repo de GitHub (../) al subdirectorio karibu/
echo "Syncing files from GitHub repo to karibu/terraform-aws-api-gateway-v1/"
mkdir -p karibu/terraform-aws-api-gateway-v1
rsync -av --delete \
    --exclude='.git' \
    --exclude='bitbucket-repo' \
    --exclude='.github' \
    --exclude='scripts' \
    --exclude='test' \
    --exclude='.env' \
    --exclude='.terraform' \
    --exclude='.terraform.lock.hcl' \
    --exclude='.terraform.tfstate' \
    --exclude='.terraform.tfstate.backup' \
    --exclude='terraform.tfstate' \
    --exclude='terraform.tfstate.backup' \
    --exclude='terraform.tfvars' \
    ../ karibu/terraform-aws-api-gateway-v1/

# Agregar todos los archivos al staging area DESPUÉS de sincronizar
git add --all
curl -sL https://github.com/KaribuLab/kli/releases/download/v0.2.2/kli  --output /tmp/kli && chmod +x /tmp/kli
commit_message=$( git log -1 --pretty=%B )
previous_version=$( git describe --tags --abbrev=0 || echo "" )
latest_version=$( /tmp/kli semver 2>&1 )
# Commit changes
git commit -m "feat: Mirror from GitHub: $commit_message" || true
# Push to bitbucket (usar -u para crear la rama remota si no existe)
git push -u origin feature/karibu-mirror
# Create a new tag
if [ "$previous_version" != "$latest_version" ]; then
    echo "Creating new tag: $latest_version"
    git tag $latest_version
    # Push to bitbucket with new tag
    echo "Pushing to bitbucket with new tag: $latest_version"
    git push origin $latest_version
fi
# Create a pull request to Bitbucket
curl -i -X POST -u $BITBUCKET_USER_EMAIL:$BITBUCKET_API_TOKEN -H "Content-Type: application/json" -d '{"title": "Mirror from GitHub", "description": "Mirror from GitHub: $commit_message", "source": {"branch": {"name": "feature/karibu-mirror"}}, "destination": {"branch": {"name": "master"}}, "close_source_branch": true}' https://api.bitbucket.org/2.0/repositories/$BITBUCKET_WORKSPACE_CLARO/$BITBUCKET_REPO_NAME_CLARO/pullrequests
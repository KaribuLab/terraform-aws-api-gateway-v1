#!/bin/bash

# Script para push a bitbucket

set -euo pipefail

# Actualizar referencias remotas primero
git fetch origin

# Guardar cambios locales temporalmente si existen
if [ -n "$(git status --porcelain)" ]; then
    echo "Saving local changes..."
    git add --all
    git stash push -m "Temporary stash before branch switch"
    stash_created=true
else
    stash_created=false
fi

# Verificar si la rama existe remotamente usando ls-remote (más confiable)
if git ls-remote --heads origin feature/karibu-mirror | grep -q feature/karibu-mirror; then
    echo "Branch feature/karibu-mirror exists remotely"
    git checkout feature/karibu-mirror 2>/dev/null || git checkout -b feature/karibu-mirror origin/feature/karibu-mirror
else
    echo "Branch feature/karibu-mirror does not exist remotely, creating it"
    # Asegurarse de estar en la rama base master antes de crear la nueva rama
    git checkout master
    git checkout -b feature/karibu-mirror
fi

# Restaurar cambios guardados si se hizo stash
if [ "$stash_created" = true ]; then
    echo "Restoring local changes..."
    git stash pop
fi
curl -sL https://github.com/KaribuLab/kli/releases/download/v0.2.2/kli  --output /tmp/kli && chmod +x /tmp/kli
commit_message=$( git log -1 --pretty=%B )
previous_version=$( git describe --tags --abbrev=0 || echo "" )
latest_version=$( /tmp/kli semver 2>&1 )
# Add all changes
git add --all
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
curl -i -X POST -u $BITBUCKET_USER_EMAIL:$BITBUCKET_API_TOKEN -H "Content-Type: application/json" -d '{"title": "Mirror from GitHub", "description": "Mirror from GitHub: $commit_message", "source": {"branch": {"name": "feature/karibu-mirror"}}, "destination": {"branch": {"name": "master"}}, "close_source_branch": true}' https://api.bitbucket.org/2.0/repositories/vtr-digital/tf_modules/pullrequests
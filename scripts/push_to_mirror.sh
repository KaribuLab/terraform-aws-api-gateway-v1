#!/bin/bash

# Script para push a bitbucket

set -euo pipefail

source_branch="feature/karibu-mirror"
target_branch="master"
source_repo_dir="${SOURCE_REPO_DIR:-..}"
mirror_subdir="${MIRROR_SUBDIR:-karibu/terraform-aws-web}"

commit_message=$( git -C "$source_repo_dir" log -1 --pretty=%s 2>/dev/null || git log -1 --pretty=%s )

# Actualizar referencias remotas primero
git fetch --prune --tags origin

# Verificar si la rama existe remotamente usando ls-remote (más confiable)
if git ls-remote --exit-code --heads origin "$source_branch" >/dev/null 2>&1; then
    echo "Branch $source_branch exists remotely"
    # Cambiar a la rama existente
    git checkout "$source_branch"
    # Hacer pull para obtener los últimos cambios
    git pull --ff-only origin "$source_branch" || true
else
    echo "Branch $source_branch does not exist remotely, creating it"
    # Crear la rama desde master (los archivos ya están en staging)
    git checkout -b "$source_branch"
fi

# Sincronizar contenido del repo de GitHub al subdirectorio espejo
mkdir -p "$mirror_subdir"
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
  "$source_repo_dir"/ "$mirror_subdir"/

git add --all

curl -sL https://github.com/KaribuLab/kli/releases/download/v0.2.2/kli  --output /tmp/kli && chmod +x /tmp/kli
created_commit=false
# Commit changes
if ! git diff --cached --quiet; then
    git commit -m "feat: Mirror from GitHub: $commit_message"
    created_commit=true
else
    echo "No staged changes to commit"
fi
# Push to bitbucket (usar -u para crear la rama remota si no existe)
git push -u origin "$source_branch"
latest_version=$( /tmp/kli semver 2>&1 )
# Create a new tag
if git rev-parse -q --verify "refs/tags/$latest_version" >/dev/null || \
   git ls-remote --exit-code --tags origin "refs/tags/$latest_version" >/dev/null 2>&1; then
    echo "Tag $latest_version already exists, skipping tag creation"
else
    echo "Creating new tag: $latest_version"
    git tag "$latest_version"
    # Push to bitbucket with new tag
    echo "Pushing to bitbucket with new tag: $latest_version"
    git push origin "refs/tags/$latest_version"
fi
# Create a pull request to Bitbucket
if [ "$created_commit" = true ]; then
    pr_payload=$(COMMIT_MESSAGE="$commit_message" SOURCE_BRANCH="$source_branch" TARGET_BRANCH="$target_branch" python3 -c 'import json, os; print(json.dumps({"title": "Mirror from GitHub", "description": "Mirror from GitHub: " + os.environ["COMMIT_MESSAGE"], "source": {"branch": {"name": os.environ["SOURCE_BRANCH"]}}, "destination": {"branch": {"name": os.environ["TARGET_BRANCH"]}}, "close_source_branch": True}))')
    curl -i -X POST \
      -u "$BITBUCKET_USER_EMAIL:$BITBUCKET_API_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$pr_payload" \
      "https://api.bitbucket.org/2.0/repositories/$BITBUCKET_WORKSPACE_CLARO/$BITBUCKET_REPO_NAME_CLARO/pullrequests"
else
    echo "No new commit was created, skipping pull request creation"
fi

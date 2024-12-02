#!/bin/bash

set -x

REPO_URL="<token>@dev.azure.com/sandeep23blr/voting-app/_git/voting-app"
TEMP_DIR="/tmp/temp_repo"
DEPLOYMENT_FILE="k8s-specifications/vote-deployment.yaml"
REGISTRY="<container registry name>"  # Your container registry

if [[ -z "$1" ]]; then
    echo "Error: Please provide the new image tag as the first argument."
    exit 1
fi

NEW_IMAGE_TAG="$1"

# Full image name including registry and tag
FULL_IMAGE_NAME="${REGISTRY}/votingapp:${NEW_IMAGE_TAG}"

# Check if the temporary directory exists
if [[ -d "$TEMP_DIR" ]]; then
    echo "Temporary directory $TEMP_DIR already exists. Cleaning up..."
    rm -rf "$TEMP_DIR"
fi

# Clone the repository
git clone "$REPO_URL" "$TEMP_DIR"
cd "$TEMP_DIR"

# Check if the deployment file exists
if [[ ! -f "$DEPLOYMENT_FILE" ]]; then
    echo "Error: Deployment file $DEPLOYMENT_FILE does not exist."
    exit 1
fi

# Debug: Print the current YAML section for containers
echo "Current container image in $DEPLOYMENT_FILE:"
grep "image:" "$DEPLOYMENT_FILE" || echo "No image line found."

# Use `yq` for precise YAML editing (fallback to `sed` if not available)
if command -v yq > /dev/null; then
    echo "Updating image using yq..."
    yq eval ".spec.template.spec.containers[].image = \"$FULL_IMAGE_NAME\"" -i "$DEPLOYMENT_FILE"
else
    echo "Updating image using sed..."
    # Use a robust sed pattern to handle any registry and tag combination
    sed -i "s|image:.*votingapp:.*|image: $FULL_IMAGE_NAME|g" "$DEPLOYMENT_FILE"
fi

# Verify the update
echo "Verifying the update..."
UPDATED_LINE=$(grep "image:" "$DEPLOYMENT_FILE" || echo "No image line found.")
echo "Updated line: $UPDATED_LINE"

if [[ "$UPDATED_LINE" == *"$FULL_IMAGE_NAME"* ]]; then
    echo "Image updated successfully in $DEPLOYMENT_FILE."
else
    echo "Error: Failed to update the image in $DEPLOYMENT_FILE."
    exit 1
fi

# Stage the deployment file only
echo "Staging changes for $DEPLOYMENT_FILE..."
git add "$DEPLOYMENT_FILE"

# Reset unrelated changes to avoid interference
echo "Resetting unrelated changes..."
git restore scripts/updateK8sManifests.sh || true

# Debug: Verify the staging
echo "Checking staged changes..."
git diff --cached

# Commit changes
echo "Committing changes..."
git commit -m "Update image in $DEPLOYMENT_FILE to $FULL_IMAGE_NAME" || {
    echo "No changes to commit."
    exit 0
}

# Push changes
echo "Pushing changes..."
git push

# Cleanup
rm -rf "$TEMP_DIR"

echo "Script completed successfully."

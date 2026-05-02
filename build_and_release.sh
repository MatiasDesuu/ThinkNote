#!/bin/bash
set -e

# ─── Variables ───────────────────────────────────────────────────────────────
GITEA_URL="http://192.168.1.119:10009"
REPO_OWNER="MatiasDesu"
REPO_NAME="ThinkNote"
GITEA_TOKEN="47a4f2b9977498ab36e4e7e7ca77b7791c2df431"
APK_PATH="$(pwd)/build/app/outputs/flutter-apk/app-release.apk"
RELEASE_TAG="v1.0.0-$(date +%Y%m%d-%H%M%S)"
RELEASE_NAME="Release $RELEASE_TAG"
RELEASE_BODY="Automatic release from build script"
LINUX_DEST="/home/matiasdesu/Documents/Software/ThinkNote"

# ─── Menu ────────────────────────────────────────────────────────────────────
echo "Select the platforms for the build (comma-separated):"
echo "1. Android (APK)"
echo "2. Linux"
echo "3. Clean Gitea Releases"
read -rp "Choose options (1-3, e.g., 1,2): " raw_input

IFS=',' read -ra choices <<< "$raw_input"

for choice in "${choices[@]}"; do
    choice="${choice// /}"
    case "$choice" in
        1) android_build ;;
        2) linux_build ;;
        3) clean_releases ;;
        *) echo "Invalid option: $choice" ;;
    esac
done

# ─── Functions ───────────────────────────────────────────────────────────────
android_build() {
    echo "Building APK..."
    flutter build apk --release

    echo "Build successful. APK at $APK_PATH"
    echo "Creating release on Gitea..."

    release_response=$(curl --fail -s -X POST \
        "$GITEA_URL/api/v1/repos/$REPO_OWNER/$REPO_NAME/releases?token=$GITEA_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"tag_name\":\"$RELEASE_TAG\",\"name\":\"$RELEASE_NAME\",\"body\":\"$RELEASE_BODY\"}")

    upload_url=$(echo "$release_response" | grep -o '"upload_url":"[^"]*"' | cut -d'"' -f4 | sed 's/{.*}//')

    if [ -z "$upload_url" ]; then
        echo "Failed to get upload URL! Response: $release_response"
        return 1
    fi

    echo "Uploading APK..."
    curl --fail -s -X POST "$upload_url?name=app-release.apk&token=$GITEA_TOKEN" \
        -F "attachment=@$APK_PATH" > /dev/null

    echo "APK uploaded successfully."
}

linux_build() {
    echo "Building Linux executable..."
    flutter build linux

    echo "Build successful. Copying files..."
    mkdir -p "$LINUX_DEST"
    cp -r "$(pwd)/build/linux/x64/release/bundle/." "$LINUX_DEST"

    echo "Files copied to $LINUX_DEST"
}

clean_releases() {
    echo "Fetching releases..."
    releases=$(curl --fail -s \
        "$GITEA_URL/api/v1/repos/$REPO_OWNER/$REPO_NAME/releases?token=$GITEA_TOKEN")

    ids=$(echo "$releases" | grep -o '"id":[0-9]*' | cut -d':' -f2)

    for id in $ids; do
        curl --fail -s -X DELETE \
            "$GITEA_URL/api/v1/repos/$REPO_OWNER/$REPO_NAME/releases/$id?token=$GITEA_TOKEN" > /dev/null
        echo "Deleted release $id"
    done

    echo "All releases cleaned."
}
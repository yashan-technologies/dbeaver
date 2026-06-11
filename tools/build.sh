#!/usr/bin/env sh

set -e

###############################################################################
# Function Definitions
###############################################################################

# Get the directory where the script is located
# Returns: Absolute path to script directory
SCRIPT_DIR="$(realpath "$(dirname "$0")")"

# Function: log
# Purpose: Provides consistent logging format with timestamps
# Arguments:
#   $1 - Message to log
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function: command_exists
# Purpose: Checks if a required command is available
# Arguments:
#   $1 - Command to check
# Returns:
#   0 if command exists, 1 if it doesn't
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

package_zip() {
    source_dir="$1"
    archive_path="$2"
    parent_dir="$(dirname "$source_dir")"
    root_dir="$(basename "$source_dir")"

    if [ ! -d "$source_dir" ]; then
        log "Error: Product directory not found at $source_dir"
        exit 1
    fi

    (cd "$parent_dir" && zip -qr "$archive_path" "$root_dir")
}

package_tar_gz() {
    source_dir="$1"
    archive_path="$2"
    parent_dir="$(dirname "$source_dir")"
    root_dir="$(basename "$source_dir")"

    if [ ! -d "$source_dir" ]; then
        log "Error: Product directory not found at $source_dir"
        exit 1
    fi

    tar -C "$parent_dir" -czf "$archive_path" "$root_dir"
}

###############################################################################
# Dependency Checks
###############################################################################

if ! command_exists 'git'; then
    log "Error: Git is required but not installed"
    log "Please install Git and try again"
    exit 1
fi

if ! command_exists 'zip'; then
    log "Error: zip is required but not installed"
    log "Please install zip and try again"
    exit 1
fi

if ! command_exists 'tar'; then
    log "Error: tar is required but not installed"
    log "Please install tar and try again"
    exit 1
fi

###############################################################################
# Path Definitions and Validation
###############################################################################

# Define paths relative to the script location
WORKSPACE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
DBEAVER_COMMON_DIR="${WORKSPACE_DIR}/dbeaver-common"
PRODUCT_DIR="${SCRIPT_DIR}/../product"
AGGREGATE_DIR="${PRODUCT_DIR}/aggregate"
COMMUNITY_TARGET_DIR="${PRODUCT_DIR}/community/target"
PRODUCT_ROOT_DIR="${COMMUNITY_TARGET_DIR}/products/org.jkiss.dbeaver.core.product"
RELEASE_PACKAGE_DIR="${COMMUNITY_TARGET_DIR}/release-packages"
RELEASE_VERSION="${RELEASE_VERSION:-${GITHUB_REF_NAME:-}}"
RELEASE_VERSION="${RELEASE_VERSION#v}"

if [ -z "$RELEASE_VERSION" ]; then
    RELEASE_VERSION="latest"
fi

# Simple check for product directory
if [ ! -d "$PRODUCT_DIR" ]; then
    log "Error: Product directory not found at $PRODUCT_DIR"
    exit 1
fi

###############################################################################
# DBeaver Common Repository Management
###############################################################################

# Clone or verify dbeaver-common repository
if [ ! -d "$DBEAVER_COMMON_DIR" ]; then
    log "Cloning dbeaver-common repository..."
    git clone https://github.com/dbeaver/dbeaver-common.git "$DBEAVER_COMMON_DIR"
else
    log "DBeaver common directory already exists at $DBEAVER_COMMON_DIR"
fi

###############################################################################
# Build Process
###############################################################################

# Execute Maven build
log "Starting Maven build..."

"$DBEAVER_COMMON_DIR/mvnw" ${MAVEN_ARGS:-} clean install -Pproduct-dbeaver-ce,product-dbeaver-eclipse-ce -T 1C -f "$AGGREGATE_DIR"

log "Build completed successfully"

###############################################################################
# Package Process
###############################################################################

log "Packaging release products..."

rm -rf "$RELEASE_PACKAGE_DIR"
mkdir -p "$RELEASE_PACKAGE_DIR"
RELEASE_PACKAGE_DIR="$(realpath "$RELEASE_PACKAGE_DIR")"

package_zip \
    "$PRODUCT_ROOT_DIR/win32/win32/x86_64/dbeaver" \
    "$RELEASE_PACKAGE_DIR/dbeaver-ce-${RELEASE_VERSION}-win32.win32.x86_64.zip"

package_zip \
    "$PRODUCT_ROOT_DIR/win32/win32/aarch64/dbeaver" \
    "$RELEASE_PACKAGE_DIR/dbeaver-ce-${RELEASE_VERSION}-win32.win32.aarch64.zip"

package_tar_gz \
    "$PRODUCT_ROOT_DIR/linux/gtk/x86_64/dbeaver" \
    "$RELEASE_PACKAGE_DIR/dbeaver-ce-${RELEASE_VERSION}-linux.gtk.x86_64.tar.gz"

package_tar_gz \
    "$PRODUCT_ROOT_DIR/linux/gtk/aarch64/dbeaver" \
    "$RELEASE_PACKAGE_DIR/dbeaver-ce-${RELEASE_VERSION}-linux.gtk.aarch64.tar.gz"

package_tar_gz \
    "$PRODUCT_ROOT_DIR/macosx/cocoa/x86_64/DBeaver.app" \
    "$RELEASE_PACKAGE_DIR/dbeaver-ce-${RELEASE_VERSION}-macosx.cocoa.x86_64.tar.gz"

package_tar_gz \
    "$PRODUCT_ROOT_DIR/macosx/cocoa/aarch64/DBeaver.app" \
    "$RELEASE_PACKAGE_DIR/dbeaver-ce-${RELEASE_VERSION}-macosx.cocoa.aarch64.tar.gz"

package_count="$(find "$RELEASE_PACKAGE_DIR" -maxdepth 1 -type f \( -name '*.zip' -o -name '*.tar.gz' \) | wc -l | tr -d ' ')"
if [ "$package_count" -ne 6 ]; then
    log "Error: Expected 6 release packages, found $package_count"
    find "$RELEASE_PACKAGE_DIR" -maxdepth 1 -type f -print
    exit 1
fi

log "Release packages created in $RELEASE_PACKAGE_DIR"
ls -lh "$RELEASE_PACKAGE_DIR"

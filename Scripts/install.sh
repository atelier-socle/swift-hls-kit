#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Copyright 2026 Atelier Socle SAS
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# install.sh — Build and install the hlskit-cli CLI tool.
#
# Usage:
#   ./Scripts/install.sh              # installs to /usr/local/bin
#   PREFIX=~/.local/bin ./Scripts/install.sh  # custom prefix
#
# Requirements: Swift 6.2+

set -euo pipefail

BINARY_NAME="hlskit-cli"
PREFIX="${PREFIX:-/usr/local/bin}"
BUILD_DIR=".build/release"

# ---------- Helpers ----------

info()  { echo "==> $*"; }
error() { echo "ERROR: $*" >&2; exit 1; }

# ---------- Platform detection ----------

OS="$(uname -s)"
case "$OS" in
    Darwin) info "Platform: macOS" ;;
    Linux)  info "Platform: Linux" ;;
    *)      error "Unsupported platform: $OS (macOS and Linux only)" ;;
esac

# ---------- Swift check ----------

if ! command -v swift &>/dev/null; then
    error "Swift is not installed. Please install Swift 6.2+ first."
fi

SWIFT_VERSION="$(swift --version 2>&1 | head -1)"
info "Swift: $SWIFT_VERSION"

# ---------- Build ----------

info "Building $BINARY_NAME (release)..."
swift build -c release

if [ ! -f "$BUILD_DIR/$BINARY_NAME" ]; then
    error "Build succeeded but binary not found at $BUILD_DIR/$BINARY_NAME"
fi

# ---------- Install ----------

info "Installing to $PREFIX/$BINARY_NAME..."
mkdir -p "$PREFIX"
install -m 755 "$BUILD_DIR/$BINARY_NAME" "$PREFIX/$BINARY_NAME"

# ---------- Verify ----------

VERSION="$("$PREFIX/$BINARY_NAME" --help 2>&1 | head -1 || true)"
info "Installed $BINARY_NAME to $PREFIX/$BINARY_NAME"
info "$VERSION"
echo ""
echo "Run 'hlskit-cli --help' to get started."

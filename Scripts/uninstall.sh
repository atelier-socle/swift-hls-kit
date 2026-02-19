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

# uninstall.sh — Remove the hlskit-cli CLI tool.
#
# Usage:
#   ./Scripts/uninstall.sh
#   PREFIX=~/.local/bin ./Scripts/uninstall.sh

set -euo pipefail

BINARY_NAME="hlskit-cli"
PREFIX="${PREFIX:-/usr/local/bin}"
TARGET="$PREFIX/$BINARY_NAME"

if [ -f "$TARGET" ]; then
    rm -f "$TARGET"
    echo "Removed $TARGET"
else
    echo "$TARGET not found — nothing to remove."
fi

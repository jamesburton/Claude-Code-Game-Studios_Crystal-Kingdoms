#!/bin/bash
# Build Crystal Kingdoms for all platforms
# Usage: ./tools/build.sh [version]
# Requires: Godot with export templates installed

set -e

VERSION=${1:-"dev"}
GODOT=${GODOT_PATH:-"godot"}
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== Crystal Kingdoms Build — ${VERSION} ==="
echo "Project: ${PROJECT_DIR}"
echo "Godot: ${GODOT}"
echo ""

# Import project
echo "Importing project..."
"${GODOT}" --headless --import --path "${PROJECT_DIR}" 2>/dev/null

# Run tests first
echo "Running tests..."
"${GODOT}" --headless --path "${PROJECT_DIR}" -s tests/test_all.gd
echo ""

# Build directories
mkdir -p "${PROJECT_DIR}/build/windows"
mkdir -p "${PROJECT_DIR}/build/linux"
mkdir -p "${PROJECT_DIR}/build/web"

# Export Windows
echo "Exporting Windows..."
"${GODOT}" --headless --path "${PROJECT_DIR}" \
  --export-release "Windows Desktop" \
  "build/windows/CrystalKingdoms.exe" 2>/dev/null && echo "  Done." || echo "  FAILED (missing templates?)"

# Export Linux
echo "Exporting Linux..."
"${GODOT}" --headless --path "${PROJECT_DIR}" \
  --export-release "Linux" \
  "build/linux/CrystalKingdoms.x86_64" 2>/dev/null && echo "  Done." || echo "  FAILED (missing templates?)"

# Export Web
echo "Exporting Web..."
"${GODOT}" --headless --path "${PROJECT_DIR}" \
  --export-release "Web" \
  "build/web/CrystalKingdoms.html" 2>/dev/null && echo "  Done." || echo "  FAILED (missing templates?)"

echo ""
echo "=== Build complete ==="
echo "Outputs in: ${PROJECT_DIR}/build/"
ls -la "${PROJECT_DIR}/build/"*/ 2>/dev/null || true

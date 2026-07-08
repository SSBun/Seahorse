#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../MCPHelper"
npm install
npm run build

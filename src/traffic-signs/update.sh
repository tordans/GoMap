#!/bin/bash
set -ex

cd "$(dirname "$0")"

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required to build traffic signs assets"
  exit 1
fi

npm install --no-fund --no-audit
node build_index.mjs

git add TrafficSignIndex.json TrafficSigns.xcassets package.json package-lock.json build_index.mjs update.sh 2>/dev/null || true

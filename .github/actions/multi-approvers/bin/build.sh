#!/usr/bin/env bash
set -euo pipefail

echo ">>> Building multi-approvers bundle via ncc..."
npx ncc build -m src/main.ts -o dist

echo ">>> Renaming bundle to dist/index.mjs..."
mv dist/index.js dist/index.mjs

echo ">>> Upgrading legacy CommonJS scope variables inside bundle..."
perl -pi -e 's/\b__dirname\b/import.meta.dirname/g' dist/index.mjs

echo ">>> Normalizing corporate registry links to public npmjs in lockfile..."
perl -pi -e 's|https://us-npm\.pkg\.dev/[^/]+/[^/]+/|https://registry.npmjs.org/|g' package-lock.json

echo ">>> Purging unwanted dist/package.json artifact..."
rm -f dist/package.json

echo ">>> Build and normalization complete!"

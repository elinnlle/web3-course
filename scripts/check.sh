#!/usr/bin/env bash
# Reproducible submission checks. Requires installed dependencies.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v forge >/dev/null || { echo 'forge is missing. Run bash scripts/setup.sh first.' >&2; exit 1; }
command -v npm >/dev/null || { echo 'npm is missing. Install Node.js 20+.' >&2; exit 1; }
if [[ ! -f lib/forge-std/src/Test.sol ]] || [[ ! -f lib/openzeppelin-foundry-upgrades/src/Upgrades.sol ]]; then
  echo 'Foundry dependencies are missing. Run bash scripts/setup.sh first.' >&2
  exit 1
fi
if [[ ! -d node_modules/@openzeppelin/upgrades-core ]]; then
  echo 'Upgrades CLI dependency is missing. Run npm install first.' >&2
  exit 1
fi

forge build --force
forge test --force -vv
npm run validate:upgrade
printf '\nAll three verification commands succeeded.\n'

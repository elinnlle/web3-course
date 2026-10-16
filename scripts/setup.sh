#!/usr/bin/env bash
# Install pinned project dependencies after extracting the ZIP or cloning GitHub.
set -euo pipefail
cd "$(dirname "$0")/.."

for binary in git forge npm; do
  if ! command -v "$binary" >/dev/null 2>&1; then
    echo "Missing dependency: $binary" >&2
    echo "Install Foundry (https://getfoundry.sh/), Git and Node.js 20+, then retry." >&2
    exit 1
  fi
done

# A downloaded ZIP has no Git metadata. Forge uses it for dependency submodules.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git init
fi

# Recover submodules first when running from a GitHub clone.
if [[ -f .gitmodules ]]; then
  git submodule sync --recursive
  git submodule update --init --recursive
fi

if [[ ! -f lib/forge-std/src/Test.sol ]]; then
  forge install foundry-rs/forge-std@v1.16.2
fi
if [[ ! -f lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol ]]; then
  forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v5.7.0
fi
if [[ ! -f lib/openzeppelin-foundry-upgrades/src/Upgrades.sol ]]; then
  forge install OpenZeppelin/openzeppelin-foundry-upgrades@v0.4.2
fi

# @openzeppelin/contracts/ resolves to the nested, matching OZ 5.7.0 submodule.
git submodule update --init --recursive
if [[ ! -f lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol ]]; then
  echo "The nested OpenZeppelin contracts submodule was not installed correctly." >&2
  exit 1
fi

if [[ -f package-lock.json ]]; then
  npm ci --no-audit --no-fund
else
  npm install --no-audit --no-fund
fi
bash scripts/check.sh

#!/usr/bin/env bash
# Restore this homework's pinned dependencies and run all submission checks.
set -euo pipefail
cd "$(dirname "$0")/.."

for binary in git forge node npm; do
  if ! command -v "$binary" >/dev/null 2>&1; then
    echo "Missing dependency: $binary" >&2
    echo "Install Foundry v1.8.5 (https://getfoundry.sh/), Git and Node.js 20+, then retry." >&2
    exit 1
  fi
done

node -e 'if (Number(process.versions.node.split(".")[0]) < 20) { console.error("Node.js 20+ is required."); process.exit(1); }'

# The Git repository belongs to the course, not to the nested homework.
# Never initialize a nested repository or install dependencies into the course root.
if ! repo_root=$(git rev-parse --show-toplevel 2>/dev/null); then
  echo 'Clone the web3-course Git repository before running setup (GitHub ZIP archives are not supported).' >&2
  exit 1
fi
project_prefix=$(git rev-parse --show-prefix)
dependencies=(
  "${project_prefix}lib/forge-std"
  "${project_prefix}lib/openzeppelin-contracts-upgradeable"
  "${project_prefix}lib/openzeppelin-foundry-upgrades"
)

# Restore only HW02 and its transitive submodules, not future homeworks.
# Gitlinks in the course repository pin the exact versions.
git -C "$repo_root" submodule sync --recursive -- "${dependencies[@]}"
git -C "$repo_root" submodule update --init --recursive --depth 1 --jobs 4 -- "${dependencies[@]}"

if [[ ! -f lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol ]]; then
  echo "The nested OpenZeppelin contracts submodule was not installed correctly." >&2
  exit 1
fi

npm ci --no-audit --no-fund
bash scripts/check.sh

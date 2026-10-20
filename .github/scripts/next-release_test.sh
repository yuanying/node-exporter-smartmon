#!/usr/bin/env bash
# Tests next-release.sh against throwaway repositories.
# Usage: .github/scripts/next-release_test.sh
set -euo pipefail

script=$(cd "$(dirname "$0")" && pwd)/next-release.sh
failures=0

# Creates a repository whose history has the tags of this one, the
# four-part v0.17.0.1 included, with v0.19.0 on its last commit.
setup() {
  repo=$(mktemp -d)
  cd "$repo"
  git init -q
  git config user.email test@example.com
  git config user.name test
  for tag in v0.14.0 v0.14.0.1 v0.17.0 v0.17.0.1 v0.18.0 v0.19.0; do
    echo "$tag" > Dockerfile
    git add -A
    git commit -qm "$tag"
    git tag "$tag"
  done
}

commit() {
  mkdir -p "$(dirname "$1")"
  echo change >> "$1"
  git add -A
  git commit -qm "change $1"
}

expect() {
  local name=$1 want=$2 got
  got=$("$script" Dockerfile smartmon.sh) || got="exit $?"
  if [[ $got == "$want" ]]; then
    echo "ok   $name"
  else
    echo "FAIL $name"
    echo "  want: ${want//$'\n'/ }"
    echo "  got:  ${got//$'\n'/ }"
    failures=$((failures + 1))
  fi
  cd /
  rm -rf "$repo"
}

setup
expect "no change since the latest tag" "release=false"

setup
commit .github/workflows/docker.yml
commit renovate.json
commit README.md
expect "only workflows, renovate.json and docs changed" "release=false"

setup
commit Dockerfile
expect "Dockerfile changed" $'release=true\ntag=v0.19.1'

setup
commit smartmon.sh
expect "smartmon.sh changed" $'release=true\ntag=v0.19.1'

setup
git tag v0.19.0.1
git tag v0.9.9
commit smartmon.sh
expect "four-part and lower tags are not taken as the latest" $'release=true\ntag=v0.19.1'

setup
git tag v0.19.10
commit Dockerfile
expect "versions compare as numbers, not as text" $'release=true\ntag=v0.19.11'

setup
git tag --list | xargs git tag -d > /dev/null
commit Dockerfile
expect "no vX.Y.Z tag" "exit 1"

if ((failures > 0)); then
  echo "$failures failed"
  exit 1
fi

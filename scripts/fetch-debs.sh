#!/usr/bin/env bash
# Downloads the .deb files from the latest release of every repository in an apps list.
#
# Usage: fetch-debs.sh <apps.txt> <out-dir>
#
# Fails if a repository's latest release has no .deb, so a broken release never makes an app
# disappear from the published repository: the previous deployment stays up instead.
set -euo pipefail

apps=$1
out=$2
mkdir -p "$out"

grep -vE '^\s*(#|$)' "$apps" | while read -r repo; do
  tag=$(gh release view --repo "$repo" --json tagName -q .tagName)
  echo "$repo $tag"
  gh release download "$tag" --repo "$repo" --pattern '*.deb' --dir "$out" --clobber
done

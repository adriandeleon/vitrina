#!/usr/bin/env bash
# Builds a signed apt repository from a directory of .deb files.
#
# Usage: build-apt.sh <debs-dir> <out-dir>
#
#   SIGNING_KEY     fingerprint of the secret key in the gpg keyring that signs the index
#   GPG_PASSPHRASE  that key's passphrase, if it has one
#
# Writes <out-dir>/apt (pool/ and dists/, the URL users put in their sources) and
# <out-dir>/vitrina.asc (the public key they verify it with). The repository is rebuilt from
# scratch every time, so it always holds exactly the given packages.
set -euo pipefail

debs=$1
out=$2
suite=stable
component=main
archs="amd64 arm64"
: "${SIGNING_KEY:?set SIGNING_KEY to the signing key fingerprint}"

repo="$out/apt"
rm -rf "$repo"
mkdir -p "$repo"

shopt -s nullglob
files=("$debs"/*.deb)
if [ ${#files[@]} -eq 0 ]; then
  echo "error: no .deb files in $debs" >&2
  exit 1
fi

# pool/main/<first letter>/<package>/<package>_<version>_<arch>.deb, the layout Debian uses.
for deb in "${files[@]}"; do
  pkg=$(dpkg-deb -f "$deb" Package)
  ver=$(dpkg-deb -f "$deb" Version)
  arch=$(dpkg-deb -f "$deb" Architecture)
  case " $archs all " in
    *" $arch "*) ;;
    *) echo "error: $deb is for $arch, which this repository does not list" >&2; exit 1 ;;
  esac
  dir="$repo/pool/$component/${pkg:0:1}/$pkg"
  dest="$dir/${pkg}_${ver}_${arch}.deb"
  if [ -e "$dest" ]; then
    echo "error: two files for $pkg $ver $arch ($deb)" >&2
    exit 1
  fi
  mkdir -p "$dir"
  cp "$deb" "$dest"
done

cd "$repo"
for arch in $archs; do
  dir="dists/$suite/$component/binary-$arch"
  mkdir -p "$dir"
  apt-ftparchive --arch "$arch" packages "pool/$component" > "$dir/Packages"
  gzip -9nk "$dir/Packages"
done

apt-ftparchive \
  -o APT::FTPArchive::Release::Origin=Vitrina \
  -o APT::FTPArchive::Release::Label=Vitrina \
  -o APT::FTPArchive::Release::Suite="$suite" \
  -o APT::FTPArchive::Release::Codename="$suite" \
  -o APT::FTPArchive::Release::Architectures="$archs" \
  -o APT::FTPArchive::Release::Components="$component" \
  -o APT::FTPArchive::Release::Description="Vitrina apps" \
  release "dists/$suite" > Release.tmp
mv Release.tmp "dists/$suite/Release"

sign() {
  if [ -n "${GPG_PASSPHRASE:-}" ]; then
    gpg --batch --yes --pinentry-mode loopback --passphrase-fd 0 --local-user "$SIGNING_KEY" "$@" <<<"$GPG_PASSPHRASE"
  else
    gpg --batch --yes --local-user "$SIGNING_KEY" "$@"
  fi
}
sign --clearsign --output "dists/$suite/InRelease" "dists/$suite/Release"
sign --armor --detach-sign --output "dists/$suite/Release.gpg" "dists/$suite/Release"

cd - >/dev/null
gpg --armor --export "$SIGNING_KEY" > "$out/vitrina.asc"

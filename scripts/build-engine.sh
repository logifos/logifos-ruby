#!/usr/bin/env bash
# Builds the logifos engine's C artifact and packages it into the gem's
# native layout. Two modes:
#
#   scripts/build-engine.sh <logifos-rs checkout>   # build a local checkout
#   scripts/build-engine.sh                          # fetch the pinned
#                                                    # revision and build
#
# The artifact lands at lib/logifos/native/<Gem::Platform.local>/logifos.dylib
# (or .so/.dll), the exact path lib/logifos/native.rb loads.
set -euo pipefail
cd "$(dirname "$0")/.."
target=$(ruby -r rbconfig -e 'print Gem::Platform.local.to_s')
suffix=$(ruby -r rbconfig -e 'print {"darwin"=>"dylib","linux"=>"so","mingw"=>"dll"}[RbConfig::CONFIG["host_os"][/\\w+$/]] || "dylib"')
dest="lib/logifos/native/${target}"
mkdir -p "$dest"

if [ "${1:-}" ]; then
  src_dir=$(cd "$1" && pwd)
else
  revision=$(ruby -e 'print ENV.fetch("LOGIFOS_RS_REVISION", "main")')
  src_dir="tmp/logifos-rs"
  mkdir -p tmp
  if [ ! -d "$src_dir/.git" ]; then
    rm -rf "$src_dir"
    git init --quiet "$src_dir"
    git -C "$src_dir" remote add origin https://github.com/logifos/logifos-rs
    git -C "$src_dir" fetch --quiet --depth 1 origin "$revision"
    git -C "$src_dir" checkout --quiet FETCH_HEAD
  fi
fi

(cd "$src_dir" && cargo build --quiet --release -p logifos-ffi)
cp "$src_dir/target/release/liblogifos_ffi.$suffix" "$dest/logifos.$suffix"
echo "packaged $dest/logifos.$suffix"

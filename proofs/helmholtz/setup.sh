#!/usr/bin/env bash
# Build Helmholtz (gitlab.com/aigarashi/ReFX, branch refx3) natively on this
# Mac, into tezos/vendor/helmholtz with its own opam switch. Takes about an
# hour, almost all of it building Octez 17.3.
#
# What its README and .opam get wrong, and what this script does instead:
# - They say OCaml 4.12.1 and Hangzhou (011) packages. The code links the
#   Nairobi (017) Octez libraries, whose 17.3 packages need OCaml >= 4.14.
#   So: OCaml 4.14.1.
# - Octez 17.x packages now live in ocaml/opam-repository-archive, where the
#   Feb 2026 archiving rewrote their bounds to the unsatisfiable
#   `hacl-star >= 0.7.0 & < 0.8 & <= 0.3.0-1`. So the switch resolves only
#   against opam-repository as it was before archiving (b6ef9f1109, Sept 5,
#   2025), where the bound is `>= 0.7.0 & < 0.8`.
# - This Mac's default SDK is newer than its OS, which breaks OCaml's
#   configure probes, so the switch pins SDKROOT to the 26.5 SDK.
# - Homebrew's cmake 4 rejects old cmake_minimum_required calls (hacl-star-raw),
#   so CMAKE_POLICY_VERSION_MINIMUM=3.5.
# - Helmholtz shells out to the `z3` binary; Homebrew's z3 works, so the
#   opam z3 package is not installed.
#
# Needs: opam, Homebrew cmake, z3, gmp, libev, pkgconf, rust (cargo).
set -euo pipefail
vendor="$(cd "$(dirname "$0")/../../../../vendor" && pwd)"
snap_rev=b6ef9f11098bd4ec095cb7188a20935f29317bf7
snap="$vendor/opam-repository-2025-09-05"
sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
export SDKROOT="$sdk" CMAKE_POLICY_VERSION_MINIMUM=3.5

if [ ! -d "$snap" ]; then
  tmp="$(mktemp -d)"
  curl -sfL -o "$tmp/snap.tar.gz" "https://github.com/ocaml/opam-repository/archive/$snap_rev.tar.gz"
  tar xzf "$tmp/snap.tar.gz" -C "$tmp"
  mv "$tmp/opam-repository-$snap_rev" "$snap"
fi

cd "$vendor"
[ -d helmholtz ] || git clone -b refx3 https://gitlab.com/aigarashi/ReFX.git helmholtz
cd helmholtz
git checkout -q 31f167e57   # refx3 head, July 13, 2023

if [ ! -d _opam ]; then
  opam switch create . ocaml-base-compiler.4.14.1 --no-install -y
  opam option "setenv+=SDKROOT = \"$sdk\"" --switch .
  opam repo add snap2025 "$snap" --this-switch --rank 1
  opam repo remove default --this-switch
fi
eval "$(opam env --switch . --set-switch)"

V=17.3
opam install -y --assume-depexts dune menhir cmdliner qcheck-alcotest \
  "tezos-base.$V" "tezos-stdlib-unix.$V" "tezos-micheline.$V" \
  "tezos-protocol-017-PtNairob.$V" "tezos-client-017-PtNairob.$V" \
  "tezos-protocol-environment.$V" "tezos-protocol-plugin-017-PtNairob.$V" \
  "tezos-shell-services.$V" "tezos-test-helpers.$V" "octez-plompiler.$V" "tezos-crypto-dal.$V"
dune build
_build/default/driver/main.exe tests/pos/boomerang.tz | tail -1   # expect VERIFIED

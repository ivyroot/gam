#!/usr/bin/env bash
# Build Mi-Cho-Coq (gitlab.com/nomadic-labs/mi-cho-coq, branch dev) natively
# on this Mac, into tezos/vendor/mi-cho-coq with its own opam switch. Takes
# about ten minutes.
#
# - MR 180 (Coq 9.2) is still open with a failing pipeline (Oct 27, 2026), so
#   this builds dev at 6262ab7 (May 28, 2024) on Coq 8.16.1, the newest its
#   .opam allows (>= 8.14, < 8.17).
# - coq-moment, coq-list-string and coq-menhirlib come from Coq's own opam
#   repository (coq-released). menhir must be the same version as
#   coq-menhirlib, because the Micheline parser is a Menhir .vy grammar.
# - This Mac's default SDK is newer than its OS, which breaks OCaml's
#   configure probes, so the switch pins SDKROOT to the 26.5 SDK.
# - opam asks for ruby as a system dependency; macOS's /usr/bin/ruby is
#   enough, hence --assume-depexts.
#
# Needs: opam, gmp.
set -euo pipefail
vendor="$(cd "$(dirname "$0")/../../../../vendor" && pwd)"
sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
menhir=20260209
export SDKROOT="$sdk"

cd "$vendor"
[ -d mi-cho-coq ] || git clone https://gitlab.com/nomadic-labs/mi-cho-coq.git
cd mi-cho-coq
git checkout -q 6262ab7   # dev head, May 28, 2024

opam repo add coq-released https://coq.inria.fr/opam/released --dont-select 2>/dev/null || true
if [ ! -d _opam ]; then
  opam switch create . ocaml-base-compiler.4.14.1 --repos=default,coq-released --no-install -y
  opam option --switch "$PWD" setenv+="SDKROOT=\"$sdk\""
fi
eval "$(opam env --switch "$PWD" --set-switch)"
opam install -y --assume-depexts coq.8.16.1 coq-menhirlib.$menhir menhir.$menhir \
  coq-moment coq-list-string ocamlbuild
./configure michocoq
make -j8

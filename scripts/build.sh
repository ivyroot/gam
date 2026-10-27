#!/usr/bin/env bash
# Compile gam.mligo with the pinned LIGO and produce everything the TezBox
# suite and the provers read:
#
#   out/gam.tz                  deployed contract (EMIT and views kept)
#   out/gam.storage.tz          initial storage (all big_maps empty)
#   out/gam.locations.tz        same code with CameLIGO source locations
#   out/gam.prove.tz            prover copy: EMIT -> stand-in, views removed
#   out/views/<name>.view.tz    each view wrapped as a stand-alone program
#   out/inventory/              instruction inventory, and forms new since the spike
#
# Needs: ligo (version in LIGO_VERSION), node with the tezos/ node_modules,
# python3. Verification tools live in tezos/verification.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
verif="$(cd "$root/../../verification" && pwd)"
cd "$root"
export LIGO_SKIP_ANALYTICS=1

want="$(cat LIGO_VERSION)"
have="$(ligo version 2>/dev/null | tail -1)"
[ "$have" = "$want" ] || { echo "ligo $have found, LIGO_VERSION pins $want" >&2; exit 1; }

mkdir -p out/views out/inventory
ligo compile contract src/gam.mligo > out/gam.tz
ligo compile contract src/gam.mligo --michelson-comments location > out/gam.locations.tz
ligo compile storage src/gam.mligo initial_storage > out/gam.storage.tz

node "$verif/prove_prep.mjs" out/gam.tz > out/gam.prove.tz 2> out/gam.prove.report.txt
for v in has_license in_collection; do
  node "$verif/prove_prep.mjs" out/gam.tz --view "$v" > "out/views/$v.view.tz" 2>> out/gam.prove.report.txt
done

# Deployed contract, then the prover inputs (prover copy plus view wrappers).
inv() { # inv DIR NAME=FILE.tz ...
  local dir="out/inventory/$1"; shift; mkdir -p "$dir"; local specs=()
  for a in "$@"; do node "$verif/tz2json.mjs" "${a#*=}" > "$dir/${a%%=*}.json"; specs+=("${a%%=*}=$dir/${a%%=*}.json"); done
  python3 -I "$verif/inventory.py" "${specs[@]}" --out "$dir" > /dev/null
}
inv deployed gam=out/gam.tz
inv prove gam_prove=out/gam.prove.tz view_has_license=out/views/has_license.view.tz view_in_collection=out/views/in_collection.view.tz

# Forms the provers were already checked against on Oct 22 (lang_spike, plus
# CONS and SET_DELEGATE from the events stand-in) versus forms gam adds. Each
# new one needs a coverage check in Mi-Cho-Coq, Helmholtz and MicSE.
comm -13 <( (cat "$verif/lang_spike/inventory/all.forms.txt"; printf 'CONS\nSET_DELEGATE\n') | sort -u) \
  <(sort -u out/inventory/prove/all.forms.txt) > out/inventory/new_forms.txt || true
echo "built with ligo $have; prover copy uses $(wc -l < out/inventory/new_forms.txt | tr -d ' ') forms not in the spike:"
sed 's/^/  /' out/inventory/new_forms.txt
cat out/gam.prove.report.txt

#!/usr/bin/env bash
# Check GAM's Mi-Cho-Coq proofs.
#
#   proofs/michocoq/run.sh     (after ./scripts/build.sh)
#
# Embeds out/gam.prove.tz in gam_prove_string.v, has Coq parse and typecheck
# it with Mi-Cho-Coq's own parser and typer (gam_source.v), checks the proofs
# against it (P5, and a concrete purchase that succeeds, so P5 isn't
# vacuous), and prints the axioms they rest on. Expected: only Coq's
# primitive-integer axioms (PrimInt63, Uint63, used by mutez) and Mi-Cho-Coq's
# abstract BLS12-381 operations, which GAM never calls, plus C.get_contract_type,
# the abstract "which address is which contract" lookup. Anything else, an
# Admitted lemma included, fails the run.
#
# Needs Mi-Cho-Coq built in tezos/vendor/mi-cho-coq (setup.sh).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
mcc="$root/../../vendor/mi-cho-coq"
eval "$(opam env --switch "$mcc" --set-switch)"
cd "$here"
python3 -I gen_string.py "$root/out/gam.prove.tz" gam_prove_string.v
coq_makefile -f _CoqProject -o Makefile.coq 2>/dev/null
make -s -f Makefile.coq 2>&1 < /dev/null | tee "$root/out/michocoq.log" | grep -v '^Warning' >/dev/null || true
axioms="$(awk '/^Axioms:/{on=1;next} on && /^[A-Za-z_]/{sub(/ *:.*/,""); print}' "$root/out/michocoq.log" | sort -u)"
for v in purchase_p5 purchase_witness; do
  [ -f $v.vo ] || { cat "$root/out/michocoq.log"; echo "FAIL $v (did not check)"; exit 1; }
done
unexpected="$(printf '%s\n' "$axioms" | grep -vE '^((PrimInt63|Uint63|bls12_381)\.|C\.get_contract_type$)' | grep . || true)"
if [ -n "$unexpected" ]; then
  echo "FAIL purchase_p5: unexpected axioms:"; echo "$unexpected"; exit 1
fi
echo "ok   purchase_p5 and purchase_witness (kernel-checked; axioms: $(printf '%s\n' "$axioms" | grep -c .) primitive-int, BLS12-381 and the contract lookup only)"

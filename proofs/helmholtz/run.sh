#!/usr/bin/env bash
# Verify GAM with Helmholtz.
#
#   proofs/helmholtz/run.sh [GLOB]     (after ./scripts/build.sh; GLOB picks specs, e.g. "purchase.*")
#
# Each NAME.spec holds a << ContractAnnot >>. A spec named after a view checks
# out/views/NAME.view.tz; any other (purchase.*) checks out/gam.prove.tz. The
# spec is spliced in front of `code` in a copy under out/helmholtz/, so the
# built .tz files stay exactly as compiled. NAME.wrong.spec files are
# deliberately false specs that must not verify, to show that a pass means
# something. Wrong specs about a successful purchase usually end UNKNOWN
# rather than UNVERIFIED (Z3 cannot build models through Helmholtz's
# sequence encoding of the operation list) and take a minute or more each.
#
# Needs Helmholtz built in tezos/vendor/helmholtz (OCaml 4.14.1 switch, Octez
# 17.3 libraries) and z3 on PATH.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
hh="${HELMHOLTZ:-$root/../../vendor/helmholtz/_build/default/driver/main.exe}"
out="$root/out/helmholtz"
mkdir -p "$out"

annotate() { # annotate SPEC TZ > OUT: spec (minus # comment lines) goes before `code`
  python3 -I - "$1" "$2" <<'EOF'
import re, sys
spec = "".join(l for l in open(sys.argv[1]) if not l.lstrip().startswith("#"))
tz = open(sys.argv[2]).read()
m = re.search(r"^(\s*)code\b", tz, re.M)
if not m: sys.exit("no code section in " + sys.argv[2])
sys.stdout.write(tz[:m.start()] + spec + tz[m.start():])
EOF
}

failed=0
for spec in "$here"/${1:-*}.spec; do
  name="$(basename "$spec" .spec)"           # e.g. has_license, purchase.p1_payment, *.wrong
  right="${name%.wrong}"
  # A spec named after a view checks that view's wrapper; anything else
  # (e.g. purchase.*) checks the whole prover copy.
  target="$root/out/views/${name%%.*}.view.tz"
  [ -f "$target" ] || target="$root/out/gam.prove.tz"
  annotated="$out/$name.tz"
  annotate "$spec" "$target" > "$annotated" || { failed=1; continue; }
  log="$out/$name.log"
  # Helmholtz exits 0 whatever the result; the verdict is the line after
  # "======== verification result ========".
  "$hh" --log-dir "$out/$name.refx" "$annotated" > "$log" 2>&1
  verdict="$(grep -E '^(VERIFIED|UNVERIFIED|UNKNOWN|TIMEOUT)$' "$log" | tail -1)"
  # A true spec must be VERIFIED. A wrong spec must not be: UNVERIFIED means Z3
  # found a counterexample; UNKNOWN or TIMEOUT means it gave up, which still
  # shows the spec isn't vacuously true (a vacuous one verifies in a second).
  if [ "$name" = "$right" ]; then
    expect=VERIFIED; [ "$verdict" = VERIFIED ] && status=ok || status=FAIL
  else
    expect="not VERIFIED"
    case "$verdict" in UNVERIFIED|UNKNOWN|TIMEOUT) status=ok ;; *) status=FAIL ;; esac
  fi
  [ "$status" = ok ] || failed=1
  printf '%-4s %-34s %-11s (expected %s)\n' "$status" "$name" "${verdict:-ERROR}" "$expect"
done
exit $failed

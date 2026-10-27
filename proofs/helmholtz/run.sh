#!/usr/bin/env bash
# Verify GAM's view wrappers with Helmholtz.
#
#   proofs/helmholtz/run.sh            (after ./scripts/build.sh)
#
# Each NAME.spec holds a << ContractAnnot >> for out/views/NAME.view.tz. The
# spec is spliced in front of `code` in a copy under out/helmholtz/, so the
# built .tz files stay exactly as compiled. NAME.wrong.spec files are
# deliberately false specs that must be rejected, to show that a pass means
# something.
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
for spec in "$here"/*.spec; do
  name="$(basename "$spec" .spec)"           # has_license or has_license.wrong
  view="${name%.wrong}"
  annotated="$out/$name.tz"
  annotate "$spec" "$root/out/views/$view.view.tz" > "$annotated" || { failed=1; continue; }
  log="$out/$name.log"
  # Helmholtz exits 0 whatever the result; the verdict is the line after
  # "======== verification result ========".
  "$hh" --log-dir "$out/$name.refx" "$annotated" > "$log" 2>&1
  verdict="$(grep -E '^(VERIFIED|UNVERIFIED|UNKNOWN|TIMEOUT)$' "$log" | tail -1)"
  expect=VERIFIED; [ "$name" != "$view" ] && expect=UNVERIFIED
  if [ "$verdict" = "$expect" ]; then status=ok; else status=FAIL; failed=1; fi
  printf '%-4s %-26s %-11s (expected %s)\n' "$status" "$name" "${verdict:-ERROR}" "$expect"
done
exit $failed

# Tezos source language for Michelson-level proving (Oct 22, 2026)

Oct 22, 2026 · @Jacob Robbins

## Summary

**Use LIGO with CameLIGO.** Our starting guess holds, and the evidence is stronger than expected. As of Oct 22, 2026, LIGO is the only Tezos language that is both actively maintained and current with mainnet: 1.16.2 shipped Oct 14, 2026 with Ushuaia support. It also produces the smallest, most provable Michelson of the three languages we compiled.

- **Only two ecosystems are alive:** LIGO (TriliTech, 3 releases this month) and SmartPy (last stable Aug 14, 2026). Archetype stopped in Dec 2024; Lorentz closed in 2023; Juvix is archived.
- **For the same token ledger, LIGO emits 47 instructions, SmartPy 66, Archetype 110.** LIGO also has the fewest failure branches and the shallowest stack access, both of which cut proof effort.
- **LIGO's output stays inside what the provers read.** Mi-Cho-Coq, Helmholtz and MicSE handle every form it emitted, as long as we strip views, inline helpers, and swap each event for a stand-in before proving. That keeps events for indexers in the deployed contract.
- **Testing is a tie.** No language's test framework targets a real node, so the TezBox suite is Taquito either way. All six samples originated and ran on our TezBox.

## What changed since Phase 1

Phase 1 showed that no high-level Tezos language ships a prover, so the source language no longer matters for proofs. It matters for two other things: whether its compiled Michelson stays inside what the provers can read, and how fast we can build a contract plus a test suite that runs on our local TezBox node.

Phase 1 findings that carry over (tezos\_prover\_phase\_1\_results):

- **Every Michelson prover is frozen at a 2020 to 2023 protocol.** Mi-Cho-Coq (Edo to Granada), Helmholtz (Nairobi) and MicSE (Edo era) are the three that read Archetype's `code` sections. Mainnet runs Ushuaia (protocol 021).
- **None reads a top-level `view` section or `EMIT`.** One `EMIT` anywhere stops all three. Views can be stripped and checked separately. Events looked like a hard blocker; Events for indexing below gives a workaround.
- **n-ary stack forms are fine for the leading three** (`DUP n`, `PAIR n`, `UNPAIR n`), but rule out WhylSon (no `DUP n`) and K-Michelson (no `PAIR n`).
- **Archetype 1.5.3 has no spec syntax left**, and its last release was Dec 17, 2024.

The new plan:

1. Write one contract in the chosen language, restricted to the instructions the provers model.
2. Write a test suite and run it against the contract deployed on TezBox.
3. After the fact, prove properties of the deployed `.tz` with the Phase 2 shortlisted prover.

So the question this doc answers: **which language and compiler ecosystem, as of Oct 2026, gives us the shortest path to steps 1 and 2 while keeping the output provable in step 3?**

## Requirements for the source language

The language has to meet five requirements, ranked. The first two decide; the rest break ties.

| # | Requirement | Why | How we check it |
| --- | --- | --- | --- |
| R1 | Output stays inside the provers' instruction set | Mi-Cho-Coq, Helmholtz and MicSE model roughly the Granada to Nairobi instruction set, with no top-level `view` and no `EMIT` | Compile the Phase 0 samples, run `verification/inventory.py`, diff against the forms each prover accepts |
| R2 | Actively maintained and current with the mainnet protocol | The contract must originate on TezBox (Ushuaia, Octez v25.2) and later on mainnet | Last release, protocol support, maintainer |
| R3 | Gives us control over views and events, and keeps output predictable | Views and events are opt-in in every language, but the compiler must not insert instructions we did not ask for | Read the compiled `.tz` for unrequested instructions |
| R4 | Good test story against a real node | Step 2 runs the suite on TezBox, not only in a simulator | Can its tests target an RPC endpoint, or do we pair it with Taquito or `octez-client`? |
| R5 | Readable, tractable Michelson | Proof effort rises with deep stack shuffling and redundant failure branches (Phase 0 saw `DUP 7`, `NAT_NEG_ASSIGN`) | Size and shape of the compiled `.tz` for the same contract |

OCaml-style syntax is a preference, not a requirement: the proofs are written against Michelson, so the source syntax only affects authoring speed.

## Candidates as of Oct 22, 2026

Only two ecosystems are actively maintained: LIGO and SmartPy. LIGO shipped three releases this month and already targets Ushuaia; SmartPy's last stable release was Aug 14, 2026. Everything else has stopped.

| Ecosystem | Syntax | Latest release | Maintainer | Protocol support | Status |
| --- | --- | --- | --- | --- | --- |
| [LIGO](https://gitlab.com/ligolang/ligo) (CameLIGO, JsLIGO) | OCaml-like (CameLIGO) or TypeScript-like (JsLIGO), one compiler | 1.16.2, Oct 14, 2026 (1.16.0 Oct 13; 1.15.6 Jul 2) | LigoLang and TriliTech (`ligo.opam`); backend shared through TriliTech's [lltz](https://github.com/trilitech/lltz) | Octez `v25-ligo` (Jun 30, 2026); Ushuaia relabel and Seoul/Tallinn address ops added Sept 2026 | **Active.** 74 commits since Oct 2025; Homebrew bottle for Apple Silicon (`arm64_tahoe`) |
| [SmartPy](https://smartpy.tezos.com/releases.html) | Python | 0.24.2, Aug 14, 2026 (stable); 0.25.0a11, Jul 30, 2026 (alpha) | SmartPy team; on PyPI as `smartpy-tezos` | Tallinn default since 0.24.0 (Jan 19, 2026); bundles `octez-client` 24.0; Ushuaia not mentioned | **Active, slower.** One stable bugfix release since January |
| [Archetype](https://github.com/completium/archetype-lang) | Own DSL | 1.5.3, Dec 17, 2024 | Completium | Pre-2025 protocols | **Stopped.** [docs.tezos.com](https://docs.tezos.com/smart-contracts/languages) calls it "no longer actively developed"; no prover since 1.4.2 |
| [Lorentz / Morley](https://gitlab.com/morley-framework/morley) | Haskell eDSL | lorentz 0.16.0, Jul 31, 2023 | Serokell | Nairobi era | **Closed.** Last commit "Update deprecation's warnings" (Jul 31, 2023) |
| [Juvix](https://github.com/anoma/juvix) | Own functional language | n/a | Anoma | n/a | **Archived** on GitHub; pivoted to Anoma, not Tezos |
| Hand-written Michelson | Michelson | n/a | n/a | Whatever we write | Always available; no compiler to trust, but no abstraction either |

The official [Tezos languages page](https://docs.tezos.com/smart-contracts/languages) (updated Nov 10, 2025) lists exactly three: LIGO, SmartPy, and Archetype, flagging only Archetype as inactive.

Two LIGO details matter for proving:

- **Raphaël Cauderlier**, a Mi-Cho-Coq author, has commits in LIGO this year. The Michelson verification and LIGO communities overlap more than the others.
- **`--michelson-comments location`** maps each Michelson instruction back to its CameLIGO source line, which helps when a proof fails on a branch.

## Comparison against the requirements

LIGO (CameLIGO) meets every requirement and wins R2 and R5 outright. SmartPy is a credible second. Archetype now fails R2 and does worst on R5. The rest drop out on R2.

| Requirement | LIGO (CameLIGO) | SmartPy | Archetype | Lorentz, Juvix | Hand-written Michelson |
| --- | --- | --- | --- | --- | --- |
| R1 Output inside prover set | **Pass.** All forms covered by Mi-Cho-Coq, Helmholtz, MicSE (views stripped) | **Pass**, same caveat | **Pass**, same caveat | Not tested | Pass by construction |
| R2 Maintained, current protocol | **Pass.** 1.16.2 (Oct 14, 2026), Ushuaia-aware | **Partial.** 0.24.2 (Aug 2026), Tallinn default, Octez 24 | **Fail.** Dec 2024 | **Fail.** Closed or archived | n/a |
| R3 No unrequested instructions | **Pass.** Views and events only when written; shared helpers become `LAMBDA` unless `[@inline]` | **Pass.** Adds `FAILWITH <line number>` for `sp.as_nat` and map lookups | **Weak.** Adds `ASSET_NOT_FOUND`, `NAT_NEG_ASSIGN` branches the source already guards | n/a | Pass |
| R4 Tests against TezBox | In-process `ligo run test` is a simulator; real-node tests via Taquito | Scenarios are simulated; real-node tests via Taquito | Completium CLI can target a node, but stale | n/a | Taquito or `octez-client` |
| R5 Tractable Michelson | **Best.** Token ledger: 47 instructions, 2 `FAILWITH`, deepest `DUP 4` | 66 instructions, 4 `FAILWITH`, `DUP 5`; emits stack-type comments | **Worst.** 110 instructions, 5 `FAILWITH`, `DUP 7` | n/a | As good as we write it |
| Syntax for this team | OCaml-like, which we prefer | Python | Own DSL | Haskell, own | Stack code |

Hand-written Michelson is the fallback for small, critical pieces, not for the whole contract: it removes compiler trust but loses types, records and pattern matching.

## Spike: the same contracts in three compilers

We rewrote the Phase 0 counter, owner-only setter and token ledger in CameLIGO and SmartPy, compiled them, and ran the Phase 0 inventory over all three. **LIGO's output is 42 to 57% smaller than Archetype's, with fewer failure branches and shallower stack access.** Everything is in `verification/lang_spike/` and rebuilds with `compare.sh`.

| Contract | Compiler | Instructions | Distinct forms | `FAILWITH` sites | Deepest `DUP`/`DIG`/`DUG n` |
| --- | --- | ---: | ---: | ---: | ---: |
| counter | Archetype 1.5.3 | 40 | 19 | 1 | 3 |
| counter | LIGO 1.16.2 | 18 | 12 | 1 | none |
| counter | SmartPy 0.24.2 | 21 | 17 | 2 | 3 |
| owner\_setter | Archetype 1.5.3 | 38 | 18 | 2 | 2 |
| owner\_setter | LIGO 1.16.2 (`[@inline]` check) | 22 | 13 | 2 | 2 |
| owner\_setter | SmartPy 0.24.2 | 22 | 13 | 2 | 2 |
| token\_ledger (with view) | Archetype 1.5.3 | 110 | 31 | 5 | 7 |
| token\_ledger (with view) | LIGO 1.16.2 | 47 | 21 | 2 | 4 |
| token\_ledger (with view) | SmartPy 0.24.2 | 66 | 25 | 4 | 5 |

**Prover coverage of the new forms.** LIGO and SmartPy emit 8 forms Archetype did not: `CAR`, `DROP`, `EXEC`, `GET n`, `ISNAT`, `LAMBDA`, `NEQ`, `UPDATE n`. We checked each prover's source:

- **Mi-Cho-Coq** (`micheline2michelson.v` on `dev`): all 8, including `GETN` and `UPDATEN`.
- **Helmholtz** (`src/refx.ml` on `refx3`): all 8. `LAMBDA` needs a lambda annotation (`retrieve_lambda_annot`), so non-inlined helpers add proof work.
- **MicSE** (`michParser.mly`, `mich.ml`): all 8; `GET n` and `UPDATE n` are expanded as macros.

**What shapes proof effort:**

- **LIGO uses `ISNAT` for nat subtraction**, so `count - n` underflow is one `IF_NONE` branch. Archetype and SmartPy compare first, then subtract, adding a second failure branch the prover must show unreachable.
- **A LIGO helper used twice becomes `LAMBDA` + `EXEC`** (26 instructions instead of 22). Marking it `[@inline]` removes the lambda. Our rule: inline every helper in contracts we prove.
- **The three LIGO modes gave byte-identical output** (default, `--lltz-ir`, `--enable-michelson-typed-opt`). The new lltz backend does not change these samples.
- **SmartPy prints the stack type after each instruction** as comments, which helps when writing Helmholtz annotations by hand.

**On-chain check.** All six main samples (Archetype, LIGO and SmartPy counters; LIGO owner setter; LIGO and SmartPy token ledgers) originated on our local TezBox (Ushuaia, Octez v25.2), took one call, and returned the expected storage. Both token ledgers' `balance_of` view returned 10 after a transfer of 10. Script: `verification/lang_spike/smoke.mjs`.

**Gaps.** Like Phase 0, no sample moves tez or calls another contract, and only one (below) uses events. Views and events both need the prover-prep step in every language.

## Testing on TezBox

No language's built-in test framework runs against a real node, so the TezBox suite will be TypeScript on Taquito whichever language we pick. That makes R4 a tie and keeps the suite reusable if we ever switch languages, since it only sees the `.tz`.

| Layer | Tool | Runs against | Role |
| --- | --- | --- | --- |
| Unit tests while writing | `ligo run test` (LIGO Test module) | LIGO's in-process interpreter | Fast feedback, property and mutation tests. LIGO's own help says no real test procedure should rely on it alone |
| Integration suite | [Taquito](https://github.com/ecadlabs/taquito) 25.1.0 (Oct 19, 2026) + Vitest or `node:test` | TezBox at `localhost:8732` (Ushuaia, Octez v25.2) | The suite of record: originate, call every entrypoint, check storage, views, failures and balances |
| Typecheck and dry runs | `octez-client` inside the TezBox container | TezBox | `typecheck script`, gas, and storage size of the exact `.tz` we prove |
| Proof | Shortlisted prover (Phase 2) | The same `.tz` file | Proof tied to the hash of the deployed `code` |

Notes from the smoke test:

- **The Taquito already in the repo is 23.1.0**, pulled in by Completium CLI. It worked against Ushuaia, but the suite should pin 25.1.0 as a direct dependency.
- **Taquito parses storage and arguments as Micheline**, so `Pair a b` must be written `(Pair a b)`. Without parentheses the node rejects the origination with `invalid_arity`.
- **TezBox ships `octez-client`** and sandbox accounts (`alice`, `bob`) in `tezbox/configuration/accounts.hjson`, so the suite needs no keys of its own.

## Events for indexing

**We can emit events and still prove the contract.** The deployed contract keeps its `EMIT`s; the copy we prove replaces each one with a stand-in of the same shape. Phase 1 counted `EMIT` as a blocker because no prover parses it. This removes the blocker without patching any prover.

**Why events.** TzKT (API 1.17.5) indexes both events (`/v1/contracts/events`, 3,742,902 on mainnet on Oct 22, 2026) and every big_map key change with its history (`/v1/bigmaps/updates`). So a big_map is not invisible, but its diffs show only what changed, not why: a balance moved, but not who sent what to whom. An event carries the action itself as a tag plus a typed payload. Dapps use events to feed indexers.

How it works:

1. In CameLIGO, `Tezos.emit "%transfer" payload` compiles to `EMIT %transfer (pair ...)`, and the event goes into the returned operation list.
2. `verification/prove_prep.mjs` rewrites each `EMIT %tag ty` to `{ DROP ; NONE key_hash ; SET_DELEGATE }`, removes views, and typechecks the result. Both versions take one value and push one operation, and neither can fail or touch storage or balance.
3. The provers check the rewritten file. Mi-Cho-Coq, Helmholtz and MicSE all support `DROP`, `NONE`, `SET_DELEGATE` and `CONS` (checked in their source).
4. The TezBox suite checks event payloads on the deployed original.

| Token ledger version | Instructions | Distinct forms | `FAILWITH` sites | Deepest `DUP`/`DIG`/`DUG n` |
| --- | ---: | ---: | ---: | ---: |
| No events | 47 | 21 | 2 | 4 |
| With `transfer` event (deployed) | 59 | 26 | 2 | 5 |
| With event, after `prove_prep.mjs` | 54 | 28 | 2 | 5 |

Against the earlier spike, the prover copy adds only two forms: `CONS` and `SET_DELEGATE`. On TezBox the evented ledger originated and transferred 10 to bob, and the call's receipt carried a `transfer` event with sender alice, recipient bob and amount 10. The prover copy also typechecks with `octez-client` in TezBox.

What we give up:

- **Proofs say where an event is emitted, not what it contains.** In the prover copy an event is a `SET_DELEGATE None` in the operation list. Payloads are covered by tests, not proofs.
- **The prover copy has a different code hash.** We tie the proof to the deployment by fetching the deployed `code` from the node, rerunning `prove_prep.mjs`, and checking the output matches the proved file byte for byte.
- **The contract must never call `SET_DELEGATE` itself**, or the stand-in becomes ambiguous. `prove_prep.mjs` refuses such contracts.

If we later need proofs about payloads, we can patch Helmholtz with an `EMIT` handler. Phase 1 found it has the same shape as Helmholtz's existing `TRANSFER_TOKENS` handler, and it keeps the payload in the logic.

## Views: keep them

**Keep on-chain views. They do not break the prover tooling, and turning them into regular entrypoints costs every caller more than it saves us.** A view is read-only: it cannot change storage or emit operations. So removing views from the prover copy cannot weaken any proof about the entrypoints. Each view body then gets its own small proof as a stand-alone program.

The gain from views is less about speed than about who can read the value and how:

| | On-chain view | Getter entrypoint (callback, TZIP-4 style) |
| --- | --- | --- |
| Who can read | Any contract, in the same execution; any off-chain client via the `run_script_view` RPC, free | Only contracts that have a callback entrypoint; off-chain clients can only simulate |
| Cost per read | Gas inside the caller's operation; nothing off-chain | A full extra transaction; the answer arrives in a later internal operation |
| Caller code | Uses the value immediately | Must split its logic across two entrypoints |
| Instructions added (Phase 1 `token_ledger_getter`) | None in `code` | `AMOUNT`, `ITER`, `TRANSFER_TOKENS` |
| Proof effort | One small stand-alone proof per view | Two extra Helmholtz loop invariants; the result is an operation, which Mi-Cho-Coq only axiomatizes, so "returns the balance" becomes a weaker claim |

**How we prove a view.** `prove_prep.mjs contract.tz --view NAME` wraps the view's body as `parameter (pair <arg> <storage>) ; storage <result> ; code { CAR ; <body> ; NIL operation ; PAIR }`. A postcondition on the wrapper's new storage is a postcondition on the view's result. On the evented ledger, the `balance_of` wrapper typechecks on TezBox, and `octez-client run script` returns 10 for bob, 990 for alice and 0 for an unknown address. That matches the deployed view, which returned 10 for bob.

Caveats:

- **A view proof assumes any storage.** Properties that rely on a contract invariant, such as balances summing to `total_supply`, take it as a precondition, and the entrypoint proofs establish it.
- **Views see the caller's context.** If a view body reads `SENDER`, `NOW` or `BALANCE`, the wrapper treats them as unconstrained inputs. That is sound but may need extra preconditions.
- **The deployment check must cover views too.** Rerun `--view` on each view of the deployed script and compare byte for byte, as for `code`.

## Recommendation, risks and next steps

**Write the contract in CameLIGO with LIGO 1.16.x, test it on TezBox with Taquito 25.1.0, and prove the compiled `.tz`.** Keep SmartPy as the fallback if LIGO stalls.

House rules for contracts we intend to prove:

1. Mark every helper `[@inline]`, so no `LAMBDA`/`EXEC` reaches the prover.
2. Emit an event (`Tezos.emit`) for every action indexers need, and run `prove_prep.mjs` before proving (see Events for indexing). Never use `SET_DELEGATE`.
3. Put read-only queries in `[@view]` functions, never getter entrypoints. Prove each view with `prove_prep.mjs --view NAME` (see Views: keep them).
4. Use `is_nat` for nat subtraction, not compare-then-subtract.
5. Pin the LIGO version and keep `--michelson-comments location` output beside each proved `.tz`.

| Risk | Likelihood | Fallback |
| --- | --- | --- |
| A future LIGO release emits a newer instruction (for example Tallinn/Seoul address ops) that the provers lack | Medium | Pin LIGO; run the inventory diff in CI on every compile |
| LIGO's Docker image is amd64 only, so it runs under emulation on this Mac | Certain, low cost | Use the Homebrew bottle (`arm64_tahoe`) for daily work |
| Payments, fee splits and cross-contract calls produce instructions not yet inventoried | High | Add a payment and fee-split sample in CameLIGO before Phase 3 |
| LIGO loses its maintainer | Low (3 releases this month) | SmartPy; the Taquito suite carries over unchanged |

Next steps:

- [ ] Install LIGO 1.16.2 natively from the Homebrew bottle
- [ ] Write a CameLIGO payment and fee-split sample; rerun `compare.sh` and the prover-coverage check
- [ ] Pin Taquito 25.1.0 and turn `smoke.mjs` into a Vitest suite against TezBox that also checks every event payload
- [ ] Carry the CameLIGO `.tz` files into the Phase 2 shortlist and Phase 3 spike instead of the Archetype ones

## Sources

All checked Oct 22, 2026.

- LIGO: [GitLab repo](https://gitlab.com/ligolang/ligo) (tags, releases, commits 1.13.0 to 1.16.2, `ligo.opam`, `.gitmodules`, `HomebrewFormula/ligo.rb` via the GitLab API); [docs 1.16.2](https://ligo.tezos.com/docs/manpages/changelog); `ligo compile contract --help` and `ligo run test --help` from `ligolang/ligo:1.16.2`
- lltz: [trilitech/lltz](https://github.com/trilitech/lltz) (last push Sept 15, 2026)
- SmartPy: [releases page](https://smartpy.tezos.com/releases.html); [PyPI smartpy-tezos](https://pypi.org/project/smartpy-tezos/) (0.24.2 installed and used)
- Archetype: [archetype-lang](https://github.com/completium/archetype-lang) (last push Dec 17, 2024); Completium CLI 1.0.29 (npm, Nov 4, 2025)
- Morley / Lorentz: [GitLab repo](https://gitlab.com/morley-framework/morley) (tags and last commits, Jul 31, 2023)
- Juvix: [anoma/juvix](https://github.com/anoma/juvix) (archived)
- Tezos docs: [Languages page](https://docs.tezos.com/smart-contracts/languages) (updated Nov 10, 2025)
- Taquito: [ecadlabs/taquito](https://github.com/ecadlabs/taquito) (25.1.0, Oct 19, 2026)
- TezBox: [tez-capital/tezbox](https://github.com/tez-capital/tezbox), local checkout `tezbox/` (Sept 6, 2026) and running image `tezos-v25.2`
- Prover sources: [Mi-Cho-Coq](https://gitlab.com/nomadic-labs/mi-cho-coq) `dev` (`micheline2michelson.v`, `syntax.v`); [Helmholtz / ReFX](https://gitlab.com/aigarashi/ReFX) `refx3` (`src/refx.ml`); [MicSE](https://github.com/kupl/MicSE) `master` (`lib/michParser.mly`, `lib/mich.ml`)
- Prior docs: tezos\_contract\_prover\_discovery\_Oct\_15\_2026, tezos\_smart\_contract\_proving\_Oct\_21\_2026, tezos\_prover\_phase\_0\_devlog, tezos\_prover\_phase\_1\_results
- Spike: `verification/lang_spike/` (`ligo/`, `smartpy/`, `compare.sh`, `summary.py`, `smoke.mjs`, `inventory/`)

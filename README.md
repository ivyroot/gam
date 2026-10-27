# GAM — Global Art Market

One shared, immutable, admin-free Tezos contract where artists list works and
collections and sell non-transferable personal and commercial display licenses.
Written in CameLIGO so that its compiled Michelson can be formally verified.

- Spec: `tezos/art-sale-ever-growing-mono-contract-plan/art-sale-ever-growing-mono-contract-plan-oct-26.md`
- Why CameLIGO, events and views: `tezos/updates/tezos_source_language_for_proving_Oct_22_2026.md`
- What was simplified for proving: `tezos/updates/art_sale_contract_provability_review_Oct_22_2026.md`

## Layout

| Path | What |
| --- | --- |
| `src/gam.mligo` | The contract: 7 entrypoints, 6 events, 2 views |
| `test/gam.test.mligo` | Unit tests on LIGO's in-process interpreter |
| `test/tezbox.test.mjs` | Integration tests on the local TezBox node (Taquito 25.1.0): batches, payouts, event payloads, views |
| `scripts/build.sh` | Compile, prepare the prover copy, inventory instructions |
| `proofs/helmholtz/` | Helmholtz specs, the runner, and the native setup script |
| `out/` | Build output, checked in so proofs and tests point at an exact `.tz` |
| `LIGO_VERSION` | The pinned compiler version; `build.sh` refuses any other |

## Build and test

Needs LIGO 1.16.2 (native: a local Homebrew tap of LIGO's own
`HomebrewFormula/ligo.rb` from the `dev` branch, which pours the
`arm64_tahoe` bottle), plus node and python3 with the `tezos/` workspace's
`node_modules`.

```bash
./scripts/build.sh
```

```bash
npm run test:unit
```

With TezBox running on `localhost:8732` (and `npm install` done once):

```bash
npm run test:tezbox
```

`build.sh` writes:

- `out/gam.tz` and `out/gam.storage.tz`: what gets originated
- `out/gam.locations.tz`: the same code annotated with CameLIGO source locations
- `out/gam.prove.tz`: the prover copy (each `EMIT` replaced by `{ DROP ; NONE key_hash ; SET_DELEGATE }`, views removed)
- `out/views/*.view.tz`: each view wrapped as a stand-alone program
- `out/inventory/new_forms.txt`: instruction forms the provers have not yet been checked against

## Proofs

Helmholtz (Z3-backed refinement types) checks specs written against the
compiled Michelson. Each `proofs/helmholtz/NAME.spec` is spliced into a copy of
the matching `.tz` under `out/helmholtz/`; `NAME.wrong.spec` files are
deliberately false and must be rejected.

```bash
npm run prove:helmholtz
```

| Spec | Property | Result (Oct 26, 2026) |
| --- | --- | --- |
| `has_license` | Returns the stored licence, or all zeros for an unwritten key; never fails; no operations | Verified |
| `in_collection` | True exactly when the membership key exists; never fails; no operations | Verified |
| `purchase.p1_payment` | Succeeds only for an existing, active target with a non-zero price for the tier, `quantity > 0`, and exactly unit price × `quantity` sent | Verified |
| `purchase.p2_failures` | Fails only with `ZERO_QUANTITY`, `UNKNOWN_LISTING`, `UNKNOWN_COLLECTION`, `NOT_ACTIVE`, `NOT_FOR_SALE`, mutez overflow, `WRONG_AMOUNT` or `ARTIST_CANNOT_RECEIVE`, each under exactly its condition | Verified |
| `purchase.p3_p4_license` | The buyer's licence count for the tier rises by exactly `quantity`, the other is unchanged, and `purchased_at_level` is set only on the first purchase | Verified |
| `purchase.p5_ops` | Operations are exactly `[transfer of AMOUNT to the artist; event]` | Verified |
| `purchase.p6_license_frame` | Only the buyer's own `(sender, artist, target)` licence entry can change | Verified |
| `purchase.p6_frame` | The other six big_maps are unchanged | Verified |
| `<entrypoint>.p6_frame` (×6) | `set_name`, `set_website`, `list`, `set_collection`, `set_collection_item` and `review` each change only the sender's own key in their one big_map; the other six are unchanged | Verified |
| `list.p7_write_once` | Success needs the sender's website; writes exactly the given record; an existing listing keeps `website_id` and `file_hash`; a new one needs a non-empty `file_hash` | Verified |
| `list.p7_failures` | Fails only with `UNKNOWN_WEBSITE`, `WEBSITE_ID_IMMUTABLE`, `FILE_HASH_IMMUTABLE` or `EMPTY_FILE_HASH`, each under exactly its condition | Verified |
| `set_collection.p7_write_once` | Success needs the sender's website; writes exactly the given record; an existing collection keeps `website_id` | Verified |
| `set_collection.p7_failures` | Fails only with `UNKNOWN_WEBSITE` or `WEBSITE_ID_IMMUTABLE`, each under exactly its condition | Verified |
| `review.p8_gate` | Success needs the sender's licence bought in an earlier block, and a rating in 1–10 or a comment | Verified |
| `review.p8_posted_at` | Stores exactly the given rating and comment with `updated_at = now`; `posted_at` is kept from the first review | Verified |
| `review.p8_failures` | Fails only with `NO_LICENSE`, `EMPTY_REVIEW`, `BAD_RATING` or `TOO_EARLY`, each under exactly its condition | Verified |

Specs about `purchase` and the P7/P8 specs have deliberately wrong twins that
must not verify. `purchase.p2_failures.wrong` and `review.p8_failures.wrong` are
refuted with a counterexample. The rest end `UNKNOWN`: Z3 can't build models
through Helmholtz's sequence encoding of the operation list, or (for
`list.p7_failures.wrong`, a failing call) most likely its string encoding of
`list`'s bytes parameters. Proofs take a second or two each; the whole run, wrong twins
included, about ten minutes of solver time (longer on a busy machine).

Helmholtz builds natively into `tezos/vendor/helmholtz` with
`proofs/helmholtz/setup.sh`, which documents the workarounds its README needs.

### Mi-Cho-Coq (kernel-checked)

`purchase`'s payout property (P5) is also proved in Coq with Mi-Cho-Coq, as a
cross-check that needs no SMT solver.

```bash
npm run prove:michocoq
```

| Proof | Property | Result (Oct 27, 2026) |
| --- | --- | --- |
| `purchase_p5` | For every environment, storage and fuel ≥ 60: if `purchase` succeeds, the artist has a `contract unit` `c` and the operations are exactly `[transfer of AMOUNT to c; SET_DELEGATE None]` (the event placeholder) | Proved |

`gam_source.v` has Coq run Mi-Cho-Coq's parser and typer on the text of
`out/gam.prove.tz` (embedded by `gen_string.py`), so the proof is about that
exact file. `run.sh` fails if the proof rests on anything beyond Coq's
primitive-integer axioms, Mi-Cho-Coq's abstract BLS12-381 operations and the
abstract contract lookup `C.get_contract_type`. The check takes about a minute.
Mi-Cho-Coq builds natively into `tezos/vendor/mi-cho-coq` with
`proofs/michocoq/setup.sh` (Coq 8.16.1).

## Notes for client tools

- **A review cannot go out until the block after the first purchase's block is baked.** The contract requires `LEVEL > purchased_at_level`, and wallets simulate at the head's level. So even a review sent on its own simulates as `TOO_EARLY` until the head has moved one block past the purchase. Sites should hide or delay the review button until then.
- **Event payloads in receipts are in optimized form** (comb pairs as sequences, addresses as bytes, timestamps as ints). Decode each with the event's own `type`, as `test/tezbox.test.mjs` does with Taquito's `Schema`.

## House rules

1. Every helper is `[@inline]`: no `LAMBDA`/`EXEC` in the output.
2. Every action indexers need is an event; never `SET_DELEGATE`.
3. Read-only queries are `[@view]`s, never getter entrypoints.
4. Nat subtraction uses `is_nat`.
5. No loops; each entrypoint writes at most one big_map entry, keyed by the sender.

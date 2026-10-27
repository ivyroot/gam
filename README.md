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

## Notes for client tools

- **A review cannot go out until the block after the first purchase's block is baked.** The contract requires `LEVEL > purchased_at_level`, and wallets simulate at the head's level. So even a review sent on its own simulates as `TOO_EARLY` until the head has moved one block past the purchase. Sites should hide or delay the review button until then.
- **Event payloads in receipts are in optimized form** (comb pairs as sequences, addresses as bytes, timestamps as ints). Decode each with the event's own `type`, as `test/tezbox.test.mjs` does with Taquito's `Schema`.

## House rules

1. Every helper is `[@inline]`: no `LAMBDA`/`EXEC` in the output.
2. Every action indexers need is an event; never `SET_DELEGATE`.
3. Read-only queries are `[@view]`s, never getter entrypoints.
4. Nat subtraction uses `is_nat`.
5. No loops; each entrypoint writes at most one big_map entry, keyed by the sender.

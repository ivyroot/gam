# Art sale contract: provability review of the Oct 8 spec (Oct 22, 2026)

Oct 22, 2026 · @Jacob Robbins

## Summary

**Drop `collection.item_count` and replace the two loops in `set_collection_items` with a single-item entrypoint plus wallet batching.** These two features hold most of the proof difficulty in the Oct 8 spec, and both buy little on-chain. With them gone, every entrypoint is a single pass with no loops, and every key property can be checked one call at a time, which Mi-Cho-Coq, Helmholtz and MicSE can all do.

- **`item_count` is the hardest thing in the contract to prove.** Its correctness is a counting rule over a whole big_map, and its only on-chain use is rejecting purchases of empty collections.
- **The loops are the second-hardest.** Each loop needs a hand-written invariant in Helmholtz, and they make the "only the caller's own data" proof much harder.
- **`purchase` is worth the effort and should stay whole.** Exact payment, monotone licence counts and payout to the artist are the properties proving is for.
- **Event payloads are tested, not proved.** Our prover prep step (`prove_prep.mjs`) replaces every `EMIT` with a stand-in, so the full-snapshot rule lives in the TezBox suite.

This review applies the approach in tezos\_source\_language\_for\_proving\_Oct\_22\_2026: CameLIGO, compiled Michelson, events and views stripped before proving.

## Hardest to prove, ranked

| Rank | Feature | Property to prove | Why it is hard | Verdict |
| --- | --- | --- | --- | --- |
| 1 | `collection.item_count` | For every collection, `item_count` equals the number of `collection_items` keys under it | A counting rule over a whole big_map. Helmholtz and MicSE check one call at a time and cannot express "how many keys match"; Mi-Cho-Coq needs a hand-built counting proof per entrypoint and per loop pass | Remove |
| 2 | Loops in `set_collection_items` | Each pass adds or removes exactly one real member, emits one event, touches only the caller's keys | Two `ITER` loops that read and write big_maps, can fail partway, emit events and update the count. Helmholtz needs a loop invariant per `ITER` | Replace with a single-item entrypoint |
| 3 | `purchase` | Exact payment; active target, non-zero price; counts rise by exactly `quantity`; `purchased_at_level` set only on first purchase; payment to `artist` | Mi-Cho-Coq models outgoing transfers only abstractly, so "funds go to the artist" is stronger in Helmholtz. `quantity` adds one `MUL`, but specs only restate the same check | Keep; the core proof target |
| 4 | Self-scoping (design principle 1) | Every write is under a key starting with `SENDER`; nothing else changes | A frame rule over every big_map in every entrypoint. Straightforward without loops (each write is one map update); much harder with them | Keep; easy once loops are gone |
| 5 | Event payloads (design principle 8) | Every `%listed` / `%collection_set` / `%website_set` carries the full current record | The prover copy replaces each `EMIT` with `{ DROP ; NONE key_hash ; SET_DELEGATE }`, so payloads are invisible to proofs | Test on TezBox, not proved |

**The hidden cost of `item_count`.** `c.item_count := c.item_count - 1` on a nat compiles to a subtraction with a failure branch. The spec says it "cannot underflow," but proving that branch is unreachable needs the counting rule from rank 1. So the count cannot be left out of the proof while the field stays.

**If we keep `item_count` anyway,** the per-call rule is easy: the count moves by exactly one for each real add or remove. The claim that it equals membership would then rest on a hand-written induction argument, not a machine proof.

## Proposed spec changes

Three changes remove the hard proofs; the fourth is optional.

| Change | What goes | What replaces it | Cost to the design | Proof gain |
| --- | --- | --- | --- | --- |
| Drop `item_count` | The field; `require c.item_count > 0` in `purchase`; the count in `%collection_set`; `set_collection_items` rewriting the collection record | The admin tool creates collections with `active = false` and opens them once they have works. Indexers count members from `%collection_item_set`. Sites show the count from their own mirror or an indexer | An artist can sell an empty collection only by reopening it while empty, the same artist's-call as setting prices to zero. The "Failed delivery" threat row moves from contract-enforced to template-enforced | Removes the rank 1 counting rule and the unreachable-underflow branch |
| Single-item membership | `set_collection_items(collection_id, add, remove)` and its two loops | `set_collection_item(collection_id, listing_id, included : bool)`; many changes go in one wallet batch, as the spec already does for multi-listing drops | One call per change, so somewhat more gas per large edit. The add-then-remove ordering rule disappears | No loops anywhere in the contract; self-scoping becomes a one-update-per-call rule |
| Two-case `tier` | The `No_license` constructor and `require tier != No_license` | `type tier = Personal \| Commercial` | None | One failure branch fewer in `purchase` |
| Optional: trim event lookups | `artist_name` and `website_url` in `%listed` and `%collection_set` | Indexers join `names` and `%website_set` themselves | Indexers do one more join | Fewer big_map reads and one "if set, else empty" branch. No effect on proofs (events are stripped), only code size and gas |

The single-item entrypoint keeps every check the loop had: the collection exists, the listing exists under the caller, `website_id` matches, and adding an existing member or removing a non-member rejects. With `item_count` gone it no longer writes the collection record or emits a `%collection_set` snapshot, only `%collection_item_set`.

These changes are independent: dropping `item_count` alone removes rank 1, and the single-item entrypoint alone removes rank 2.

## Easy to prove, keep as is

Each of these is a property of a single call, with no loops and no counting, so all three provers can state it.

| Feature | Entrypoint | Property |
| --- | --- | --- |
| `active` and zero price (principles 4, 5) | `purchase` | Rejects when the target is inactive or the requested tier's price is 0 |
| `file_hash` write-once (principle 10) | `list` | A new listing needs a non-empty hash; an existing one keeps its hash, or the call rejects |
| `website_id` fixed at creation | `list`, `set_collection` | The website must be registered; an existing record keeps its `website_id`, or the call rejects |
| Non-transferability (principle 2) | All | No entrypoint lowers a licence count or writes a licence under another buyer |
| Review gate | `review` | Needs a licence on that target, a rating of 1 to 10 if present, and `LEVEL` above `purchased_at_level`; `posted_at` never changes after the first write |
| `has_license` view | View | Returns the stored record, or `{0; 0; 0}` for a key never written; proved with `prove_prep.mjs --view has_license` |
| `in_collection` view | View | Returns whether the key exists (`MEM`); proved with `prove_prep.mjs --view in_collection` |
| Execution order (reentrancy section) | `purchase` | Guaranteed by Michelson semantics: storage is committed before any emitted operation runs. Nothing to prove beyond the operation list |

## Open checks for Phase 2

- [ ] Confirm MicSE supports `LEVEL` (used by `review`). Mi-Cho-Coq and Helmholtz do.
- [ ] Add `SIZE` on bytes, `NOW`, `CONTRACT unit` and `MUL` on mutez by nat to the prover coverage check.
- [ ] Check that Helmholtz can state the self-scoping frame rule for big_maps keyed by nested pairs and an `or` (`target`).
- [ ] Decide with the spec owner whether to drop `item_count` and adopt the single-item entrypoint, then revise the spec before any CameLIGO is written.
- [ ] Write the TezBox tests for event payloads, since proofs will not cover them.

## Sources

- Spec: `tezos/art-sale-ever-growing-mono-contract-plan/art-sale-ever-growing-mono-contract-plan-oct-8.md` (read Oct 22, 2026; earlier drafts not read)
- Toolchain and prover-prep approach: tezos\_source\_language\_for\_proving\_Oct\_22\_2026; `verification/prove_prep.mjs`
- Prover capabilities: tezos\_prover\_phase\_1\_results, and prover source read Oct 22, 2026 ([Mi-Cho-Coq](https://gitlab.com/nomadic-labs/mi-cho-coq) `dev`, [Helmholtz / ReFX](https://gitlab.com/aigarashi/ReFX) `refx3`, [MicSE](https://github.com/kupl/MicSE) `master`)

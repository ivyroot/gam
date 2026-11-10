# Global Art Market: design whitepaper



## Ethos

- One shared, immutable, admin-free Tezos contract underlies every deployment. No owner key, no pause function, no upgrade path — nothing to compromise or govern because nothing is privileged.
- The contract takes no cut. It cannot enforce that editorial, curatorial, or distribution parties (charts, magazines, aggregators) also take no cut — that can only ever be a cultural norm the ecosystem holds itself to, the way straight edge is a personal code rather than an external constraint. What the system *can* do is make free, uncut linking the path of least resistance, so charging a toll requires deliberately added friction rather than being the default.
- The goal is a distribution flywheel that favors fringe, indie, and upcoming artists: every listing, collection, and sale is a public, cryptographically-verified event (verified because artist == account), which anyone can build charts, feeds, or discovery tools on top of — without needing permission from a central registry.
- Sustainable artist revenue comes from a simple, familiar ladder: a prospect buys one work, becomes a customer, and later buys a collection at its own price. The contract enforces each price exactly as the artist set it; it never computes a discount.
- Explicit anti-goals: no admin, no privileged party, no discount logic that could create edge-case bugs in immutable code, no tradable receipts (this is not an NFT), no forced dependency on paid third-party services (e.g. IPFS pinning subscriptions) for a basic listing.

## System overview

Roles:
- **Artist** — a Tezos wallet address, paired with one or more registered websites that fulfill their listings and collections. There is no separate "storefront" concept: an artist's site (built on Cloudflare Pages + Workers) is both the display layer and the only place that can actually deliver files, since delivery requires access to that specific deployment's private R2 bucket and session logic. Fully sovereign: only the holder of the key can write to that address's listings, collections, or websites, and every sale pays that same address. One person may operate several artist identities (noms de plume), each with its own site(s), with no on-chain linkage between them.
- **Buyer** — a Tezos wallet address that purchases display licenses — for a single listing or for a whole collection — directly from an artist's own site.
- **Editorial / discovery parties** — magazines, charts, aggregators, and any other third-party site. They can read the public event log and link to a listing or collection, but they hold no files and cannot fulfill a purchase — only the artist's own declared site can do that. Discovery is open to anyone; fulfillment is not.
- **Shared contract** — the single, immutable, admin-free registry described below. Every artist's site, and any editorial tool that wants to read the public log, points at the same contract.

What an artist sells, in two shapes:
- **A listing** — one artwork, one file, one price per tier. The entry point for a new collector.
- **A collection** — a named, priced group of the artist's own listings. Buying it grants downloads of every listing it currently contains, including works added after the purchase. The collection holds only references to listings; it has no file of its own.

## On-chain contract

### Design principles

1. **No entrypoint acts on anyone else's data.** Every write is scoped to `Tezos.get_sender()`. This is what makes "no admin" achievable — there's no privileged code path to compromise because there isn't one. It also means a collection can only ever contain its own artist's listings: membership keys are written under the caller's address, and each referenced listing is looked up under that same address.
2. **No transfer entrypoint exists, anywhere, for anything.** This is what makes licenses non-tradable without needing a special "soulbound" flag — there's simply no function that could ever move one.
3. **Price is enforced atomically on-chain.** `purchase` checks the sent amount against a price that was itself set on-chain, in the same operation — for listings and collections alike. Never trust an off-chain-only price.
4. **Zero price means not for sale.** Since `purchase` already requires payment `> 0`, a price of `0` for a tier naturally fails that check — no separate `is_for_sale` flag or `option` type needed. An artist can pull either tier of a listing or a collection from sale independently at any time by re-sending its record with that price set to `0`.
5. **`active = false` means closed to direct purchase, but still visible.** Listings and collections each carry an explicit `active` flag. When it's `false`, `purchase` of that listing or collection rejects for both tiers, but the record, its event history, its licenses and its reviews all stay exactly where they are, and the artist's site keeps showing its page. This is the realistic alternative to guessing a supply cap at mint time, which was a recurring failure in NFT drops: set the cap too low and you leave your best collectors unserved, too high and the unsold remainder reads as failure. Here there's no cap to guess — the artist simply closes the sale when they decide it's done, and can reopen it later the same way. Zero price (principle 4) and `active` are complementary: zero price pulls one tier while the other stays on sale; `active = false` closes the whole thing without having to touch, and later remember, both prices.
   - **Collection-only works.** A listing's `active` flag governs only buying that listing on its own. A listing with `active = false` that sits in an active collection is still obtainable — by buying the collection. Its prices stay set and visible on purpose: the single-work price is the public anchor that makes the collection price read as good value (see "Collections" below). The listing page then says "available in [collection]" rather than "no longer available."
6. **Artists sell display licenses to their art, delivered as digital downloads, in two types: personal display and commercial display — and any account can buy as many of each as it wants.** This applies identically to a listing and to a collection. The tiers are independent, not a hierarchy: a buyer can hold either, both, or neither, purchased in any order, each at its own full price. There is no per-buyer limit on either tier; every purchase is charged the full price × quantity, regardless of anything the buyer already holds — a buyer who already owns some works in a collection still pays the collection's full price — with no discount logic anywhere. The rationale is a lesson from the NFT bull run: the largest purchasers need to be *allowed* to spend more. At the successful-but-not-huge artist level, a single dedicated collector very often accounts for the majority of an artist's sales — the same pattern as physical fine art, where one patron can carry an artist's career — and that collector carries most of the profit upside for a body of work. A one-per-buyer rule caps exactly that person. `license` therefore records per-tier *counts* rather than booleans, and `purchase` is an unconditional "price matches, target active, increment the count" — no "already held" check at all, which is exactly the kind of thing that's safe to leave immutable forever.
7. **Each artist operates at least one website, which hosts their listing and collection pages and fulfills their digital downloads.** A ready-made template, with setup instructions, deploys that site at minimized cost to the artist — see "Off-chain architecture (Cloudflare)" below.
8. **Every listing, collection, and website write emits the full current record as an event, not a diff.** This keeps indexers from ending up with partial or stale data after an update. See "Event log" below.
9. **No on-chain enumeration, deliberately.** The only read-only additions are `view`s for point lookups — never a way to list "everything an address holds," "everyone who bought this," or "every work in this collection." Collection membership is stored as one small entry per (collection, listing) pair, never as a growing list inside the collection record. (See "Views, and why there's no on-chain enumeration" below for the specific failure mode this avoids.)
10. **Each listing sells exactly one file, fixed forever, committed at creation.** Usually that's a single image, the way collectors already buy individual works. An artist may list a zip as the file if they want to, but the contract never knows or tracks what's inside it; grouping works on-chain is what collections are for. The file's hash is written on-chain by the artist's wallet when the listing is created and can never change — so a listing is a permanent commitment to one exact, finished file, and a buyer can check on their own machine, with a standard command, that the file they downloaded is the one the artist put in. There are no pre-release or "coming soon" listings: anything a buyer can see listed is a published work. A different file always means a new listing. The contract treats the hash as opaque bytes and knows nothing about hash algorithms; that is an app-level convention (see "One file per listing, and download verification" below).
11. **A collection is references, not files.** A collection record holds a title, description, price, `website_id`, and `active`; its contents are membership entries pointing at the artist's own listings. A collection license entitles its holder to download every listing the collection *currently* contains. The artist can add works at any time — existing collection holders get them automatically — and can remove works at any time. The contract makes no promise about future contents; that trust sits between artist and collector, and the public event history records exactly what a collection contained at any moment (see "Collections" below).

### Storage schema

```
type tier =
  | Personal
  | Commercial

// What a license, a purchase, or a review is for.
// listing_id and collection_id are separate per-artist number spaces.
type target =
  | Listing    of nat   // listing_id
  | Collection of nat   // collection_id

type website = {
  url : string;   // the ONLY site that can fulfill listings and collections created under this website_id
}

type listing = {
  title                     : bytes;    // UTF-8, on-chain, public — see "Text encoding" below
  item_type                 : bytes;    // UTF-8, e.g. "photograph", "video", "illustration"
  description               : bytes;    // UTF-8, ~300 bytes max, on-chain, public
  personal_display_price    : tez;      // mutez; 0 = not for sale
  commercial_display_price  : tez;      // mutez; 0 = not for sale
  website_id                : nat;      // fixed at creation, immutable thereafter — see "Entrypoints" below; resolve via `websites`
  active                    : bool;     // false = visible but not purchasable on its own (both tiers) — see design principle 5
  file_hash                 : bytes;    // opaque digest of the exact file served; required at creation, never changes — see "Entrypoints"
}

type collection = {
  title                     : bytes;    // UTF-8, on-chain, public
  description               : bytes;    // UTF-8, ~300 bytes max, on-chain, public
  personal_display_price    : tez;      // mutez; 0 = not for sale
  commercial_display_price  : tez;      // mutez; 0 = not for sale
  website_id                : nat;      // fixed at creation; every member listing must share it
  active                    : bool;     // false = visible but closed to purchase (both tiers)
}

type license = {
  personal           : nat;        // count of personal-display licenses bought; independent of commercial — see design principle 6
  commercial         : nat;        // count of commercial-display licenses bought
  purchased_at_level : nat;        // block level at first purchase of either tier; meaningful only once either count is > 0 — gates review timing
}
// Counts are fixed-size fields in one record, not a growing collection: a nat's
// encoding grows only logarithmically (a buyer would need ~2^56 purchases to add
// 8 bytes), so this does NOT reintroduce the per-address growing-index problem
// described in "Views, and why there's no on-chain enumeration".

type review = {
  rating     : option<nat>;    // 1-10 if present
  comment    : option<bytes>;  // UTF-8, ~300 bytes max, on-chain, public
  posted_at  : timestamp;      // set once, on the first review write — never changes after
  updated_at : timestamp;      // set on every write, including the first
}

type storage = {
  names            : big_map<address, bytes>;   // UTF-8 — see "Text encoding" below
  // (artist, website_id) -> a fulfillment site the artist has registered
  websites         : big_map<(address * nat), website>;
  // (artist, listing_id) -> listing
  listings         : big_map<(address * nat), listing>;
  // (artist, collection_id) -> collection
  collections      : big_map<(address * nat), collection>;
  // (artist, collection_id, listing_id) -> unit; the key's existence IS membership
  collection_items : big_map<(address * nat * nat), unit>;
  // (buyer, artist, target) -> independent tier entitlements, for a listing or a collection
  licenses         : big_map<(address * address * target), license>;
  // (buyer, artist, target) -> the buyer's review of that listing or collection, if any
  reviews          : big_map<(address * address * target), review>;
}
```

`target` is an ordinary Michelson `or` type, which is comparable, so it can sit inside a `big_map` key. Using it for `licenses` and `reviews` means a collection needs no second license table, no second review table, and no second `purchase` or `review` entrypoint.

### Text encoding

`names`, `listing.title`, `listing.item_type`, `listing.description`, `collection.title`, `collection.description`, and `review.comment` are typed as `bytes` (raw UTF-8), not Michelson's native `string`, which is restricted to printable ASCII and can't hold non-Latin names, titles, or reviews. `website.url` stays `string`, since URLs are already ASCII-safe by convention. Every reader — the artist's own site, an indexer, a syndicator — is responsible for UTF-8-decoding these fields; a generic block explorer will show them as raw hex by default.

### Entrypoints

Three verbs for the sale itself (`list`, `purchase`, `review`), two for collections (`set_collection`, `set_collection_item`), plus two self-scoped artist helpers (`set_name`, `set_website`):

```
entrypoint set_name(display_name: bytes):   // UTF-8 — see "Text encoding" above
  names[Tezos.get_sender()] := display_name
  // no event needed; purely a display convenience, read by any site or discovery tool on demand

entrypoint set_website(website_id: nat, url: string):
  artist := Tezos.get_sender()
  websites[(artist, website_id)] := { url }

  // FULL SNAPSHOT EMIT, same discipline as %listed below
  EMIT %website_set {
    artist      = artist,
    website_id  = website_id,
    url         = url,
    timestamp   = Tezos.get_now()
  }

entrypoint list(
  listing_id: nat,
  title: bytes,          // UTF-8
  item_type: bytes,      // UTF-8
  description: bytes,    // UTF-8
  personal_display_price: tez,
  commercial_display_price: tez,
  website_id: nat,             // which of the artist's registered websites fulfills this listing
  active: bool,                // false = keep the listing visible but not purchasable on its own
  file_hash: bytes             // required; permanent from creation
):
  artist := Tezos.get_sender()
  require websites[(artist, website_id)] exists   // must be registered via set_website first

  existing := listings[(artist, listing_id)]
  if existing exists:
    require website_id = existing.website_id
    // immutable once set — an attempt to repoint an existing listing at a
    // different website_id REJECTS the whole call, rather than silently
    // keeping the old value or silently accepting the new one.
    require file_hash = existing.file_hash
    // write-once: a listing sells the file it was created with, forever.
    // A different file means creating a new listing (see "One file per listing" below).
  else:
    require size(file_hash) > 0
    // no listing exists without its file: only finished, published works are listed

  record := {
    title, item_type, description,
    personal_display_price, commercial_display_price,
    website_id, active, file_hash
  }
  listings[(artist, listing_id)] := record

  // FULL SNAPSHOT EMIT — always the complete current record,
  // never just the field(s) that changed on this call.
  EMIT %listed {
    artist            = artist,
    artist_name       = names[artist],       // if set, else empty
    listing_id        = listing_id,
    title             = record.title,
    item_type         = record.item_type,
    description       = record.description,
    personal_price    = record.personal_display_price,
    commercial_price  = record.commercial_display_price,
    website_id        = record.website_id,
    website_url       = websites[(artist, website_id)].url,  // resolved inline so indexers don't need a second lookup to render a link
    active            = record.active,
    file_hash         = record.file_hash,
    timestamp         = Tezos.get_now()
  }

entrypoint set_collection(
  collection_id: nat,
  title: bytes,          // UTF-8
  description: bytes,    // UTF-8
  personal_display_price: tez,
  commercial_display_price: tez,
  website_id: nat,
  active: bool
):
  artist := Tezos.get_sender()
  require websites[(artist, website_id)] exists

  existing := collections[(artist, collection_id)]
  if existing exists:
    require website_id = existing.website_id   // same immutability rule as listings

  record := {
    title, description,
    personal_display_price, commercial_display_price,
    website_id, active
  }
  collections[(artist, collection_id)] := record

  EMIT %collection_set {                        // FULL SNAPSHOT, same discipline as %listed
    artist           = artist,
    artist_name      = names[artist],
    collection_id    = collection_id,
    title            = record.title,
    description      = record.description,
    personal_price   = record.personal_display_price,
    commercial_price = record.commercial_display_price,
    website_id       = record.website_id,
    website_url      = websites[(artist, website_id)].url,
    active           = record.active,
    timestamp        = Tezos.get_now()
  }

entrypoint set_collection_item(collection_id: nat, listing_id: nat, included: bool):
  // exactly one membership change per call, no loop; many changes are one
  // wallet batch of these calls (see "Batching" below)
  artist := Tezos.get_sender()
  c := collections[(artist, collection_id)]          // fails if no such collection

  if included:
    l := listings[(artist, listing_id)]               // fails if no such listing: own listings only
    require l.website_id = c.website_id               // the collection's site must hold the file
    require collection_items[(artist, collection_id, listing_id)] does not exist
    collection_items[(artist, collection_id, listing_id)] := ()
  else:
    require collection_items[(artist, collection_id, listing_id)] exists
    remove collection_items[(artist, collection_id, listing_id)]

  // the collection record itself is unchanged, so no %collection_set snapshot
  EMIT %collection_item_set { artist, collection_id, listing_id, included, timestamp = Tezos.get_now() }

entrypoint purchase(artist: address, target: target, tier: tier, quantity: nat):
  require quantity > 0

  (personal_price, commercial_price) :=
    match target:
      Listing listing_id =>
        l := listings[(artist, listing_id)]          // fails if no such listing
        require l.active                             // closed or collection-only listings reject direct purchase
        (l.personal_display_price, l.commercial_display_price)
      Collection collection_id =>
        c := collections[(artist, collection_id)]    // fails if no such collection
        require c.active                             // the admin tool keeps a collection closed whenever it holds no works
        (c.personal_display_price, c.commercial_display_price)

  unit_price := if tier = Personal then personal_price else commercial_price
  require unit_price > 0mutez               // 0 = this tier not for sale
  total_price := unit_price * quantity       // Michelson MUL on mutez fails on overflow rather than wrapping
  require Tezos.get_amount() = total_price

  buyer := Tezos.get_sender()
  current := licenses[(buyer, artist, target)]  // default { personal=0; commercial=0; purchased_at_level=0 }
  // no "already held" check: repeat purchases of either tier are allowed
  // without limit (design principle 6), always at full price, no discount

  licenses[(buyer, artist, target)] := {
    personal           = current.personal   + (if tier = Personal   then quantity else 0),
    commercial         = current.commercial + (if tier = Commercial then quantity else 0),
    purchased_at_level = if current.personal > 0 or current.commercial > 0
                          then current.purchased_at_level   // preserve first-ever purchase block
                          else Tezos.get_level()
  }
  Tezos.transaction(unit, Tezos.get_amount(), artist_contract(artist))  // funds go straight to the artist

  EMIT %purchased {
    buyer      = buyer,
    artist     = artist,
    target     = target,
    tier       = tier,
    quantity   = quantity,
    unit_price = unit_price,
    price_paid = total_price,
    timestamp  = Tezos.get_now()
  }

entrypoint review(artist: address, target: target, rating: option<nat>, comment: option<bytes>):   // comment is UTF-8
  buyer := Tezos.get_sender()
  license := licenses[(buyer, artist, target)]
  require license.personal > 0 or license.commercial > 0    // must actually hold a license for this target, either tier
  require rating != None or comment != None                  // no empty no-op writes
  match rating:
    Some(r) => require r >= 1 and r <= 10
    None    => skip
  require Tezos.get_level() > license.purchased_at_level     // strictly a later BLOCK than the purchase —
                                                               // same-block (or same batched operation group)
                                                               // purchase-then-review is rejected outright

  existing := reviews[(buyer, artist, target)]
  reviews[(buyer, artist, target)] := {
    rating, comment,
    posted_at  = if existing exists then existing.posted_at else Tezos.get_now(),  // immutable after first write
    updated_at = Tezos.get_now()
  }
  // upsert: editing after the first (already block-gated) write updates
  // rating/comment/updated_at freely, with no re-gating — but posted_at
  // never moves, so an edit can never buy a review fresher placement in
  // any feed that ranks by posted_at (see "Reviews" below).

  EMIT %reviewed {
    buyer      = buyer,
    artist     = artist,
    target     = target,
    rating     = rating,
    comment    = comment,
    posted_at  = reviews[(buyer, artist, target)].posted_at,
    updated_at = Tezos.get_now()
  }
```

`quantity` is a convenience, not a requirement: a collector could equally make several single-unit `purchase` calls. It exists so a large purchase is one operation, one payout transfer, and one `%purchased` event rather than N of each. Closing or reopening a sale is done through `list` or `set_collection` with `active` flipped (the admin tool re-sends the unchanged fields), rather than a separate `set_active` entrypoint, so that every change to a listing or collection — including this one — goes through its single full-snapshot event path.

A listing is created with its `file_hash`, and every later `list` call for that listing must send the same hash. Hash length and format are never checked on-chain; the app owns that.

**Collection membership details.**
- `set_collection` never touches membership; only `set_collection_item` does, exactly one entry per call. Adding a listing that's already a member, or removing one that isn't, REJECTS the call, so every `%collection_item_set` event describes a real change.
- A collection must exist (via `set_collection`) before items can be added, and every member listing must share the collection's `website_id`, because the site that sells the collection is the one whose storage holds the files it delivers.
- Membership ignores the listing's own `active` flag: a closed listing can be added to a collection, which is exactly how collection-only works are made (design principle 5).
- The contract does not count members, and does not stop an active collection from being bought while empty. The admin tool creates every collection with `active = false` and opens it (a further `set_collection` with `active = true`) only once it holds at least one work, as the last call of the same batch that adds its works. When a removal would take out a collection's last work, the admin tool puts a `set_collection` with `active = false` before it in the same batch, so an open collection is never left empty. Member counts come from indexers (the `%collection_item_set` stream) or the site's own mirror.
- Each call changes exactly one membership entry, with no loop, and nothing stored grows with the number of changes. Adding or removing many works at once is one `set_collection_item` call per work in a single wallet batch, still one approval and all-or-nothing; its practical size is bounded by Tezos' per-operation-group size and gas limits (see "Batching" below).

**Batching.** Tezos wallets can bundle several contract calls into one signed operation group (Taquito's `wallet.batch()`, supported by Beacon-compatible wallets), which the artist approves once and which succeeds or fails as a whole. The admin tool uses this rather than any batch entrypoint on the contract: creating twelve listings, a collection, and its membership is `list` ×12, then `set_collection` (created closed), then `set_collection_item` ×12, then `set_collection` again to open it — one approval, all-or-nothing, and every `list` still goes through the normal full-snapshot path. Each operation group is size-limited (on the order of 32 KB, plus per-operation gas and storage caps — confirm the live protocol constants before launch), so a few dozen listings fit in one approval and larger drops are split across several. Buyers can batch too, but don't need to: one collection purchase is one `purchase` call.

Naming: `list`, `purchase`, `review`, `set_name`, `set_website`, `set_collection`, and `set_collection_item` are all verbs — a block explorer's transaction history reads as a consistent stream of actions, not a mix of nouns and verbs.

### Event log

Tezos' native `EMIT` instruction is used for `%listed`, `%collection_set`, `%collection_item_set`, `%purchased`, `%website_set`, and `%reviewed` — cheap, structured, and designed for exactly this: indexers (TzKT and others) pick these up natively, giving any third-party chart, feed, or magazine a canonical stream of "new listing," "collection created or changed," "work added to or removed from a collection," "sale happened," "site registered," and "review posted" events across every artist, without needing custom per-site scraping. `%purchased` and `%reviewed` carry a `target`, so consumers can tell a single-work sale from a collection sale.

**Rule:** `%listed`, `%collection_set`, and `%website_set` always carry the complete current record (all fields), on every call — including calls that only change one field (e.g. a price update or a domain migration). Never emit a partial diff. `%collection_item_set` is the complete record for one membership entry (which, having no value, is just "in" or "out"). This guarantees any consumer that only watches the event stream (rather than also querying big_map state) never ends up with a stale or incomplete picture of a listing, collection, or website after an edit — and can rebuild exactly which works a collection contained at any past moment.

### Non-transferability

There is no `transfer`, `approve`, or similar entrypoint anywhere in this contract — not on listings, not on collections, not on licenses. This is the entire mechanism by which licenses are non-tradable: there's no code path that could ever move one between addresses, so there's nothing for a marketplace or aggregator to hook into even if someone wanted to build a secondary market on top of it.

### Reviews

`review` lets a buyer record their own opinion of a listing or collection they've purchased. Like every other entrypoint, it's scoped to the caller: a buyer only ever writes into their own `(buyer, artist, target)` slot in `reviews`, never touching the artist's records.

- **No moderation, no deletion, ever.** Consistent with the rest of this contract (no admin, nothing patchable), there is no entrypoint that removes or hides a review — not for the artist, not for anyone. A comment, once written, is there permanently, immutably, next to the artist's own listing or collection. This is an accepted, disclosed tradeoff, not an oversight.
- **Editable, but edits can't buy visibility.** Calling `review` again overwrites its `rating`/`comment` and bumps `updated_at`, but never touches `posted_at` — set once, on the first write, immutable after. Any syndicator or feed that ranks by `posted_at` gains an editor nothing by re-posting, since their position in a feed never moves no matter how many times they touch the review. `updated_at` still exists and is still emitted, purely as an honest "last touched" signal for a UI to show an "edited" badge — it's just not the field anything should be ranked by.
- **You review what you bought.** Eligibility follows the license target: a single-listing buyer reviews that listing; a collection buyer reviews the collection. Holding a collection license does not open a review slot on each work inside it — a collector who wants to review one work individually can do so only if they also bought that listing on its own.
- **Eligibility is per-target, not per-tier, and one review per buyer regardless of quantity.** `purchased_at_level` is set once, on the first purchase of *either* tier for that target, and never reset by any later purchase — a buyer is reviewing the work, not the license tier. A collector who has bought 20 licenses still gets exactly one `(buyer, artist, target)` review slot; buying more never buys more voice. Feeds that want to show it may display the buyer's count next to the review, read from `licenses`.
- **Closed listings and collections stay reviewable.** `review` doesn't check `active`, so buyers can still review after the artist closes a sale.

### Views, and why there's no on-chain enumeration

Two read-only additions are included; on-chain enumeration is deliberately left out.

**Included — `view`s for point lookups:**

```
view has_license(param: (address * address * target), storage: storage) : license
  (buyer, artist, target) := param
  return storage.licenses[(buyer, artist, target)]
  // default { personal=0; commercial=0; purchased_at_level=0 } for a key never written

view in_collection(param: (address * nat * nat), storage: storage) : bool
  (artist, collection_id, listing_id) := param
  return storage.collection_items[(artist, collection_id, listing_id)] exists
```

Tezos on-chain views are synchronous, read-only functions: other contracts, or off-chain callers via RPC, can call one and get a result immediately, with no transaction and no gas cost for the off-chain case. `has_license` lets any other contract — or any off-chain tool — check whether (and how many times) a specific buyer holds a specific tier of a listing or collection, or compare `purchased_at_level` against the current chain level to check whether the review gate has already opened, without depending on TzKT or any other indexer for that one fact. `in_collection` answers "is this listing in this collection right now?" Together they answer the download question for any (buyer, listing) pair: a listing license, or a collection license plus current membership. Neither adds storage or touches `purchase`; both are pure reads over data that already exists.

One thing integrators must know: a collection purchase writes a license for the collection, never one per contained listing (that would mean looping over a stored, growing set — exactly what this section rules out). So `has_license(buyer, artist, Listing n)` alone does not reveal rights that come from a collection; a third-party contract or tool checking "may this buyer use work n?" must also check the buyer's collection licenses together with `in_collection`.

**Left out — anything that enumerates.** Both ways of adding on-chain iteration fail for the same mechanical reason, not a style preference:

- *A read-only iterator entrypoint* ("give me every listing an address holds," "give me every work in this collection"). A view still runs inside the same Michelson VM as any entrypoint, and `big_map` has no `ITER` instruction in that VM — read-only or not. Making the read free of gas doesn't unlock enumeration; the restriction is in the instruction set itself.
- *A growing value under one key* (e.g. a `big_map<address, list<...>>` tracking everything a buyer has bought, everyone who bought a given listing, or a `set<nat>` of member listings stored inside the collection record). `big_map`'s laziness only applies at the level of *which key* is touched — the *value* under a key is an ordinary value, fully deserialized and reserialized on every read or write of that key. So this kind of index makes a buyer's own storage cost grow with how much they've already bought, a listing's popularity index grow with how many buyers it's had, and a collection's every update grow with how many works it holds. Tezos enforces hard gas and storage limits per operation, so this isn't just "slower over time" — past some size, that specific account, listing, or collection stops fitting under the limit and becomes permanently unable to transact through this contract again. Since the contract can't be patched, there's no fixing it after the fact.

Worth sitting with why this matters more here than in most systems: the failure lands precisely on success. A prolific collector, a viral listing, or a collection that keeps growing for years — the exact outcomes this whole design is trying to enable — are exactly what would hit the ceiling first. That is why `collection_items` stores one fixed-size entry per (collection, listing) pair: adding the 500th work costs the same as adding the first.

Full enumeration — "everything this address owns," "everyone who bought this listing," "every work in this collection" — is left entirely to off-chain indexers (TzKT and similar), which already handle it well via sub-field filtering on the `licenses` and `collection_items` big_maps or the event stream (see "Event log" above). This isn't a workaround; it's the standard division of labor across essentially the entire Tezos ecosystem — nothing enumerates on-chain, everything queries an indexer, for exactly this reason.

The same reasoning governs `websites`, `collections`, and `reviews`: all are self-scoped, point-keyed `big_map`s with exactly the same shape as `listings` and `licenses`, so they inherit this section's guarantees without needing separate treatment — an artist's own website and collection counts and a buyer's own reviews are bounded by their own gas and storage, never anyone else's.

### Reentrancy and execution order

Sending tez to an address can trigger code, the same basic shape as Ethereum's `receive`/`fallback` mechanism — but only if that address is an originated contract (`KT1`). Sending to a plain implicit wallet (`tz1`/`tz2`/`tz3`), which is what an `artist` address is expected to be, never runs any code at all.

Nothing in this contract currently restricts `artist` to implicit accounts, though — it's just an address. So it's worth stating plainly why `purchase` is already safe even if an artist's address is itself a contract (one that auto-splits revenue, for instance):

- Tezos doesn't execute internal operations synchronously the way the EVM does. When an entrypoint finishes, the operations it emits are queued and only run *after* that entrypoint's own storage writes are fully committed — not mid-execution, the way a Solidity external call can trigger an immediate callback into stale state. This is checks-effects-interactions enforced at the protocol level, which is exactly why the classic DAO-style drain-on-callback attack doesn't have a foothold here.
- `purchase` already follows that ordering deliberately, not incidentally: `licenses[(buyer, artist, target)]` is written *before* the tez transfer to `artist` is queued. So even if `artist` is a contract that tries to call back into `purchase` (or anything else) upon receiving funds, it does so against a storage state where the license has already been recorded — there's no stale balance to exploit twice.
- Every entrypoint is self-scoped to its own caller (design principle 1), so even a malicious artist-side contract gains no extra privilege by reentering — it can already do everything to its own listings and collections that it could ever do, reentrant or not.
- The one pattern that remains genuinely worth testing for isn't same-call reentrancy — it's multi-step, callback-based designs, where a contract calls out and waits for a *separate* entrypoint to be invoked later with a result, leaving state in an intermediate condition in between. Nothing in this contract currently has that shape (every entrypoint is a single-step, self-contained call), which is worth keeping true deliberately rather than by accident as the design evolves.

## Off-chain architecture (Cloudflare)

*Pages and Workers are not two separate things here — together they are one artist's website. Every deployment of this template belongs to exactly one artist and does two jobs: display that artist's own listings and collections, and be the only place able to fulfill them. There is no independent "storefront" layer.*

### Components

- **Cloudflare Pages** — hosts the artist's static site (public listing and collection pages), free tier.
- **Cloudflare Workers** — edge compute for wallet sign-in verification, license checks against the chain (via TzKT's public API), session issuance, and gated file delivery (free tier: 100k requests/day, 10ms CPU time per request — CPU time excludes time spent waiting on I/O like R2 fetches, per Cloudflare's own documentation, so streaming large files doesn't burn the CPU budget).
- **Cloudflare R2** — private object storage for the actual art files. Free tier: 10GB storage, no egress fees ever (this is the key cost advantage over S3 for a download-heavy site).
- **Cloudflare KV / D1** — session cache, redownload counters, per-buyer "already downloaded" markers, the site's file catalog (`listing_id` → R2 object key, file name, content type, size), and a local mirror of which of this site's collections contain each listing (a lookup aid only — the chain is checked before any download).

### Route convention

Every deployment of this template MUST serve the same eight routes, relative to its own `website.url` — fixed by the shared template's own routing, not stored on-chain:

- `/listings.json` — public, unauthenticated, machine-readable index of every listing and collection this site fulfills. See "Public metadata JSON" below.
- `/listing/{listing_id}` — the public, unauthenticated display page: title, description, previews, price(s), buy button, the collections it belongs to, and (once posted) reviews. When the listing's `active` is `false`, the page shows its prices without a buy button and says either "available in [collection]" (if an active collection contains it) or "no longer available."
- `/listing/{listing_id}/listing.json` — public, unauthenticated, machine-readable extended metadata for that one listing: preview URLs and everything else that's public but not worth paying to put on-chain. See "Public metadata JSON" below.
- `/collection/{collection_id}` — the public, unauthenticated collection page: title, description, collection price(s) and buy button (or a closed state when `active` is `false`), the works it currently contains in display order with each work's own price shown as the anchor, the work count, and (once posted) collection reviews.
- `/collection/{collection_id}/collection.json` — public, unauthenticated, machine-readable extended metadata for that collection. See "Public metadata JSON" below.
- `/download/{listing_id}` — the authenticated, **private** download page for one work: the file's name and size, its hash with a link to verify it on-chain, the verification command for the buyer's OS, and the download button.
- `/download/{listing_id}/file` — the authenticated, gated stream of the file itself, described below.
- `/download/collection/{collection_id}` — the authenticated, **private** collection download page: every work the collection currently contains, each marked as new or already downloaded by this buyer, with a link to that work's `/download/{listing_id}` page and a "download all new" action. See "Collections" below.

The `/download/{listing_id}/file` route is the only one that streams a file; the other `/download/` pages only show what a buyer is entitled to and link to it, and nothing in the JSON routes reveals any file.

This is deliberately not a new on-chain field. A `listing_id` or `collection_id` is already unique per artist (the address half of the key does the rest), and `%listed` and `%collection_set` already resolve `website_url` inline (see "Entrypoints" above) — so any syndicator, chart, or magazine can construct a working deep link to a specific listing's or collection's display page from nothing but the event stream, with zero additional on-chain storage and zero extra reads. Keeping the convention fixed at the template level, rather than letting each deployment (or each listing) choose its own scheme, is what makes that guarantee hold across every independent site running this template — the same reasoning that already governs the hardcoded `/download/` route below.

A vanity/SEO-friendly slug (e.g. `/listing/harbor-at-dusk` instead of `/listing/42`, or `/collection/night-harbors` instead of `/collection/3`) is a legitimate want, but belongs entirely off-chain and app-level: the artist's own site can maintain a slug-to-id redirect table in KV/D1 and change it freely over time, the same way the redownload policy is deliberately kept off-chain because it's exactly the kind of thing likely to change (see "Redownload policy" below). Nothing about it needs to touch the immutable contract.

### Public metadata JSON

The on-chain listing and collection records deliberately hold only what must be verifiable and canonical: titles, a listing's type, short descriptions, prices, `active`, `website_id`, a listing's `file_hash`, and a collection's membership. Everything else a discovery tool needs to render them well — preview images, video teasers, longer descriptions, tags, display order, a human summary of the file — would be expensive to store on-chain and would bloat every event, so it lives on the artist's own site as JSON at fixed, template-level paths.

- **`/listing/{listing_id}/listing.json`** (required on every listing page): the extended public metadata for one listing. Suggested shape:

```json
{
  "schema": "art-sale/listing@1",
  "artist": "tz1...",
  "listing_id": 42,
  "previews": [
    { "url": "https://artist.example/previews/42/cover.webp", "kind": "image", "width": 1600, "height": 1200, "alt": "..." },
    { "url": "https://artist.example/previews/42/teaser.mp4", "kind": "video" }
  ],
  "long_description": "...",
  "tags": ["photography", "night"],
  "file_summary": "Full-resolution TIFF, 8000 × 6000",
  "license_terms": "https://artist.example/terms",
  "replaces": 7,
  "links": [{ "label": "Process notes", "url": "https://..." }],
  "updated_at": "2026-10-08T00:00:00Z"
}
```

- **`/collection/{collection_id}/collection.json`** (required on every collection page): the extended public metadata for one collection. Suggested shape:

```json
{
  "schema": "art-sale/collection@1",
  "artist": "tz1...",
  "collection_id": 3,
  "previews": [
    { "url": "https://artist.example/previews/c3/cover.webp", "kind": "image", "width": 1600, "height": 1200, "alt": "..." }
  ],
  "long_description": "...",
  "tags": ["photography", "night"],
  "order": [42, 17, 18, 19],
  "license_terms": "https://artist.example/terms/collections",
  "updated_at": "2026-10-08T00:00:00Z"
}
```

- **`/listings.json`** (required at the site root): an index of every listing and collection this deployment fulfills — at minimum `artist`, the `listing_id` or `collection_id`, and the `listing.json` / `collection.json` URL for each, plus optionally a cover preview URL, so a chart or magazine can render a grid of an artist's work with one fetch instead of one per item.

Rules that keep this from undermining the on-chain design:

- **The chain wins.** Titles, prices, `active`, `website_id`, `file_hash`, and collection membership are authoritative on-chain only. The JSON should not repeat them; if a site does include them as a convenience, consumers must treat the chain (or the event stream) as truth on any disagreement. In particular, a collection's `order` is display order only: it may omit members or list stale ones, and consumers must take membership from the chain. `listings.json` is a discovery aid, not a source of record — an aggregator can still find every listing and collection without it, from the event stream.
- **Public means public.** All of these files are served without authentication and with `Access-Control-Allow-Origin: *`, so any third-party site can fetch them from the browser. Preview URLs point at deliberately public, reduced assets (watermarked, downsized, excerpted) — never at the private R2 objects that hold listing files.
- **Not the file.** `file_summary` describes the file in human terms; the file itself stays private behind `/download/`.
- **Replacement links, display only.** The optional `replaces` (on a new listing) and `replaced_by` (on the old one) fields say that a corrected file supersedes an earlier listing, so a page can point buyers to the newer version and charts can group sales of the same work. They grant nothing: download access comes only from on-chain licenses (see "Collections" below).
- **License terms per listing and per collection.** `license_terms` says what each tier permits. A collection's terms apply to each work it contains — a commercial collection license is a commercial license for each of those works.
- **Not hash-anchored.** Unlike the listing's file, this metadata is freely editable and nothing on-chain commits to it — appropriate for previews and copy, which artists will tweak constantly.
- **Versioned schema.** The `schema` field lets the template evolve the format without breaking existing aggregators; aggregators should ignore unknown fields.

### Wallet sign-in and gated delivery flow

1. Buyer connects wallet (Taquito + octez.connect/Beacon) and signs a nonce-and-domain-bound challenge message (domain-binding prevents replaying a signature captured on one deployment against a different one, since this template will be run by many independent instances).
2. Worker verifies the signature and issues a short-lived, HttpOnly/Secure/SameSite signed cookie identifying that buyer address on this site. The cookie proves who the buyer is; it does not by itself grant any file.
3. On every `/download/` request, the Worker checks the chain (via TzKT or the contract's views over RPC, with awareness that an indexer is a trust dependency) for an entitlement to that listing, in this order:
   - a `licenses` entry at (buyer, artist, `Listing listing_id`) with the requested tier's count greater than zero; or
   - a `licenses` entry at (buyer, artist, `Collection c`) with the requested tier's count greater than zero, for some collection `c` that currently contains the listing (`in_collection(artist, c, listing_id)`). The site's local mirror says which of its collections to check; the chain confirms membership, so a stale mirror can never grant access.

   Delivery is the same whether a buyer holds 1 or 50 of a tier; the count matters for the artist's sales and for discovery, not for access. Since tiers are independent on-chain, a site MAY choose to treat `commercial > 0` as also satisfying a `personal`-tier request — a real-world licensing convenience applied entirely at the Worker layer, with no such relationship encoded in the contract itself. A site may cache a positive result briefly in KV.
4. The buyer lands on the download page — for one work, or for a collection, listing every work in it — which shows each file's hash, a link to the same hash on a block explorer, and the command to check it.
5. On the file request, the Worker re-checks entitlement, looks up the listing's R2 key in the site's catalog, records the download in KV (so the collection page can mark it as already downloaded), and streams the file from R2 via a bucket binding, byte-for-byte unchanged — returning the object's stream directly in the response so the transfer itself doesn't scale the Worker's CPU usage.

```javascript
// Cloudflare Worker — gated download handler (sketch)
export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // /download/{listing_id}/file — the listing's one file
    // (the /download/{listing_id} page is handled separately, with the same checks)
    const m = url.pathname.match(/^\/download\/(\d+)\/file$/);
    if (m) {
      const session = await verifySignedCookie(request, env);
      if (!session) return new Response('Not authorized', { status: 401 });

      const [, listingId] = m;
      const entitled = await isEntitled(
        session.buyerAddress, env.ARTIST_ADDRESS, listingId, requestedTier(request), env
        // 1. has_license(buyer, artist, Listing listingId): requested tier's count > 0
        // 2. otherwise, for each collection the site's mirror says contains this listing:
        //    has_license(buyer, artist, Collection c) with the tier's count > 0
        //    AND in_collection(artist, c, listingId) confirmed on-chain
        // a site may optionally treat commercial as also satisfying a personal-tier request
      );
      if (!entitled) return new Response('No matching license found', { status: 403 });

      const file = await env.CATALOG.get(`file:${listingId}`, 'json');
      if (!file) return new Response('No file for this listing', { status: 404 });
      const object = await env.ART_BUCKET.get(file.r2_key);
      if (!object) return new Response('File missing', { status: 404 });

      // mark as downloaded, so /download/collection/{id} can show what's new
      await env.CATALOG.put(`dl:${session.buyerAddress}:${listingId}`, '1');

      return new Response(object.body, {
        headers: {
          // serve the exact bytes the artist hashed: no resizing, re-encoding,
          // or on-the-fly zipping, and no-transform so nothing in between re-compresses it
          'content-type': file.content_type,
          'cache-control': 'private, no-transform',
          'content-length': String(object.size),
          // non-ASCII file.name (e.g. a Japanese filename) needs RFC 5987
          // filename*=UTF-8''... encoding here, not a raw quoted string —
          // a separate, off-chain instance of the same i18n concern as the
          // on-chain text fields, see "Text encoding" above
          'content-disposition': `attachment; filename="${file.name}"`,
        },
      });
    }

    // ... sign-in route, admin upload route, the site's own static routes ...
  },
};
```

### Admin authentication

The buyer sign-in flow above is deliberately not how the artist authenticates to their own admin page — the admin page needs to trust exactly one address, not look up a license for it. It reuses the same wallet-signature primitive, checked differently:

1. Artist connects wallet and signs a nonce-and-domain-bound challenge, identical in shape to the buyer flow.
2. The Worker checks `signer_address = env.ARTIST_ADDRESS` — the single address baked in at deploy time (see "Deploy-to-Cloudflare flow" below) — rather than querying `licenses` at all. No chain lookup is needed for this check; the comparison is entirely local to the Worker's own config.
3. On a match, the Worker issues an admin session cookie scoped to the upload, listing-edit, collection-edit, website-registration, and display-name routes — the only routes that can prepare `list`, `set_collection`, `set_collection_item`, `set_website`, and `set_name` calls, or write to R2/the catalog. The admin session never holds the wallet key: every on-chain call is signed in the artist's own wallet at the moment it's made.

This is the highest-value target in the whole system per artist deployment: compromising this one session grants everything an admin panel can do off-chain for that artist (uploading or swapping files in R2, editing the catalog) — but not writing anything on-chain, since that needs the wallet. A swapped file therefore won't match the hash the artist signed, which is exactly what buyer-side verification catches; see "One file per listing, and download verification" below. For an operator running several pseudonyms behind one login, this is exactly the "blast radius" concern flagged in the Identity model section below — worth repeating here as the concrete mechanism that concern is actually about.

### Deploy-to-Cloudflare flow for new artists

Using Cloudflare's real "Deploy to Cloudflare" button feature (auto-provisions R2 buckets, KV namespaces, and secrets from the repo's Wrangler config):

1. Artist clicks the button.
2. Fills in: their Tezos payout address, optionally a site name/theme variable. R2 bucket, KV namespace, and a signing secret are auto-generated.
3. Deploy completes — live artist website pointed at the one shared, pre-deployed contract (no contract origination, no gas cost, no Tezos dev knowledge required from the artist).
4. Remaining manual steps, all handled by a small in-Worker admin page (itself gated by the admin authentication flow above) rather than the raw Cloudflare dashboard: a one-time `set_website` call registering this deployment's own domain (the admin tool auto-fills the URL and picks the next unused `website_id`, so the artist never has to type either), then uploading each file and creating its listing (a `list` call referencing that `website_id` and carrying the file's hash), and optionally creating collections from those listings (`set_collection` created closed, one `set_collection_item` per work, then `set_collection` to open it), all signed in the artist's wallet. The admin tool always uploads a file to R2 and confirms the upload before asking the wallet to sign the `list` call for it, so no listing ever goes on-chain without its file in place. When several listings and a collection are created at once, the admin tool batches them into one operation group the artist signs once (see "Batching" above).

An artist who later rebuilds their site at a new domain re-calls `set_website` with the same `website_id` and a new `url` — every listing and collection that already references that `website_id` picks up the change automatically, with no need to touch them individually. A brand-new, independently-hosted site instead gets a new `website_id`, and only future listings and collections can reference it — existing ones stay bound to whichever site they were created under, by design (see "Entrypoints" above).

### One file per listing, and download verification

**What a listing sells.** Exactly one file. For most listings that's a single image — the unit collectors already think in, and the easiest thing to explain on a listing page: what you see previewed is the work you're buying. An artist may list a zip as the file if they want to; the contract doesn't distinguish images from zips or any other format — a file is a file — and it never records what a zip contains. Selling a group of works is what collections are for (see "Collections" below).

**Only published works are listed.** `list` requires the file's hash when a listing is created, and the admin tool uploads the file before the listing goes on-chain. There is no "coming soon" or pre-release state: a buyer never has to work out whether they're paying for something that doesn't exist yet. An artist who wants to build anticipation does that on their own site, off-chain, before listing.

**Fixed forever.** A listing's `file_hash` is set at creation and never changes. That gives three guarantees:
- What a buyer downloads is exactly what the listing has always offered; the hash shown on-chain today is the hash that will always be shown.
- If the artist's wallet key is ever stolen, the thief cannot point existing listings at a malicious file. Every listing that has already sold stays safe; only new listings could be affected, and those are visible.
- A `listing_id` always refers to the same work, so its reviews and sales counts always describe the same file.

**When a file needs to change.** To fix a bad export or re-cut a work, the artist closes the old listing (`active = false`) and creates a new one. The old listing stays visible with its sales and reviews, and `listing.json` on each side declares the link (`replaced_by` on the old, `replaces` on the new). If the old listing is in a collection, the artist swaps it for the new one with two batched `set_collection_item` calls (add the new, remove the old), and every collection holder can download the corrected file. Buyers of the old listing on its own keep the file they bought, which still matches its on-chain hash; the replacement is a separate listing with its own price.

**Keep the file.** Because the hash is permanent, the exact file must be kept for the life of the listing — it can't be re-compressed, converted, or swapped for a smaller version. The R2 object is the served copy; the artist should also keep their own backup of every file they list. If the served copy is ever lost, the remedy is restoring it from that backup.

**Who can download.** Anyone holding a license of either tier for the listing, bought at any time — or a license for a collection that currently contains it.

**Trust model.** The artist is trusted with their own content: if an artist deliberately ships something harmful in their own file, nothing in this framework can prevent it, and it doesn't try. What the hash protects against is a *third party* swapping the file — through a compromised R2 bucket, Cloudflare account, admin session, or domain. Any of those can change what a site serves, but none can change the hash on-chain, because only the artist's wallet can call `list` and the hash never changes after creation. The site never holds the wallet key.

**How a buyer verifies.** On their own machine, with a standard command:

| OS | Command |
|---|---|
| macOS | `shasum -a 256 <file>` |
| Linux | `sha256sum <file>` |
| Windows (PowerShell) | `Get-FileHash <file>` |

…and compare the output to the listing's `file_hash` on-chain. The download page shows the expected hash and the right command for the buyer's OS, for convenience, and also links to the listing on a block explorer / TzKT, since that copy comes from the chain rather than from the site. Because the hash is stored as raw `bytes`, explorers display it as hex — exactly the form these commands print — and because it never changes, there is only ever one value to compare against.

**Hash algorithm: an app convention, not a contract rule.** The template computes SHA-256. Nothing on-chain records the algorithm, and the contract doesn't check the hash's length or format. This keeps the immutable contract minimal and avoids a permanent, unvalidated label field. It's safe because a wrong algorithm guess can only make a genuine file fail to match, never make a tampered file pass: a forger would need a file whose hash equals the bytes the artist signed, which is infeasible under any standard algorithm. Hash length identifies the family; if the template ever adopts a different default, verifier tooling tries every supported algorithm of a given length.

**Serving the exact bytes.** The hash is of the file itself, so the bytes served must be the bytes hashed:
- The admin tool computes SHA-256 in the browser from the file the artist selected, before the wallet prompt, and passes the same checksum to R2 on upload so a corrupted upload is rejected.
- The Worker streams the R2 object unchanged (its original content type, `no-transform`) and never resizes, re-encodes, or zips on the fly — including on the collection download page, where each work is downloaded as its own file so each one can still be checked against its own hash.

**Privacy.** The hash is public on-chain and reveals nothing about the file's contents. The file itself stays private to license holders.

**What a buyer is getting.** A license and a download — not an edition or a token. There is no supply cap; scarcity, when an artist wants it, comes from closing a listing or collection with `active`. The template's listing and collection pages say this plainly so collectors used to editioned NFTs know what they're buying.

### Collections

**What a collection sells.** A license to every work the collection contains — now and as it grows — at the collection's own on-chain price, in the same two independent tiers as a listing. The intended path is a familiar one: a prospect finds the artist's site, buys one work they like, and becomes a customer; a returning customer then sees the value in a collection priced at, say, 3–4× a single work for 12–15 works. Each work's own price, shown on the collection page next to it, is the public anchor that makes the collection price read as good value. Those numbers are template guidance, not contract rules: the contract enforces whatever prices the artist sets and never computes a discount, so a buyer who already owns some of the works still pays the collection's full price.

**Collection-only works.** An artist can make a work available only through a collection by keeping its listing closed (`active = false`) while it sits in an active collection. The listing keeps its prices, so its page and the collection page still show what the work would cost on its own; its page reads "available in [collection]" and links there.

**A growing collection.** The artist can add works at any time with `set_collection_item`. Every existing collection holder can download a new work from the moment it's added, with no new purchase and no new transaction on their side. The collection download page (`/download/collection/{collection_id}`) lists every current work, marks the ones this buyer has already downloaded (from the KV markers the Worker writes on each download), and offers "download all new" — which downloads each new work as its own file, so each one can still be verified against its own hash.

**Membership and trust.** The artist can also remove works at any time; the contract doesn't promise anything about a collection's future contents and doesn't try to. Download access follows *current* membership: once a work is removed, collection holders can no longer download it through that collection, though files they already downloaded are theirs, and anyone who also bought the work on its own keeps access through that license. What the system does guarantee is a permanent public record: every `%collection_item_set` and `%purchased` event is on-chain, so anyone can reconstruct exactly what a collection contained when a given buyer bought it. The template's collection page says plainly that contents can change, the same way listing pages say a license is not an edition.

**Reviews.** A collection buyer reviews the collection, not each work inside it (see "Reviews" above).

### Redownload policy

Deliberately kept entirely off-chain and app-level, not contract-level, since it's exactly the kind of policy likely to change over time:
- Template default: unlimited redownloads of anything already licensed, with one additional session-refresh allowed per day beyond the first (tracked via a KV counter keyed by buyer + listing + day).
- Left open for extension (e.g. an email-request-backed override) without ever touching the immutable contract.

## Artist setup checklist

Everything above touches configuration in passing; this consolidates it into one reference — what an artist actually sets, in the order they'd typically do it, to bring a deployment of this template online.

1. **Deploy.** Click "Deploy to Cloudflare," supply a Tezos payout address and, optionally, a site name/theme (see "Deploy-to-Cloudflare flow" above). R2 bucket, KV namespace, and signing secret auto-provision — nothing to configure there.
2. **Authenticate to the admin panel** with that same wallet (see "Admin authentication" above).
3. **Register at least one website** via `set_website`, required before any listing or collection can be created.
4. **Optionally set a display name** via `set_name` — skippable, but the `artist_name` in `%listed` and `%collection_set` reads empty until it's set.
5. **Per listing, repeated for every artwork**: upload the file (the admin tool computes its hash and confirms the upload), fill in title/item_type/description/prices, and confirm — a `list` call carrying the hash, with `active = true` (or `false` for a work that should be available only through a collection). Upload public previews and fill in the extended metadata the site serves as `listing.json` (and adds to `listings.json`). Keep your own backup of the file.
6. **Per collection (optional)**: fill in title/description/prices and confirm (`set_collection`; the admin tool creates it closed and opens it once it has works), then choose its works (one `set_collection_item` per work, batched, with the opening `set_collection` as the batch's last call); set display order, previews, and terms for `collection.json`. Creating listings and a collection together is one batched approval. To grow the collection later, add works with more `set_collection_item` calls — existing collection holders get them automatically.
7. **Fixing a file** means a new listing: create it, close the old one, set `replaces` / `replaced_by`, and swap the new listing in for the old one in any collection that contains it.
8. **When a sale is done**, flip the listing or collection to inactive from the admin panel (a `list` or `set_collection` call with `active = false`). Its page, its JSON, its reviews, and every buyer's downloads keep working.

| Item | Set via | Required? | Mutable later? |
|---|---|---|---|
| Tezos payout address | Deploy-to-Cloudflare form | Required | No — this *is* the artist's on-chain identity everywhere in this document (`Tezos.get_sender()` on every write, `env.ARTIST_ADDRESS` for admin auth, the `purchase` payout target); there's no "change it" path, only a fresh deployment under a different address |
| Site name / theme | Deploy-to-Cloudflare form | Optional | Yes, freely — cosmetic only |
| Display name (`set_name`) | On-chain entrypoint, via admin panel | Optional | Yes, freely — single-value upsert |
| At least one website (`set_website`) | On-chain entrypoint, via admin panel | Required before any `list` or `set_collection` call | The `url` is freely editable and propagates to every listing and collection referencing it; the `website_id` itself, once referenced, can never be un-registered or reassigned |
| Redownload policy | App-level config (KV), template ships a default | Optional override | Yes, freely — deliberately off-chain for exactly this reason (see "Redownload policy" above) |
| Per listing: title, item_type, description, prices, `active` | On-chain `list` call, via admin panel | Required, once per artwork | Yes, freely, by re-calling `list` |
| Per listing: `website_id` | On-chain `list` call, at creation | Required | No — fixed permanently at creation |
| Per listing: the file and its `file_hash` | R2 upload, then on-chain `list` call, via admin panel | Required at creation | No — fixed at creation; a different file is a new listing |
| Per listing: previews and extended public metadata (`listing.json`, indexed in `listings.json`) | Admin panel, stored by the site (KV/D1 + public R2 or Pages assets) | Required (the routes must exist; content can be minimal) | Yes, freely — off-chain and not hash-anchored |
| Per collection: title, description, prices, `active` | On-chain `set_collection` call, via admin panel | Optional (collections are optional) | Yes, freely, by re-calling `set_collection` |
| Per collection: `website_id` | On-chain `set_collection` call, at creation | Required | No — fixed permanently at creation; every member listing must share it |
| Per collection: member works | On-chain `set_collection_item` calls, via admin panel | Required before the admin tool opens it for sale (not contract-enforced) | Yes — add or remove any time; access follows current membership |
| Per collection: display order, previews, terms (`collection.json`) | Admin panel, stored by the site | Required (the routes must exist; content can be minimal) | Yes, freely — off-chain |

Two things from this table worth carrying forward, both covered in more depth elsewhere in this document: the payout address isn't really "configuration" so much as the root identity everything else hangs off of, and `website_id` and `file_hash` are the fields that behave like the payout address rather than like the rest of a listing or collection — set once, never revisited.

## Identity model

- **Artist = wallet address, full stop.** No separate on-chain "artist" object beyond `names[address]`. This is what makes multiple noms de plume free: one person can hold as many independent artist identities as they want, each fully sovereign and mutually unlinked on-chain.
- **Multi-pseudonym operator tooling, two things to be deliberate about:**
  1. **Blast radius**: if one admin session/login can switch between managing several pseudonyms, compromising that one session compromises all of them at once. Worth treating as a materially higher-value target than a single-artist session.
  2. **Unlinkability as a feature**: no session token, log line, or analytics event should ever record "this operator controls addresses X, Y, Z" in one place — that record itself would become the single point of failure for what's supposed to be independent pseudonyms.
- **Display name**: a self-scoped `set_name` entrypoint in the same contract, rather than requiring Tezos Domains (a real, currently-active naming service, but one that involves a recurring rental cost and tradable NFT domains — more friction and more speculation-adjacent than fits this project's ethos). Sites may optionally prefer a Tezos Domains reverse record if an artist already has one, but nothing requires it.
- **Name and websites are deliberately decoupled, and websites are deliberately plural.** `set_name` (persona name) is a single mutable UTF-8 field; `set_website` (fulfillment sites) is a growing, self-scoped list of `(website_id, url)` slots, matching the fact that an artist may run one site or several — a real pattern, since some artists build a dedicated site per release or collection. Neither construct depends on the other, and a listing's or collection's binding to a specific `website_id` is fixed at creation (see "Entrypoints" above), independent of whatever the artist's current display name is.

## Fulfillment and discovery model

- **Only the artist's own declared website can fulfill a listing or collection.** A listing's or collection's `website_id` resolves to a `websites` entry the artist registered themselves via `set_website` — an on-chain claim about where delivery happens, secured by their signature, not independently verified. Nothing stops a third party from building a page that calls `purchase` directly (there's no gatekeeping on who can call it), but doing so gains them nothing: the files live behind that specific deployment's private R2 bucket and session logic, which only the real artist's real site has access to. There's no incentive for a competing checkout to exist, because it could take someone's money but could never hand over the art.
- **A buyer's license isn't tied to wherever they clicked "buy."** `purchase` writes the same on-chain record no matter which page initiated the call, so a buyer who reaches the flow through a sketchy third-party link is still fine — their (buyer, artist, target) entitlement is real and redeemable at the artist's actual registered site, found via that listing's or collection's `website_id` and its registered URL. The worst a copycat page can do is cause confusion about where to go next, not loss of funds or of purchased rights.
- **Editorial and discovery parties never sell anything.** Magazines, charts, and aggregators consume the public `%listed`/`%collection_set`/`%purchased` event stream and link back to an artist's own site — full stop — using the fixed `/listing/{listing_id}` and `/collection/{collection_id}` route convention (see "Route convention" above) to construct a working deep link from nothing but the event data itself. No registry, no partnership, no permission needed to build on that stream. Per the ethos, they take no cut; the contract can't enforce that, but it also gives them nothing to intermediate, since they were never capable of fulfilling a sale in the first place.
- **Website registration is a separate, required step before listing.** A website is a distinct, standing commitment — that a fulfillment backend exists and is running — and gets its own first-class, artist-owned representation via `set_website`, rather than being a field on each listing. `(address, website_id) -> url` is a growing, self-scoped list, the same shape as `listings`, so it correctly supports artists who run several independent sites. Updating a registered site's `url` propagates automatically to every listing and collection that references it, with no need to re-send each one. A `website_id` must be registered via `set_website` before any `list` or `set_collection` call can reference it, and that binding is permanent once created — a listing or collection can never move to a different site; only new ones can pick up a new `website_id`. Because a collection's works must share its `website_id`, a collection never promises a file its own site can't serve.
- **Feeds group by artist and by collection.** One listing per work means a prolific artist produces many `%listed` events; reference feed tooling groups an artist's new listings together, and shows works added to a collection (`%collection_item_set`) under that collection, rather than showing each as a separate item.
- **Collections are on-chain and sellable.** A collection is a first-class record with its own prices and its own license (see "Collections" above), so charts can rank collection sales alongside single-work sales from the same `%purchased` stream, distinguished by `target`. Purely cosmetic groupings — tags, themes — still belong in `listing.json` `tags`, off-chain.
- **No referral cuts.** Nothing pays a third party for driving a sale, by design — consistent with the "no cut for editorial/distribution parties" ethos stated at the top of this document.

## Threat model summary

Illicit-benefit categories identified, and how each is closed:

| Category | Example attack | Mitigation |
|---|---|---|
| Free/underpriced acquisition | Calling `purchase` with an arbitrary amount | Price is read from the on-chain listing or collection record and checked atomically in the same call |
| Free/underpriced acquisition | Replaying a sign-in signature across deployments | Sign-in challenge is nonce- and domain-bound |
| Free/underpriced acquisition | Buying many units for less than the full price | `price_paid` must equal unit price × `quantity` exactly; mutez multiplication fails on overflow instead of wrapping to a small number |
| Free/underpriced acquisition | Buying a listing or collection the artist has closed, including a collection-only work bought on its own | `purchase` rejects when the target's `active` is `false`, independently of either tier's price |
| Free/underpriced acquisition | Getting a work through a collection license after it was removed from that collection | The Worker checks current membership on-chain (`in_collection`) on every download; its local mirror only says where to look and can never grant access |
| Free/underpriced acquisition | Adding another artist's listing to your own collection, to sell their work | Membership keys and the listing lookup are both under the caller's address, so only the caller's own listings can be added |
| Failed delivery | A collection that promises works its site can't serve | `set_collection_item` requires each listing's `website_id` to match the collection's; the admin tool keeps a collection closed (`active = false`) whenever it holds no works: it opens a collection only in the same batch that gives it works, and closes it in the same batch that removes its last work (template-enforced, not contract-enforced) |
| Failed delivery | Paying for a listing whose file doesn't exist yet | `list` requires the file hash at creation, and the admin tool uploads the file before signing; there are no pre-release listings |
| Revenue diversion | Compromised admin panel changes payout address | Every write is self-scoped by wallet signature; no admin entrypoint exists at all |
| Revenue diversion | A privileged contract owner reroutes funds across every deployment at once | No admin key, no pause, no upgrade path in the shared contract — enforced by simply never writing those entrypoints |
| Revenue diversion | Poisoned template default (supply-chain) changes the shared contract address | Treat any PR touching the contract address as highest-scrutiny review |
| Theft of already-paid value | Session/cookie hijacking | HttpOnly/Secure/SameSite cookies, short expiry, per-instance auto-generated secrets |
| Availability | Flooding the sign-in endpoint | Rate-limit auth attempts per IP/address |
| Market/visibility manipulation | An artist (or a friend) repeatedly buying their own listing to inflate sales counts in charts | Not preventable — the artist pays themselves, losing only fees, and unlimited quantity makes it cheap to do at scale. Recommended off-chain charting convention: rank by distinct buyers and by total volume separately, and flag buyer == artist purchases. (Accepted, disclosed.) |
| Market/visibility manipulation | Repeatedly re-editing a review to bump its recency/visibility in feeds | `posted_at` is set once and never changes on edit; recommended off-chain ranking convention sorts by `posted_at`, so edits gain no visibility boost |
| Tampered delivery | A third party (compromised R2, Cloudflare account, admin session, or domain) serves a modified file | Each listing's file hash is written on-chain by the artist's wallet, which the site never holds; the buyer compares hashes on their own machine. Detection, not prevention |
| Tampered delivery | A stolen artist wallet key is used to point already-sold listings at a malicious file | `file_hash` never changes after creation: existing listings can never be repointed, so exposure is limited to new listings — including new listings added to existing collections, which collection holders would see appear as new works (and whose hashes are public on-chain like any other) |
| (Accepted, disclosed) | The artist removes works from a collection after selling it, or stops adding the works they promised | The contract makes no promise about future contents; access follows current membership. Every membership change and every purchase is a permanent public event, so what a collection held at the time of any sale can always be reconstructed |
| (Accepted, out of scope) | The artist ships harmful content in their own file | The artist is trusted with their own content; nothing in this framework can guard against it |
| (Accepted, disclosed) | Unfair or defamatory review text, permanent and unmoderated | No delete/moderation entrypoint anywhere in this contract, by design; the one-block gate only prevents same-block self-dealing, not a genuine bad-faith review posted afterward |
| (Accepted, disclosed) | A registered `website.url` domain lapses or is hijacked, redirecting buyers to whatever now lives there | No mechanism, on-chain or off, verifies live domain control; a cryptographic fix is out of scope as disproportionate cost/complexity for this project |

## Cost model recap

- **Cloudflare**: Pages, Workers (100k req/day), R2 (10GB, zero egress) all comfortably free at a single artist's site scale; Workers CPU-time billing excludes I/O wait, so file streaming doesn't consume the compute budget.
- **Tezos**: storage burn is on the order of a few tenths of a tez per kilobyte (order-of-magnitude — confirm the live protocol constant before launch, since this has shifted across past protocol amendments and the January 2026 "Tallinn" upgrade specifically touched storage costs for address-keyed contracts). A listing with a title, type, ~300-byte description, and two prices should cost low single-digit cents in burned tez, once, at listing time. The file hash adds 32 bytes. A collection record is about the same size as a listing; each membership entry is a small fixed-size key (an address and two nats) with no value, paid once when the work is added — the cost of adding a work never depends on how many the collection already holds. A buyer's license entry costs the same whether it's for a listing or a collection.

## Pre-launch checklist

- [ ] Confirm current live `cost_per_byte` protocol constant via a node/explorer before estimating final listing costs.
- [ ] Confirm personal and commercial purchases are fully independent: buying one doesn't block or discount the other, and repeat purchases of an already-held tier are accepted at full price and increment the correct count.
- [ ] Test `quantity`: rejects 0, rejects an amount that isn't exactly unit price × quantity (both under and over), and fails cleanly (rather than wrapping) on a quantity large enough to overflow mutez.
- [ ] Test `active`, for listings and collections alike: `purchase` rejects for both tiers when `active` is `false` even with nonzero prices; flipping back to `true` reopens the sale; existing licenses, `has_license`, reviews, and downloads are unaffected by closing; `%listed` and `%collection_set` carry `active` on every call.
- [ ] Publish the `listing.json` / `collection.json` / `listings.json` schemas (v1) with the template, and confirm all of these routes are served unauthenticated with `Access-Control-Allow-Origin: *` and never reference the private R2 objects that hold listing files.
- [ ] Test `file_hash`: `list` REJECTS creating a listing with an empty hash; any non-empty length is accepted at creation; afterward, a `list` call with a different hash REJECTS while one with the same hash (e.g. a price change) succeeds; `%listed` carries `file_hash` on every call.
- [ ] Confirm the admin tool never signs a `list` call until that file's R2 upload has completed and its checksum was accepted.
- [ ] End-to-end on Ghostnet, for both a single image and a zip: upload through the admin tool, download through the Worker, and confirm `shasum -a 256`, `sha256sum`, and `Get-FileHash` all match the hex shown for that listing on a block explorer.
- [ ] Test `set_collection`: requires a registered `website_id`; a later call with a different `website_id` REJECTS; `%collection_set` carries the full record on every call.
- [ ] Test `set_collection_item`: rejects for a collection that doesn't exist, a listing that doesn't exist under the caller's address (including another artist's listing with the same id), a listing whose `website_id` differs from the collection's, adding an existing member, and removing a non-member; accepts a closed (`active = false`) listing; emits exactly one `%collection_item_set` per call and no `%collection_set`; a wallet batch of several calls is all-or-nothing (one failing call leaves no membership changed).
- [ ] Test collection purchases: `purchase(Collection c)` rejects when `active` is `false` and on a zero-price tier; the admin tool never opens a collection with no works, and closes an open collection in the same batch that removes its last work; a successful purchase writes `licenses[(buyer, artist, Collection c)]` and nothing per listing; `%purchased` carries the `target`; a buyer who already owns some member listings pays the full collection price.
- [ ] Test collection-only works: a listing with `active = false` and nonzero prices rejects direct purchase, is downloadable by holders of an active collection that contains it, and its page shows its prices with "available in [collection]."
- [ ] Test collection download access end-to-end: a collection holder can download every current member; a work added after purchase becomes downloadable immediately; a removed work stops being downloadable through the collection (but remains so for anyone with its own listing license); a stale local mirror never grants access the chain doesn't confirm; the collection download page marks already-downloaded works correctly.
- [ ] Measure the largest batch that fits in one operation group on Ghostnet — `list` calls with full-length text plus `set_collection` (closed), one `set_collection_item` per work, and the opening `set_collection` — and have the admin tool split larger drops automatically. Confirm a failing call anywhere in the batch leaves nothing written.
- [ ] Confirm no deployment path stores the artist's wallet key on the site; every `list`, `set_collection`, `set_collection_item`, `set_website`, and `set_name` call is signed in the artist's wallet.
- [ ] Full test suite on Ghostnet covering: zero-price-as-not-for-sale, `active = false` as closed-but-visible, unlimited repeat purchases, independent per-tier pricing, full-snapshot event emission on both create and update, non-transferability — each for listings and collections.
- [ ] Independent audit of the contract before mainnet origination — it cannot be patched afterward.
- [ ] Confirm sign-in challenge domain-binding is implemented correctly across independently-deployed artist websites before any of them go live simultaneously.
- [ ] Confirm `list` and `set_collection` REJECT a `website_id` not yet registered via `set_website`, confirm a `list` or `set_collection` update that passes a different `website_id` than the original REJECTS the call, and confirm updating a website's `url` via `set_website` correctly propagates to every listing and collection that references it without needing to re-send them.
- [ ] Test `review`, for both target kinds: rejects when called in the same block as the triggering `purchase` (including when batched into one operation group), accepts starting the very next block, rejects from a buyer with no license on that target (including a collection holder reviewing a member listing they didn't buy on its own), rejects an out-of-range rating, rejects a fully-empty (no rating, no comment) call, and confirms an edit after the initial gated write updates `updated_at` but never `posted_at`.
- [ ] Confirm `has_license` returns the correct default (`{personal: 0; commercial: 0; purchased_at_level: 0}`) for a key that was never written, for both `Listing` and `Collection` targets, and that `in_collection` returns `false` for a pair never written or since removed; test both as genuine views (no gas cost, no side effects) rather than entrypoints.
- [ ] Document for integrators that `has_license(…, Listing n)` does not reflect rights held through a collection, with a reference snippet for checking both.
- [ ] Test UTF-8 round-tripping end-to-end on Ghostnet for `names`, listing and collection `title` and `description`, `item_type`, and `review.comment`: non-Latin scripts (e.g. CJK, Arabic/RTL), combining diacritics, and emoji, encoded to `bytes` by the admin tool and correctly decoded by the artist's own site, any reference indexer tooling, and a generic block explorer's raw view (confirm the latter shows hex, as expected, and isn't relied on for display).
- [ ] Confirm current live average block time before relying on "one block" as a user-facing latency expectation for posting a review after purchase.
- [ ] Ship reference indexer/syndicator tooling with the recommended posted_at-based ranking convention documented and implemented by default, so early third-party feeds don't default to naive last-updated sorting before the convention has a chance to spread.
- [ ] Treat any future PR that adds a per-address, per-listing, or per-collection growing index (including storing member lists inside a collection record) as a rejected pattern by default — flag it against this document's "Views, and why there's no on-chain enumeration" section before it goes anywhere near mainnet.
- [ ] Test `purchase` with `artist` set to an originated contract (`KT1`), not just an implicit wallet — confirm the license write is fully committed before the tez transfer is queued, and confirm a contract that attempts to call back into the registry mid-payout gains no extra privilege.
- [ ] Confirm admin authentication rejects every signer except `env.ARTIST_ADDRESS`, including a valid buyer signature for a different address, before any admin route (upload, `list`, `set_collection`, `set_collection_item`, `set_website`, `set_name`) is reachable.

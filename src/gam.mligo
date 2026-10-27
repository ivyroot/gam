// Global Art Market (GAM): one shared, immutable, admin-free contract where
// artists list works and collections and sell non-transferable display
// licenses for them.
//
// Spec: art-sale-ever-growing-mono-contract-plan-oct-26.md
//
// House rules for contracts we prove (tezos_source_language_for_proving_Oct_22_2026):
//   1. Every helper is [@inline], so no LAMBDA/EXEC reaches the prover.
//   2. Every action indexers need is an event; SET_DELEGATE is never used.
//   3. Read-only queries are [@view]s, never getter entrypoints.
//   4. Nat subtraction uses is_nat (there is none today).
//   5. The LIGO version is pinned in LIGO_VERSION.
// And from the Oct 22 provability review: no loops anywhere, and every write
// is a single big_map update under a key that starts with the sender.

// ---------------------------------------------------------------------------
// Types

type tier =
  | Personal
  | Commercial

// What a license, a purchase, or a review is for. listing_id and
// collection_id are separate per-artist number spaces.
type target =
  | Listing of nat     // listing_id
  | Collection of nat  // collection_id

type website = {
  url : string  // the ONLY site that can fulfill listings and collections created under this website_id
}

type listing = {
  title                    : bytes;  // UTF-8
  item_type                : bytes;  // UTF-8, e.g. "photograph"
  description              : bytes;  // UTF-8
  personal_display_price   : tez;    // 0 = not for sale
  commercial_display_price : tez;    // 0 = not for sale
  website_id               : nat;    // fixed at creation
  active                   : bool;   // false = visible but not purchasable on its own
  file_hash                : bytes   // required at creation, never changes
}

type collection = {
  title                    : bytes;  // UTF-8
  description              : bytes;  // UTF-8
  personal_display_price   : tez;    // 0 = not for sale
  commercial_display_price : tez;    // 0 = not for sale
  website_id               : nat;    // fixed at creation; every member listing must share it
  active                   : bool    // false = visible but closed to purchase
}

type license = {
  personal           : nat;  // personal-display licenses bought
  commercial         : nat;  // commercial-display licenses bought
  purchased_at_level : nat   // level of the first purchase of either tier; gates review
}

type review = {
  rating     : nat option;    // 1-10 if present
  comment    : bytes option;  // UTF-8
  posted_at  : timestamp;     // set on the first write, never changes
  updated_at : timestamp      // set on every write
}

type storage = {
  names            : (address, bytes) big_map;                        // UTF-8 display names
  websites         : (address * nat, website) big_map;                // (artist, website_id)
  listings         : (address * nat, listing) big_map;                // (artist, listing_id)
  collections      : (address * nat, collection) big_map;             // (artist, collection_id)
  collection_items : (address * nat * nat, unit) big_map;             // (artist, collection_id, listing_id); key existence IS membership
  licenses         : (address * address * target, license) big_map;   // (buyer, artist, target)
  reviews          : (address * address * target, review) big_map     // (buyer, artist, target)
}

type ret = operation list * storage

let initial_storage : storage = {
  names            = Big_map.empty;
  websites         = Big_map.empty;
  listings         = Big_map.empty;
  collections      = Big_map.empty;
  collection_items = Big_map.empty;
  licenses         = Big_map.empty;
  reviews          = Big_map.empty
}

// ---------------------------------------------------------------------------
// Entrypoint parameters

type set_website_param = {
  website_id : nat;
  url        : string
}

type list_param = {
  listing_id               : nat;
  title                    : bytes;
  item_type                : bytes;
  description              : bytes;
  personal_display_price   : tez;
  commercial_display_price : tez;
  website_id               : nat;
  active                   : bool;
  file_hash                : bytes
}

type set_collection_param = {
  collection_id            : nat;
  title                    : bytes;
  description              : bytes;
  personal_display_price   : tez;
  commercial_display_price : tez;
  website_id               : nat;
  active                   : bool
}

type set_collection_item_param = {
  collection_id : nat;
  listing_id    : nat;
  included      : bool
}

type purchase_param = {
  artist   : address;
  target   : target;
  tier     : tier;
  quantity : nat
}

type review_param = {
  artist  : address;
  target  : target;
  rating  : nat option;
  comment : bytes option
}

// ---------------------------------------------------------------------------
// Event payloads. %listed, %collection_set and %website_set always carry the
// complete current record, never a diff.

type website_set_event = {
  artist     : address;
  website_id : nat;
  url        : string;
  timestamp  : timestamp
}

type listed_event = {
  artist           : address;
  artist_name      : bytes;   // empty if never set
  listing_id       : nat;
  title            : bytes;
  item_type        : bytes;
  description      : bytes;
  personal_price   : tez;
  commercial_price : tez;
  website_id       : nat;
  website_url      : string;
  active           : bool;
  file_hash        : bytes;
  timestamp        : timestamp
}

type collection_set_event = {
  artist           : address;
  artist_name      : bytes;   // empty if never set
  collection_id    : nat;
  title            : bytes;
  description      : bytes;
  personal_price   : tez;
  commercial_price : tez;
  website_id       : nat;
  website_url      : string;
  active           : bool;
  timestamp        : timestamp
}

type collection_item_set_event = {
  artist        : address;
  collection_id : nat;
  listing_id    : nat;
  included      : bool;
  timestamp     : timestamp
}

type purchased_event = {
  buyer      : address;
  artist     : address;
  target     : target;
  tier       : tier;
  quantity   : nat;
  unit_price : tez;
  price_paid : tez;
  timestamp  : timestamp
}

type reviewed_event = {
  buyer      : address;
  artist     : address;
  target     : target;
  rating     : nat option;
  comment    : bytes option;
  posted_at  : timestamp;
  updated_at : timestamp
}

// ---------------------------------------------------------------------------
// Helpers (all inlined)

[@inline] let website_url (artist : address) (website_id : nat) (s : storage) : string =
  match Big_map.find_opt (artist, website_id) s.websites with
  | None -> failwith "UNKNOWN_WEBSITE"
  | Some w -> w.url

[@inline] let artist_name (artist : address) (s : storage) : bytes =
  match Big_map.find_opt artist s.names with
  | None -> 0x
  | Some n -> n

// ---------------------------------------------------------------------------
// Entrypoints. Every write is keyed by Tezos.get_sender (), except that
// purchase sends the payment to the named artist.

[@entry] let set_name (display_name : bytes) (s : storage) : ret =
  // no event: a display convenience, read on demand
  [], { s with names = Big_map.update (Tezos.get_sender ()) (Some display_name) s.names }

[@entry] let set_website (p : set_website_param) (s : storage) : ret =
  let artist = Tezos.get_sender () in
  let websites = Big_map.update (artist, p.website_id) (Some { url = p.url }) s.websites in
  let ev = Tezos.emit "%website_set"
    ({ artist = artist; website_id = p.website_id; url = p.url; timestamp = Tezos.get_now () } : website_set_event) in
  [ev], { s with websites = websites }

[@entry] let list (p : list_param) (s : storage) : ret =
  let artist = Tezos.get_sender () in
  let url = website_url artist p.website_id s in
  let () =
    match Big_map.find_opt (artist, p.listing_id) s.listings with
    | Some existing ->
      let () = if p.website_id <> existing.website_id then failwith "WEBSITE_ID_IMMUTABLE" in
      if p.file_hash <> existing.file_hash then failwith "FILE_HASH_IMMUTABLE"
    | None ->
      if Bytes.length p.file_hash = 0n then failwith "EMPTY_FILE_HASH" in
  let record : listing = {
    title                    = p.title;
    item_type                = p.item_type;
    description              = p.description;
    personal_display_price   = p.personal_display_price;
    commercial_display_price = p.commercial_display_price;
    website_id               = p.website_id;
    active                   = p.active;
    file_hash                = p.file_hash
  } in
  let listings = Big_map.update (artist, p.listing_id) (Some record) s.listings in
  let ev = Tezos.emit "%listed" ({
    artist           = artist;
    artist_name      = artist_name artist s;
    listing_id       = p.listing_id;
    title            = p.title;
    item_type        = p.item_type;
    description      = p.description;
    personal_price   = p.personal_display_price;
    commercial_price = p.commercial_display_price;
    website_id       = p.website_id;
    website_url      = url;
    active           = p.active;
    file_hash        = p.file_hash;
    timestamp        = Tezos.get_now ()
  } : listed_event) in
  [ev], { s with listings = listings }

[@entry] let set_collection (p : set_collection_param) (s : storage) : ret =
  let artist = Tezos.get_sender () in
  let url = website_url artist p.website_id s in
  let () =
    match Big_map.find_opt (artist, p.collection_id) s.collections with
    | Some existing ->
      if p.website_id <> existing.website_id then failwith "WEBSITE_ID_IMMUTABLE"
    | None -> () in
  let record : collection = {
    title                    = p.title;
    description              = p.description;
    personal_display_price   = p.personal_display_price;
    commercial_display_price = p.commercial_display_price;
    website_id               = p.website_id;
    active                   = p.active
  } in
  let collections = Big_map.update (artist, p.collection_id) (Some record) s.collections in
  let ev = Tezos.emit "%collection_set" ({
    artist           = artist;
    artist_name      = artist_name artist s;
    collection_id    = p.collection_id;
    title            = p.title;
    description      = p.description;
    personal_price   = p.personal_display_price;
    commercial_price = p.commercial_display_price;
    website_id       = p.website_id;
    website_url      = url;
    active           = p.active;
    timestamp        = Tezos.get_now ()
  } : collection_set_event) in
  [ev], { s with collections = collections }

[@entry] let set_collection_item (p : set_collection_item_param) (s : storage) : ret =
  // exactly one membership change per call; many changes are one wallet batch
  let artist = Tezos.get_sender () in
  let c =
    match Big_map.find_opt (artist, p.collection_id) s.collections with
    | None -> failwith "UNKNOWN_COLLECTION"
    | Some c -> c in
  let key = (artist, p.collection_id, p.listing_id) in
  let is_member = Big_map.mem key s.collection_items in
  let () =
    if p.included then
      let l =
        match Big_map.find_opt (artist, p.listing_id) s.listings with
        | None -> failwith "UNKNOWN_LISTING"
        | Some l -> l in
      let () = if l.website_id <> c.website_id then failwith "WEBSITE_MISMATCH" in
      if is_member then failwith "ALREADY_MEMBER"
    else
      if not is_member then failwith "NOT_MEMBER" in
  let value = if p.included then Some () else None in
  let ev = Tezos.emit "%collection_item_set" ({
    artist        = artist;
    collection_id = p.collection_id;
    listing_id    = p.listing_id;
    included      = p.included;
    timestamp     = Tezos.get_now ()
  } : collection_item_set_event) in
  [ev], { s with collection_items = Big_map.update key value s.collection_items }

[@entry] let purchase (p : purchase_param) (s : storage) : ret =
  let () = if p.quantity = 0n then failwith "ZERO_QUANTITY" in
  let (personal_price, commercial_price) =
    match p.target with
    | Listing listing_id ->
      (match Big_map.find_opt (p.artist, listing_id) s.listings with
       | None -> failwith "UNKNOWN_LISTING"
       | Some l ->
         if not l.active then failwith "NOT_ACTIVE"
         else (l.personal_display_price, l.commercial_display_price))
    | Collection collection_id ->
      (match Big_map.find_opt (p.artist, collection_id) s.collections with
       | None -> failwith "UNKNOWN_COLLECTION"
       | Some c ->
         if not c.active then failwith "NOT_ACTIVE"
         else (c.personal_display_price, c.commercial_display_price)) in
  let unit_price =
    match p.tier with
    | Personal -> personal_price
    | Commercial -> commercial_price in
  let () = if unit_price = 0tez then failwith "NOT_FOR_SALE" in
  let total_price = unit_price * p.quantity in  // MUL on mutez fails on overflow
  let () = if Tezos.get_amount () <> total_price then failwith "WRONG_AMOUNT" in
  let buyer = Tezos.get_sender () in
  let key = (buyer, p.artist, p.target) in
  // no "already held" check: repeat purchases are unlimited, always at full price
  let license =
    match Big_map.find_opt key s.licenses with
    | None ->
      { personal = 0n; commercial = 0n; purchased_at_level = Tezos.get_level () }
    | Some current -> current in
  let license =
    match p.tier with
    | Personal -> { license with personal = license.personal + p.quantity }
    | Commercial -> { license with commercial = license.commercial + p.quantity } in
  let artist_contract : unit contract =
    match Tezos.get_contract_opt p.artist with
    | None -> failwith "ARTIST_CANNOT_RECEIVE"
    | Some c -> c in
  // storage is committed before the payout runs (no reentrancy window)
  let payout = Tezos.Next.Operation.transaction () total_price artist_contract in
  let ev = Tezos.emit "%purchased" ({
    buyer      = buyer;
    artist     = p.artist;
    target     = p.target;
    tier       = p.tier;
    quantity   = p.quantity;
    unit_price = unit_price;
    price_paid = total_price;
    timestamp  = Tezos.get_now ()
  } : purchased_event) in
  [payout; ev], { s with licenses = Big_map.update key (Some license) s.licenses }

[@entry] let review (p : review_param) (s : storage) : ret =
  let buyer = Tezos.get_sender () in
  let key = (buyer, p.artist, p.target) in
  let license =
    match Big_map.find_opt key s.licenses with
    | None -> failwith "NO_LICENSE"
    | Some l -> l in
  let () =
    match (p.rating, p.comment) with
    | (None, None) -> failwith "EMPTY_REVIEW"
    | (Some r, _) -> if r < 1n || r > 10n then failwith "BAD_RATING"
    | (None, Some _) -> () in
  // strictly a later block than the first purchase
  let () = if Tezos.get_level () <= license.purchased_at_level then failwith "TOO_EARLY" in
  let now = Tezos.get_now () in
  let posted_at =
    match Big_map.find_opt key s.reviews with
    | None -> now
    | Some existing -> existing.posted_at in
  let record : review = { rating = p.rating; comment = p.comment; posted_at = posted_at; updated_at = now } in
  let ev = Tezos.emit "%reviewed" ({
    buyer      = buyer;
    artist     = p.artist;
    target     = p.target;
    rating     = p.rating;
    comment    = p.comment;
    posted_at  = posted_at;
    updated_at = now
  } : reviewed_event) in
  [ev], { s with reviews = Big_map.update key (Some record) s.reviews }

// ---------------------------------------------------------------------------
// Views: point lookups only, never enumeration.

[@view] let has_license (buyer, artist, target : address * address * target) (s : storage) : license =
  match Big_map.find_opt (buyer, artist, target) s.licenses with
  | None -> { personal = 0n; commercial = 0n; purchased_at_level = 0n }
  | Some l -> l

[@view] let in_collection (artist, collection_id, listing_id : address * nat * nat) (s : storage) : bool =
  Big_map.mem (artist, collection_id, listing_id) s.collection_items

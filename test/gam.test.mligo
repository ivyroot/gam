// Unit tests for gam.mligo on LIGO's in-process interpreter.
//
//   ligo run test test/gam.test.mligo
//
// Fast feedback only. The suite of record runs the compiled out/gam.tz on
// TezBox with Taquito. One rule cannot be tested here: review's "strictly a
// later block" gate, because every transfer below bakes its own block, so a
// purchase and a review can never share one. test/tezbox.test.mjs covers it
// with a wallet batch.

#import "../src/gam.mligo" "Gam"

module T = Test.Next

type ctx = {
  c      : (Gam parameter_of, Gam.storage) typed_address;
  addr   : address;
  alice  : address;  // artist
  bob    : address;  // buyer
  carol  : address   // second artist
}

let one = 1tez
let five = 5tez

// ---------------------------------------------------------------------------
// Helpers

let setup () : ctx =
  let () = T.State.reset 4n ([] : tez list) in
  let o = T.Originate.contract (contract_of Gam) Gam.initial_storage 0tez in
  { c = o.taddr; addr = T.Typed_address.to_address o.taddr;
    alice = T.Account.address 1n; bob = T.Account.address 2n; carol = T.Account.address 3n }

let call (x : ctx) (who : address) (p : Gam parameter_of) (amt : tez) : test_exec_result =
  let () = T.State.set_source who in
  T.Typed_address.transfer x.c p amt

let ok (x : ctx) (who : address) (p : Gam parameter_of) (amt : tez) : unit =
  match call x who p amt with
  | Success _ -> ()
  | Fail (Rejected (v, _)) -> let () = T.IO.log ("unexpected rejection", v) in failwith "UNEXPECTED_REJECTION"
  | Fail e -> let () = T.IO.log e in failwith "UNEXPECTED_FAILURE"

let rejects (x : ctx) (who : address) (p : Gam parameter_of) (amt : tez) (err : string) : unit =
  match call x who p amt with
  | Fail (Rejected (v, _)) ->
    if T.Compare.eq v (T.Michelson.eval err) then ()
    else let () = T.IO.log ("expected", err, "got", v) in failwith "WRONG_REJECTION"
  | Fail e -> let () = T.IO.log ("expected", err, "got", e) in failwith "WRONG_FAILURE"
  | Success _ -> let () = T.IO.log ("expected", err, "but call succeeded") in failwith "MISSING_REJECTION"

let storage (x : ctx) : Gam.storage = T.Typed_address.get_storage x.c

let listing_p (id : nat) (website_id : nat) (active : bool) (hash : bytes) : Gam.list_param = {
  listing_id = id; title = 0x5469746c65; item_type = 0x70686f746f; description = 0x;
  personal_display_price = one; commercial_display_price = five;
  website_id = website_id; active = active; file_hash = hash
}

let collection_p (id : nat) (website_id : nat) (active : bool) : Gam.set_collection_param = {
  collection_id = id; title = 0x436f6c6c; description = 0x;
  personal_display_price = 2tez; commercial_display_price = 0tez;
  website_id = website_id; active = active
}

let site (x : ctx) (who : address) (id : nat) : unit =
  ok x who (Set_website { website_id = id; url = "https://site.example" }) 0tez

// alice: website 1, listing 1 (active), listing 2 (inactive), collection 1
// (active) holding listing 2.
let shop () : ctx =
  let x = setup () in
  let () = site x x.alice 1n in
  let () = ok x x.alice (List (listing_p 1n 1n true 0x01)) 0tez in
  let () = ok x x.alice (List (listing_p 2n 1n false 0x02)) 0tez in
  let () = ok x x.alice (Set_collection (collection_p 1n 1n false)) 0tez in
  let () = ok x x.alice (Set_collection_item { collection_id = 1n; listing_id = 2n; included = true }) 0tez in
  let () = ok x x.alice (Set_collection (collection_p 1n 1n true)) 0tez in
  x

let license_of (x : ctx) (buyer : address) (artist : address) (t : Gam.target) : Gam.license =
  Option.value_with_error "NO_VIEW_RESULT" (Tezos.call_view "has_license" (buyer, artist, t) x.addr)

// T.State.last_events returns only the events of the most recent operation
let only (type a) (evs : a list) : a =
  match evs with
  | [e] -> e
  | _ -> failwith "EXPECTED_ONE_EVENT"

let buy (artist : address) (t : Gam.target) (tier : Gam.tier) (q : nat) : Gam parameter_of =
  Purchase { artist = artist; target = t; tier = tier; quantity = q }

// ---------------------------------------------------------------------------
// set_name, set_website

let test_set_website_emits_full_record =
  let x = setup () in
  let () = ok x x.alice (Set_name 0xe697a5) 0tez in
  let () = site x x.alice 7n in
  let s = storage x in
  let () = T.Assert.assert (Big_map.find_opt x.alice s.names = Some 0xe697a5) in
  let () = T.Assert.assert (Big_map.find_opt (x.alice, 7n) s.websites = Some { url = "https://site.example" }) in
  let e : Gam.website_set_event = only (T.State.last_events x.c "website_set") in
  T.Assert.assert (e.artist = x.alice && e.website_id = 7n && e.url = "https://site.example")

// ---------------------------------------------------------------------------
// list

let test_list_requires_registered_website =
  let x = setup () in
  let () = site x x.carol 1n in   // carol's website 1 is not alice's
  rejects x x.alice (List (listing_p 1n 1n true 0x01)) 0tez "UNKNOWN_WEBSITE"

let test_list_requires_file_hash_at_creation =
  let x = setup () in
  let () = site x x.alice 1n in
  rejects x x.alice (List (listing_p 1n 1n true 0x)) 0tez "EMPTY_FILE_HASH"

let test_list_update_keeps_hash_and_website =
  let x = setup () in
  let () = site x x.alice 1n in
  let () = site x x.alice 2n in
  let () = ok x x.alice (List (listing_p 1n 1n true 0xaa)) 0tez in
  let () = rejects x x.alice (List (listing_p 1n 1n true 0xbb)) 0tez "FILE_HASH_IMMUTABLE" in
  let () = rejects x x.alice (List (listing_p 1n 2n true 0xaa)) 0tez "WEBSITE_ID_IMMUTABLE" in
  // a price change with the same hash and website is fine
  let () = ok x x.alice (List { (listing_p 1n 1n false 0xaa) with personal_display_price = 0tez }) 0tez in
  match Big_map.find_opt (x.alice, 1n) (storage x).listings with
  | Some l -> T.Assert.assert (l.personal_display_price = 0tez && not l.active && l.file_hash = 0xaa)
  | None -> failwith "MISSING_LISTING"

let test_listed_event_is_full_snapshot =
  let x = setup () in
  let () = site x x.alice 1n in
  let () = ok x x.alice (List (listing_p 1n 1n true 0xaa)) 0tez in
  let first : Gam.listed_event = only (T.State.last_events x.c "listed") in
  let () = T.Assert.assert (first.artist_name = 0x && first.commercial_price = five) in
  let () = ok x x.alice (Set_name 0x416c696365) 0tez in
  // an update that only changes the price still carries every field
  let () = ok x x.alice (List { (listing_p 1n 1n true 0xaa) with commercial_display_price = 9tez }) 0tez in
  let second : Gam.listed_event = only (T.State.last_events x.c "listed") in
  T.Assert.assert (second.artist = x.alice && second.artist_name = 0x416c696365 && second.listing_id = 1n
          && second.title = 0x5469746c65 && second.item_type = 0x70686f746f
          && second.personal_price = one && second.commercial_price = 9tez
          && second.website_id = 1n && second.website_url = "https://site.example"
          && second.active && second.file_hash = 0xaa)

// ---------------------------------------------------------------------------
// set_collection, set_collection_item

let test_collection_website_rules =
  let x = setup () in
  let () = rejects x x.alice (Set_collection (collection_p 1n 1n false)) 0tez "UNKNOWN_WEBSITE" in
  let () = site x x.alice 1n in
  let () = site x x.alice 2n in
  let () = ok x x.alice (Set_collection (collection_p 1n 1n false)) 0tez in
  let e : Gam.collection_set_event = only (T.State.last_events x.c "collection_set") in
  let () = T.Assert.assert (e.collection_id = 1n && e.website_url = "https://site.example" && not e.active) in
  rejects x x.alice (Set_collection (collection_p 1n 2n false)) 0tez "WEBSITE_ID_IMMUTABLE"

let test_collection_membership_rules =
  let x = setup () in
  let () = site x x.alice 1n in
  let () = site x x.alice 2n in
  let () = ok x x.alice (List (listing_p 1n 1n false 0x01)) 0tez in   // closed listings can join
  let () = ok x x.alice (List (listing_p 2n 2n true 0x02)) 0tez in
  let add c l : Gam parameter_of = Set_collection_item { collection_id = c; listing_id = l; included = true } in
  let remove c l : Gam parameter_of = Set_collection_item { collection_id = c; listing_id = l; included = false } in
  let () = rejects x x.alice (add 1n 1n) 0tez "UNKNOWN_COLLECTION" in
  let () = ok x x.alice (Set_collection (collection_p 1n 1n false)) 0tez in
  let () = rejects x x.alice (add 1n 9n) 0tez "UNKNOWN_LISTING" in
  let () = rejects x x.alice (add 1n 2n) 0tez "WEBSITE_MISMATCH" in
  let () = ok x x.alice (add 1n 1n) 0tez in
  let a : Gam.collection_item_set_event = only (T.State.last_events x.c "collection_item_set") in
  let () = T.Assert.assert (a.included && a.artist = x.alice && a.collection_id = 1n && a.listing_id = 1n) in
  let () = rejects x x.alice (add 1n 1n) 0tez "ALREADY_MEMBER" in
  let in_c () : bool = Option.value_with_error "NO_VIEW_RESULT" (Tezos.call_view "in_collection" (x.alice, 1n, 1n) x.addr) in
  let () = T.Assert.assert (in_c ()) in
  let () = ok x x.alice (remove 1n 1n) 0tez in
  let r : Gam.collection_item_set_event = only (T.State.last_events x.c "collection_item_set") in
  let () = T.Assert.assert (not r.included && r.collection_id = 1n && r.listing_id = 1n) in
  let () = rejects x x.alice (remove 1n 1n) 0tez "NOT_MEMBER" in
  T.Assert.assert (not (in_c ()))

let test_membership_is_self_scoped =
  let x = shop () in
  // carol has her own collection 1 on her own website 1, but alice's
  // listing 1 is not hers, so she cannot add it
  let () = site x x.carol 1n in
  let () = ok x x.carol (Set_collection (collection_p 1n 1n false)) 0tez in
  let () = rejects x x.carol (Set_collection_item { collection_id = 1n; listing_id = 1n; included = true }) 0tez "UNKNOWN_LISTING" in
  // nor can she remove a member of alice's collection 1: her own collection 1 has none
  let () = rejects x x.carol (Set_collection_item { collection_id = 1n; listing_id = 2n; included = false }) 0tez "NOT_MEMBER" in
  T.Assert.assert (Big_map.mem (x.alice, 1n, 2n) (storage x).collection_items)

// ---------------------------------------------------------------------------
// purchase

let test_purchase_rejections =
  let x = shop () in
  let () = rejects x x.bob (buy x.alice (Listing 1n) Personal 0n) 0tez "ZERO_QUANTITY" in
  let () = rejects x x.bob (buy x.alice (Listing 9n) Personal 1n) one "UNKNOWN_LISTING" in
  let () = rejects x x.bob (buy x.alice (Collection 9n) Personal 1n) one "UNKNOWN_COLLECTION" in
  let () = rejects x x.bob (buy x.alice (Listing 2n) Personal 1n) one "NOT_ACTIVE" in      // collection-only work
  let () = rejects x x.bob (buy x.alice (Collection 1n) Commercial 1n) 0tez "NOT_FOR_SALE" in  // price 0
  let () = rejects x x.bob (buy x.alice (Listing 1n) Personal 2n) one "WRONG_AMOUNT" in     // underpay
  let () = rejects x x.bob (buy x.alice (Listing 1n) Personal 1n) 2tez "WRONG_AMOUNT" in    // overpay
  let () = rejects x x.bob (buy x.carol (Listing 1n) Personal 1n) one "UNKNOWN_LISTING" in  // wrong artist
  T.Assert.assert (not (Big_map.mem (x.bob, x.alice, Listing 1n) (storage x).licenses))

let test_purchase_pays_artist_and_counts =
  let x = shop () in
  let before = T.Address.get_balance x.alice in
  let () = ok x x.bob (buy x.alice (Listing 1n) Personal 3n) 3tez in
  let e1 : Gam.purchased_event = only (T.State.last_events x.c "purchased") in
  let () = T.Assert.assert (e1.buyer = x.bob && e1.artist = x.alice && e1.target = Listing 1n
                   && e1.tier = Personal && e1.quantity = 3n && e1.unit_price = one && e1.price_paid = 3tez) in
  let first = license_of x x.bob x.alice (Listing 1n) in
  let () = T.Assert.assert (first.personal = 3n && first.commercial = 0n && first.purchased_at_level > 0n) in
  let () = T.Assert.assert (T.Address.get_balance x.alice = before + 3tez) in
  let () = T.Assert.assert (T.Address.get_balance x.addr = 0tez) in
  // repeat purchases of either tier are unlimited, at full price, and keep the first level
  let () = ok x x.bob (buy x.alice (Listing 1n) Commercial 2n) 10tez in
  let e2 : Gam.purchased_event = only (T.State.last_events x.c "purchased") in
  let () = T.Assert.assert (e2.tier = Commercial && e2.quantity = 2n && e2.unit_price = five && e2.price_paid = 10tez) in
  let () = ok x x.bob (buy x.alice (Listing 1n) Personal 1n) one in
  let later = license_of x x.bob x.alice (Listing 1n) in
  let () = T.Assert.assert (later.personal = 4n && later.commercial = 2n) in
  let () = T.Assert.assert (later.purchased_at_level = first.purchased_at_level) in
  T.Assert.assert (T.Address.get_balance x.alice = before + 14tez)

let test_collection_purchase_is_its_own_target =
  let x = shop () in
  let () = ok x x.bob (buy x.alice (Collection 1n) Personal 1n) 2tez in
  let lc = license_of x x.bob x.alice (Collection 1n) in
  let ll = license_of x x.bob x.alice (Listing 2n) in
  let () = T.Assert.assert (lc.personal = 1n) in
  // no per-listing license is written for the collection's members
  let () = T.Assert.assert (ll.personal = 0n && ll.commercial = 0n && ll.purchased_at_level = 0n) in
  // closing the collection stops sales but keeps licenses
  let () = ok x x.alice (Set_collection (collection_p 1n 1n false)) 0tez in
  let () = rejects x x.bob (buy x.alice (Collection 1n) Personal 1n) 2tez "NOT_ACTIVE" in
  T.Assert.assert ((license_of x x.bob x.alice (Collection 1n)).personal = 1n)

let test_has_license_default =
  let x = shop () in
  let l = license_of x x.carol x.alice (Listing 1n) in
  T.Assert.assert (l.personal = 0n && l.commercial = 0n && l.purchased_at_level = 0n)

// ---------------------------------------------------------------------------
// review

let test_review_rejections =
  let x = shop () in
  let rv t r c : Gam parameter_of = Review { artist = x.alice; target = t; rating = r; comment = c } in
  let () = rejects x x.bob (rv (Listing 1n) (Some 5n) (None : bytes option)) 0tez "NO_LICENSE" in
  let () = ok x x.bob (buy x.alice (Collection 1n) Personal 1n) 2tez in
  // a collection license gives no review slot on its member listings
  let () = rejects x x.bob (rv (Listing 2n) (Some 5n) (None : bytes option)) 0tez "NO_LICENSE" in
  let () = rejects x x.bob (rv (Collection 1n) (None : nat option) (None : bytes option)) 0tez "EMPTY_REVIEW" in
  let () = rejects x x.bob (rv (Collection 1n) (Some 0n) (None : bytes option)) 0tez "BAD_RATING" in
  let () = rejects x x.bob (rv (Collection 1n) (Some 11n) (Some 0x6869)) 0tez "BAD_RATING" in
  T.Assert.assert (not (Big_map.mem (x.bob, x.alice, Collection 1n) (storage x).reviews))

let test_review_posted_at_never_moves =
  let x = shop () in
  let () = ok x x.bob (buy x.alice (Listing 1n) Personal 1n) one in
  let key = (x.bob, x.alice, Listing 1n) in
  let () = ok x x.bob (Review { artist = x.alice; target = Listing 1n; rating = Some 10n; comment = (None : bytes option) }) 0tez in
  let first = Option.value_with_error "NO_REVIEW" (Big_map.find_opt key (storage x).reviews) in
  let () = T.Assert.assert (first.posted_at = first.updated_at) in
  // closed listings stay reviewable, and edits keep posted_at
  let () = ok x x.alice (List (listing_p 1n 1n false 0x01)) 0tez in
  let () = ok x x.bob (Review { artist = x.alice; target = Listing 1n; rating = (None : nat option); comment = Some 0x6f6b }) 0tez in
  let edited = Option.value_with_error "NO_REVIEW" (Big_map.find_opt key (storage x).reviews) in
  let () = T.Assert.assert (edited.posted_at = first.posted_at && edited.updated_at > first.updated_at) in
  let () = T.Assert.assert (edited.rating = (None : nat option) && edited.comment = Some 0x6f6b) in
  let e : Gam.reviewed_event = only (T.State.last_events x.c "reviewed") in
  T.Assert.assert (e.buyer = x.bob && e.artist = x.alice && e.target = Listing 1n && e.posted_at = first.posted_at
                   && e.updated_at = edited.updated_at && e.comment = Some 0x6f6b)

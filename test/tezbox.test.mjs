// Integration tests on the local TezBox node (http://localhost:8732, Ushuaia,
// Octez v25.2): originate out/gam.tz and drive it as the admin tool and a
// buyer would. This covers what LIGO's interpreter cannot: real wallet
// batches (all-or-nothing, several calls in one block, hence review's
// same-block gate), payouts on a real node, event payloads as an indexer
// sees them, and views over RPC.
//
//   npm run test:tezbox      (after ./scripts/build.sh)
//
// Signs with TezBox's public sandbox accounts from tezbox/configuration.
import { test, before } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { TezosToolkit, OpKind } from "@taquito/taquito";
import { InMemorySigner } from "@taquito/signer";
import { Parser } from "@taquito/michel-codec";
import { Schema } from "@taquito/michelson-encoder";

const RPC = process.env.TEZBOX_RPC ?? "http://localhost:8732";
const root = new URL("..", import.meta.url).pathname;
const accounts = readFileSync(`${root}../../tezbox/configuration/accounts.hjson`, "utf8");
const account = (name) => ({
  pkh: accounts.match(new RegExp(`${name}:[\\s\\S]*?pkh: (\\S+)`))[1],
  sk: accounts.match(new RegExp(`${name}:[\\s\\S]*?sk: unencrypted:(\\S+)`))[1],
});
const ALICE = account("alice"), BOB = account("bob");

const toolkit = (who) => {
  const t = new TezosToolkit(RPC);
  t.setProvider({ signer: new InMemorySigner(who.sk) });
  return t;
};
const asAlice = toolkit(ALICE), asBob = toolkit(BOB);
const parser = new Parser();
const mich = (s) => parser.parseMichelineExpression(s);
const hex = (s) => "0x" + Buffer.from(s, "utf8").toString("hex");
const URL_ = "https://alice.example";
const TEZ = 1_000_000;

let gam; // KT1 address

// Parameter values, as right-combed Michelson (field order from src/gam.mligo).
const P = {
  set_name: (name) => hex(name),
  set_website: (id, url) => `(Pair ${id} "${url}")`,
  list: (id, { active = true, hash = "0x01", personal = TEZ, commercial = 5 * TEZ } = {}) =>
    `(Pair ${id} ${hex("Title " + id)} ${hex("photo")} ${hex("désc ✓")} ${personal} ${commercial} 1 ${active ? "True" : "False"} ${hash})`,
  set_collection: (id, active) => `(Pair ${id} ${hex("Coll")} 0x ${2 * TEZ} 0 1 ${active ? "True" : "False"})`,
  set_collection_item: (cid, lid, included) => `(Pair ${cid} ${lid} ${included ? "True" : "False"})`,
  purchase: (artist, target, tier, q) => `(Pair "${artist}" ${target} ${tier} ${q})`,
  review: (artist, target, rating, comment) => `(Pair "${artist}" ${target} ${rating} ${comment})`,
};
const Listing = (n) => `(Left ${n})`, Collection = (n) => `(Right ${n})`;
const Personal = "(Left Unit)", Commercial = "(Right Unit)";

const tx = (entrypoint, value, amountMutez = 0) => ({
  kind: OpKind.TRANSACTION, to: gam, amount: amountMutez, mutez: true,
  parameter: { entrypoint, value: mich(value) },
});
async function call(t, entrypoint, value, amountMutez = 0) {
  const { kind, ...params } = tx(entrypoint, value, amountMutez);
  const op = await t.contract.transfer(params);
  await op.confirmation();
  return op;
}
async function batch(t, ops) {
  const op = await t.contract.batch(ops).send();
  await op.confirmation();
  return op;
}
async function rejectsWith(promise, code) {
  await assert.rejects(promise, (e) => JSON.stringify(e.errors ?? e.message ?? e).includes(`"${code}"`)
    || assert.fail(`expected ${code}, got ${e.message} ${JSON.stringify(e.errors ?? "").slice(0, 400)}`));
}

// Events in an operation's receipt, as { tag, data }. The receipt carries
// payloads in optimized form (comb pairs as sequences, addresses as bytes), so
// decode each with its own type, as an indexer does: records become objects
// keyed by field name, nats and mutez BigNumbers, options a value or null.
function events(op) {
  return (op.operationResults ?? op.results ?? [])
    .flatMap((r) => r.metadata?.internal_operation_results ?? [])
    .filter((r) => r.kind === "event")
    .map((r) => ({ tag: r.tag, data: new Schema(r.type).Execute(r.payload) }));
}
const utf8 = (h) => Buffer.from(h, "hex").toString("utf8");
const num = (b) => Number(b);   // BigNumber or numeric string
// Block level of the chain head, and a wait until it passes a given level.
const head = async () => (await asAlice.rpc.getBlockHeader()).level;
async function blockAfter(level) {
  while ((await head()) <= level) await new Promise((r) => setTimeout(r, 1000));
}

// View results, decoded by each view's return type.
const VIEW_TYPES = {
  has_license: "(pair (nat %personal) (pair (nat %commercial) (nat %purchased_at_level)))",
  in_collection: "bool",
};
async function view(name, input) {
  const r = await asAlice.rpc.runScriptView({
    contract: gam, view: name, input: mich(input), chain_id: await asAlice.rpc.getChainId(),
    unparsing_mode: "Readable",
  });
  return new Schema(mich(VIEW_TYPES[name])).Execute(r.data);
}

before(async () => {
  const op = await asAlice.contract.originate({
    code: readFileSync(`${root}out/gam.tz`, "utf8"),
    init: mich(readFileSync(`${root}out/gam.storage.tz`, "utf8").trim()),
  });
  gam = (await op.contract()).address;
  console.log(`gam originated at ${gam}`);
});

test("admin batch: site, listings, closed collection, members, open", async () => {
  const op = await batch(asAlice, [
    tx("set_name", P.set_name("Alice ✿")),
    tx("set_website", P.set_website(1, URL_)),
    tx("list", P.list(1)),
    tx("list", P.list(2, { active: false, hash: "0x02" })),   // collection-only work
    tx("set_collection", P.set_collection(1, false)),
    tx("set_collection_item", P.set_collection_item(1, 2, true)),
    tx("set_collection", P.set_collection(1, true)),
  ]);
  const tags = events(op).map((e) => e.tag);
  assert.deepEqual(tags, ["website_set", "listed", "listed", "collection_set", "collection_item_set", "collection_set"]);

  // %listed is a full snapshot including the name and the resolved website URL
  const l = events(op)[1].data;
  assert.equal(l.artist, ALICE.pkh);
  assert.equal(utf8(l.artist_name), "Alice ✿");
  assert.equal(num(l.listing_id), 1);
  assert.equal(utf8(l.title), "Title 1");
  assert.equal(utf8(l.item_type), "photo");
  assert.equal(utf8(l.description), "désc ✓");
  assert.equal(num(l.personal_price), TEZ);
  assert.equal(num(l.commercial_price), 5 * TEZ);
  assert.equal(num(l.website_id), 1);
  assert.equal(l.website_url, URL_);
  assert.equal(l.active, true);
  assert.equal(l.file_hash, "01");
  assert.ok(l.timestamp);
  const item = events(op)[4].data;
  assert.equal(num(item.collection_id), 1);
  assert.equal(num(item.listing_id), 2);
  assert.equal(item.included, true);
  assert.equal(events(op)[5].data.active, true);

  assert.equal(await view("in_collection", `(Pair "${ALICE.pkh}" 1 2)`), true);
});

test("a failing call anywhere in a batch writes nothing", async () => {
  // listing 3 is valid; the membership add after it is not (listing 9 does not exist)
  await rejectsWith(batch(asAlice, [
    tx("list", P.list(3, { hash: "0x03" })),
    tx("set_collection_item", P.set_collection_item(1, 9, true)),
  ]), "UNKNOWN_LISTING");
  await rejectsWith(call(asBob, "purchase", P.purchase(ALICE.pkh, Listing(3), Personal, 1), TEZ), "UNKNOWN_LISTING");
});

test("purchase pays the artist exactly and emits %purchased", async () => {
  const before = await asAlice.tz.getBalance(ALICE.pkh);
  const op = await call(asBob, "purchase", P.purchase(ALICE.pkh, Listing(1), Personal, 2), 2 * TEZ);
  const after = await asAlice.tz.getBalance(ALICE.pkh);
  assert.equal(after.minus(before).toNumber(), 2 * TEZ);
  assert.equal((await asAlice.tz.getBalance(gam)).toNumber(), 0);

  const [ev] = events(op);
  assert.equal(ev.tag, "purchased");
  const p = ev.data;
  assert.equal(p.buyer, BOB.pkh);
  assert.equal(p.artist, ALICE.pkh);
  assert.equal(num(p.target.listing), 1);
  assert.ok("personal" in p.tier);
  assert.deepEqual([p.quantity, p.unit_price, p.price_paid].map(num), [2, TEZ, 2 * TEZ]);

  const lic = await view("has_license", `(Pair "${BOB.pkh}" "${ALICE.pkh}" (Left 1))`);
  assert.equal(num(lic.personal), 2);
  assert.equal(num(lic.commercial), 0);
  assert.ok(num(lic.purchased_at_level) > 0);

  await rejectsWith(call(asBob, "purchase", P.purchase(ALICE.pkh, Listing(1), Personal, 2), TEZ), "WRONG_AMOUNT");
  await rejectsWith(call(asBob, "purchase", P.purchase(ALICE.pkh, Listing(2), Personal, 1), TEZ), "NOT_ACTIVE");
});

test("review in the same block as the first purchase is rejected", async () => {
  await rejectsWith(batch(asBob, [
    tx("purchase", P.purchase(ALICE.pkh, Collection(1), Personal, 1), 2 * TEZ),
    tx("review", P.review(ALICE.pkh, Collection(1), "(Some 9)", "None")),
  ]), "TOO_EARLY");
  // the purchase in that batch was rolled back too
  const lic = await view("has_license", `(Pair "${BOB.pkh}" "${ALICE.pkh}" (Right 1))`);
  assert.deepEqual([lic.personal, lic.commercial, lic.purchased_at_level].map(num), [0, 0, 0]);
});

test("review in a later block works, and an edit keeps posted_at", async () => {
  await call(asBob, "purchase", P.purchase(ALICE.pkh, Collection(1), Personal, 1), 2 * TEZ);
  // A wallet simulates at the head's level, so until the block after the
  // purchase's is baked, even a review sent on its own simulates as TOO_EARLY.
  await blockAfter(await head());
  const [first] = events(await call(asBob, "review", P.review(ALICE.pkh, Collection(1), "(Some 9)", "None")));
  const [edit] = events(await call(asBob, "review", P.review(ALICE.pkh, Collection(1), "None", `(Some ${hex("こんにちは")})`)));
  assert.equal(first.tag, "reviewed");
  assert.equal(num(first.data.rating.Some), 9);   // options in an event decode as { Some } or null
  assert.equal(first.data.comment, null);
  assert.equal(edit.data.posted_at, first.data.posted_at);      // posted_at never moves
  assert.notEqual(edit.data.updated_at, first.data.updated_at);
  assert.equal(edit.data.rating, null);
  assert.equal(utf8(edit.data.comment.Some), "こんにちは");
  assert.equal(num(edit.data.target.collection), 1);
});

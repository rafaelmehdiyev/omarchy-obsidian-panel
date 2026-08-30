const { test } = require("node:test");
const assert = require("node:assert/strict");
const { generateVaultId, mergeVaultEntry, vaultIdFromObserved } = require("../obsidian_json.js");

test("generateVaultId returns 16 lowercase hex chars", () => {
  const id = generateVaultId();
  assert.match(id, /^[0-9a-f]{16}$/);
});

test("generateVaultId returns unique values across calls", () => {
  const ids = new Set();
  for (let i = 0; i < 1000; ++i) ids.add(generateVaultId());
  assert.equal(ids.size, 1000);
});

test("vaultIdFromObserved accepts an existing 16-hex string", () => {
  assert.equal(vaultIdFromObserved("c496b76fedaa7a5a"), "c496b76fedaa7a5a");
});

test("vaultIdFromObserved rejects malformed inputs", () => {
  assert.throws(() => vaultIdFromObserved(""));
  assert.throws(() => vaultIdFromObserved("zzzzzzzzzzzzzzzz"));
  assert.throws(() => vaultIdFromObserved("c496b76fedaa7a5"));
});

test("mergeVaultEntry adds a new vault, preserves existing entries", () => {
  const before = {
    vaults: {
      "c496b76fedaa7a5a": { path: "/home/u/Vaults/A", ts: 1 },
      "668d99623d91f96f": { path: "/home/u/Vaults/B", ts: 2 }
    }
  };
  const after = mergeVaultEntry(before, "ffffffffffffffff", "/home/u/Vaults/C", 1700000000000);
  assert.equal(after.vaults["c496b76fedaa7a5a"].path, "/home/u/Vaults/A");
  assert.equal(after.vaults["ffffffffffffffff"].path, "/home/u/Vaults/C");
  assert.equal(after.vaults["ffffffffffffffff"].ts, 1700000000000);
});

test("mergeVaultEntry preserves unknown top-level keys", () => {
  const before = { vaults: {}, someFutureKey: { experimental: true } };
  const after = mergeVaultEntry(before, "ffffffffffffffff", "/x", 1);
  assert.deepEqual(after.someFutureKey, { experimental: true });
});

test("mergeVaultEntry throws on collision", () => {
  const before = { vaults: { "c496b76fedaa7a5a": { path: "/x", ts: 1 } } };
  assert.throws(() => mergeVaultEntry(before, "c496b76fedaa7a5a", "/y", 2));
});
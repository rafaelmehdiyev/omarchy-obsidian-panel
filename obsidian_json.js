"use strict";

function generateVaultId() {
  const buf = new Uint8Array(8);
  if (typeof crypto !== "undefined" && crypto.getRandomValues) {
    crypto.getRandomValues(buf);
  } else {
    for (let i = 0; i < 8; ++i) buf[i] = Math.floor(Math.random() * 256);
  }
  let out = "";
  for (let i = 0; i < 8; ++i) out += buf[i].toString(16).padStart(2, "0");
  return out;
}

function vaultIdFromObserved(value) {
  if (typeof value !== "string" || !/^[0-9a-f]{16}$/.test(value)) {
    throw new Error("invalid vaultId: " + JSON.stringify(value));
  }
  return value;
}

function mergeVaultEntry(config, id, path, ts) {
  vaultIdFromObserved(id);
  if (!config || typeof config !== "object") throw new Error("config must be an object");
  const vaults = config.vaults && typeof config.vaults === "object" ? config.vaults : {};
  if (Object.prototype.hasOwnProperty.call(vaults, id)) {
    throw new Error("vaultId already exists: " + id);
  }
  const next = Object.assign({}, config);
  next.vaults = Object.assign({}, vaults);
  next.vaults[id] = { path: path, ts: ts };
  return next;
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    generateVaultId: generateVaultId,
    vaultIdFromObserved: vaultIdFromObserved,
    mergeVaultEntry: mergeVaultEntry
  };
}
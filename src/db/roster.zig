// Re-export shim — roster.zig has been split into focused modules.
// Callers can import this file unchanged; will be removed once all
// callers migrate to the specific store imports.

const critter_store = @import("critter_store.zig");
const inventory_store = @import("inventory_store.zig");
const currency_store = @import("currency_store.zig");
const meta_store = @import("meta_store.zig");

// --- Critter Store ---
pub const saveCritter = critter_store.saveCritter;
pub const addScar = critter_store.addScar;
pub const loadCritter = critter_store.loadCritter;
pub const loadRoster = critter_store.loadRoster;
pub const freeCritter = critter_store.freeCritter;
pub const freeRoster = critter_store.freeRoster;
pub const swapCritterOrder = critter_store.swapCritterOrder;
pub const updateCritterMove3 = critter_store.updateCritterMove3;
pub const countCritters = critter_store.countCritters;
pub const countCooldowns = critter_store.countCooldowns;
pub const getFirstCritterId = critter_store.getFirstCritterId;

// --- Inventory Store ---
pub const InventoryEntry = inventory_store.InventoryEntry;
pub const addInventoryItem = inventory_store.addInventoryItem;
pub const removeInventoryItem = inventory_store.removeInventoryItem;
pub const loadInventory = inventory_store.loadInventory;
pub const freeInventory = inventory_store.freeInventory;

// --- Currency Store ---
pub const getCurrency = currency_store.getCurrency;
pub const addCurrency = currency_store.addCurrency;
pub const spendCurrency = currency_store.spendCurrency;

// --- Meta Store ---
pub const getMetaUpgradeLevel = meta_store.getMetaUpgradeLevel;
pub const purchaseMetaUpgrade = meta_store.purchaseMetaUpgrade;
pub const getMetaStat = meta_store.getMetaStat;
pub const incrementMetaStat = meta_store.incrementMetaStat;
pub const updateMetaStatMax = meta_store.updateMetaStatMax;
pub const isSpeciesDiscovered = meta_store.isSpeciesDiscovered;
pub const markSpeciesDiscovered = meta_store.markSpeciesDiscovered;
pub const setMetaFlag = meta_store.setMetaFlag;
pub const countMetaKeysWithPrefix = meta_store.countMetaKeysWithPrefix;

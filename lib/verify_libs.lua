-- Lua 5.4 library verification script
-- Run with: lua lib/verify_libs.lua (from project root)
-- Or drop into Vexel's engine.load() to verify at runtime

local ok_count, fail_count = 0, 0

local function test(name, require_path)
  local ok, result = pcall(require, require_path)
  if ok then
    print(string.format("  [OK]   %-20s loaded successfully", name))
    ok_count = ok_count + 1
  else
    print(string.format("  [FAIL] %-20s %s", name, result))
    fail_count = fail_count + 1
  end
  return ok, result
end

print("=== CodeCritters Lua Library Verification ===")
print(string.format("Lua version: %s\n", _VERSION))

-- Single-file libraries
local ok, class = test("middleclass", "lib.middleclass")
test("bump", "lib.bump")
test("flux", "lib.flux")
test("dkjson", "lib.dkjson")
test("inspect", "lib.inspect")
test("statemachine", "lib.statemachine")
test("vector (hump)", "lib.vector")
test("timer (hump)", "lib.timer")

-- Multi-file libraries
test("jumper.pathfinder", "lib.jumper.pathfinder")
test("behaviourtree", "lib.behaviourtree")

print(string.format("\n=== Results: %d OK, %d FAILED ===", ok_count, fail_count))

-- Quick smoke tests if all loaded
if fail_count == 0 then
  print("\n--- Smoke Tests ---")

  -- middleclass: create a class
  local Creature = class('Creature')
  function Creature:initialize(name, hp) self.name = name; self.hp = hp end
  local c = Creature:new("StackOverflow", 42)
  assert(c.name == "StackOverflow" and c.hp == 42, "middleclass failed")
  print("  middleclass: class creation OK")

  -- dkjson: encode/decode
  local json = require("lib.dkjson")
  local encoded = json.encode({species="NullPointer", type="DEBUG", hp=35})
  local decoded = json.decode(encoded)
  assert(decoded.species == "NullPointer", "dkjson failed")
  print("  dkjson: encode/decode OK")

  -- inspect: table printing
  local inspect = require("lib.inspect")
  local output = inspect({name="SegFault", stats={hp=50, logic=30}})
  assert(output:find("SegFault"), "inspect failed")
  print("  inspect: table inspection OK")

  -- statemachine: state transitions
  local machine = require("lib.statemachine")
  local fsm = machine.create({
    initial = 'hub',
    events = {
      {name = 'enter_dungeon', from = 'hub', to = 'dungeon'},
      {name = 'start_battle', from = 'dungeon', to = 'battle'},
      {name = 'end_battle', from = 'battle', to = 'dungeon'},
    }
  })
  fsm:enter_dungeon()
  fsm:start_battle()
  assert(fsm.current == 'battle', "statemachine failed")
  print("  statemachine: transitions OK")

  -- flux: create a tween
  local flux = require("lib.flux")
  local obj = {x = 0, y = 0}
  flux.to(obj, 1.0, {x = 100, y = 200})
  flux.update(0.5)
  assert(obj.x > 0 and obj.x < 100, "flux failed")
  print("  flux: tweening OK")

  -- vector: basic math
  local vector = require("lib.vector")
  local v1 = vector(3, 4)
  assert(math.abs(v1:len() - 5) < 0.001, "vector failed")
  print("  vector: math OK")

  print("\n=== All smoke tests passed! ===")
end

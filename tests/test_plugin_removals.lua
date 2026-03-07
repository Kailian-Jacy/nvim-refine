-- Test: Plugin removals from Issue #45
-- Verifies that removed plugins are no longer actively referenced in config files.
-- Run with: lua tests/test_plugin_removals.lua
-- Or: nvim --headless -l tests/test_plugin_removals.lua

-- Determine config dir relative to this test file
local this_file = debug.getinfo(1, "S").source:sub(2)
local test_dir = this_file:match("(.*/)")
local config_dir = test_dir .. "../config.nvim/lua"

local pass_count = 0
local fail_count = 0
local errors = {}

local function check(desc, ok, detail)
  if ok then
    pass_count = pass_count + 1
    print("  ✓ " .. desc)
  else
    fail_count = fail_count + 1
    local msg = "  ✗ " .. desc .. (detail and (": " .. detail) or "")
    print(msg)
    table.insert(errors, msg)
  end
end

-- Helper: grep for a pattern in lua files, ignoring comment-only lines
-- A "comment-only line" is one where the pattern only appears after a "--"
local function grep_active(pattern)
  local cmd = string.format(
    'grep -rn "%s" %s --include="*.lua" | grep -v "^[^:]*:[^:]*:[[:space:]]*--" || true',
    pattern, config_dir
  )
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()
  -- Trim whitespace
  return result:match("^%s*(.-)%s*$")
end

print("Plugin Removal Tests (Issue #45)")
print("=================================")

-- 1. Telescope removed
print("\n1. telescope.nvim removal:")
local telescope_active = grep_active("nvim.telescope/telescope")
check("No active telescope plugin specs", telescope_active == "", telescope_active)
local telescope_require = grep_active('require%(.*telescope')
check("No active telescope require() calls", telescope_require == "", telescope_require)

-- 2. cmp-tabnine removed
print("\n2. cmp-tabnine removal:")
local tabnine_spec = grep_active("cmp.tabnine")
check("No active cmp-tabnine plugin specs", tabnine_spec == "", tabnine_spec)
local tabnine_source = grep_active("cmp_tabnine")
check("No active cmp_tabnine source references", tabnine_source == "", tabnine_source)

-- 3. obsidian-bridge removed
print("\n3. obsidian-bridge.nvim removal:")
local obsidian_bridge = grep_active("obsidian.bridge")
check("No active obsidian-bridge references", obsidian_bridge == "", obsidian_bridge)

-- 4. mcphub removed
print("\n4. mcphub.nvim removal:")
local mcphub_require = grep_active('require%(.*mcphub')
check("No active mcphub require() calls", mcphub_require == "", mcphub_require)
local mcphub_spec = grep_active("ravitemer/mcphub")
check("No active mcphub plugin specs", mcphub_spec == "", mcphub_spec)

-- 5. barbecue replaced with standalone nvim-navic
print("\n5. barbecue.nvim → nvim-navic:")
local barbecue_spec = grep_active("utilyre/barbecue")
check("No active barbecue plugin specs", barbecue_spec == "", barbecue_spec)
local barbecue_require = grep_active('require%(.*barbecue')
check("No active barbecue require() calls", barbecue_require == "", barbecue_require)
-- Verify nvim-navic still referenced as standalone plugin
local navic_spec = grep_active("SmiteshP/nvim.navic")
check("nvim-navic still has active plugin spec", navic_spec ~= "")

-- 6. Noice consolidated
print("\n6. noice.nvim consolidation:")
-- Check that theme.lua has no active noice plugin spec
local noice_theme_cmd = string.format(
  'grep -n "folke/noice.nvim" %s/plugins/theme.lua | grep -v "^[^:]*:[[:space:]]*--" || true',
  config_dir
)
local handle = io.popen(noice_theme_cmd)
local noice_in_theme = handle:read("*a"):match("^%s*(.-)%s*$")
handle:close()
check("noice spec NOT active in theme.lua", noice_in_theme == "", noice_in_theme)

local noice_lua_cmd = string.format(
  'grep -n "folke/noice.nvim" %s/plugins/noice.lua | grep -v "^[^:]*:[[:space:]]*--" || true',
  config_dir
)
handle = io.popen(noice_lua_cmd)
local noice_in_noice = handle:read("*a"):match("^%s*(.-)%s*$")
handle:close()
check("noice spec exists in noice.lua", noice_in_noice ~= "")

-- 7. Integrity: no broken requires
print("\n7. Integrity checks:")
check("No broken barbecue requires", (grep_active('require%(.*barbecue')) == "")
check("No broken telescope requires", (grep_active('require%(.*telescope')) == "")
check("No broken mcphub requires", (grep_active('require%(.*mcphub')) == "")
check("No broken tabnine requires", (grep_active('require%(.*tabnine')) == "")

-- Summary
print("\n=================================")
print(string.format("Results: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
  print("\nFailed tests:")
  for _, e in ipairs(errors) do
    print(e)
  end
  os.exit(1)
else
  print("All tests passed! ✓")
  os.exit(0)
end

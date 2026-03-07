-- Test for Issue #43: SnacksPickerListCursorLine override
-- Run: nvim --headless -l tests/test_issue43_cursorline.lua

local passed, failed = 0, 0
local function check(name, cond)
  if cond then passed = passed + 1; print("  PASS: " .. name)
  else failed = failed + 1; print("  FAIL: " .. name) end
end

-- Source the theme overrides block by extracting the return table
local theme_path = "config.nvim/lua/plugins/theme.lua"
local src = io.open(theme_path, "r"):read("*a")

-- Test 1: SnacksPickerListCursorLine override exists in theme.lua
check("SnacksPickerListCursorLine defined in theme.lua",
  src:find('SnacksPickerListCursorLine') ~= nil)

-- Test 2: It links to CursorLineNoneEmpty
check("links to CursorLineNoneEmpty",
  src:find('SnacksPickerListCursorLine%s*=%s*{%s*link%s*=%s*"CursorLineNoneEmpty"') ~= nil)

-- Test 3: CursorLineNoneEmpty links to Visual (the chain)
check("CursorLineNoneEmpty links to Visual",
  src:find('CursorLineNoneEmpty%s*=%s*{%s*link%s*=%s*"Visual"') ~= nil)

-- Test 4: CursorLine is transparent (bg = "")
check("CursorLine is transparent",
  src:find('CursorLine%s*=%s*{%s*bg%s*=%s*""') ~= nil)

-- Test 5: Matches existing pattern (SnacksPickerPreviewCursorLine also overridden)
check("SnacksPickerPreviewCursorLine also overridden (consistent pattern)",
  src:find('SnacksPickerPreviewCursorLine%s*=%s*{%s*link%s*=%s*"CursorLineNoneEmpty"') ~= nil)

print(string.format("\n=== Results: %d passed, %d failed ===", passed, failed))
os.exit(failed > 0 and 1 or 0)

-- tests/test_plugin_removals.lua
-- Verify that removed plugins leave no broken references.
-- Run: nvim --headless -u NONE -l tests/test_plugin_removals.lua

local errors = {}

local function check_no_reference(pattern, description)
  local handle = io.popen('grep -rn "' .. pattern .. '" config.nvim/lua/ --include="*.lua" 2>/dev/null')
  if not handle then
    table.insert(errors, "FAIL: could not run grep for " .. description)
    return
  end
  local result = handle:read("*a")
  handle:close()
  if result and #result > 0 then
    table.insert(errors, "FAIL: " .. description .. " — residual references found:\n" .. result)
  else
    print("PASS: " .. description)
  end
end

-- 1. telescope.nvim: no active references
check_no_reference("telescope", "No telescope references remain")

-- 2. cmp-tabnine: no references
check_no_reference("tabnine\\|cmp_tabnine", "No cmp-tabnine references remain")

-- 3. obsidian-bridge: no references
check_no_reference("obsidian-bridge\\|ObsidianBridge", "No obsidian-bridge references remain")

-- 4. mcphub: no references
check_no_reference("mcphub\\|MCP", "No mcphub references remain")

-- 5. barbecue: no references
check_no_reference("barbecue", "No barbecue references remain")

-- 6. Verify noice.lua exists and has init function
local noice_handle = io.popen('grep -c "init = function" config.nvim/lua/plugins/noice.lua 2>/dev/null')
if noice_handle then
  local count = noice_handle:read("*a"):gsub("%s+", "")
  noice_handle:close()
  if tonumber(count) and tonumber(count) >= 1 then
    print("PASS: noice.lua contains init function (consolidated from theme.lua)")
  else
    table.insert(errors, "FAIL: noice.lua missing init function")
  end
end

-- 7. Verify no duplicate noice spec in theme.lua
local theme_noice = io.popen('grep -c "folke/noice.nvim" config.nvim/lua/plugins/theme.lua 2>/dev/null')
if theme_noice then
  local count = theme_noice:read("*a"):gsub("%s+", "")
  theme_noice:close()
  if tonumber(count) and tonumber(count) == 0 then
    print("PASS: No duplicate noice spec in theme.lua")
  else
    table.insert(errors, "FAIL: Duplicate noice spec still exists in theme.lua")
  end
end

-- 8. Verify standalone nvim-navic spec exists
local navic_handle = io.popen('grep -c "SmiteshP/nvim-navic" config.nvim/lua/plugins/lsp.lua 2>/dev/null')
if navic_handle then
  local count = navic_handle:read("*a"):gsub("%s+", "")
  navic_handle:close()
  if tonumber(count) and tonumber(count) >= 1 then
    print("PASS: Standalone nvim-navic spec exists in lsp.lua")
  else
    table.insert(errors, "FAIL: nvim-navic spec not found in lsp.lua")
  end
end

-- 9. Verify make_text_document_params is used (not make_position_params)
local lsp_api = io.popen('grep -c "make_text_document_params" config.nvim/lua/config/keymaps.lua 2>/dev/null')
if lsp_api then
  local count = lsp_api:read("*a"):gsub("%s+", "")
  lsp_api:close()
  if tonumber(count) and tonumber(count) >= 1 then
    print("PASS: Uses make_text_document_params (not deprecated make_position_params)")
  else
    table.insert(errors, "FAIL: make_text_document_params not found in keymaps.lua")
  end
end

-- Summary
print("\n--- Summary ---")
if #errors == 0 then
  print("All " .. 9 .. " checks passed!")
  os.exit(0)
else
  for _, err in ipairs(errors) do
    print(err)
  end
  print(#errors .. " check(s) failed.")
  os.exit(1)
end

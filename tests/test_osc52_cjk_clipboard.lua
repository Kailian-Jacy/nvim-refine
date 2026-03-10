-- Test for Issue #58: CJK Characters Become `?` When Copying from Remote Neovim
--
-- Verifies that the OSC52 clipboard integration correctly handles CJK and
-- multi-byte characters. The root cause was that osc52.copy(reg) returns a
-- function, but the old autocmd never called it — making the OSC52 send a no-op.
--
-- Run: nvim --headless -u NORC -l tests/test_osc52_cjk_clipboard.lua
--
-- What this tests:
--   1. osc52.copy("+") actually sends an OSC52 escape sequence (not just returns a function)
--   2. Base64-encoded content correctly represents UTF-8 CJK characters
--   3. The correct OSC52 clipboard ('c' for '+' register) is used
--   4. Multi-line CJK text works
--   5. Mixed ASCII + CJK text works
--   6. Empty content is handled gracefully
--   7. The autocmds.lua source code calls the returned function (not discarding it)
--   8. The Y keymap uses the '+' register for consistency with Cmd+V paste

local passed = 0
local failed = 0

local function log(msg)
  print(msg)
end

local function assert_test(name, condition, msg)
  if condition then
    log("  PASS: " .. name)
    passed = passed + 1
  else
    log("  FAIL: " .. name .. (msg and (" - " .. msg) or ""))
    failed = failed + 1
  end
end

--- Read a file and return its contents as a string
local function read_file(path)
  local fh = io.open(path, "r")
  if not fh then return nil end
  local content = fh:read("*a")
  fh:close()
  return content
end

log("=== Issue #58: CJK Clipboard OSC52 Tests ===")
log("")

-- Locate source files relative to this test
local test_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
local repo_root = test_dir:gsub("tests/$", "")
local autocmds_lua = repo_root .. "config.nvim/lua/config/autocmds.lua"
local keymaps_lua = repo_root .. "config.nvim/lua/config/keymaps.lua"

-- ============================================================
-- Test 1: osc52.copy("+") returns a callable function
-- ============================================================
log("[Test 1] osc52.copy() returns a function")

local osc52 = require("vim.ui.clipboard.osc52")
local copy_fn = osc52.copy("+")
assert_test(
  "osc52.copy('+') returns a function",
  type(copy_fn) == "function",
  "Expected function, got " .. type(copy_fn)
)

-- ============================================================
-- Test 2: OSC52 sequence is actually sent with CJK content
-- ============================================================
log("")
log("[Test 2] OSC52 sequence sent with CJK content")

-- Mock nvim_chan_send to capture the escape sequence
local captured_sequences = {}
local orig_chan_send = vim.api.nvim_chan_send
vim.api.nvim_chan_send = function(fd, data)
  table.insert(captured_sequences, { fd = fd, data = data })
end

local cjk_lines = { "你好世界" }
osc52.copy("+")(cjk_lines)

assert_test(
  "nvim_chan_send was called",
  #captured_sequences > 0,
  "No escape sequence was sent"
)

if #captured_sequences > 0 then
  local seq = captured_sequences[1]
  assert_test(
    "Written to fd 2 (stderr)",
    seq.fd == 2,
    "Expected fd=2, got fd=" .. tostring(seq.fd)
  )

  -- Verify the OSC52 format: ESC]52;c;<base64>ESC\
  local clipboard_id, b64 = seq.data:match('\027%]52;(%w);([A-Za-z0-9+/=]+)\027\\')
  assert_test(
    "OSC52 escape sequence has correct format",
    clipboard_id ~= nil and b64 ~= nil,
    "Could not parse OSC52 sequence from: " .. vim.inspect(seq.data)
  )

  if clipboard_id and b64 then
    assert_test(
      "Uses clipboard 'c' for '+' register",
      clipboard_id == "c",
      "Expected clipboard='c', got '" .. clipboard_id .. "'"
    )

    -- Decode and verify the content is correct UTF-8 CJK
    local decoded = vim.base64.decode(b64)
    assert_test(
      "Base64-decoded content matches original CJK text",
      decoded == "你好世界",
      "Expected '你好世界', got '" .. tostring(decoded) .. "'"
    )
  end
end

-- ============================================================
-- Test 3: Multi-line CJK text
-- ============================================================
log("")
log("[Test 3] Multi-line CJK text")

captured_sequences = {}
local multiline_cjk = { "第一行中文", "第二行中文", "第三行" }
osc52.copy("+")(multiline_cjk)

assert_test(
  "Multi-line CJK: nvim_chan_send was called",
  #captured_sequences > 0,
  "No escape sequence sent for multi-line CJK"
)

if #captured_sequences > 0 then
  local _, b64 = captured_sequences[1].data:match('\027%]52;(%w);([A-Za-z0-9+/=]+)\027\\')
  if b64 then
    local decoded = vim.base64.decode(b64)
    local expected = "第一行中文\n第二行中文\n第三行"
    assert_test(
      "Multi-line CJK: lines joined with newline and decoded correctly",
      decoded == expected,
      "Expected '" .. expected .. "', got '" .. tostring(decoded) .. "'"
    )
  else
    assert_test("Multi-line CJK: parse OSC52 sequence", false, "Could not parse")
  end
end

-- ============================================================
-- Test 4: Mixed ASCII + CJK text
-- ============================================================
log("")
log("[Test 4] Mixed ASCII + CJK text")

captured_sequences = {}
local mixed_lines = { "Hello 你好 World 世界", "line2: テスト test" }
osc52.copy("+")(mixed_lines)

assert_test(
  "Mixed ASCII+CJK: nvim_chan_send was called",
  #captured_sequences > 0,
  "No escape sequence sent for mixed text"
)

if #captured_sequences > 0 then
  local _, b64 = captured_sequences[1].data:match('\027%]52;(%w);([A-Za-z0-9+/=]+)\027\\')
  if b64 then
    local decoded = vim.base64.decode(b64)
    local expected = "Hello 你好 World 世界\nline2: テスト test"
    assert_test(
      "Mixed ASCII+CJK: decoded content matches original",
      decoded == expected,
      "Expected '" .. expected .. "', got '" .. tostring(decoded) .. "'"
    )
  else
    assert_test("Mixed ASCII+CJK: parse OSC52 sequence", false, "Could not parse")
  end
end

-- ============================================================
-- Test 5: Empty content handled gracefully
-- ============================================================
log("")
log("[Test 5] Empty content handling")

-- The autocmd guards against empty content before calling copy().
-- But verify that copy() itself doesn't crash with empty input.
captured_sequences = {}
local ok, err = pcall(function()
  osc52.copy("+")({"" })
end)
assert_test(
  "Empty single-line string doesn't crash",
  ok,
  "osc52.copy crashed with empty string: " .. tostring(err)
)

-- Verify an empty string still produces valid base64 (just empty content)
if #captured_sequences > 0 then
  local _, b64 = captured_sequences[1].data:match('\027%]52;(%w);([A-Za-z0-9+/=]*)\027\\')
  assert_test(
    "Empty string produces valid OSC52 sequence",
    b64 ~= nil,
    "Could not parse OSC52 sequence for empty content"
  )
end

-- Restore original function
vim.api.nvim_chan_send = orig_chan_send

-- ============================================================
-- Test 6: Register 'p' used for '*' register (clipboard selection)
-- ============================================================
log("")
log("[Test 6] Register mapping: '*' → clipboard 'p'")

captured_sequences = {}
vim.api.nvim_chan_send = function(fd, data)
  table.insert(captured_sequences, { fd = fd, data = data })
end

osc52.copy("*")({ "test" })

if #captured_sequences > 0 then
  local clipboard_id = captured_sequences[1].data:match('\027%]52;(%w);')
  assert_test(
    "Register '*' maps to clipboard 'p' (primary selection)",
    clipboard_id == "p",
    "Expected clipboard='p' for '*' register, got '" .. tostring(clipboard_id) .. "'"
  )
end

vim.api.nvim_chan_send = orig_chan_send

-- ============================================================
-- Test 7: Source code verification — autocmds.lua calls the function
-- ============================================================
log("")
log("[Test 7] autocmds.lua source: OSC52 copy function is actually called")

local autocmds_content = read_file(autocmds_lua)
assert_test(
  "autocmds.lua is readable",
  autocmds_content ~= nil,
  "Could not read " .. autocmds_lua
)

if autocmds_content then
  -- The fix: .copy("+")(lines) — the returned function is called with lines
  local has_copy_call = autocmds_content:find('copy%("?%+?"?%)%(lines%)') ~= nil
  assert_test(
    'osc52.copy("+") is called with (lines) — not just returned',
    has_copy_call,
    "Expected .copy(\"+\")(lines) pattern — the returned function must be invoked"
  )

  -- The old bug: .copy('"') with no invocation of the returned function
  local has_old_bug = autocmds_content:find("copy%('\"'%)%s*$") ~= nil
      or autocmds_content:find('copy%(\'"\'%)%s*$') ~= nil
  assert_test(
    "Old bug pattern (copy with no invocation) is absent",
    not has_old_bug,
    "Found old pattern where copy() return value is discarded"
  )

  -- Must use vim.v.event.regcontents (not reading from a register)
  local uses_regcontents = autocmds_content:find("vim%.v%.event%.regcontents") ~= nil
  assert_test(
    "Uses vim.v.event.regcontents for yanked content",
    uses_regcontents,
    "Should use vim.v.event.regcontents instead of reading a register"
  )

  -- Must guard against empty content
  local guards_empty = autocmds_content:find("#lines == 0") ~= nil
  assert_test(
    "Guards against empty content",
    guards_empty,
    "Should check for empty lines before sending OSC52"
  )

  -- Must filter by operator == "y"
  local checks_operator = autocmds_content:find('vim%.v%.event%.operator') ~= nil
  assert_test(
    "Checks vim.v.event.operator for yank operations",
    checks_operator,
    "Should only send OSC52 for yank operations"
  )

  -- Must skip named register yanks to avoid duplicate OSC52
  local skips_named_regs = autocmds_content:find('vim%.v%.event%.regname') ~= nil
  assert_test(
    "Filters by regname to avoid duplicate OSC52 with native provider",
    skips_named_regs,
    "Should skip named register yanks (handled by native clipboard provider)"
  )
end

-- ============================================================
-- Test 8: Source code verification — keymaps.lua Y uses '+' register
-- ============================================================
log("")
log("[Test 8] keymaps.lua: Y keymap uses '+' register for consistency")

local keymaps_content = read_file(keymaps_lua)
assert_test(
  "keymaps.lua is readable",
  keymaps_content ~= nil,
  "Could not read " .. keymaps_lua
)

if keymaps_content then
  -- Y should map to "+y (not "*y) for register consistency with Cmd+V paste
  local y_mapping = keymaps_content:match('vim%.keymap%.set%(.- "Y".- \'(.-)\'%)')
  assert_test(
    "Y keymap found in keymaps.lua",
    y_mapping ~= nil,
    "Could not find Y keymap"
  )

  if y_mapping then
    assert_test(
      'Y maps to "+y (system clipboard register)',
      y_mapping == '"+y',
      "Expected Y to map to '\"+y', got '" .. y_mapping .. "'"
    )
  end

  -- Cmd+V paste reads from '+' register — verify consistency
  local paste_uses_plus = keymaps_content:find('<C%-R>%+') ~= nil
      or keymaps_content:find('"%+p') ~= nil
  assert_test(
    "Cmd+V paste reads from '+' register (consistent with Y)",
    paste_uses_plus,
    "Paste should use '+' register to match Y keymap"
  )
end

-- ============================================================
-- Summary
-- ============================================================
log("")
log(string.format("=== Results: %d passed, %d failed ===", passed, failed))

if failed > 0 then
  vim.cmd("cq!")  -- exit with error code
else
  vim.cmd("qa!")
end

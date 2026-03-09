"""Category A: Configuration validation tests (P0)."""
import pytest
import subprocess
import os

LAZY_DIR = os.path.expanduser("~/.local/share/nvim/lazy")
DAP_VIEW_PATH = os.path.join(LAZY_DIR, "nvim-dap-view")
DAP_PATH = os.path.join(LAZY_DIR, "nvim-dap")


def _run_nvim_lua(lua_code: str, timeout: float = 10.0) -> subprocess.CompletedProcess:
    """Run a Lua snippet in headless nvim and return the result.
    
    Note: nvim --headless prints to stderr, so we merge stdout+stderr for checking.
    """
    cmd = [
        "nvim", "--headless", "--clean",
        "+lua " + lua_code,
        "+qa",
    ]
    result = subprocess.run(
        cmd, capture_output=True, text=True, timeout=timeout
    )
    # Combine stdout and stderr for assertion - nvim headless uses stderr for print()
    result.output = result.stdout + result.stderr
    return result


def _test_dap_view_config(hide: str, width_field: str = "width", width_val: str = "0.35") -> subprocess.CompletedProcess:
    """Test dap-view setup with given config, return process result."""
    lua = (
        f"vim.opt.rtp:append('{DAP_PATH}'); "
        f"vim.opt.rtp:append('{DAP_VIEW_PATH}'); "
        f"local ok, err = pcall(function() "
        f"require('dap-view').setup({{windows={{terminal={{position='right',{width_field}={width_val},hide={hide}}}}}}}) "
        f"end); "
        f"if ok then print('CONFIG_OK') else print('CONFIG_ERROR: ' .. tostring(err)) end"
    )
    return _run_nvim_lua(lua)


class TestFixedConfig:
    """Tests that the fixed configuration loads correctly."""

    def test_hide_empty_table_loads_ok(self):
        """A1: hide={} (fixed config) loads without error."""
        result = _test_dap_view_config(hide="{}")
        assert "CONFIG_OK" in result.output, f"Expected success, got: {result.output}"

    def test_width_field_loads_ok(self):
        """A2: width=0.35 (fixed config) loads without error."""
        result = _test_dap_view_config(hide="{}", width_field="width", width_val="0.35")
        assert "CONFIG_OK" in result.output, f"Expected success, got: {result.output}"

    def test_hide_with_adapter_name_loads_ok(self):
        """hide={"debugpy"} also loads correctly."""
        result = _test_dap_view_config(hide='{"debugpy"}')
        assert "CONFIG_OK" in result.output, f"Expected success, got: {result.output}"

    def test_hide_with_multiple_adapters_loads_ok(self):
        """hide={"debugpy","codelldb"} also loads correctly."""
        result = _test_dap_view_config(hide='{"debugpy","codelldb"}')
        assert "CONFIG_OK" in result.output, f"Expected success, got: {result.output}"


class TestOldBrokenConfig:
    """Tests that the old broken configuration triggers correct errors."""

    def test_hide_boolean_triggers_error(self):
        """A3: hide=true (old config) triggers 'expected table, got boolean'."""
        result = _test_dap_view_config(hide="true")
        assert "CONFIG_ERROR" in result.output, f"Expected error, got: {result.output}"
        assert "expected table, got boolean" in result.output or "hide" in result.output

    def test_size_field_triggers_error(self):
        """A4: size=0.35 (old config) triggers 'unexpected field'."""
        result = _test_dap_view_config(hide="{}", width_field="size", width_val="0.35")
        assert "CONFIG_ERROR" in result.output, f"Expected error, got: {result.output}"
        assert "unexpected field" in result.output or "size" in result.output

    def test_both_old_bugs_together(self):
        """Both size and hide=true together trigger an error."""
        result = _test_dap_view_config(hide="true", width_field="size", width_val="0.35")
        assert "CONFIG_ERROR" in result.output, f"Expected error, got: {result.output}"


class TestConfigEdgeCases:
    """Edge cases for configuration validation."""

    def test_hide_string_triggers_error(self):
        """hide='debugpy' (string, not table) triggers error."""
        result = _test_dap_view_config(hide="'debugpy'")
        assert "CONFIG_ERROR" in result.output, f"Expected error, got: {result.output}"

    def test_hide_number_triggers_error(self):
        """hide=1 (number) triggers error."""
        result = _test_dap_view_config(hide="1")
        assert "CONFIG_ERROR" in result.output, f"Expected error, got: {result.output}"

    def test_default_config_loads_ok(self):
        """Default config (no overrides) loads fine."""
        lua = (
            f"vim.opt.rtp:append('{DAP_PATH}'); "
            f"vim.opt.rtp:append('{DAP_VIEW_PATH}'); "
            f"local ok, err = pcall(function() "
            f"require('dap-view').setup() "
            f"end); "
            f"if ok then print('CONFIG_OK') else print('CONFIG_ERROR: ' .. tostring(err)) end"
        )
        result = _run_nvim_lua(lua)
        assert "CONFIG_OK" in result.output, f"Expected success, got: {result.output}"

return {
  {
    -- Persistent breakpoints: save/restore breakpoints across sessions.
    -- Addresses nvim-config#9: Persistent breakpoints.
    "Kailian-Jacy/persistent-breakpoints.nvim",
    dependencies = { "mfussenegger/nvim-dap" },
    lazy = false,
    keys = {
      -- Override default breakpoint toggles to use persistent versions.
      {
        "<leader>xb",
        function()
          require("persistent-breakpoints.api").toggle_breakpoint()
        end,
        desc = "Toggle Breakpoint (persistent)",
      },
      {
        "<leader>xB",
        function()
          require("persistent-breakpoints.api").set_conditional_breakpoint()
        end,
        desc = "Conditional Breakpoint (persistent)",
      },
      {
        "<leader>xd",
        function()
          require("persistent-breakpoints.api").clear_all_breakpoints()
        end,
        desc = "Clear All Breakpoints",
      },
      {
        "<leader>xl",
        function()
          -- Force reload breakpoints for all loaded buffers.
          require("persistent-breakpoints.api").reload_breakpoints()
          vim.notify("Breakpoints reloaded from disk.", vim.log.levels.INFO)
        end,
        desc = "Reload Breakpoints from disk",
      },
    },
    opts = {
      -- Auto-load breakpoints when a buffer is opened.
      load_breakpoints_event = { "BufReadPost" },
      -- Always reload even if breakpoints were set manually in this session.
      always_reload = true,
      -- Save breakpoints to project-local path (default: vim.fn.stdpath("data")).
      -- This makes breakpoints per-project.
      save_dir = vim.fn.stdpath("data") .. "/breakpoints",
    },
    config = function(_, opts)
      require("persistent-breakpoints").setup(opts)

      -- Auto-save breakpoints when they are modified.
      -- This covers both add and remove operations.
      vim.api.nvim_create_autocmd({ "User" }, {
        pattern = "PersistentBreakpointsSaved",
        callback = function()
          vim.print_silent("Breakpoints saved.")
        end,
      })
    end,
  },
  {
    "igorlfs/nvim-dap-view",
    -- lazy load: will be activated by cmd or keys
    lazy = true,
    cmd = {
      "DapViewToggle",
      "DapViewOpen",
      "DapViewShow",
      "DapViewWatch",
    },
    keys = {
      {
        "<leader>ud",
        "<cmd>DapViewToggle<CR>",
        mode = "n",
        desc = "Toggle DAP View, default to console.",
      },
    },
    config = function ()
      vim.api.nvim_create_autocmd({ "FileType" }, {
        pattern = { "dap-view", "dap-view-term", "dap-repl" }, -- dap-repl is set by `nvim-dap`
        callback = function(args)
            vim.keymap.set("n", "q", "<C-w>q", { buffer = args.buf })
        end,
      })
      require("dap-view").setup({
        winbar = {
          show = true, -- For now.
          sections = { "repl", "console", "watches", "scopes", "exceptions", "breakpoints", "threads", "sessions" },
          base_sections = {
            scopes = {
              keymap = "P",
              label = "Scopes [P]",
              short_label = " [P]",
              action = function()
                require("dap-view.views").switch_to_view("scopes")
              end,
            },
            threads = {
                keymap = "F",
                label = "Frames [F]",
                short_label = "󰂥 [F]",
                action = function()
                    require("dap-view.views").switch_to_view("threads")
                end,
            },
            sessions = {
                keymap = "S", -- I ran out of mnemonics
                label = "Sessions [S]",
                short_label = " [S]",
                action = function()
                    require("dap-view.views").switch_to_view("sessions")
                end,
            },
          },
          default_section = "scopes",
        },
        -- Terminal/console configuration
        windows = {
          terminal = {
            -- Position: bottom split for terminal output
            position = "right",
            -- Height of the terminal window
            size = 0.35,
            -- Hide the terminal when not in a debug session
            hide = true,
          },
        },
        -- Automatically open dap-view when debug session starts
        switchbuf = "uselast",
      })
    end
  },
  {
    "theHamsta/nvim-dap-virtual-text",
    -- NOTE: update dap version if error happens.
    -- dap virual text and dap view is built upon certain nvim-dap versions, lacking great backward compatibility fascilities. 
    -- so turn off lazy and update the dap plugin sometimes solves the problem.
    keys = {
      {
        "<leader>uv",
        "<cmd>DapVirtualTextToggle<cr>",
        desc = "Toggle DAP Virtual Text",
      },
    },
    config = function()
      require("nvim-dap-virtual-text").setup({
        all_references = true,
        display_callback = function(variable)
          local truncate_size = vim.g.debug_virtual_text_truncate_size or 20
          if #variable.value > truncate_size then
            return ' ' .. variable.value:sub(1, truncate_size) .. '...'
          end
          return ' ' .. variable.value
        end,
      })
    end,
  },
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "jbyuki/one-small-step-for-vimkind",
    },
    lazy = true,
    keys = {
      -- { "<leader>d", "", desc = "+debug", mode = {"n", "v"} },
      -- break points: use persistent-breakpoints.nvim instead (see above).
      -- These keymaps are kept as fallback if persistent-breakpoints is not loaded.
      {
        "<leader>xb",
        function()
          local ok, pb = pcall(require, "persistent-breakpoints.api")
          if ok then
            pb.toggle_breakpoint()
          else
            require("dap").toggle_breakpoint()
          end
        end,
        desc = "Toggle Breakpoint",
      },
      {
        "<leader>xB",
        function()
          local ok, pb = pcall(require, "persistent-breakpoints.api")
          if ok then
            pb.set_conditional_breakpoint()
          else
            require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
          end
        end,
        desc = "Breakpoint Condition",
      },
      -- starting.
      {
        "<leader>Dl",
        function()
          require("dap").run_last()
        end,
        desc = "Run Last",
      },
      -- { "<leader>Da", function() require("dap").continue({ before = get_args }) end, desc = "Run with Args" },
      {
        "<leader>dr",
        function()
          require("dap").repl.toggle()
        end,
        desc = "Toggle REPL",
      },
      {
        "<leader>ds",
        function()
          require("dap").session()
        end,
        desc = "Session",
      },
      -- { "<leader>dw", function() require("dap.ui.widgets").hover() end, desc = "Widgets" },
      -- Enable/disable all breakpoints
      {
        "<leader>xE",
        function()
          -- Toggle all breakpoints enabled/disabled
          local dap = require("dap")
          local bps = require("dap.breakpoints")
          local all_bps = bps.get()
          local has_any = false
          for _, buf_bps in pairs(all_bps) do
            if #buf_bps > 0 then
              has_any = true
              break
            end
          end
          if not has_any then
            vim.print_silent("No breakpoints set.")
            return
          end
          -- Toggle: if breakpoints are currently "active" (shown), remove them all but save state.
          -- If they were disabled, restore them.
          if vim.g._dap_breakpoints_disabled then
            -- Re-enable: restore saved breakpoints
            local saved = vim.g._dap_breakpoints_saved or {}
            for bufnr_str, buf_bps in pairs(saved) do
              local bufnr = tonumber(bufnr_str)
              if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
                for _, bp in ipairs(buf_bps) do
                  dap.set_breakpoint(bp.condition, bp.hit_condition, bp.log_message)
                end
              end
            end
            vim.g._dap_breakpoints_disabled = false
            vim.g._dap_breakpoints_saved = nil
            vim.print_silent("All breakpoints enabled.")
          else
            -- Disable: save current breakpoints and clear all
            local saved = {}
            for bufnr, buf_bps in pairs(all_bps) do
              saved[tostring(bufnr)] = buf_bps
            end
            vim.g._dap_breakpoints_saved = saved
            -- Clear all breakpoints from all buffers
            for bufnr, _ in pairs(all_bps) do
              if vim.api.nvim_buf_is_valid(bufnr) then
                bps.clear(bufnr)
                -- Update signs
                pcall(function()
                  require("dap.breakpoints").to_qf_list(bps.get())
                end)
              end
            end
            vim.g._dap_breakpoints_disabled = true
            vim.print_silent("All breakpoints disabled.")
          end
        end,
        desc = "Enable/disable all breakpoints",
      },
    },
    config = function()
      local dap = require("dap")

      -- ============================================================
      -- Auto-open/close dap-view with debug sessions
      -- ============================================================

      -- Open dap-view when debug session initializes
      dap.listeners.after["event_initialized"]["dap-view-auto"] = function(_, _)
        vim.print_silent("Debug Session initialized")
        vim.g.debugging_status = "DebugOthers"
        require("lualine").refresh()

        -- Auto-open dap-view on session start
        pcall(function()
          require("dap-view").open()
        end)
      end

      -- Track stopped state
      dap.listeners.before["event_stopped"]["nvim-dap-noui"] = function(_, _)
        vim.g.debugging_status = "Stopped"
        require("lualine").refresh()

        -- When stopped, switch to scopes view for inspection
        pcall(function()
          local dap_view_state = require("dap-view.state")
          if dap_view_state.winnr and vim.api.nvim_win_is_valid(dap_view_state.winnr) then
            require("dap-view").jump_to_view("scopes")
          end
        end)
      end

      dap.listeners.before["event_continued"]["nvim-dap-noui"] = function(_, _)
        vim.g.debugging_status = "Running"
        require("lualine").refresh()
      end

      -- Close dap-view when all sessions end
      dap.listeners.before.event_terminated["nvim-dap-noui"] = function(_, _)
        vim.g.debugging_status = "NoDebug"
        vim.print_silent("Debug Session Terminated.")
        require("lualine").refresh()

        -- Auto-close dap-view when last session ends
        vim.defer_fn(function()
          if not dap.session() then
            pcall(function()
              require("dap-view").close()
            end)
          end
        end, 500)
      end

      dap.listeners.before.event_exited["nvim-dap-noui"] = function(_, _)
        vim.g.debugging_status = "NoDebug"
        vim.print_silent("Debug Session Exited.")
        require("lualine").refresh()

        vim.defer_fn(function()
          if not dap.session() then
            pcall(function()
              require("dap-view").close()
            end)
          end
        end, 500)
      end

      dap.listeners.before.disconnect["nvim-dap-noui"] = function(_, _)
        vim.g.debugging_status = "NoDebug"
        vim.print_silent("Debug Session Disconnected.")
        require("lualine").refresh()

        vim.defer_fn(function()
          if not dap.session() then
            pcall(function()
              require("dap-view").close()
            end)
          end
        end, 500)
      end

      -- ============================================================
      -- Customized helper functions
      -- ============================================================

      ---@return table<string, integer>
      vim.g.debugging_session_status = function ()
        local sessions = dap.sessions()
        local stopped_session = 0
        local running_session = 0
        for _, session in pairs(sessions) do
          if session.stopped_thread_id ~= nil then
            stopped_session = stopped_session + 1
          else
            running_session = running_session + 1
          end
        end
        return {stopped_session = stopped_session, running_session = running_session}
      end

      -- ============================================================
      -- DAP Adapters Registration
      -- ============================================================

      ---@param name string
      ---@param exe_name? string
      local function dap_register_if_executable(name, exe_name)
        exe_name = exe_name or name
        local path = vim.g.get_full_path_of(exe_name)
        if path ~= "" then
          dap.adapters[name] = {
            id = name,
            type = "executable",
            command = path,
          }
        end
      end
      dap_register_if_executable("cppdbg", "OpenDebugAD7")
      dap_register_if_executable("codelldb")
      dap_register_if_executable("gopls")
      dap_register_if_executable("sh", "bash-debug-adapter")

      -- As debugpy is sometimes provided by venv, when switching venv, availability of debugpy may change.
      -- So we just register it here, if debugpy does not exists, we'll let dap reports executable missing.
      dap.adapters.debugpy = {
        type = "executable",
        -- We want to update the actual debugpy instance it points to
        --   as used python executable is updated.
        -- So we are not using full path here.
        command = "debugpy",
        -- env = {},
        name = "debugpy",
      }

      -- ============================================================
      -- Lua debug neovim itself configuration
      -- ============================================================
      -- 1. Run require"osv".launch({port = 8086}) before debugging.
      -- 2. Navigate to lua file and start debugging.
      dap.adapters.neovimlua = function(callback, config)
        callback({ type = 'server', host = config.host or "127.0.0.1", port = config.port or 8086 })
      end
      dap.configurations.lua = {
        {
          type = 'neovimlua',
          request = 'attach',
          name = "Attach to running Neovim instance",
        }
      }

      -- ============================================================
      -- Terminal configuration for dap
      -- ============================================================
      -- Configure the integrated terminal to open in a split
      dap.defaults.fallback.terminal_win_cmd = "belowright 15new"
      -- Force external terminal when needed
      dap.defaults.fallback.force_external_terminal = false
      -- Focus the main editor (not the terminal) after launch
      dap.defaults.fallback.focus_terminal = false

      -- ============================================================
      -- Per-project debug configuration templates
      -- ============================================================
      -- :DapConfigTemplate creates a starter launch.json for the detected project type
      vim.api.nvim_create_user_command("DapConfigTemplate", function(opts)
        local cwd = vim.fn.getcwd()
        local vscode_dir = cwd .. "/.vscode"
        local launch_json = vscode_dir .. "/launch.json"

        if vim.fn.filereadable(launch_json) == 1 then
          local choice = vim.fn.confirm("launch.json already exists. Overwrite?", "&Yes\n&No", 2)
          if choice ~= 1 then
            vim.print_silent("Aborted.")
            return
          end
        end

        -- Auto-detect project type
        local project_type = opts.args
        if not project_type or #project_type == 0 then
          -- Try to detect from files in cwd
          if vim.fn.glob(cwd .. "/Cargo.toml") ~= "" then
            project_type = "rust"
          elseif vim.fn.glob(cwd .. "/go.mod") ~= "" then
            project_type = "go"
          elseif vim.fn.glob(cwd .. "/CMakeLists.txt") ~= "" or vim.fn.glob(cwd .. "/Makefile") ~= "" then
            project_type = "cpp"
          elseif vim.fn.glob(cwd .. "/*.py") ~= "" or vim.fn.glob(cwd .. "/setup.py") ~= "" or vim.fn.glob(cwd .. "/pyproject.toml") ~= "" then
            project_type = "python"
          elseif vim.fn.glob(cwd .. "/*.sh") ~= "" then
            project_type = "bash"
          else
            project_type = "generic"
          end
        end

        ---@type table<string, string>
        local templates = {
          rust = [[{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "codelldb",
      "request": "launch",
      "name": "Debug (codelldb)",
      "program": "${workspaceFolder}/target/debug/${workspaceFolderBasename}",
      "args": [],
      "cwd": "${workspaceFolder}",
      "sourceLanguages": ["rust"],
      "preLaunchTask": "cargo build"
    }
  ]
}]],
          go = [[{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "go",
      "request": "launch",
      "name": "Debug (dlv)",
      "mode": "debug",
      "program": "${workspaceFolder}",
      "args": []
    },
    {
      "type": "go",
      "request": "launch",
      "name": "Debug Test",
      "mode": "test",
      "program": "${file}",
      "args": []
    }
  ]
}]],
          cpp = [[{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "cppdbg",
      "request": "launch",
      "name": "Debug (cppdbg)",
      "program": "${workspaceFolder}/build/${workspaceFolderBasename}",
      "args": [],
      "cwd": "${workspaceFolder}",
      "MIMode": "gdb",
      "setupCommands": [
        { "text": "-enable-pretty-printing", "ignoreFailures": true }
      ]
    },
    {
      "type": "codelldb",
      "request": "launch",
      "name": "Debug (codelldb)",
      "program": "${workspaceFolder}/build/${workspaceFolderBasename}",
      "args": [],
      "cwd": "${workspaceFolder}"
    }
  ]
}]],
          python = [[{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "debugpy",
      "request": "launch",
      "name": "Debug Current File",
      "program": "${file}",
      "args": [],
      "cwd": "${workspaceFolder}",
      "console": "integratedTerminal"
    },
    {
      "type": "debugpy",
      "request": "launch",
      "name": "Debug Module",
      "module": "${workspaceFolderBasename}",
      "args": [],
      "cwd": "${workspaceFolder}"
    }
  ]
}]],
          bash = [[{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "sh",
      "request": "launch",
      "name": "Debug Script",
      "program": "${file}",
      "cwd": "${workspaceFolder}"
    }
  ]
}]],
          generic = [[{
  "version": "0.2.0",
  "configurations": []
}]],
        }

        local template = templates[project_type] or templates.generic

        if vim.fn.isdirectory(vscode_dir) == 0 then
          vim.fn.mkdir(vscode_dir, "p")
        end

        local file = io.open(launch_json, "w")
        if file then
          file:write(template)
          file:close()
          vim.cmd("edit " .. launch_json)
          vim.print_silent("Created " .. project_type .. " launch.json template.")
        else
          vim.notify("Failed to create launch.json", vim.log.levels.ERROR)
        end
      end, {
        desc = "Create a launch.json template for the detected (or specified) project type",
        nargs = "?",
        complete = function()
          return { "rust", "go", "cpp", "python", "bash", "generic" }
        end,
      })

      -- ============================================================
      -- Sign customization for breakpoints
      -- ============================================================
      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DapBreakpoint", linehl = "", numhl = "" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DapBreakpointCondition", linehl = "", numhl = "" })
      vim.fn.sign_define("DapBreakpointRejected", { text = "○", texthl = "DapBreakpointRejected", linehl = "", numhl = "" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DapStopped", linehl = "debugPc", numhl = "" })
      vim.fn.sign_define("DapLogPoint", { text = "◇", texthl = "DapLogPoint", linehl = "", numhl = "" })

      -- ============================================================
      -- Highlight groups for DAP signs
      -- ============================================================
      vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#FF6B6B" })
      vim.api.nvim_set_hl(0, "DapBreakpointCondition", { fg = "#FFD93D" })
      vim.api.nvim_set_hl(0, "DapBreakpointRejected", { fg = "#6C757D" })
      vim.api.nvim_set_hl(0, "DapStopped", { fg = "#6BCB77" })
      vim.api.nvim_set_hl(0, "DapLogPoint", { fg = "#4ECDC4" })
    end,
  },
  --[[{
    "rcarriga/nvim-dap-ui",
    dependencies = {
      "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio"
    }
  },]]
}

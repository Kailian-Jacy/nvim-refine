return {
  {
    "Kailian-Jacy/persistent-breakpoints.nvim",
    opts = {
      load_breakpoints_event = { "BufReadPost" },
      always_reload = true,
    }
  },
  {
    "igorlfs/nvim-dap-view",
    -- If it's lazy loaded, it will cause failure to mount event on dap
    -- So keymaps won't trigger
    lazy = false,
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
    lazy = false,
    keys = {
      -- { "<leader>d", "", desc = "+debug", mode = {"n", "v"} },
      -- break points.
      {
        "<leader>xb",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "Toggle Breakpoint",
      },
      {
        "<leader>xB",
        function()
          require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
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
      -- To be moved to telescope in the future.
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
          if require("dap-view").is_open() then
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
  -- {
  --   -- "nvim-telescope/telescope-dap.nvim",
  --   "Kailian-Jacy/telescope-dap.nvim",
  --   config = function()
  --     require("telescope").load_extension("dap")
  --   end,
  -- },
}

local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system { "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", lazypath }
  vim.fn.system { "git", "-C", lazypath, "checkout", "tags/stable" }
  local oldcmdheight = vim.opt.cmdheight:get()
  vim.opt.cmdheight = 1
  vim.notify "Please wait while plugins are installed..."
  vim.api.nvim_create_autocmd("User", {
    once = true,
    pattern = "LazyInstall",
    callback = function()
      vim.cmd.bw()
      vim.opt.cmdheight = oldcmdheight
      vim.tbl_map(function(module) pcall(require, module) end, { "nvim-treesitter", "mason" })
      astronvim.notify "Mason is installing packages if configured, check status with :Mason"
    end,
  })
end
vim.opt.rtp:prepend(lazypath)

local function parse_plugins(plugins)
  local new_plugins = {}
  local idx = 1
  for key, plugin in pairs(plugins) do
    if type(key) == "string" and not plugin[1] then plugin[1] = key end
    if plugin.dependencies then plugin.dependencies = parse_plugins(plugin.dependencies) end
    new_plugins[idx] = plugin
    idx = idx + 1
  end
  return new_plugins
end

local function pin_plugins(plugins)
  if not astronvim.updater.snapshot then return plugins end
  for plugin, options in pairs(plugins) do
    local pin = astronvim.updater.snapshot[plugin:match "/([^/]*)$"]
    if pin and pin.commit and not (options.version or options.commit) then
      options.commit = pin.commit
      options.branch = pin.branch
      if plugin.dependencies then plugin.dependencies = pin_plugins(plugin.dependencies) end
    end
  end
  return plugins
end

require("lazy").setup(
  parse_plugins(astronvim.user_plugin_opts(
    "plugins.init",
    pin_plugins {
      ["folke/lazy.nvim"] = { version = "^7" },
      ["b0o/SchemaStore.nvim"] = {},
      ["nvim-lua/plenary.nvim"] = {},
      ["folke/neodev.nvim"] = { version = "^1", config = function() require "configs.neodev" end },
      ["goolord/alpha-nvim"] = { cmd = "Alpha", config = function() require "configs.alpha" end },
      ["mrjones2014/smart-splits.nvim"] = { config = function() require "configs.smart-splits" end },
      ["onsails/lspkind.nvim"] = { enabled = vim.g.icons_enabled, config = function() require "configs.lspkind" end },
      ["rebelot/heirline.nvim"] = { event = "VimEnter", config = function() require "configs.heirline" end },
      ["famiu/bufdelete.nvim"] = { cmd = { "Bdelete", "Bwipeout" } },
      ["s1n7ax/nvim-window-picker"] = { version = "^1", config = function() require "configs.window-picker" end },
      ["windwp/nvim-autopairs"] = { event = "InsertEnter", config = function() require "configs.autopairs" end },
      ["folke/which-key.nvim"] = {
        version = "^1",
        event = "VeryLazy",
        config = function() require "configs.which-key" end,
      },
      ["numToStr/Comment.nvim"] = {
        keys = { { "gc", mode = { "n", "v" } }, { "gb", mode = { "n", "v" } } },
        config = function() require "configs.Comment" end,
      },
      ["akinsho/toggleterm.nvim"] = {
        cmd = { "ToggleTerm", "TermExec" },
        config = function() require "configs.toggleterm" end,
      },
      ["nvim-tree/nvim-web-devicons"] = {
        enabled = vim.g.icons_enabled,
        config = function() require "configs.nvim-web-devicons" end,
      },
      ["Darazaki/indent-o-matic"] = {
        init = function() table.insert(astronvim.file_plugins, "indent-o-matic") end,
        config = function() require "configs.indent-o-matic" end,
      },
      ["rcarriga/nvim-notify"] = {
        version = "^3",
        init = function() astronvim.load_plugin_with_func("nvim-notify", vim, "notify") end,
        config = function() require "configs.notify" end,
      },
      ["stevearc/dressing.nvim"] = {
        init = function() astronvim.load_plugin_with_func("dressing.nvim", vim.ui, { "input", "select" }) end,
        config = function() require "configs.dressing" end,
      },
      ["nvim-neo-tree/neo-tree.nvim"] = {
        version = "^2",
        dependencies = { ["MunifTanjim/nui.nvim"] = {} },
        cmd = "Neotree",
        init = function() vim.g.neo_tree_remove_legacy_commands = true end,
        config = function() require "configs.neo-tree" end,
      },

      ["nvim-treesitter/nvim-treesitter"] = {
        init = function() table.insert(astronvim.file_plugins, "nvim-treesitter") end,
        cmd = {
          "TSBufDisable",
          "TSBufEnable",
          "TSBufToggle",
          "TSDisable",
          "TSEnable",
          "TSToggle",
          "TSInstall",
          "TSInstallInfo",
          "TSInstallSync",
          "TSModuleInfo",
          "TSUninstall",
          "TSUpdate",
          "TSUpdateSync",
        },
        dependencies = {
          ["windwp/nvim-ts-autotag"] = {},
          ["JoosepAlviste/nvim-ts-context-commentstring"] = {},
        },
        build = function() require("nvim-treesitter.install").update { with_sync = true }() end,
        config = function() require "configs.treesitter" end,
      },
      ["NvChad/nvim-colorizer.lua"] = {
        init = function() table.insert(astronvim.file_plugins, "nvim-colorizer.lua") end,
        cmd = { "ColorizerToggle", "ColorizerAttachToBuffer", "ColorizerDetachFromBuffer", "ColorizerReloadAllBuffers" },
        config = function() require "configs.colorizer" end,
      },
      ["max397574/better-escape.nvim"] = {
        event = "InsertCharPre",
        config = function() require "configs.better_escape" end,
      },
      ["Shatur/neovim-session-manager"] = {
        event = "BufWritePost",
        cmd = "SessionManager",
        config = function() require "configs.session_manager" end,
      },
      ["lukas-reineke/indent-blankline.nvim"] = {
        init = function() table.insert(astronvim.file_plugins, "indent-blankline.nvim") end,
        config = function() require "configs.indent-line" end,
      },
      ["lewis6991/gitsigns.nvim"] = {
        enabled = vim.fn.executable "git" == 1,
        ft = "gitcommit",
        init = function() table.insert(astronvim.git_plugins, "gitsigns.nvim") end,
        config = function() require "configs.gitsigns" end,
      },
      ["nvim-telescope/telescope.nvim"] = {
        cmd = "Telescope",
        config = function() require "configs.telescope" end,
        dependencies = {
          ["nvim-telescope/telescope-fzf-native.nvim"] = { enabled = vim.fn.executable "make" == 1, build = "make" },
        },
      },
      ["stevearc/aerial.nvim"] = {
        init = function() table.insert(astronvim.file_plugins, "aerial.nvim") end,
        config = function() require "configs.aerial" end,
      },
      ["L3MON4D3/LuaSnip"] = {
        config = function() require "configs.luasnip" end,
        dependencies = { ["rafamadriz/friendly-snippets"] = {} },
      },
      ["hrsh7th/nvim-cmp"] = {
        commit = "a9c701fa7e12e9257b3162000e5288a75d280c28", -- https://github.com/hrsh7th/nvim-cmp/issues/1382
        event = "InsertEnter",
        config = function() require "configs.cmp" end,
        dependencies = {
          ["saadparwaiz1/cmp_luasnip"] = {},
          ["hrsh7th/cmp-buffer"] = {},
          ["hrsh7th/cmp-path"] = {},
          ["hrsh7th/cmp-nvim-lsp"] = {},
        },
      },
      ["neovim/nvim-lspconfig"] = {
        init = function() table.insert(astronvim.file_plugins, "nvim-lspconfig") end,
        config = function() require "configs.lspconfig" end,
      },
      ["jose-elias-alvarez/null-ls.nvim"] = {
        init = function() table.insert(astronvim.file_plugins, "null-ls.nvim") end,
        config = function() require "configs.null-ls" end,
      },
      ["mfussenegger/nvim-dap"] = {
        enabled = vim.fn.has "win32" == 0,
        init = function() table.insert(astronvim.file_plugins, "nvim-dap") end,
        config = function() require "configs.dap" end,
        dependencies = { ["rcarriga/nvim-dap-ui"] = { config = function() require "configs.dapui" end } },
      },
      ["williamboman/mason.nvim"] = {
        cmd = {
          "Mason",
          "MasonInstall",
          "MasonUninstall",
          "MasonUninstallAll",
          "MasonLog",
          "MasonUpdate", -- astronvim command
          "MasonUpdateAll", -- astronvim command
        },
        init = function() table.insert(astronvim.file_plugins, "mason.nvim") end,
        config = function()
          require "configs.mason"
          for _, module in ipairs { "mason-lspconfig", "mason-null-ls", "mason-nvim-dap" } do
            pcall(require, module)
          end
        end,
      },
      ["williamboman/mason-lspconfig.nvim"] = {
        cmd = { "LspInstall", "LspUninstall" },
        config = function() require "configs.mason-lspconfig" end,
        dependencies = { ["neovim/nvim-lspconfig"] = {} },
      },
      ["jayp0521/mason-null-ls.nvim"] = {
        cmd = { "NullLsInstall", "NullLsUninstall" },
        config = function() require "configs.mason-null-ls" end,
        dependencies = { ["jayp0521/mason-null-ls.nvim"] = {} },
      },
      ["jayp0521/mason-nvim-dap.nvim"] = {
        cmd = { "DapInstall", "DapUninstall" },
        config = function() require "configs.mason-nvim-dap" end,
        dependencies = { ["mfussenegger/nvim-dap"] = {} },
      },
    }
  )),
  astronvim.user_plugin_opts("plugins.lazy", {
    defaults = { lazy = true },
    install = { colorscheme = { astronvim.user_plugin_opts("colorscheme", false, false), "astronvim" } },
    performance = {
      rtp = {
        paths = { astronvim.install.config },
        disabled_plugins = { "tohtml", "gzip", "matchit", "zipPlugin", "netrwPlugin", "tarPlugin", "matchparen" },
      },
    },
    lockfile = vim.fn.stdpath "data" .. "/lazy-lock.json",
  })
)

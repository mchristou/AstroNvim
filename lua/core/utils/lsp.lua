--- ### AstroNvim LSP
--
-- This module is automatically loaded by AstroNvim on during it's initialization into global variable `astronvim.lsp`
--
-- This module can also be manually loaded with `local updater = require("core.utils").lsp`
--
-- @module core.utils.lsp
-- @see core.utils
-- @copyright 2022
-- @license GNU General Public License v3.0

astronvim.lsp = {}
local tbl_contains = vim.tbl_contains
local tbl_isempty = vim.tbl_isempty
local user_opts = astronvim.user_opts
local conditional_func = astronvim.conditional_func
local is_available = astronvim.is_available
local server_config = "lsp.config"
local setup_handlers = user_opts("lsp.setup_handlers", {
  function(server, opts) require("lspconfig")[server].setup(opts) end,
  sumneko_lua = function(server, opts) -- initialize neodev before sumneko_lua if it's available
    pcall(require, "neodev")
    require("lspconfig")[server].setup(opts)
  end,
})

astronvim.lsp.formatting = user_opts("lsp.formatting", { format_on_save = { enabled = true }, disabled = {} })
if type(astronvim.lsp.formatting.format_on_save) == "boolean" then
  astronvim.lsp.formatting.format_on_save = { enabled = astronvim.lsp.formatting.format_on_save }
end

astronvim.lsp.format_opts = vim.deepcopy(astronvim.lsp.formatting)
astronvim.lsp.format_opts.disabled = nil
astronvim.lsp.format_opts.format_on_save = nil
astronvim.lsp.format_opts.filter = function(client)
  local filter = astronvim.lsp.formatting.filter
  local disabled = astronvim.lsp.formatting.disabled or {}
  -- check if client is fully disabled or filtered by function
  return not (vim.tbl_contains(disabled, client.name) or (type(filter) == "function" and not filter(client)))
end

--- Helper function to set up a given server with the Neovim LSP client
-- @param server the name of the server to be setup
astronvim.lsp.setup = function(server)
  -- if server doesn't exist, set it up from user server definition
  if not pcall(require, "lspconfig.server_configurations." .. server) then
    local server_definition = user_opts(server_config .. server)
    if server_definition.cmd then require("lspconfig.configs")[server] = { default_config = server_definition } end
  end
  local opts = astronvim.lsp.server_settings(server)
  local setup_handler = setup_handlers[server] or setup_handlers[1]
  if setup_handler then setup_handler(server, opts) end
end

--- The `on_attach` function used by AstroNvim
-- @param client the LSP client details when attaching
-- @param bufnr the number of the buffer that the LSP client is attaching to
astronvim.lsp.on_attach = function(client, bufnr)
  local capabilities = client.server_capabilities
  local lsp_mappings = {
    n = {
      ["<leader>ld"] = { function() vim.diagnostic.open_float() end, desc = "Hover diagnostics" },
      ["[d"] = { function() vim.diagnostic.goto_prev() end, desc = "Previous diagnostic" },
      ["]d"] = { function() vim.diagnostic.goto_next() end, desc = "Next diagnostic" },
      ["gl"] = { function() vim.diagnostic.open_float() end, desc = "Hover diagnostics" },
    },
    v = {},
  }

  if is_available "mason-lspconfig.nvim" then
    lsp_mappings.n["<leader>li"] = { "<cmd>LspInfo<cr>", desc = "LSP information" }
  end

  if is_available "null-ls.nvim" then
    lsp_mappings.n["<leader>lI"] = { "<cmd>NullLsInfo<cr>", desc = "Null-ls information" }
  end

  if capabilities.codeActionProvider then
    lsp_mappings.n["<leader>la"] = { function() vim.lsp.buf.code_action() end, desc = "LSP code action" }
    lsp_mappings.v["<leader>la"] = lsp_mappings.n["<leader>la"]
  end

  if capabilities.codeLensProvider then
    lsp_mappings.n["<leader>ll"] = { function() vim.lsp.codelens.refresh() end, desc = "LSP codelens refresh" }
    lsp_mappings.n["<leader>lL"] = { function() vim.lsp.codelens.run() end, desc = "LSP codelens run" }
  end

  if capabilities.declarationProvider then
    lsp_mappings.n["gD"] = { function() vim.lsp.buf.declaration() end, desc = "Declaration of current symbol" }
  end

  if capabilities.definitionProvider then
    lsp_mappings.n["gd"] = { function() vim.lsp.buf.definition() end, desc = "Show the definition of current symbol" }
  end

  if capabilities.documentFormattingProvider and not tbl_contains(astronvim.lsp.formatting.disabled, client.name) then
    lsp_mappings.n["<leader>lf"] = {
      function() vim.lsp.buf.format(astronvim.lsp.format_opts) end,
      desc = "Format buffer",
    }
    lsp_mappings.v["<leader>lf"] = lsp_mappings.n["<leader>lf"]

    vim.api.nvim_buf_create_user_command(
      bufnr,
      "Format",
      function() vim.lsp.buf.format(astronvim.lsp.format_opts) end,
      { desc = "Format file with LSP" }
    )
    local autoformat = astronvim.lsp.formatting.format_on_save
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
    if
      autoformat.enabled
      and (tbl_isempty(autoformat.allow_filetypes or {}) or tbl_contains(autoformat.allow_filetypes, filetype))
      and (tbl_isempty(autoformat.ignore_filetypes or {}) or not tbl_contains(autoformat.ignore_filetypes, filetype))
    then
      local autocmd_group = "auto_format_" .. bufnr
      vim.api.nvim_create_augroup(autocmd_group, { clear = true })
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = autocmd_group,
        buffer = bufnr,
        desc = "Auto format buffer " .. bufnr .. " before save",
        callback = function()
          if vim.g.autoformat_enabled then
            vim.lsp.buf.format(astronvim.extend_tbl(astronvim.lsp.format_opts, { bufnr = bufnr }))
          end
        end,
      })
      lsp_mappings.n["<leader>uf"] = {
        function() astronvim.ui.toggle_autoformat() end,
        desc = "Toggle autoformatting",
      }
    end
  end

  if capabilities.documentHighlightProvider then
    local highlight_name = vim.fn.printf("lsp_document_highlight_%d", bufnr)
    vim.api.nvim_create_augroup(highlight_name, {})
    vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
      group = highlight_name,
      buffer = bufnr,
      callback = function() vim.lsp.buf.document_highlight() end,
    })
    vim.api.nvim_create_autocmd("CursorMoved", {
      group = highlight_name,
      buffer = bufnr,
      callback = function() vim.lsp.buf.clear_references() end,
    })
  end

  if capabilities.hoverProvider then
    lsp_mappings.n["K"] = { function() vim.lsp.buf.hover() end, desc = "Hover symbol details" }
  end

  if capabilities.implementationProvider then
    lsp_mappings.n["gI"] = { function() vim.lsp.buf.implementation() end, desc = "Implementation of current symbol" }
  end

  if capabilities.referencesProvider then
    lsp_mappings.n["gr"] = { function() vim.lsp.buf.references() end, desc = "References of current symbol" }
    lsp_mappings.n["<leader>lR"] = { function() vim.lsp.buf.references() end, desc = "Search references" }
  end

  if capabilities.renameProvider then
    lsp_mappings.n["<leader>lr"] = { function() vim.lsp.buf.rename() end, desc = "Rename current symbol" }
  end

  if capabilities.signatureHelpProvider then
    lsp_mappings.n["<leader>lh"] = { function() vim.lsp.buf.signature_help() end, desc = "Signature help" }
  end

  if capabilities.typeDefinitionProvider then
    lsp_mappings.n["gT"] = { function() vim.lsp.buf.type_definition() end, desc = "Definition of current type" }
  end

  if capabilities.workspaceSymbolProvider then
    lsp_mappings.n["<leader>lG"] = { function() vim.lsp.buf.workspace_symbol() end, desc = "Search workspace symbols" }
  end

  if is_available "telescope.nvim" then -- setup telescope mappings if available
    if lsp_mappings.n.gd then lsp_mappings.n.gd[1] = function() require("telescope.builtin").lsp_definitions() end end
    if lsp_mappings.n.gI then
      lsp_mappings.n.gI[1] = function() require("telescope.builtin").lsp_implementations() end
    end
    if lsp_mappings.n.gr then lsp_mappings.n.gr[1] = function() require("telescope.builtin").lsp_references() end end
    if lsp_mappings.n["<leader>lR"] then
      lsp_mappings.n["<leader>lR"][1] = function() require("telescope.builtin").lsp_references() end
    end
    if lsp_mappings.n.gT then
      lsp_mappings.n.gT[1] = function() require("telescope.builtin").lsp_type_definitions() end
    end
    if lsp_mappings.n["<leader>lG"] then
      lsp_mappings.n["<leader>lG"][1] = function() require("telescope.builtin").lsp_workspace_symbols() end
    end
  end

  if not vim.tbl_isempty(lsp_mappings.v) then lsp_mappings.v["<leader>l"] = { name = "LSP" } end
  astronvim.set_mappings(user_opts("lsp.mappings", lsp_mappings), { buffer = bufnr })

  local on_attach_override = user_opts("lsp.on_attach", nil, false)
  conditional_func(on_attach_override, true, client, bufnr)
end

--- The default AstroNvim LSP capabilities
astronvim.lsp.capabilities = vim.lsp.protocol.make_client_capabilities()
astronvim.lsp.capabilities.textDocument.completion.completionItem.documentationFormat = { "markdown", "plaintext" }
astronvim.lsp.capabilities.textDocument.completion.completionItem.snippetSupport = true
astronvim.lsp.capabilities.textDocument.completion.completionItem.preselectSupport = true
astronvim.lsp.capabilities.textDocument.completion.completionItem.insertReplaceSupport = true
astronvim.lsp.capabilities.textDocument.completion.completionItem.labelDetailsSupport = true
astronvim.lsp.capabilities.textDocument.completion.completionItem.deprecatedSupport = true
astronvim.lsp.capabilities.textDocument.completion.completionItem.commitCharactersSupport = true
astronvim.lsp.capabilities.textDocument.completion.completionItem.tagSupport = { valueSet = { 1 } }
astronvim.lsp.capabilities.textDocument.completion.completionItem.resolveSupport = {
  properties = { "documentation", "detail", "additionalTextEdits" },
}
astronvim.lsp.capabilities = user_opts("lsp.capabilities", astronvim.lsp.capabilities)
astronvim.lsp.flags = user_opts "lsp.flags"

--- Get the server settings for a given language server to be provided to the server's `setup()` call
-- @param  server_name the name of the server
-- @return the table of LSP options used when setting up the given language server
function astronvim.lsp.server_settings(server_name)
  local server = require("lspconfig")[server_name]
  local lsp_opts = astronvim.extend_tbl(
    { capabilities = server.capabilities, flags = server.flags },
    { capabilities = astronvim.lsp.capabilities, flags = astronvim.lsp.flags }
  )
  if server_name == "jsonls" then -- by default add json schemas
    local schemastore_avail, schemastore = pcall(require, "schemastore")
    if schemastore_avail then
      lsp_opts.settings = { json = { schemas = schemastore.json.schemas(), validate = { enable = true } } }
    end
  end
  if server_name == "sumneko_lua" then -- by default initialize neodev and disable third party checking
    lsp_opts.settings = { Lua = { workspace = { checkThirdParty = false } } }
  end
  local opts = user_opts(server_config .. server_name, lsp_opts)
  local old_on_attach = server.on_attach
  local user_on_attach = opts.on_attach
  opts.on_attach = function(client, bufnr)
    conditional_func(old_on_attach, true, client, bufnr)
    astronvim.lsp.on_attach(client, bufnr)
    conditional_func(user_on_attach, true, client, bufnr)
  end
  return opts
end

return astronvim.lsp

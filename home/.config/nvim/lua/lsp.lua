-- https://github.com/neovim/nvim-lspconfig
-- https://github.com/neovim/nvim-lspconfig/blob/master/CONFIG.md
vim.cmd [[autocmd CursorHold,CursorHoldI * lua require'nvim-lightbulb'.update_lightbulb()]]
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("cmp_nvim_lsp").update_capabilities(capabilities)
capabilities.textDocument.completion.completionItem.snippetSupport = true
capabilities.textDocument.completion.completionItem.resolveSupport = {
    properties = {
        "documentation",
        "detail",
        "additionalTextEdits"
    }
}

local nvim_lsp = require("lspconfig")
local pid = vim.fn.getpid()
local lsp_plugins = {
    sumneko_lua = {
        settings = {
            Lua = {
                diagnostics = {
                    globals = { 'vim', 'table', 'math', 'string', 'io', 'os', 'debug' }
                }
            }
        }
    },
    ansiblels = {},
    pyright = {},
    bashls = {},
    dockerls = {},
    graphql = {},
    gopls = {},
    phpactor = {
        cmd = { "phpactor", "language-server" },
        filetypes = { "php" },
        root_dir = nvim_lsp.util.root_pattern("composer.json", ".git"),
        init_options = {
            -- ["language_server_phpstan.enabled"] = true,
            -- ["language_server_psalm.enabled"] = true,
        }
    },
    intelephense = {
        cmd = { "intelephense", "--stdio" },
        filetypes = { "php" },
        root_dir = nvim_lsp.util.root_pattern("composer.json", ".git"),
        settings = {
            intelephense = {
                stubs = {
                    "amqp",
                    "apache",
                    "apcu",
                    "bcmath",
                    "blackfire",
                    "bz2",
                    "calendar",
                    "cassandra",
                    "com_dotnet",
                    "Core",
                    "couchbase",
                    "crypto",
                    "ctype",
                    "cubrid",
                    "curl",
                    "date",
                    "dba",
                    "decimal",
                    "dom",
                    "ds",
                    "enchant",
                    "Ev",
                    "event",
                    "exif",
                    "fann",
                    "FFI",
                    "ffmpeg",
                    "fileinfo",
                    "filter",
                    "fpm",
                    "ftp",
                    "gd",
                    "gearman",
                    "geoip",
                    "geos",
                    "gettext",
                    "gmagick",
                    "gmp",
                    "gnupg",
                    "grpc",
                    "hash",
                    "http",
                    "ibm_db2",
                    "iconv",
                    "igbinary",
                    "imagick",
                    "imap",
                    "inotify",
                    "interbase",
                    "intl",
                    "json",
                    "judy",
                    "ldap",
                    "leveldb",
                    "libevent",
                    "libsodium",
                    "libxml",
                    "lua",
                    "lzf",
                    "mailparse",
                    "mapscript",
                    "mbstring",
                    "mcrypt",
                    "memcache",
                    "memcached",
                    "meminfo",
                    "meta",
                    "ming",
                    "mongo",
                    "mongodb",
                    "mosquitto-php",
                    "mqseries",
                    "msgpack",
                    "mssql",
                    "mysql",
                    "mysql_xdevapi",
                    "mysqli",
                    "ncurses",
                    "newrelic",
                    "oauth",
                    "oci8",
                    "odbc",
                    "openssl",
                    "parallel",
                    "Parle",
                    "pcntl",
                    "pcov",
                    "pcre",
                    "pdflib",
                    "PDO",
                    "pdo_ibm",
                    "pdo_mysql",
                    "pdo_pgsql",
                    "pdo_sqlite",
                    "pgsql",
                    "Phar",
                    "phpdbg",
                    "posix",
                    "pspell",
                    "pthreads",
                    "radius",
                    "rar",
                    "rdkafka",
                    "readline",
                    "recode",
                    "redis",
                    "Reflection",
                    "regex",
                    "rpminfo",
                    "rrd",
                    "SaxonC",
                    "session",
                    "shmop",
                    "SimpleXML",
                    "snmp",
                    "soap",
                    "sockets",
                    "sodium",
                    "solr",
                    "SPL",
                    "SplType",
                    "SQLite",
                    "sqlite3",
                    "sqlsrv",
                    "ssh2",
                    "standard",
                    "stats",
                    "stomp",
                    "suhosin",
                    "superglobals",
                    "svn",
                    "sybase",
                    "sync",
                    "sysvmsg",
                    "sysvsem",
                    "sysvshm",
                    "tidy",
                    "tokenizer",
                    "uopz",
                    "uv",
                    "v8js",
                    "wddx",
                    "win32service",
                    "winbinder",
                    "wincache",
                    "wordpress",
                    "xcache",
                    "xdebug",
                    "xhprof",
                    "xml",
                    "xmlreader",
                    "xmlrpc",
                    "xmlwriter",
                    "xsl",
                    "xxtea",
                    "yaf",
                    "yaml",
                    "yar",
                    "zend",
                    "Zend OPcache",
                    "ZendCache",
                    "ZendDebugger",
                    "ZendUtils",
                    "zip",
                    "zlib",
                    "zmq",
                    "zookeeper"
                },
                files = {
                    maxSize = 5000000
                }
            }
        }
    },
    tsserver = {},
    vimls = {},
    vuels = {},
    yamlls = {},
    omnisharp = {
        cmd = { "omnisharp", "--languageserver", "--hostPID", tostring(pid) }
    },
    jsonls = {},
    cssls = {},
    html = {},
    elixirls = {
        filetypes = { "elixir", "eelixir", "ex", "exs" },
        cmd = { "elixir-ls" }
    },
    -- hls = {},
    terraformls = {},
    ccls = {},
    sqlls = {},
    asm_lsp = {},
    clangd = {},
    csharp_ls = {},
    cmake = {},
    codeqlls = {},
    cucumber_language_server = {},
    diagnosticls = {},
}

local on_attach = function(client, bufnr)
    -- print('onattch called!', client, bufnr)
    require "lsp_signature".on_attach()

    local function buf_set_keymap(...)
        vim.api.nvim_buf_set_keymap(bufnr, ...)
    end

    local function buf_set_option(...)
        vim.api.nvim_buf_set_option(bufnr, ...)
    end

    buf_set_option("omnifunc", "v:lua.vim.lsp.omnifunc")

    -- Mappings.
    local opts = { noremap = true, silent = true }
    -- https://oroques.dev/notes/neovim-init/
    buf_set_keymap("n", "gD", "<Cmd>lua vim.lsp.buf.declaration()<CR>", opts)
    buf_set_keymap("n", "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", opts)
    buf_set_keymap("n", "K", "<Cmd>lua vim.lsp.buf.hover()<CR>", opts)
    buf_set_keymap("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
    buf_set_keymap("n", "<C-k>", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)
    buf_set_keymap("n", "<leader>wa", "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>", opts)
    buf_set_keymap("n", "<leader>wr", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>", opts)
    buf_set_keymap("n", "<leader>wl", "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>", opts)
    buf_set_keymap("n", "<leader>D", "<cmd>lua vim.lsp.buf.type_definition()<CR>", opts)
    buf_set_keymap("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)

    buf_set_keymap("n", "rn", "<cmd>Lspsaga rename<cr>", { silent = true, noremap = true })
    buf_set_keymap("n", "ga", "<cmd>Lspsaga code_action<cr>", { silent = true, noremap = true })
    buf_set_keymap("x", "ga", ":<c-u>Lspsaga range_code_action<cr>", { silent = true, noremap = true })
    buf_set_keymap("n", "K", "<cmd>Lspsaga hover_doc<cr>", { silent = true, noremap = true })
    buf_set_keymap("n", "<leader>el", "<cmd>Lspsaga show_line_diagnostics<cr>", { silent = true, noremap = true })
    buf_set_keymap("n", "]d", "<cmd>Lspsaga diagnostic_jump_next<cr>", { silent = true, noremap = true })
    buf_set_keymap("n", "[d", "<cmd>Lspsaga diagnostic_jump_prev<cr>", { silent = true, noremap = true })
    buf_set_keymap("n", "<C-u>", "<cmd>lua require('lspsaga.action').smart_scroll_with_saga(-1, '<c-u>')<cr>", {})
    buf_set_keymap("n", "<C-d>", "<cmd>lua require('lspsaga.action').smart_scroll_with_saga(1, '<c-d>')<cr>", {})

    -- buf_set_keymap("n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
    -- buf_set_keymap("n", "ga", "<cmd>lua vim.lsp.buf.code_action()<CR>", opts)
    -- buf_set_keymap("n", "<leader>e", "<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>", opts)
    -- buf_set_keymap("n", "[d", "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>", opts)
    -- buf_set_keymap("n", "]d", "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", opts)
    -- buf_set_keymap("n", "<leader>q", "<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>", opts)
    -- buf_set_keymap("n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)

    -- Set some keybinds conditional on server capabilities
    if client.supports_method('document_formatting') then
        buf_set_keymap("n", "gF", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)
    end
    if client.supports_method('document_range_formatting') then
        buf_set_keymap("v", "gF", "<cmd>lua vim.lsp.buf.range_formatting()<CR>", opts)
    end

    -- Set autocommands conditional on server_capabilities
    if client.supports_method('document_highlight') then
        vim.api.nvim_exec(
            [[
                hi LspReferenceRead cterm=underline,bold ctermbg=red guibg=LightYellow
                hi LspReferenceText cterm=underline,bold ctermbg=red guibg=LightYellow
                hi LspReferenceWrite cterm=underline,bold ctermbg=red guibg=LightYellow
                augroup lsp_document_highlight
                autocmd! * <buffer>
                autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()
                autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
                augroup END
            ]],
            false
        )
    end
end

local function get_options(plugin)
    local options = { capabilities = capabilities, autostart = true, on_attach = on_attach }
    if lsp_plugins[plugin] ~= nil then
        for option_key, option_value in pairs(lsp_plugins[plugin]) do
            options[option_key] = option_value
        end
    else
        print('Plugin configuration couldnt be loaded: ', plugin)
    end

    return options
end

local servers = {}
for k, _ in pairs(lsp_plugins) do
    table.insert(servers, k)
end

local lsp_installer = require('nvim-lsp-installer')
lsp_installer.setup({
    ensure_installed = servers,
    automatic_installation = true,
    ui = {
        icons = {
            server_installed = "✓",
            server_pending = "➜",
            server_uninstalled = "✗"
        }
    }
})

-- print('Servers:')
-- print(vim.inspect(servers))

require("lspkind").init({})

for plugin, _ in pairs(lsp_plugins) do
    nvim_lsp[plugin].setup(get_options(plugin))
end

-- lsp_installer.on_server_ready(function(server)
--     server:setup(get_options(server.name))
-- end)

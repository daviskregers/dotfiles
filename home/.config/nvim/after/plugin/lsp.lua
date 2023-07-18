local ok, lsp = pcall(require, 'lsp-zero')

if not ok then
	print "Failed loading plugin 'lsp-zero', skipping setup..."
	return
end

lsp.preset("recommended")
lsp.ensure_installed({
  'tsserver',
  'eslint',
  'rust_analyzer',
  'phpactor',
  'intelephense',
})

local cmp = require('cmp')
local cmp_select = {behavior = cmp.SelectBehavior.Select}
local cmp_mappings = lsp.defaults.cmp_mappings({
  ['<C-p>'] = cmp.mapping.select_prev_item(cmp_select),
  ['<C-n>'] = cmp.mapping.select_next_item(cmp_select),
  ['<C-y>'] = cmp.mapping.confirm({ select = true }),
  ["<C-Space>"] = cmp.mapping.complete(),
})

-- disable completion with tab
-- this helps with copilot setup
cmp_mappings['<Tab>'] = nil
cmp_mappings['<S-Tab>'] = nil

lsp.setup_nvim_cmp({
  mapping = cmp_mappings
})

lsp.set_preferences({
    suggest_lsp_servers = true,
    sign_icons = {
	error = 'E',
	warn = 'W',
	hint = 'H',
	info = 'I'
    }
})

lsp.on_attach(function(client, bufnr)
  local opts = {buffer = bufnr, remap = false}

  vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
  vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
  vim.keymap.set("n", "<leader>vws", vim.lsp.buf.workspace_symbol, opts)
  vim.keymap.set("n", "<leader>vd", vim.diagnostic.open_float, opts)
  vim.keymap.set("n", "[d", vim.diagnostic.goto_next, opts)
  vim.keymap.set("n", "]d", vim.diagnostic.goto_prev, opts)
  vim.keymap.set("n", "<leader>vca", vim.lsp.buf.code_action, opts)
  vim.keymap.set("n", "<leader>vrr", vim.lsp.buf.references, opts)
  vim.keymap.set("n", "<leader>vrn", vim.lsp.buf.rename, opts)
  vim.keymap.set("i", "<C-h>", vim.lsp.buf.signature_help, opts)
end)

vim.diagnostic.config({
    virtual_text = true,
})

local lspconfig = require('lspconfig')

lsp.configure('jsonls', {
  settings = {
    json = {
      schemas = require('schemastore').json.schemas(),
      validate = { enable = true },
    },
  },
})

lsp.configure('phpactor', {
    cmd = { "phpactor", "language-server" },
    filetypes = { "php" },
    root_dir = lspconfig.util.root_pattern("composer.json", ".git"),
})

lsp.configure('intelephense', {
    cmd = { "intelephense", "--stdio" },
    filetypes = { "php" },
    root_dir = lspconfig.util.root_pattern("composer.json", ".git"),
    settings = {
        intelephense = {
            stubs = {
                "amqp", "apache", "apcu", "bcmath", "blackfire", "bz2", "calendar", "cassandra", "com_dotnet",
                "Core", "couchbase", "crypto", "ctype", "cubrid", "curl", "date", "dba", "decimal", "dom", "ds",
                "enchant", "Ev", "event", "exif", "fann", "FFI", "ffmpeg", "fileinfo", "filter", "fpm", "ftp",
                "gd", "gearman", "geoip", "geos", "gettext", "gmagick", "gmp", "gnupg", "grpc", "hash", "http",
                "ibm_db2", "iconv", "igbinary", "imagick", "imap", "inotify", "interbase", "intl", "json", "judy",
                "ldap", "leveldb", "libevent", "libsodium", "libxml", "lua", "lzf", "mailparse", "mapscript",
                "mbstring", "mcrypt", "memcache", "memcached", "meminfo", "meta", "ming", "mongo", "mongodb",
                "mosquitto-php", "mqseries", "msgpack", "mssql", "mysql", "mysql_xdevapi", "mysqli", "ncurses",
                "newrelic", "oauth", "oci8", "odbc", "openssl", "parallel", "Parle", "pcntl", "pcov", "pcre",
                "pdflib", "PDO", "pdo_ibm", "pdo_mysql", "pdo_pgsql", "pdo_sqlite", "pgsql", "Phar", "phpdbg",
                "posix", "pspell", "pthreads", "radius", "rar", "rdkafka", "readline", "recode", "redis",
                "Reflection", "regex", "rpminfo", "rrd", "SaxonC", "session", "shmop", "SimpleXML", "snmp",
                "soap", "sockets", "sodium", "solr", "SPL", "SplType", "SQLite", "sqlite3", "sqlsrv", "ssh2",
                "standard", "stats", "stomp", "suhosin", "superglobals", "svn", "sybase", "sync", "sysvmsg",
                "sysvsem", "sysvshm", "tidy", "tokenizer", "uopz", "uv", "v8js", "wddx", "win32service",
                "winbinder", "wincache", "wordpress", "xcache", "xdebug", "xhprof", "xml", "xmlreader",
                "xmlrpc", "xmlwriter", "xsl", "xxtea", "yaf", "yaml", "yar", "zend", "Zend OPcache", "ZendCache",
                "ZendDebugger", "ZendUtils", "zip", "zlib", "zmq", "zookeeper"
        },
            files = {
                maxSize = 5000000
            }
        }
    }
})

lsp.setup()

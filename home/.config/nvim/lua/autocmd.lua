require('autocmd-lua').augroup {
  -- the keys `group` and `autocmds` are also optional
  'filetype_commands',
  {{
    'FileType', {
      yaml = 'set tabstop=2 shiftwidth=2',
      yml = 'set tabstop=2 shiftwidth=2',
      tf = 'set tabstop=2 shiftwidth=2',
      tf = 'set tabstop=4 shiftwidth=4',
    }
  }}
}

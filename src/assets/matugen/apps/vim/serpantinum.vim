set background={{mode}}
highlight clear
if exists("syntax_on")
  syntax reset
endif
if has("termguicolors")
  set termguicolors
endif
let g:colors_name = "serpantinum"

highlight Normal guifg={{colors.on_surface.default.hex}} guibg={{colors.surface.default.hex}} gui=NONE cterm=NONE
highlight NormalFloat guifg={{colors.on_surface.default.hex}} guibg={{colors.surface_container_high.default.hex}} gui=NONE cterm=NONE
highlight ColorColumn guibg={{colors.surface_container_low.default.hex}} gui=NONE cterm=NONE
highlight Cursor guifg={{colors.on_primary.default.hex}} guibg={{colors.primary.default.hex}} gui=NONE cterm=NONE
highlight CursorLine guibg={{colors.surface_container_low.default.hex}} gui=NONE cterm=NONE
highlight CursorColumn guibg={{colors.surface_container_low.default.hex}} gui=NONE cterm=NONE
highlight CursorLineNr guifg={{colors.primary.default.hex}} gui=bold cterm=bold
highlight LineNr guifg={{colors.outline.default.hex}} gui=NONE cterm=NONE
highlight SignColumn guibg={{colors.surface.default.hex}} gui=NONE cterm=NONE
highlight FoldColumn guifg={{colors.outline.default.hex}} guibg={{colors.surface.default.hex}} gui=NONE cterm=NONE
highlight Folded guifg={{colors.on_surface_variant.default.hex}} guibg={{colors.surface_container.default.hex}} gui=NONE cterm=NONE
highlight VertSplit guifg={{colors.outline_variant.default.hex}} guibg={{colors.surface.default.hex}} gui=NONE cterm=NONE
highlight StatusLine guifg={{colors.on_surface.default.hex}} guibg={{colors.surface_container_high.default.hex}} gui=NONE cterm=NONE
highlight StatusLineNC guifg={{colors.on_surface_variant.default.hex}} guibg={{colors.surface_container_low.default.hex}} gui=NONE cterm=NONE
highlight StatusLineTerm guifg={{colors.on_surface.default.hex}} guibg={{colors.surface_container_high.default.hex}} gui=NONE cterm=NONE
highlight StatusLineTermNC guifg={{colors.on_surface_variant.default.hex}} guibg={{colors.surface_container_low.default.hex}} gui=NONE cterm=NONE
highlight TabLine guifg={{colors.on_surface_variant.default.hex}} guibg={{colors.surface_container_low.default.hex}} gui=NONE cterm=NONE
highlight TabLineFill guibg={{colors.surface_container_low.default.hex}} gui=NONE cterm=NONE
highlight TabLineSel guifg={{colors.on_primary.default.hex}} guibg={{colors.primary.default.hex}} gui=bold cterm=bold
highlight Pmenu guifg={{colors.on_surface.default.hex}} guibg={{colors.surface_container_high.default.hex}} gui=NONE cterm=NONE
highlight PmenuSel guifg={{colors.on_primary.default.hex}} guibg={{colors.primary.default.hex}} gui=NONE cterm=NONE
highlight PmenuSbar guibg={{colors.surface_container_highest.default.hex}} gui=NONE cterm=NONE
highlight PmenuThumb guibg={{colors.outline.default.hex}} gui=NONE cterm=NONE
highlight WildMenu guifg={{colors.on_primary.default.hex}} guibg={{colors.primary.default.hex}} gui=NONE cterm=NONE
highlight Visual guibg={{colors.secondary_container.default.hex}} gui=NONE cterm=NONE
highlight Search guifg={{colors.on_secondary_container.default.hex}} guibg={{colors.secondary_container.default.hex}} gui=NONE cterm=NONE
highlight IncSearch guifg={{colors.on_primary.default.hex}} guibg={{colors.primary.default.hex}} gui=NONE cterm=NONE
highlight CurSearch guifg={{colors.on_primary.default.hex}} guibg={{colors.primary.default.hex}} gui=NONE cterm=NONE
highlight MatchParen guifg={{colors.primary.default.hex}} guibg=NONE gui=bold,underline cterm=bold,underline
highlight NonText guifg={{colors.outline_variant.default.hex}} gui=NONE cterm=NONE
highlight SpecialKey guifg={{colors.outline_variant.default.hex}} gui=NONE cterm=NONE
highlight EndOfBuffer guifg={{colors.surface.default.hex}} gui=NONE cterm=NONE
highlight Directory guifg={{colors.primary.default.hex}} gui=NONE cterm=NONE
highlight Title guifg={{colors.primary.default.hex}} gui=bold cterm=bold
highlight ErrorMsg guifg={{colors.error.default.hex}} guibg=NONE gui=NONE cterm=NONE
highlight WarningMsg guifg={{colors.tertiary.default.hex}} gui=NONE cterm=NONE
highlight MoreMsg guifg={{colors.secondary.default.hex}} gui=NONE cterm=NONE
highlight ModeMsg guifg={{colors.on_surface.default.hex}} gui=bold cterm=bold
highlight Question guifg={{colors.secondary.default.hex}} gui=NONE cterm=NONE
highlight QuickFixLine guibg={{colors.surface_container.default.hex}} gui=NONE cterm=NONE
highlight DiffAdd guibg={{colors.secondary_container.default.hex}} gui=NONE cterm=NONE
highlight DiffChange guibg={{colors.surface_container.default.hex}} gui=NONE cterm=NONE
highlight DiffDelete guifg={{colors.on_error_container.default.hex}} guibg={{colors.error_container.default.hex}} gui=NONE cterm=NONE
highlight DiffText guifg={{colors.on_primary_container.default.hex}} guibg={{colors.primary_container.default.hex}} gui=NONE cterm=NONE
highlight SpellBad guisp={{colors.error.default.hex}} gui=undercurl cterm=underline
highlight SpellCap guisp={{colors.tertiary.default.hex}} gui=undercurl cterm=underline
highlight SpellRare guisp={{colors.secondary.default.hex}} gui=undercurl cterm=underline
highlight SpellLocal guisp={{colors.secondary.default.hex}} gui=undercurl cterm=underline

highlight Comment guifg={{colors.outline.default.hex}} gui=italic cterm=italic
highlight Constant guifg={{colors.primary_fixed_dim.default.hex}} gui=NONE cterm=NONE
highlight String guifg={{colors.tertiary.default.hex}} gui=NONE cterm=NONE
highlight Character guifg={{colors.tertiary.default.hex}} gui=NONE cterm=NONE
highlight Number guifg={{colors.tertiary_fixed_dim.default.hex}} gui=NONE cterm=NONE
highlight Boolean guifg={{colors.tertiary_fixed_dim.default.hex}} gui=NONE cterm=NONE
highlight Float guifg={{colors.tertiary_fixed_dim.default.hex}} gui=NONE cterm=NONE
highlight Identifier guifg={{colors.on_surface.default.hex}} gui=NONE cterm=NONE
highlight Function guifg={{colors.secondary.default.hex}} gui=NONE cterm=NONE
highlight Statement guifg={{colors.primary.default.hex}} gui=NONE cterm=NONE
highlight Conditional guifg={{colors.primary.default.hex}} gui=NONE cterm=NONE
highlight Repeat guifg={{colors.primary.default.hex}} gui=NONE cterm=NONE
highlight Label guifg={{colors.tertiary.default.hex}} gui=NONE cterm=NONE
highlight Operator guifg={{colors.on_surface_variant.default.hex}} gui=NONE cterm=NONE
highlight Keyword guifg={{colors.primary.default.hex}} gui=NONE cterm=NONE
highlight Exception guifg={{colors.error.default.hex}} gui=NONE cterm=NONE
highlight PreProc guifg={{colors.tertiary.default.hex}} gui=NONE cterm=NONE
highlight Include guifg={{colors.primary.default.hex}} gui=NONE cterm=NONE
highlight Define guifg={{colors.primary.default.hex}} gui=NONE cterm=NONE
highlight Macro guifg={{colors.tertiary.default.hex}} gui=NONE cterm=NONE
highlight Type guifg={{colors.secondary_fixed_dim.default.hex}} gui=NONE cterm=NONE
highlight StorageClass guifg={{colors.primary.default.hex}} gui=NONE cterm=NONE
highlight Structure guifg={{colors.secondary_fixed_dim.default.hex}} gui=NONE cterm=NONE
highlight Typedef guifg={{colors.secondary_fixed_dim.default.hex}} gui=NONE cterm=NONE
highlight Special guifg={{colors.tertiary.default.hex}} gui=NONE cterm=NONE
highlight SpecialChar guifg={{colors.secondary_fixed_dim.default.hex}} gui=NONE cterm=NONE
highlight Delimiter guifg={{colors.outline.default.hex}} gui=NONE cterm=NONE
highlight Underlined gui=underline cterm=underline
highlight Error guifg={{colors.error.default.hex}} guibg=NONE gui=NONE cterm=NONE
highlight Todo guifg={{colors.on_primary.default.hex}} guibg={{colors.primary.default.hex}} gui=bold cterm=bold

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end
vim.o.termguicolors = true
vim.g.colors_name = "serpantinum"

local c = {
  bg = "{{colors.surface.default.hex}}",
  bg_low = "{{colors.surface_container_low.default.hex}}",
  bg_mid = "{{colors.surface_container.default.hex}}",
  bg_high = "{{colors.surface_container_high.default.hex}}",
  bg_highest = "{{colors.surface_container_highest.default.hex}}",
  fg = "{{colors.on_surface.default.hex}}",
  fg_variant = "{{colors.on_surface_variant.default.hex}}",
  outline = "{{colors.outline.default.hex}}",
  outline_variant = "{{colors.outline_variant.default.hex}}",
  primary = "{{colors.primary.default.hex}}",
  on_primary = "{{colors.on_primary.default.hex}}",
  primary_container = "{{colors.primary_container.default.hex}}",
  on_primary_container = "{{colors.on_primary_container.default.hex}}",
  primary_fixed = "{{colors.primary_fixed_dim.default.hex}}",
  secondary = "{{colors.secondary.default.hex}}",
  secondary_container = "{{colors.secondary_container.default.hex}}",
  on_secondary_container = "{{colors.on_secondary_container.default.hex}}",
  secondary_fixed = "{{colors.secondary_fixed_dim.default.hex}}",
  tertiary = "{{colors.tertiary.default.hex}}",
  tertiary_fixed = "{{colors.tertiary_fixed_dim.default.hex}}",
  error = "{{colors.error.default.hex}}",
  error_container = "{{colors.error_container.default.hex}}",
  on_error_container = "{{colors.on_error_container.default.hex}}",
}

local hl = function(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

hl("Normal", { fg = c.fg, bg = c.bg })
hl("NormalNC", { fg = c.fg, bg = c.bg })
hl("NormalFloat", { fg = c.fg, bg = c.bg_high })
hl("FloatBorder", { fg = c.outline, bg = c.bg_high })
hl("FloatTitle", { fg = c.primary, bg = c.bg_high, bold = true })
hl("ColorColumn", { bg = c.bg_low })
hl("Cursor", { fg = c.on_primary, bg = c.primary })
hl("CursorLine", { bg = c.bg_low })
hl("CursorColumn", { bg = c.bg_low })
hl("CursorLineNr", { fg = c.primary, bold = true })
hl("LineNr", { fg = c.outline })
hl("SignColumn", { bg = c.bg })
hl("FoldColumn", { fg = c.outline, bg = c.bg })
hl("Folded", { fg = c.fg_variant, bg = c.bg_mid })
hl("VertSplit", { fg = c.outline_variant })
hl("WinSeparator", { fg = c.outline_variant })
hl("StatusLine", { fg = c.fg, bg = c.bg_high })
hl("StatusLineNC", { fg = c.fg_variant, bg = c.bg_low })
hl("TabLine", { fg = c.fg_variant, bg = c.bg_low })
hl("TabLineFill", { bg = c.bg_low })
hl("TabLineSel", { fg = c.on_primary, bg = c.primary, bold = true })
hl("WinBar", { fg = c.fg, bg = c.bg })
hl("WinBarNC", { fg = c.fg_variant, bg = c.bg })
hl("Pmenu", { fg = c.fg, bg = c.bg_high })
hl("PmenuSel", { fg = c.on_primary, bg = c.primary })
hl("PmenuSbar", { bg = c.bg_highest })
hl("PmenuThumb", { bg = c.outline })
hl("Visual", { bg = c.secondary_container })
hl("Search", { fg = c.on_secondary_container, bg = c.secondary_container })
hl("IncSearch", { fg = c.on_primary, bg = c.primary })
hl("CurSearch", { fg = c.on_primary, bg = c.primary })
hl("MatchParen", { fg = c.primary, bold = true, underline = true })
hl("NonText", { fg = c.outline_variant })
hl("Whitespace", { fg = c.outline_variant })
hl("SpecialKey", { fg = c.outline_variant })
hl("EndOfBuffer", { fg = c.bg })
hl("Directory", { fg = c.primary })
hl("Title", { fg = c.primary, bold = true })
hl("ErrorMsg", { fg = c.error })
hl("WarningMsg", { fg = c.tertiary })
hl("MoreMsg", { fg = c.secondary })
hl("ModeMsg", { fg = c.fg, bold = true })
hl("Question", { fg = c.secondary })
hl("QuickFixLine", { bg = c.bg_mid })
hl("DiffAdd", { bg = c.secondary_container })
hl("DiffChange", { bg = c.bg_mid })
hl("DiffDelete", { fg = c.on_error_container, bg = c.error_container })
hl("DiffText", { fg = c.on_primary_container, bg = c.primary_container })
hl("SpellBad", { sp = c.error, undercurl = true })
hl("SpellCap", { sp = c.tertiary, undercurl = true })
hl("SpellRare", { sp = c.secondary, undercurl = true })
hl("SpellLocal", { sp = c.secondary, undercurl = true })

hl("Comment", { fg = c.outline, italic = true })
hl("Constant", { fg = c.primary_fixed })
hl("String", { fg = c.tertiary })
hl("Character", { fg = c.tertiary })
hl("Number", { fg = c.tertiary_fixed })
hl("Boolean", { fg = c.tertiary_fixed })
hl("Float", { fg = c.tertiary_fixed })
hl("Identifier", { fg = c.fg })
hl("Function", { fg = c.secondary })
hl("Statement", { fg = c.primary })
hl("Conditional", { fg = c.primary })
hl("Repeat", { fg = c.primary })
hl("Label", { fg = c.tertiary })
hl("Operator", { fg = c.fg_variant })
hl("Keyword", { fg = c.primary })
hl("Exception", { fg = c.error })
hl("PreProc", { fg = c.tertiary })
hl("Include", { fg = c.primary })
hl("Define", { fg = c.primary })
hl("Macro", { fg = c.tertiary })
hl("Type", { fg = c.secondary_fixed })
hl("StorageClass", { fg = c.primary })
hl("Structure", { fg = c.secondary_fixed })
hl("Typedef", { fg = c.secondary_fixed })
hl("Special", { fg = c.tertiary })
hl("SpecialChar", { fg = c.secondary_fixed })
hl("Delimiter", { fg = c.outline })
hl("Underlined", { underline = true })
hl("Error", { fg = c.error })
hl("Todo", { fg = c.on_primary, bg = c.primary, bold = true })

hl("DiagnosticError", { fg = c.error })
hl("DiagnosticWarn", { fg = c.tertiary })
hl("DiagnosticInfo", { fg = c.secondary })
hl("DiagnosticHint", { fg = c.outline })
hl("DiagnosticOk", { fg = c.secondary })
hl("DiagnosticUnderlineError", { sp = c.error, undercurl = true })
hl("DiagnosticUnderlineWarn", { sp = c.tertiary, undercurl = true })
hl("DiagnosticUnderlineInfo", { sp = c.secondary, undercurl = true })
hl("DiagnosticUnderlineHint", { sp = c.outline, undercurl = true })

hl("@variable", { fg = c.fg })
hl("@variable.builtin", { fg = c.primary_fixed })
hl("@variable.parameter", { fg = c.fg_variant })
hl("@variable.member", { fg = c.fg_variant })
hl("@property", { fg = c.fg_variant })
hl("@function", { link = "Function" })
hl("@function.builtin", { fg = c.secondary_fixed })
hl("@function.method", { link = "Function" })
hl("@constructor", { fg = c.secondary })
hl("@keyword", { link = "Keyword" })
hl("@keyword.return", { fg = c.primary, italic = true })
hl("@type", { link = "Type" })
hl("@type.builtin", { fg = c.secondary_fixed, italic = true })
hl("@string", { link = "String" })
hl("@string.escape", { fg = c.secondary_fixed })
hl("@number", { link = "Number" })
hl("@boolean", { link = "Boolean" })
hl("@constant", { link = "Constant" })
hl("@constant.builtin", { fg = c.primary_fixed, italic = true })
hl("@comment", { link = "Comment" })
hl("@punctuation", { fg = c.outline })
hl("@punctuation.bracket", { fg = c.outline })
hl("@punctuation.delimiter", { fg = c.outline })
hl("@operator", { link = "Operator" })
hl("@tag", { fg = c.primary })
hl("@tag.attribute", { fg = c.tertiary })
hl("@tag.delimiter", { fg = c.outline })
hl("@markup.heading", { fg = c.primary, bold = true })
hl("@markup.link", { fg = c.tertiary, underline = true })
hl("@markup.raw", { fg = c.tertiary })
hl("@module", { fg = c.secondary_fixed })
hl("@attribute", { fg = c.tertiary })

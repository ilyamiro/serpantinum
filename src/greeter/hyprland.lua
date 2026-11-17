---@diagnostic disable: undefined-global

local function env(name, default)
  local value = os.getenv(name)
  if value == nil or value == "" then return default end
  return value
end

hl.monitor({
  output   = "",
  mode     = "preferred",
  position = "auto",
  scale    = "auto",
})

hl.config({
  general = {
    gaps_in     = 0,
    gaps_out    = 0,
    border_size = 0,
  },

  decoration = {
    rounding = 0,
    shadow   = { enabled = false },
    blur     = { enabled = false },
  },

  animations = { enabled = false },

  input = {
    kb_layout          = env("SERPANTINUM_GREETER_KB_LAYOUT", "us"),
    kb_variant         = env("SERPANTINUM_GREETER_KB_VARIANT", ""),
    kb_options         = env("SERPANTINUM_GREETER_KB_OPTIONS", ""),
    numlock_by_default = true,
    follow_mouse       = 1,
  },

  cursor = {
    hide_on_key_press = true,
  },

  misc = {
    disable_hyprland_logo    = true,
    disable_splash_rendering = true,
    force_default_wallpaper  = 0,
    background_color         = 0xff000000,
    disable_autoreload       = true,
    focus_on_activate        = false,
  },

  ecosystem = {
    no_update_news  = true,
    no_donation_nag = true,
  },

  xwayland = { enabled = false },
})

local extra = env("SERPANTINUM_GREETER_HYPRLAND_EXTRA", nil)
if extra then
  local ok, err = pcall(dofile, extra)
  if not ok then print("serpantinum-greeter: failed to load " .. extra .. ": " .. tostring(err)) end
end

hl.on("hyprland.start", function()
  hl.exec_cmd("serpantinum-greeter")
end)

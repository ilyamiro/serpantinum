hl.config({
  general = {
    border_size = 0,
    gaps_in = 4,
    gaps_out = 6,
    float_gaps = 6,
    resize_on_border = true,
    extend_border_grab_area = 30,
  },

  decoration = {
    rounding = 12,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    blur = {
      enabled = true,
      size = 8,
      passes = 2,
      new_optimizations = true,
    },
    shadow = {
      enabled = false,
    },
  },

  input = {
    kb_layout = "us",
    kb_options = "grp:alt_shift_toggle",
    accel_profile = "flat",
    touchpad = {
      natural_scroll = true,
      disable_while_typing = false,
    },
  },

  misc = {
    focus_on_activate = false,
    font_family = "JetBrains Mono",
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
  },
})

hl.curve("myBezier", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })

hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "myBezier", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "myBezier", style = "popin 80%" })
hl.animation({ leaf = "layers", enabled = true, speed = 5, bezier = "myBezier", style = "fade" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 5, bezier = "myBezier", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 5, bezier = "myBezier", style = "fade" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "myBezier" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "myBezier", style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 5, bezier = "myBezier", style = "fade" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 5, bezier = "myBezier", style = "fade" })

local layoutMode = _G.layoutMode or "mixed"

local floatingClasses = {
  "pavucontrol",
  "org.pulseaudio.pavucontrol",
  "blueman-manager",
  "nm-connection-editor",
  "nwg-look",
  "lxappearance",
  "qt6ct",
  "kvantummanager",
}

local function isUtilityWindow(w)
  local class = w.class or ""
  for _, cls in ipairs(floatingClasses) do
    if class == cls then return true end
  end
  local title = w.title or ""
  return title:match("^Open ") ~= nil
    or title:match("^Save ") ~= nil
    or title:match("^Choose ") ~= nil
    or title:match("^Select ") ~= nil
    or title:match("^Pick ") ~= nil
end

local function float_window(w)
  hl.dispatch(hl.dsp.window.float({ action = "set", window = w }))
  hl.dispatch(hl.dsp.window.center({ window = w }))
end

local function tile_window(w)
  hl.dispatch(hl.dsp.window.float({ action = "unset", window = w }))
end

function apply_layout_mode(mode)
  if mode ~= "tiling" and mode ~= "mixed" and mode ~= "floating" then
    mode = "mixed"
  end
  _G.layoutMode = mode
  for _, w in ipairs(hl.get_windows()) do
    if w.fullscreen == 0 then
      local want_float = mode == "floating" or (mode == "mixed" and isUtilityWindow(w))
      if want_float then
        float_window(w)
      else
        tile_window(w)
      end
    end
  end
end

if layoutMode == "floating" then
  hl.window_rule({ float = true, center = true, match = { class = ".*" } })
elseif layoutMode == "tiling" then
  hl.window_rule({ tile = true, match = { class = ".*" } })
else
  for _, cls in ipairs(floatingClasses) do
    hl.window_rule({ float = true, center = true, match = { class = "^" .. cls .. "$" } })
  end
  hl.window_rule({
    float = true,
    center = true,
    match = { title = "^(Open|Save|Choose|Select|Pick)[[:space:]].*" },
  })
end

hl.on("window.open", function(w)
  local mode = _G.layoutMode or "mixed"
  if mode == "floating" then
    float_window(w)
  elseif mode == "tiling" then
    tile_window(w)
  elseif isUtilityWindow(w) then
    float_window(w)
  end
end)

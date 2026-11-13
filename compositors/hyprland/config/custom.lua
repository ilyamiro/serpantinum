-- serpantinum: loads the user's overrides from ~/.config/hypr/custom/<topic>.lua
-- right after the default config/<topic>.lua. Missing files are fine; errors in
-- a custom file are reported and never abort the rest of the config.
local M = {}

-- "super+shift + left" -> "SUPER + SHIFT + left" (the spelling the defaults use)
function M.normalize_key(key)
  local parts = {}
  for part in string.gmatch(key, "[^+]+") do
    parts[#parts + 1] = (string.gsub(part, "^%s*(.-)%s*$", "%1"))
  end
  for i = 1, #parts - 1 do
    parts[i] = string.upper(parts[i])
  end
  return table.concat(parts, " + ")
end

local function report(topic, msg)
  local text = "serpantinum: error in custom/" .. topic .. ".lua: " .. tostring(msg)
  local ok = pcall(hl.notification.create, { text = text, timeout = 10000 })
  if not ok then print(text) end
end

function M.load(topic)
  local orig_bind
  if topic == "keybinds" then
    orig_bind = hl.bind
    hl.bind = function(key, ...)
      pcall(hl.unbind, M.normalize_key(key))
      return orig_bind(key, ...)
    end
  end

  local ok, err = pcall(require, "custom/" .. topic)

  if orig_bind then hl.bind = orig_bind end

  if not ok and not string.find(tostring(err), "module 'custom/" .. topic .. "' not found", 1, true) then
    report(topic, err)
  end
end

return M

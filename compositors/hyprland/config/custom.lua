-- serpantinum: custom overrides helper
-- Loads the user's overrides from ~/.config/hypr/custom/<topic>.lua right
-- after the default config/<topic>.lua. Missing files are fine; errors in a
-- custom file are reported and never abort the rest of the config.
-- Keep the first line as it is: the installer uses it to recognise this file.
local M = {}

local function trim(s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function split_key(key)
  local parts = {}
  for part in string.gmatch(key, "[^+]+") do
    parts[#parts + 1] = trim(part)
  end
  return parts
end

-- "super+shift + left" -> "SUPER + SHIFT + left" (the spelling the defaults use)
function M.normalize_key(key)
  if type(key) ~= "string" then return key end
  local parts = split_key(key)
  for i = 1, #parts - 1 do
    parts[i] = string.upper(parts[i])
  end
  return table.concat(parts, " + ")
end

local MOD_RANK = { SUPER = 1, SHIFT = 2, CTRL = 3, CONTROL = 3, ALT = 4 }

-- Every spelling of <key> a default bind may use: modifiers as given and in
-- the order SUPER, SHIFT, CTRL, ALT (others after, as given); the key part as
-- given, upper-cased, lower-cased and capitalised. No duplicates.
function M.key_variants(key)
  if type(key) ~= "string" then return {} end
  local parts = split_key(key)
  if #parts == 0 then return {} end

  local last = parts[#parts]
  local raw, upper, ranked = {}, {}, {}
  for i = 1, #parts - 1 do
    raw[i] = parts[i]
    upper[i] = string.upper(parts[i])
    ranked[i] = { name = upper[i], rank = MOD_RANK[upper[i]] or 5, pos = i }
  end
  table.sort(ranked, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.pos < b.pos
  end)
  local canon = {}
  for i, m in ipairs(ranked) do canon[i] = m.name end

  local keys = {
    last,
    string.upper(last),
    string.lower(last),
    string.upper(string.sub(last, 1, 1)) .. string.lower(string.sub(last, 2)),
  }

  local out, seen = {}, {}
  for _, mods in ipairs({ raw, upper, canon }) do
    for _, k in ipairs(keys) do
      local all = {}
      for i, m in ipairs(mods) do all[i] = m end
      all[#all + 1] = k
      local v = table.concat(all, " + ")
      if not seen[v] then
        seen[v] = true
        out[#out + 1] = v
      end
    end
  end
  return out
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
      pcall(function()
        for _, v in ipairs(M.key_variants(key)) do
          pcall(hl.unbind, v)
        end
      end)
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

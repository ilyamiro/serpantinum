-- Run: lua install/tests/hypr_custom_test.lua
local script = arg and arg[0] or "install/tests/hypr_custom_test.lua"
local repo = script:match("^(.*)/install/tests/[^/]+$") or "."
local sandbox = os.getenv("HYPR_CUSTOM_SANDBOX")
local own_sandbox = false
if not sandbox then
  local p = io.popen("mktemp -d")
  sandbox = p and p:read("l")
  if p then p:close() end
  if not sandbox or sandbox == "" then
    io.stderr:write("hypr_custom_test: mktemp -d failed\n")
    os.exit(2)
  end
  own_sandbox = true
end
os.execute("mkdir -p '" .. sandbox .. "/custom'")
package.path = repo .. "/compositors/hyprland/?.lua;" .. sandbox .. "/?.lua;" .. package.path

local fails = 0
local function check(name, cond)
  if cond then print("ok   " .. name) else print("FAIL " .. name); fails = fails + 1 end
end
local function write(topic, body)
  local f = assert(io.open(sandbox .. "/custom/" .. topic .. ".lua", "w"))
  f:write(body); f:close()
end
local function clean()
  os.execute("rm -f '" .. sandbox .. "'/custom/*.lua")
  package.loaded["custom/keybinds"] = nil
  package.loaded["custom/settings"] = nil
  package.loaded["custom/env"] = nil
end

local binds, unbinds, notes, known
local function reset()
  binds, unbinds, notes, known = {}, {}, {}, {}
  hl = {
    bind = function(key) binds[#binds + 1] = key end,
    unbind = function(key)
      unbinds[#unbinds + 1] = key
      if not known[key] then error("unknown key " .. key) end
    end,
    notification = { create = function(o) notes[#notes + 1] = o.text end },
    dsp = {},
  }
end

local custom
local function fresh()
  clean(); reset()
  package.loaded["config/custom"] = nil
  custom = require("config/custom")
end

-- missing_topic_is_silent
fresh()
custom.load("env")
check("missing_topic_is_silent", #notes == 0)

-- custom_bind_replaces_default
fresh()
known["SUPER + q"] = true
hl.bind("SUPER + Q")
write("keybinds", 'hl.bind("SUPER+q")')
custom.load("keybinds")
local has = false
for _, k in ipairs(unbinds) do if k == "SUPER + q" then has = true end end
check("custom_bind_replaces_default", has and binds[#binds] == "SUPER+q")

-- unbind_error_is_ignored
fresh()
write("keybinds", 'hl.bind("SUPER + F12")')
custom.load("keybinds")
check("unbind_error_is_ignored", binds[#binds] == "SUPER + F12" and #notes == 0)

-- syntax_error_is_reported
fresh()
write("settings", "this is = = not lua (")
custom.load("settings")
check("syntax_error_is_reported", #notes == 1 and notes[1]:find("custom/settings.lua", 1, true) ~= nil)

-- wrapper_restored_after_error
fresh()
local orig = hl.bind
write("keybinds", 'hl.bind("SUPER + A")\nerror("boom")')
custom.load("keybinds")
check("wrapper_restored_after_error", rawequal(hl.bind, orig))

-- non_keybind_topic_not_wrapped
fresh()
orig = hl.bind
write("settings", "hl.SEEN_BIND = hl.bind")
custom.load("settings")
check("non_keybind_topic_not_wrapped", rawequal(hl.SEEN_BIND, orig))

-- normalize_key
fresh()
check("normalize_key",
  custom.normalize_key("super+shift + left") == "SUPER + SHIFT + left"
  and custom.normalize_key("SUPER + mouse:272") == "SUPER + mouse:272"
  and custom.normalize_key("Print") == "Print")

-- bind_tries_case_variants: a lower-case key also removes the upper-case default
fresh()
write("keybinds", 'hl.bind("SUPER+q")')
custom.load("keybinds")
local tried = {}
for _, k in ipairs(unbinds) do tried[k] = true end
check("bind_tries_case_variants", tried["SUPER + Q"] == true and tried["SUPER + q"] == true and binds[#binds] == "SUPER+q")

-- bind_tries_canonical_modifier_order
fresh()
write("keybinds", 'hl.bind("SHIFT+SUPER+Left")')
custom.load("keybinds")
tried = {}
for _, k in ipairs(unbinds) do tried[k] = true end
check("bind_tries_canonical_modifier_order", tried["SUPER + SHIFT + Left"] == true and tried["SHIFT + SUPER + Left"] == true and binds[#binds] == "SHIFT+SUPER+Left")

-- bind_variants_are_distinct
fresh()
write("keybinds", 'hl.bind("SUPER + Q")')
custom.load("keybinds")
tried = {}
local dup = false
for _, k in ipairs(unbinds) do if tried[k] then dup = true end; tried[k] = true end
check("bind_variants_are_distinct", not dup and tried["SUPER + Q"] == true and tried["SUPER + q"] == true)

-- non_string_key_does_not_error
fresh()
write("keybinds", 'hl.bind(123)\nhl.bind(nil)\nhl.bind("SUPER + B")')
custom.load("keybinds")
check("non_string_key_does_not_error", #notes == 0 and binds[#binds] == "SUPER + B" and binds[1] == 123)

clean()
if own_sandbox then os.execute("rm -rf '" .. sandbox .. "'") end
if fails > 0 then os.exit(1) end

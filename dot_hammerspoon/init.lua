
-- Hammerspoon configuration

local store = os.getenv("HOME") .. "/.password-store"
local clipboard_seconds = 20
local shell_path = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
local spaces = require("hs.spaces")

local alert_style = {
  textSize = 16,
  padding = 8,
  radius = 10,
}

local function notify(message, seconds)
  hs.alert.show(message, alert_style, seconds)
end

local function shell_quote(value)
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

-- Maccy: do not retain passwords copied by this chooser.
local function maccy_ignore_next_copy()
  hs.execute("/usr/bin/defaults write org.p0deje.Maccy ignoreEvents -bool true")
  hs.execute("/usr/bin/defaults write org.p0deje.Maccy ignoreOnlyNextEvent -bool true")
end

local function maccy_cancel_ignore_next_copy()
  hs.execute("/usr/bin/defaults write org.p0deje.Maccy ignoreEvents -bool false")
  hs.execute("/usr/bin/defaults write org.p0deje.Maccy ignoreOnlyNextEvent -bool false")
end

local function pass_entries()
  local command = "find " .. shell_quote(store) .. " -type f -name '*.gpg' -print 2>/dev/null"
  local output = hs.execute(command) or ""
  local choices = {}

  for path in output:gmatch("[^\r\n]+") do
    local entry = path:sub(#store + 2):gsub("%.gpg$", "")
    table.insert(choices, {
      text = entry,
      subText = "Copy password",
      entry = entry,
    })
  end

  table.sort(choices, function(a, b)
    return a.text < b.text
  end)

  return choices
end

local chooser

local function copy_password(choice)
  if not choice then
    maccy_cancel_ignore_next_copy()
    return
  end

  local command = "PATH=" .. shell_path .. "; export PATH; pass show -- " .. shell_quote(choice.entry)
  local output, success = hs.execute(command)

  if not success or not output then
    maccy_cancel_ignore_next_copy()
    notify("Could not decrypt: " .. choice.entry, 1.5)
    return
  end

  local password = output:match("([^\r\n]+)")
  if not password then
    maccy_cancel_ignore_next_copy()
    notify("Entry has no password: " .. choice.entry, 1.5)
    return
  end

  hs.pasteboard.setContents(password)
  notify("Copied " .. choice.entry, 0.8)

  hs.timer.doAfter(clipboard_seconds, function()
    if hs.pasteboard.getContents() == password then
      hs.pasteboard.setContents("")
    end
  end)
end

chooser = hs.chooser.new(function(choice)
  chooser:hide()
  hs.timer.doAfter(0.05, function()
    copy_password(choice)
  end)
end)

chooser:placeholderText("Password…")
chooser:rows(9)
chooser:width(38)

-- Option+Command+P: pass chooser
hs.hotkey.bind({ "alt", "cmd" }, "P", function()
  maccy_ignore_next_copy()
  chooser:choices(pass_entries())
  chooser:query("")
  chooser:show()
end)

-- Kill macOS's Cmd+H shortcut globally.
cmd_h_blocker = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  local flags = event:getFlags()

  if flags.cmd and event:getKeyCode() == hs.keycodes.map.h then
    return true
  end

  return false
end)
cmd_h_blocker:start()

-- Option+A/S: run the action once and suppress text input, including repeats.
local option_letter_actions = {
  [hs.keycodes.map.a] = function()
    hs.osascript.applescript([[
      tell application "Finder"
        make new Finder window to home
        activate
      end tell
    ]])
  end,
  [hs.keycodes.map.s] = function()
    hs.task.new("/usr/bin/open", nil, {
      "-n",
      "-a",
      "/Applications/kitty.app",
    }):start()
  end,
}

option_letter_tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  local flags = event:getFlags()
  local action = option_letter_actions[event:getKeyCode()]

  if not action or not flags.alt or flags.shift or flags.cmd or flags.ctrl then
    return false
  end

  if event:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) == 0 then
    action()
  end

  return true
end)
option_letter_tap:start()

-- Shift+Option+1–4: move the focused window to Desktop 1–4.
-- This mirrors Amethyst's workaround for newer macOS releases: hold the title
-- bar while posting macOS's configured "Switch to Desktop N" symbolic hotkey.
local desktop_move_in_progress = false

local function move_focused_window_to_desktop(number)
  if desktop_move_in_progress then
    return
  end

  local window = hs.window.focusedWindow()
  if not window then
    notify("No focused window", 1)
    return
  end

  local desktops = {}
  local desktop_spaces = spaces.spacesForScreen(window:screen()) or {}

  for _, space_id in ipairs(desktop_spaces) do
    if spaces.spaceType(space_id) == "user" then
      table.insert(desktops, space_id)
    end
  end

  local target_space = desktops[number]
  if not target_space then
    notify("Desktop " .. number .. " does not exist on this display", 1.5)
    return
  end

  local zoom_button = window:zoomButtonRect()
  if not zoom_button then
    notify("Window has no draggable title bar", 1.5)
    return
  end

  local original_mouse_position = hs.mouse.absolutePosition()
  local title_bar_point = {
    x = zoom_button.x + zoom_button.w + 5,
    y = zoom_button.y + zoom_button.h / 2,
  }

  desktop_move_in_progress = true
  hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.mouseMoved, title_bar_point):post()
  hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseDown, title_bar_point):post()

  hs.timer.doAfter(0.05, function()
    -- On this Mac, the symbolic hotkeys for Desktop 1–4 are Option+1–4.
    hs.eventtap.event.newKeyEvent({ "alt" }, tostring(number), true):post()
    hs.eventtap.event.newKeyEvent({ "alt" }, tostring(number), false):post()

    hs.timer.doAfter(0.4, function()
      hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseUp, title_bar_point):post()

      hs.timer.doAfter(0.05, function()
        hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.mouseMoved, original_mouse_position):post()

        hs.timer.doAfter(0.1, function()
          window:focus()
          desktop_move_in_progress = false
        end)
      end)
    end)
  end)
end

-- Consume Shift+Option+1–4 at the event level. hs.hotkey permits the held key
-- to auto-repeat as German-layout symbols, while this tap suppresses repeats.
local desktop_number_for_keycode = {
  [18] = 1,
  [19] = 2,
  [20] = 3,
  [21] = 4,
}

desktop_move_tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  local flags = event:getFlags()
  local desktop_number = desktop_number_for_keycode[event:getKeyCode()]

  if not desktop_number or not flags.alt or not flags.shift or flags.cmd or flags.ctrl then
    return false
  end

  if event:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) == 0 then
    move_focused_window_to_desktop(desktop_number)
  end

  return true
end)
desktop_move_tap:start()


-- Option + German "+" key: type ~
hs.hotkey.bind({ "alt" }, 30, function()
  hs.eventtap.keyStrokes("~")
end)

-- Option+ß (German keyboard): type \.
hs.hotkey.bind({ "alt" }, 27, function()
  hs.eventtap.keyStrokes("\\")
end)

-- Option+<: type |
hs.hotkey.bind({ "alt" }, "<", function()
  hs.eventtap.keyStrokes("|")
end)

-- Fn+Space: keyboard backlight up.
-- Shift+Fn+Space: keyboard backlight down.
local function send_keyboard_illumination(key)
  hs.eventtap.event.newSystemKeyEvent(key, true):post()
  hs.eventtap.event.newSystemKeyEvent(key, false):post()
end

keyboard_illumination_tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  local flags = event:getFlags()

  if event:getKeyCode() ~= hs.keycodes.map.space or not flags.fn then
    return false
  end

  if flags.shift then
    send_keyboard_illumination("ILLUMINATION_DOWN")
  else
    send_keyboard_illumination("ILLUMINATION_UP")
  end

  return true
end)
keyboard_illumination_tap:start()

-- Command+Option+E: Emoji & Symbols.
hs.hotkey.bind({ "cmd", "alt" }, "E", function()
  hs.eventtap.keyStroke({ "ctrl", "cmd" }, "space", 0)
end)

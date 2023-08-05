-- If you need a reference, "/config" will output the location of the default
-- config on your system.
-- Also, https://github.com/dzwdz/hewwo/blob/main/config_default.lua

-- Feel free to remove any part of this, the default config is loaded before
-- this file. It only got copied over to make it easier for you to make changes.

config.nick = nil -- autodetect

config.color.nicks = {"31", "32", "33", "34", "35", "36"}
config.color.clock = "38;5;8"
config.color.in_messages = true
if os.getenv("NO_COLOR") then config.color = {} end -- https://no-color.org

config.mention_show_bg = false -- toggles color background for mentions of your nickname

config.left_margin = false -- all (most) messages starting at the same column, some empty space on the left
config.left_margin_width = 20

config.timefmt = "%H:%M "

config.quit_msg = "oki goodnite uwu  >.<"

-- controls how many lines of *your* input are browseable with the up/down arrows
config.history_size = 50

-- /whois data
config.ident.username = nil -- autodetect
config.ident.realname = nil

-- user friendliness
config.display_ctcp = false

-- command aliases
commands["b"] = commands["buffer"]
commands["j"] = commands["join"]

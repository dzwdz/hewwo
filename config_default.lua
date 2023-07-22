-- If you need a reference, "/config" will output the location of the default
-- config on your system.
-- Also, https://github.com/dzwdz/hewwo/blob/main/config_default.lua

config.nick = nil -- autodetect

config.colors = {"31", "32", "33", "34", "35", "36"}
config.timefmt = "\x1b[38;5;8m".."%H:%M".."\x1b[0m "

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

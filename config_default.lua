local config = init_config()

-- If you need a reference, "/config" will output the location of the default
-- config on your system.
-- Also, https://github.com/dzwdz/hewwo/blob/main/config_default.lua

-- Feel free to remove any part of this, the default config is loaded before
-- this file. It only got copied over to make it easier for you to make changes.
-- The only exceptions are the first line (with init_config) and the last line
-- (with a return).


config.nick = os.getenv("USER")

config.color.nicks = {"31", "32", "33", "34", "35", "36"}
-- config.color.nicks = {"36", "35", "32", "33", "34;1", -- Weechat colorscheme
--                       "0", "36;1", "35;1", "32;1", "34"}
config.color.clock = "38;5;8"
config.color.in_messages = true
if os.getenv("NO_COLOR") then config.color = {} end -- https://no-color.org

-- 0= don't, 1= invert your nick, 2= invert the sender's nick, 3= both
config.invert_mentions = 2
-- "bell" the terminal on mentions?
config.bell = true

config.timefmt = "%H:%M "

-- If nil, don't display a left margin.
-- If it's a number, display a left margin of that size with right-adjusted
-- nicks, similarly to the default Weechat style.
config.margin = nil -- try 8

config.quit_msg = "oki goodnite uwu  >.<"

-- how many lines of *your* input are browseable with the up/down arrows
config.input_history = 50
-- how many messages can be stored in a single buffer?
config.buffer_history = 300
-- how much of the history should be printed when switching buffers?
config.switch_history = 50

-- /whois data
config.ident.username = nil -- autodetect
config.ident.realname = nil

-- user friendliness
config.display_ctcp = false

-- server config
config.host = "localhost"
config.port = "6667" -- must be a string

-- command aliases
config.commands["b"] = "buffer" -- alias /b to /buffer
config.commands["j"] = "join"

return config

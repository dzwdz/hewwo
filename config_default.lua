config.nick = nil -- autodetect

config.debug = false
config.colors = {"31", "32", "33", "34", "35", "36"}
config.timefmt = "\x1b[38;5;8m".."%H:%M".."\x1b[0m"

config.quit_msg = "oki goodnite uwu  >.<"

-- controls how many lines of *your* input are browseable with the up/down arrows
config.history_size = 50

-- command aliases
commands["b"] = commands["buffer"]
commands["j"] = commands["join"]

-- not really proper i18n, this just holds some of the user visible strings

i18n = {}

i18n.query_hint = [[
hint: you've just received a private message!
      try "/msg %s [your reply]"]]

i18n.quit_hint = [[hint: if you meant to quit, try /QUIT]]

-- TODO /help buffers
i18n.buffer_hint = [[
hint: The active buffer switched to %s, so you'll only see messages from there.
      If you want to switch back, try "/buf %s".
      "/ls" or "/buffers" will list all the buffers you're in.]]


i18n.help = {}
i18n.help.main = [[
/help cmd      will list all the available commands
/help manual   will show the manual
/help unread   will explain the [0!0] thing in your prompt]]

-- TODO help_manual
i18n.help.manual = [[
nobody bothered to write this help string yet. blame dzwdz]]

-- TODO help_unread
i18n.help.unread = [[
nobody bothered to write this help string yet. blame dzwdz]]

i18n.help._unknown = [[
i'm not sure what "%s" is.
"/help" with no arguments will list everything that i do know, though]]


i18n.connecting = [[
logging you in as %s. if you don't like that, try /nick]]

i18n.connected = [[
ok, i'm connected! try "/join #newbirc" or "/help"]]

i18n.quit_failsafe = [[
if you are sure you want to close the client, type "/QUIT" (all caps)]]


-- TODO add instructions on how to scroll to the wiki
i18n.list_after = [[

those are all the channels on this server. hopefully that wasn't too
overwhelming. you should be able to scroll the list.
if you can't, you can either:
1. run "/list | less"
2. try using tmux: https://tilde.town/wiki/learn/tmux.html
]]


set_cmd_help("query", [[Send a private message to someone.]])
set_cmd_help("quit", [[Leave all channels and close hewwo.]])
set_cmd_help("who", [[See who's in the current channel.]])
set_cmd_help("buffers", [[List all the open buffers (including channels you left).]])
set_cmd_help("action", [[Send a roleplay message, e.g. "/me jumps into hyperspace".]])

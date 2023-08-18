-- not really proper i18n, this just holds some of the user visible strings

local i18n = safeinit(...)

i18n.hint = {}
i18n.hint.query = [[
hint: you've just received a private message!
      try "/msg %s [your reply]"]]

i18n.hint.quit = [[hint: if you meant to quit, try /QUIT]]

i18n.hint.buffer = [[
hint: The active buffer switched to %s, so you'll only see messages from there.
      If you want to switch back, try "/buffer %s". Also, see "/help buffers".]]

i18n.hint.msg_in_unread = [[
hint: The first message received in a buffer you've switched away from will be
      displayed, to let you know where people are currently talking.]]

i18n.hint.join_syntax = [[
hint: Did you mean to join multiple channels?
      /join #a #b  joins #a using the channel key "#b"
      /join #a,#b  joins #a and #b]]

i18n.hint.editor = [[
hint: if you prefer another editor, try setting the EDITOR environment variable]]


i18n.help = {}
i18n.help.main = [[
/help /cmd     will give you information about that command
/help prompt   will explain the [0!0] thing in your prompt
/help buffers  will explain what buffers are]]

i18n.help.prompt = [[
Let's assume your prompt is [4!2 #tildetown]:
* The 1st number, 4, is the amount of unread buffers
* The 2nd number, 2, is the amount of buffers with unread mentions
* "#tildetown" is the buffer you're currently in

If you're wondering what an buffer even is, "/help buffers"]]

i18n.help.buffers = [[
A buffer is a thing with messages. There's three kinds of them:
1. channel buffers        - e.g. "#tildetown"
2. direct message buffers - e.g. "dzwdz"
3. special buffers        - e.g. ":mentions"

You can only view one buffer at a time, but you can switch between them at
any time using "/buffer" (or "/b" for short). That will also print all the
messages in that buffer, so you're up to date on what was happening there.

You can also list all buffers with "/buffers" or "/ls".]]

i18n.help._unknown = [[
Unknown help topic "%s". Try "/help", with no arguments.]]

i18n.help._unknowncmd = [[
Unknown command "%s". Try "/help", with no arguments.]]


i18n.connecting = [[
logging you in as %s. if you don't like that, try /nick]]

i18n.connected = [[
ok, i'm connected! try "/join #tildetown" or "/help"]]

i18n.err_rochan = [[
"%s" is a special read-only buffer.
try "/join #tildetown", or "/help buffers"
]]

i18n.err_nochan = [[
you need to enter a channel to chat. try "/join #tildetown"]]

i18n.err_config = [[

!!! There's an error somewhere in your config !!!
The default config was loaded as a fallback for now.
Please use  /config edit  to fix it.
]]

i18n.quit_failsafe = [[
if you are sure you want to close the client, type "/QUIT" (all caps)]]

i18n.nick_invalid = [[
%s isn't a valid nick]]

i18n.alias_loop = [[
infinite alias loop detected for "/%s". check your config]]


i18n.list_after = [[

those are all the channels on this server. hopefully that wasn't too
overwhelming. you should be able to scroll the list.
if you can't, you can either:
1. run "/list | less"
2. try using tmux: https://tilde.town/wiki/learn/tmux.html
]]

i18n.cli_usage = [[
usage: hewwo [-c host] [-p port] [-n nick]
]]

i18n.cmd = {}
i18n.cmd.help = {}
i18n.cmd.help.action = [[
Send a roleplay message, e.g. "/me jumps into hyperspace".]]
i18n.cmd.help.buffers = [[
List all the open buffers (including channels you left).
See also: /help buffers]]
i18n.cmd.help.close = [[
Remove a buffer's stored history, and remove it from the buffer list.]]
i18n.cmd.help.config = [[Customize hewwo.]]
i18n.cmd.help.history = [[Display the history of a buffer.

By default, only the few most recent messages are displayed when you switch to
another buffer. This lets you read the older (but still limited) history.

This is also useful if you've changed your config and want to see your changes.]]
i18n.cmd.help.nick = [[Set your own nick (shared across all channels).]]
i18n.cmd.help.join = [[
Joins channel(s). The key is required for private channels.]]
i18n.cmd.help.list = [[List all the channels on the server.]]
i18n.cmd.help.query = [[Send a private message to someone.]]
i18n.cmd.help.quit = [[Leave all channels and close hewwo.]]
i18n.cmd.help.who = [[See who's in the current channel.]]
i18n.cmd.help.topic = [[Read or set the topic of the current channel.]]

i18n.cmd.inline = {}
i18n.cmd.inline.config = "[edit]"
i18n.cmd.inline.history = "[buffer] [amount]"
i18n.cmd.inline.join = "#chan1[,#chan2...] [key]"
i18n.cmd.inline.list = "[| system command]"
i18n.cmd.inline.query = "target message"
i18n.cmd.inline.topic = "[new topic]"

return i18n

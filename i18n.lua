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

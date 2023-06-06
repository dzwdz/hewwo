commands = {}

commands["nick"] = function(_, ...)
	if #{...} ~= 1 then
		print("/nick takes exactly one argument")
		return
	end
	local nick = ...
	-- TODO validate nick
	writecmd("NICK", nick)
	conn.user = nick
	print("your nick is now "..hi(nick))
end

commands["join"] = function(_, ...)
	if #{...} == 0 then
		print("missing argument. try /join #tildetown")
		return
	end
	for i, v in ipairs({...}) do
		writecmd("JOIN", v)
	end
	local last = ({...})[#{...}] -- wonderful syntax
	open_chan(last)
end

commands["quit"] = function(line, ...)
	if line == "/QUIT" then
		writecmd("QUIT")
		os.exit(0)
	end
	print("if you are sure you want to exit, type \"/QUIT\" (all caps)")
end

commands["msg"] = function(line, user, ...)
	if not user then
		print("usage: /msg [user] blah blah blah")
		return
	end
	local msg = string.gsub(line, "^[^ ]* *[^ ]* *", "")
	message(conn.user, user, msg)
	writecmd("PRIVMSG", user, msg)
	conn.pm_hint = true
end
commands["q"] = commands["msg"]

commands["buf"] = function(line, ...)
	if #{...} ~= 1 then
		print("/buf takes in exactly one argument - a channel/username")
		return
	end
	local chan = ...
	open_chan(chan)
end
commands["b"] = commands["buf"]
commands["buffer"] = commands["buf"]

commands["action"] = function(line, ...)
	local msg = "\1ACTION " .. string.gsub(line, "^[^ ]* *", "")
	message(conn.user, conn.chan, msg)
	writecmd("PRIVMSG", conn.chan, msg)
end
commands["me"] = commands["action"]

commands["lua"] = function(line, ...)
	line = string.gsub(line, "^[^ ]* *", "")
	local fn, err = load(line, "=(user)")
	if fn then
		fn()
		return
	end
	-- try wrapping in print()
	local fn, _ = load("print("..line..")", "=(user)")
	if fn then
		fn()
		return
	end
	print(err)
end

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
		buffers:make(v)
	end
	local last = ({...})[#{...}] -- wonderful syntax
	buffers:switch(last)
end

commands["quit"] = function(line, ...)
	if line == "/QUIT" then
		writecmd("QUIT", config.quit_msg)
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
	buffers:switch(chan)
end
commands["b"] = commands["buf"]
commands["buffer"] = commands["buf"]

commands["action"] = function(line, ...)
	local msg = "\1ACTION " .. string.gsub(line, "^[^ ]* *", "")
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

commands["buffers"] = function()
	local total = 0
	print("You're in:")
	for k,v in pairs(buffers.tbl) do
		local unread = ""
		if v.unread > 0 then
			unread = string.format("(%d unread)", v.unread)
		end
		print(k, v.state, unread)
		total = total + 1
	end
	printf("(%d buffers in total)", total)
end
commands["bufs"] = commands["buffers"]
commands["ls"] = commands["buffers"]

commands["help"] = function()
	local aliases = {}
	for k,v in pairs(commands) do
		if not aliases[v] then
			aliases[v] = {}
		end
		table.insert(aliases[v], "/"..k)
	end
	for k,v in pairs(aliases) do
		-- sort by length descending. the longest alias is the primary one
		table.sort(v, function(a, b) return #a > #b end)

		local s = v[1]
		for _,alias in ipairs(v) do
			if s ~= alias then
				s = s.." = "..alias
			end
		end
		print(s)
	end
end

commands["unread"] = function()
	-- TODO /unread
	print("actually, go figure it out on your own. this isn't implemented yet")
end

commands["who"] = function(_, ...)
	if not conn.chan then
		printf("you're not in a channel yet")
		return
	end
	local nicks = {}
	for k, v in pairs(conn.chanusers[conn.chan]) do
		if v then
			table.insert(nicks, k)
		end
	end
	table.sort(nicks)

	local s = ""
	local slen = 0
	printf("people in %s:", conn.chan)
	for _, nick in ipairs(nicks) do
		-- TODO unicode view len
		local len = string.len(nick) + 4
		local padlen = -len % 12
		local len = len + padlen
		nick = "[ " .. hi(nick) .. string.rep(" ", padlen) .. " ]"
		if string.len(s) + padlen >= 80 then
			print(s)
			s = ""
			slen = 0
		end
		s = s..nick
		slen = slen + padlen
	end
	if s ~= "" then
		print(s)
	end
end
commands["nicks"] = commands["who"]

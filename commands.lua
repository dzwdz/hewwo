commands = {}
commands_help = {}

function set_cmd_help(cmd, help)
	commands_help[commands[cmd]] = help
end

-- max_args doesn't include the command itself
-- see below for examples
function cmd_parse(line, max_args, pipe)
	-- line = string.gsub(line, "^ *", "")  guaranteed to start with /

	local args = {}
	local pos = 1
	if pipe then
		local split = string.find(line, "|")
		if split then
			args.pipe = string.sub(line, split+1)
			line = string.sub(line, 1, split-1)
		end
	end
	line = string.gsub(line, " *$", "")
	while true do
		local ws, we = string.find(line, " +", pos)
		if ws and (not max_args or #args < max_args) then
			table.insert(args, string.sub(line, pos, ws-1))
			pos = we + 1
		else
			table.insert(args, string.sub(line, pos))
			break
		end
	end
	args[0] = string.gsub(args[1], "^/", "")
	table.remove(args, 1)
	return args
end
run_test(function(t)
	t(cmd_parse("/q dzwdz blah blah"), {[0]="q", "dzwdz", "blah", "blah"})
	t(cmd_parse("/q dzwdz blah blah", 2), {[0]="q", "dzwdz", "blah blah"})
	t(cmd_parse("/q   dzwdz   blah   blah", 2), {[0]="q", "dzwdz", "blah   blah"})

	t(cmd_parse("/list | less"), 
		{[0]="list", "|", "less"})
	t(cmd_parse("/list | less", nil, true), 
		{[0]="list", ["pipe"]=" less"})
end)

commands["nick"] = function(line, args)
	if #args == 0 then
		printf("your nick is %s", hi(conn.user))
	elseif #args == 1 then
		local nick = args[1]
		-- TODO validate nick
		writecmd("NICK", nick)
		if not conn.nick_verified then
			conn.user = nick
		end
		printf("changing your nick to %s...", hi(nick))
	else
		print("/nick takes exactly one argument")
	end
end

commands["join"] = function(line, args)
	if #args == 0 then
		print("missing argument. try /join #tildetown")
		return
	end
	-- TODO check conn.nick_verified
	for i, v in ipairs(args) do
		writecmd("JOIN", v)
		buffers:make(v)
	end
	local last = args[#args]
	buffers:switch(last)
end

commands["part"] = function(line, args)
	if #args == 0 then
		writecmd("PART", conn.chan)
	else
		for i, v in ipairs(args) do
			writecmd("PART", v)
		end
	end
end
commands["leave"] = commands["part"]

commands["quit"] = function(line, args)
	-- remember all caps when you spell the command's name
	if args[0] == "QUIT" then
		args = cmd_parse(line, 1)
		writecmd("QUIT", args[1] or config.quit_msg)
		os.exit(0)
	else
		print(i18n.quit_failsafe)
	end
end

commands["msg"] = function(line, args)
	local args = cmd_parse(line, 2)
	if #args == 2 then
		writecmd("PRIVMSG", args[1], args[2])
		conn.pm_hint = true -- TODO move to the new hint system
	else
		printf("usage: /%s [user] blah blah blah", args[0])
	end
end
commands["q"] = commands["msg"]
commands["query"] = commands["msg"]

commands["buffer"] = function(line, args)
	if #args ~= 1 then
		printf("/%s takes in exactly one argument - a channel/username", args[0])
		return
	end
	buffers:switch(args[1])
end
commands["buf"] = commands["buffer"]

commands["action"] = function(line, args)
	if not conn.chan then
		print("you must enter a channel first")
		return
	end
	local content = cmd_parse(line, 1)[1] or ""
	writecmd("PRIVMSG", conn.chan, "\1ACTION "..content.."\1")
end
commands["me"] = commands["action"]

commands["lua"] = function(line, args)
	args = cmd_parse(line, 1)
	if #args == 0 then
		printf("try /%s 2 + 2", args[0])
		return
	end

	-- hmm, should this maybe be a custom buffer?
	printf("lua: %s", args[1])
	local fn, err = load(args[1], "=(user)")
	if fn then
		fn()
		return
	end
	-- try wrapping in print()
	local fn, _ = load("print("..args[1]..")", "=(user)")
	if fn then
		fn()
		return
	end
	print(err)
end

commands["buffers"] = function()
	local total = 0
	print("You're in:")
	for k,buf in pairs(buffers.tbl) do
		local s = k
		if buf.unread > 0 then
			s = string.format("%s, %d unread", s, buf.unread)
		end
		if buf.mentions > 0 then
			s = string.format("%s, %d mention(s)", s, buf.mentions)
		end
		if buf.connected == false then
			s = s .. ", disconnected"
		end -- can also be nil
		print(s)
		total = total + 1
	end
	printf("(%d buffers in total)", total)
end
commands["bufs"] = commands["buffers"]
commands["ls"] = commands["buffers"]

commands["help"] = function(line, args)
	local what = args[1]
	if what == "cmd" then
		local aliases = {}
		local aliases_ord = {}
		for k,v in pairs(commands) do
			if not aliases[v] then
				aliases[v] = {}
			end
			table.insert(aliases[v], k)
		end
		for k,v in pairs(aliases) do
			-- sort by length descending. the longest alias is the primary one
			table.sort(v, function(a, b) return #a > #b end)
			table.insert(aliases_ord, v)
		end
		-- sort commands alphabetically
		table.sort(aliases_ord, function(a, b) return a[1] < b[1] end)
		for _,v in ipairs(aliases_ord) do
			local s = ""
			for _,alias in ipairs(v) do
				if s == "" then
					s = "/"..alias
				else
					s = s.." = /"..alias
				end
			end
			print(s)
			local help = commands_help[commands[v[1]]]
			if help then 
				print("  "..help)
			end
		end
	else
		local s = i18n.help[what or "main"]
		if s then
			print(s)
		else
			printf(i18n.help._unknown, what)
		end
	end
	print()
end

commands["who"] = function(line, args)
	if #args ~= 0 then
		printf("/who doesn't support any arguments yet")
		return
	end
	if not conn.chan then
		printf("you're not in a channel yet")
		return
	end

	local nicks = {}
	for k, v in pairs(buffers.tbl[conn.chan].users) do
		if v then
			table.insert(nicks, k)
		end
	end
	table.sort(nicks)

	local s = ""
	local slen = 0
	printf("people in %s:", conn.chan)
	for line, argsk in ipairs(nicks) do
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

commands["warp"] = function(line, args)
	if #args ~= 1 then
		printf("/warp takes exactly one argument")
		return
	end

	local pattern = args[1]
	if buffers.tbl["#"..pattern] then
		buffers:switch("#"..pattern)
	elseif buffers.tbl[pattern] then
		buffers:switch(pattern)
	else
		local matches = {}
		for k,_ in pairs(buffers.tbl) do
			if string.find(k, pattern) then
				table.insert(matches, k)
			end
		end
		if #matches == 0 then
			printf([[no buffer found matching "%s"]], pattern)
		elseif #matches == 1 then
			buffers:switch(matches[1])
		else
			printf([[found multiple buffers matching "%s":]], pattern)
			for _,v in ipairs(matches) do
				print(v)
			end
		end
	end
end
commands["w"] = commands["warp"]

commands["topic"] = function(line, args)
	if #args == 0 then
		print("usage: /topic [a topic for the current channel]")
		print("       /topic #stuff [a topic for #stuff]")
		return
	end
	if string.sub(args[1], 1, 1) == "#" then
		args = cmd_parse(line, 2)
		writecmd("TOPIC", args[1], args[2])
	else
		args = cmd_parse(line, 1)
		writecmd("TOPIC", conn.chan, args[1])
	end
end

commands["list"] = function(line, args)
	args = cmd_parse(line, nil, true)
	if #args ~= 0 then
		print([[/list currently doesn't take any arguments]])
		print([[did you maybe mean?  /list | less]])
		return
	end
	if args.pipe then
		ext_run(args.pipe)
	end
	writecmd("LIST", ">1")
end

commands["config"] = function(line, args)
	local function execf(...)
		local cmd = string.format(...)
		printf("$ %s", cmd)
		return os.execute(cmd)
	end

	local path = {}
	for p in string.gmatch(package.path, "[^;]+%?.lua") do
		p = string.gsub(p, "?", "config")
		table.insert(path, p)
	end
	local default = package.searchpath("config_default", package.path)

	if args[1] == nil then
		printf("In order of preference, I search for a config in:")
		for k,v in ipairs(path) do
			printf("%d. %s", k, v)
		end
		printf("The default config is at %s", default)
		printf("try /config edit")
	elseif args[1] == "edit" then
		local dir, s = string.gsub(path[1], "/config.lua$", "")
		if s ~= 1 then
			print("something went wrong, sorry")
			return
		end

		if not file_exists(path[1]) then
			-- yeah, yeah, this isn't portable. whatever
			if not execf([[mkdir -p "%s"]], dir) then return end
			if not execf([[cp "%s" "%s"]], default, path[1]) then return end
		end

		if not execf([[${EDITOR:-nano} "%s"]], path[1]) then return end

		-- TODO hot reload
		print("if you expected the config to get reloaded")
		print("have a nice disappointment. this isn't implemented yet")
	else
		print("usage: /config [edit]")
	end
end

commands["raw"] = function(line, args)
	args = cmd_parse(line, 1)
	writecmdraw(args[1])
end

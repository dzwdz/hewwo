local commands = safeinit(...)

local buffers = require "buffers"
local i18n = require "i18n"
local irc = require "irc"
local ui = require "ui"
local util = require "util"
local Gs = require "state"

commands["nick"] = function(line, args)
	local hi = ui.highlight
	if #args == 0 then
		printf("your nick is %s", hi(Gs.user))
	elseif #args == 1 then
		local nick = args[1]
		if not irc.is_nick(nick) then
			printf(i18n.nick_invalid, nick)
			return
		end
		-- TODO validate nick
		irc.writecmd("NICK", nick)
		if not Gs.active then
			Gs.user = nick
		end
		printf("changing your nick to %s...", hi(nick))
	else
		print("/nick takes exactly one argument")
	end
end

commands["join"] = function(line, args)
	args = util.parsecmd(line, 2)
	if not Gs.active then
		print("sorry, you're not connected yet.")
		return
	end

	-- with no arguments, try to rejoin the open channel
	args[1] = args[1] or Gs.chan
	if not args[1] then
		print("missing argument. try /join #tildetown")
		return
	end

	if not irc.is_channel(args[1]) then
		print([[
/join's argument must be a channel (start with a #). try /join #tildetown]])
		return
	end
	if irc.is_channel(args[2]) then
		ui.hint(i18n.hint.join_syntax)
	end

	local key = args[2] -- intended to be nil with no key
	local last
	for chan in string.gmatch(args[1], "[^,]+") do -- comma separated
		irc.writecmd("JOIN", chan, key)
		buffers:make(chan)
		last = chan
	end
	buffers:switch(last)
end
-- ["j"] set in default config

commands["part"] = function(line, args)
	-- TODO inconsistent with /join
	if #args == 0 then
		irc.writecmd("PART", Gs.chan)
	else
		for _,v in ipairs(args) do
			irc.writecmd("PART", v)
		end
	end
end
commands["leave"] = commands["part"]

commands["quit"] = function(line, args)
	-- remember all caps when you spell the command's name
	if args[0] == "QUIT" then
		args = util.parsecmd(line, 1)
		irc.writecmd("QUIT", args[1] or config.quit_msg)
		os.exit(0)
	else
		print(i18n.quit_failsafe)
	end
end

commands["close"] = function(line, args)
	local chan = args[1] or Gs.chan

	-- TODO special buffers should be distinguished somehow else
	if chan and string.match(chan, "^:") then
		printf([[buffer %s is special]], chan)
	elseif not Gs.buffers[chan] then
		printf([[buffer %s not found]], chan)
	elseif Gs.buffers[chan].connected then
		printf([[buffer %s still connected]], chan)
		printf([[try /part %s]], chan)
	else
		Gs.buffers[chan] = nil

		if Gs.chan == chan then
			Gs.chan = nil
		end
	end
end

commands["msg"] = function(line, args)
	local args = util.parsecmd(line, 2)
	if #args == 2 then
		irc.writecmd("PRIVMSG", args[1], args[2])
		Gs.pm_hint = true -- TODO move to the new hint system
	else
		printf("usage: /%s [user] blah blah blah", args[0])
	end
end
commands["q"] = commands["msg"]
commands["query"] = commands["msg"]

commands["action"] = function(line, args)
	if not Gs.chan then
		print("you must enter a channel first")
		return
	end
	local content = util.parsecmd(line, 1)[1] or ""
	irc.writecmd("PRIVMSG", Gs.chan, "\1ACTION "..content.."\1")
end
commands["me"] = commands["action"]

commands["lua"] = function(line, args)
	args = util.parsecmd(line, 1)
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
	fn = load("print("..args[1]..")", "=(user)")
	if fn then
		fn()
		return
	end
	print(err)
end

commands["buffers"] = function()
	local total = 0
	print("You're in:")
	for k,buf in pairs(Gs.buffers) do
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
		local aliases = {} -- map from function to its names
		for k,v in pairs(commands) do
			if not aliases[v] then
				aliases[v] = {}
			end
			table.insert(aliases[v], "/"..k)
		end
		for k,v in pairs(config.commands) do
			if type(v) == "string" then
				if commands[v] then -- simple alias
					table.insert(aliases[commands[v]], "/"..k)
				end
			end -- don't care about custom functions
		end

		local aliases_ord = {} -- list of those names
		for _,v in pairs(aliases) do
			-- sort by length descending. the longest alias is the primary one
			table.sort(v, function(a, b) return #a > #b end)
			table.insert(aliases_ord, v)
		end
		-- sort the commands alphabetically
		table.sort(aliases_ord, function(a, b) return a[1] < b[1] end)

		for _,names in ipairs(aliases_ord) do
			local help, inline
			for _,alias in ipairs(names) do
				alias = string.sub(alias, 2) -- strip slash
				help = help or i18n.cmd.help[alias]
				inline = inline or i18n.cmd.inline[alias]
			end

			local s = names[1]
			if inline then
				s = s .. " " .. inline
			end
			if #names > 1 then
				s = string.format("%s  (also %s)", s, table.concat(names, ",", 2))
			end
			print(s)
			if help then
				-- TODO /help /command to view the entire help string
				help = string.gsub(help, "\n.*", " [...]")
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
	if not Gs.chan then
		printf("you're not in a channel yet")
		return
	end

	local nicks = {}
	for k, v in pairs(Gs.buffers[Gs.chan].users) do
		if v then
			table.insert(nicks, k)
		end
	end
	table.sort(nicks)

	local s = ""
	printf("people in %s:", Gs.chan)
	for _,nick in ipairs(nicks) do
		local len = utf8.len(nick) + 4
		local padlen = -len % 12
		nick = "[ " .. ui.highlight(nick) .. string.rep(" ", padlen) .. " ]"
		if utf8.len(s) + len + padlen >= 80 then
			print(s)
			s = ""
		end
		s = s..nick
	end
	if s ~= "" then
		print(s)
	end
end
commands["nicks"] = commands["who"]

commands["buffer"] = function(line, args)
	if #args ~= 1 then
		printf("/buffer takes exactly one argument")
		return
	end

	local pattern = args[1]
	if Gs.buffers[pattern] then
		buffers:switch(pattern)
	elseif Gs.buffers["#"..pattern] then
		buffers:switch("#"..pattern)
	else
		local matches = {}
		for k,_ in pairs(Gs.buffers) do
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
commands["buf"] = commands["buffer"]
-- ["b"] set in default config

commands["topic"] = function(line, args)
	if #args == 0 then
		irc.writecmd("TOPIC", Gs.chan)
	else
		local topic = util.parsecmd(line, 1)[1]
		irc.writecmd("TOPIC", Gs.chan, topic)
	end
end

commands["list"] = function(line, args)
	args = util.parsecmd(line, nil, true)
	if #args ~= 0 then
		print([[/list currently doesn't take any arguments]])
		print([[did you maybe mean?  /list | less]])
		return
	end
	if args.pipe then
		ext.run(args.pipe, "list")
	end
	irc.writecmd("LIST", ">1")
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
		printf("Also, try \"/config edit\".\n")
	elseif args[1] == "edit" then
		local dir, s = string.gsub(path[1], "/config.lua$", "")
		if s ~= 1 then
			print("something went wrong, sorry")
			return
		end

		if not util.file_exists(path[1]) then
			-- yeah, yeah, this isn't portable. whatever
			if not execf([[mkdir -p "%s"]], dir) then return end
			if not execf([[cp "%s" "%s"]], default, path[1]) then return end
		end

		local editor = os.getenv("EDITOR") or "nano"
		local cmd = string.format([[%s "%s"]], editor, path[1])
		ext.run(cmd, "/config edit", {
			callback = function ()
				-- TODO hint about $EDITOR
				-- TODO handle errors
				package.loaded["config"] = nil
				require("config")
				print("config reloaded!")
			end,
			tty = true, -- don't override stdin
		})
	else
		print("usage: /config [edit]")
	end
end

commands["raw"] = function(line, args)
	args = util.parsecmd(line, 1)
	irc.writecmd(args[1])
end

return commands

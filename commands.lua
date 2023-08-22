local commands = safeinit(...)

local Gs = require "state"
local buffers = require "buffers"
local config = require "config"
local i18n = require "i18n"
local irc = require "irc"
local ui = require "ui"
local util = require "util"

commands.tbl = commands.tbl or {}
local tbl = commands.tbl

local tag = {}
tag.basic = {}
tag.devel = {}
tag.oper = {}

function commands.run(line)
	local args = util.parsecmd(line)
	local cmd = string.lower(args[0])
	local impl

	impl = config.commands[cmd] or commands.tbl[cmd]
	local i = 0
	while type(impl) == "string" do -- resolve aliases recursively
		impl = config.commands[impl] or commands.tbl[impl]
		i = i + 1
		if i >= 100 then
			printf(i18n.alias_loop, cmd)
			break
		end
	end
	if type(impl) == "function" then
		impl(line, args)
	elseif type(impl) == "table" then
		impl.fn(line, args)
	else
		printf([[unknown command "/%s"]], cmd)
	end
end

local cmd_metatable = {
	help = function(self, short)
		local help, inline
		for _,name in ipairs(self.names) do
			help   = help   or i18n.cmd.help[name]
			inline = inline or i18n.cmd.inline[name]
		end

		local s = "/" .. self.names[1]
		if inline then
			s = s .. " " .. inline
		end
		if #self.names > 1 then
			local nameslash = {}
			for k,name in ipairs(self.names) do
				nameslash[k] = "/" .. name
			end
			s = string.format("%s  (also %s)", s, table.concat(nameslash, ",", 2))
		end
		if help then
			if short then
				help = string.gsub(help, "\n.*", " [...]")
			end
			help = string.gsub("\n" .. help, "\n", "\n  ") -- indent
			s = s .. help
		end
		return s
	end
}

-- compare (sort) alphabetically by the primary name
local cmdcmp = util.proxycmp(function(cmd) return cmd.names[1] end)

function commands.register(data, fn)
	local obj = setmetatable({}, {__index=cmd_metatable})
	local tagged = false
	obj.fn = fn
	obj.names = {}

	for _, ent in ipairs(data) do
		if type(ent) == "string" then
			table.insert(obj.names, ent)
			tbl[ent] = obj
		elseif type(ent) == "table" then
			-- it's a tag
			table.insert(ent, obj)
			table.sort(ent, cmdcmp)
			tagged = true
		end
	end
	if not tagged then
		error(string.format("%q lacks tags", obj.names[1]))
	end

	table.insert(tbl, obj)
	-- keep commands.tbl sorted at all times for /help purposes
	table.sort(tbl, cmdcmp)
end
local reg = commands.register

reg({"nick", tag.basic}, function(line, args)
	local hi = ui.highlight
	if #args == 0 then
		printf("your nick is %s", hi(Gs.user))
	elseif #args == 1 then
		local nick = args[1]
		if not irc.is_nick(nick) then
			printf(i18n.nick_invalid, nick)
			return
		end
		irc.writecmd("NICK", nick)
		if not Gs.active then
			Gs.user = nick
		end
		printf("changing your nick to %s...", hi(nick))
	else
		print("/nick takes exactly one argument")
	end
end)

reg({"join", tag.basic}, function(line, args)
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
end)

reg({"part", "leave", tag.basic}, function(line, args)
	-- TODO /part is inconsistent with /join
	if #args == 0 then
		irc.writecmd("PART", Gs.chan)
	else
		for _,v in ipairs(args) do
			irc.writecmd("PART", v)
		end
	end
end)

reg({"quit", tag.basic}, function(line, args)
	-- remember all caps when you spell the command's name
	if args[0] == "QUIT" then
		args = util.parsecmd(line, 1)
		irc.writecmd("QUIT", args[1] or config.quit_msg)
		os.exit(0)
	else
		print(i18n.quit_failsafe)
	end
end)

reg({"close", tag.basic}, function(line, args)
	local chan = args[1] or Gs.chan

	if buffers:is_special(chan) then
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
end)

reg({"msg", "q", "query", tag.basic}, function(line, args)
	local args = util.parsecmd(line, 2)
	if #args == 2 then
		irc.writecmd("PRIVMSG", args[1], args[2])
		ui.hint_silence(i18n.hint.query)
	else
		printf("usage: /%s [user] blah blah blah", args[0])
	end
end)

reg({"action", "me", tag.basic}, function(line, args)
	if not Gs.chan then
		print("you must enter a channel first")
		return
	end
	local content = util.parsecmd(line, 1)[1] or ""
	irc.writecmd("PRIVMSG", Gs.chan, "\1ACTION "..content.."\1")
end)

reg({"lua", tag.devel}, function(line, args)
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
end)

reg({"buffers", "bufs", "ls", tag.basic}, function()
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
end)

reg({"help", tag.basic}, function(line, args)
	local what = args[1]
	printf("-- %s", line)

	if what == nil then
		for _, cmd in ipairs(tbl) do
			print(cmd:help(true))
		end
		print()
		print(i18n.help.main)
	elseif string.match(what, "^/") then
		local cmd = tbl[string.sub(what, 2)]
		if cmd then
			print(cmd:help(false))
		else
			printf(i18n.help._unknowncmd, what)
		end
	else
		local s = i18n.help[what or "main"]
		if s then
			print(s)
		else
			printf(i18n.help._unknown, what)
			if tbl[what] then
				printf([[Did you mean "/help /%s"?]], what)
			end
		end
	end
	print()
end)

reg({"who", "nicks", tag.basic}, function(line, args)
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
end)

-- "b" set in default config
reg({"buffer", "buf", tag.basic}, function(line, args)
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
end)

reg({"topic", tag.oper}, function(line, args)
	if #args == 0 then
		irc.writecmd("TOPIC", Gs.chan)
	else
		local topic = util.parsecmd(line, 1)[1]
		irc.writecmd("TOPIC", Gs.chan, topic)
	end
end)

reg({"list", tag.basic}, function(line, args)
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
end)

reg({"config", tag.basic}, function(line, args)
	local function execf(...)
		local cmd = string.format(...)
		printf("$ %s", cmd)
		return os.execute(cmd)
	end

	local path = {}
	for p in string.gmatch(package.path, "[^;]+%?[^;]+") do
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
		printf("Try \"/config edit\".\n")
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
		if editor == "" then
			editor = "nano"
		end
		local cmd = string.format([[%s "%s"]], editor, path[1])
		ext.run(cmd, "/config edit", {
			callback = function ()
				util.config_load()
				if not os.getenv("EDITOR") then
					ui.hint(i18n.hint.editor)
				end
				print("config reloaded!")
			end,
			tty = true, -- don't override stdin
		})
	else
		print("usage: /config [edit]")
	end
end)

reg({"raw", tag.devel}, function(line, args)
	args = util.parsecmd(line, 1)
	irc.writecmd(args[1])
end)

reg({"history", "his", "h", tag.basic}, function(line, args)
	local buf, amt
	buf = Gs.chan
	if #args >= 3 then
		-- TODO generic usage command
		print("too many arguments")
	end
	if args[1] then
		if Gs.buffers[args[1]] then
			buf = args[1]
		elseif #args == 1 then
			amt = tonumber(args[1])
			if not amt then
				printf("\"%s\" is neither a buffer or a number", args[1])
				return
			end
		else
			printf("\"%s\" is not a valid buffer", args[1])
			return
		end
	end
	if args[2] then
		amt = tonumber(args[2])
		if not amt then
			printf("\"%s\" is not a number", args[2])
			return
		end
	end
	buffers:print(buf, amt)
end)

return commands

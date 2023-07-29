-- "capi" is provided by C
require "tests"
require "util"
require "irc"
require "commands"
require "buffers"
require "i18n"
require "ui"
-- also see eof

-- for functions called by C
cback = {}

conn = {
	user = nil,
	active = false,
	nick_idx = 1, -- for the initial nick
	-- i don't care if the nick gets ugly, i need to connect ASAP to prevent
	-- the connection from dropping

	chan = nil,
}


-- The whole external program piping shebang.
-- Basically: if an external program is launched, print() should
--            either buffer up the input to show later, or pipe it
--            to the program.
ext = {}
ext.running = false
ext.ringbuf = nil
ext._pipe = false
ext.reason = nil
ext.eof = capi.ext_eof
function print(...)
	if ext.running then
		if ext._pipe then
			local args = {...}
			for k,v in ipairs(args) do
				if type(v) == "string" then
					args[k] = ui.strip_ansi(v)
				end
			end
			capi.print_internal(table.unpack(args))
		else
			ext.ringbuf:push({...})
		end
	else
		capi.print_internal(...)
	end
end

function ext.run(cmdline, reason)
	if ext.running then return end
	ext.running = true
	ext.ringbuf = ringbuf:new(500)
	capi.ext_run_internal(cmdline)
	ext._pipe = false
	ext.reason = reason
end

-- true:  print()s should be passed to the external process
-- false: print()s should be cached until the ext process quits
function ext.setpipe(b)
	ext._pipe = b
end

function cback.ext_quit()
	ext.running = false
	-- TODO notify the user if the ringbuf overflowed
	capi.print_internal("printing the messages you've missed...")
	for v in ext.ringbuf:iter(ext.ringbuf) do
		capi.print_internal(table.unpack(v))
	end
	ext.ringbuf = nil
	ext.reason = nil
end


function cback.init(...)
	local argv = {...}
	local host = argv[2] or "localhost"
	local port = argv[3] or "6667"
	if not capi.dial(host, port) then
		printf("couldn't connect to %s:%s :(", host, port)
		os.exit(1)
	end

	local default_name = os.getenv("USER") or "townie"
	config.nick = config.nick or default_name -- a hack
	conn.user = config.nick
	printf(i18n.connecting, hi(conn.user))
	irc.writecmd("USER", config.ident.username or default_name, "0", "*",
	                 config.ident.realname or default_name)
	irc.writecmd("NICK", conn.user)
	capi.history_resize(config.history_size)

	conn.chan = nil

	buffers:make(":mentions")
	buffers.tbl[":mentions"].printcmd = function (self, ent)
		ui.printcmd(ent.line, ent.ts, ent.buf)
	end
	buffers.tbl[":mentions"].onswitch = function (self)
		for k,v in pairs(buffers.tbl) do
			v.mentions = 0
		end
	end
end

function cback.disconnected()
	-- TODO do something reasonable
	conn.active = false
	print([[you got disconnected from the server :/]])
	print([[restart hewwo with "/QUIT" to reconnect]])
end

function cback.in_net(line)
	if config.debug then
		print("<=", ui.escape(line))
	end
	irc.newcmd(line, true)
	ui.updateprompt()
end

function cback.in_user(line)
	if line == "" then return end
	if line == nil then
		ui.hint(i18n.quit_hint)
		return
	end
	capi.history_add(line)

	if string.sub(line, 1, 1) == "/" then
		if string.sub(line, 2, 2) == "/" then
			line = string.sub(line, 2)
			irc.writecmd("PRIVMSG", conn.chan, line)
		else
			local args = cmd_parse(line)
			local cmd = commands[string.lower(args[0])]
			if cmd then
				cmd(line, args)
			else
				print("unknown command \"/"..args[0].."\"")
			end
		end
	elseif conn.chan then
		if string.sub(conn.chan, 1, 1) == ":" then
			printf(i18n.err_rochan, conn.chan)
		else
			irc.writecmd("PRIVMSG", conn.chan, line)
		end
	else
		print(i18n.err_nochan)
	end
	ui.updateprompt()
end

function cback.completion(line)
	local tbl = {}
	local word = string.match(line, "[^ ]*$") or ""
	if word == "" then return {} end
	local wlen = string.len(word)
	local rest = string.sub(line, 1, -string.len(word)-1)

	local function addfrom(src, prefix, suffix)
		if not src then return end
		prefix = prefix or ""
		suffix = suffix or " "
		local wlen = string.len(word)
		for k, v in pairs(src) do
			k = prefix..k..suffix
			if v and wlen < string.len(k) and word == string.sub(k, 1, wlen) then
				table.insert(tbl, rest..k)
			end
		end
	end

	local buf = buffers.tbl[conn.chan]
	if buf then
		if word == line then
			addfrom(buf.users, "", ": ")
		else
			addfrom(buf.users)
		end
	end
	addfrom(buffers.tbl)
	addfrom(commands, "/")
	return tbl
end

config = {}
config.ident = {}
config.color = {}
require "config_default"
require "config" -- last so as to let it override stuff

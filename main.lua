-- Used for initializing packages without breaking circular dependencies.
-- Must be called before any requires, and the argument must match what will
-- be used for the require() calls. Passing ... works, because the first
-- argument to a chunk is the module name, and the other arguments are ignored.
-- See the other files for examples.
function safeinit(name)
	package.loaded[name] = package.loaded[name] or {}
	return package.loaded[name]
end


-- "capi" is provided by C
local Gs = require "state"
local argv = require "argv"
local buffers = require "buffers"
local commands = require "commands"
local i18n = require "i18n"
local irc = require "irc"
local ringbuf = require "ringbuf"
local ui = require "ui"
local util = require "util"
-- also see eof

-- for functions called by C
cback = {}

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

function printf(...)
	print(string.format(...))
end

function ext.run(cmdline, reason, opts)
	if ext.running then return end
	opts = opts or {}

	-- TODO move into a separate file and put most stuff into locals
	ext.running = true
	ext.ringbuf = ringbuf:new(1000)
	ext._pipe = false
	ext.reason = reason
	ext.callback = opts.callback
	capi.ext_run_internal(cmdline, opts.tty)
end

-- true:  print()s should be passed to the external process
-- false: print()s should be cached until the ext process quits
function ext.setpipe(b)
	ext._pipe = b
end

function cback.ext_quit()
	ext.running = false
	print("printing the messages you've missed...")
	if ext.ringbuf:full() then
		print("note: some older messages were dropped, so this isn't a complete list")
	end
	for v in ext.ringbuf:iter(ext.ringbuf) do
		print(table.unpack(v))
	end
	if ext.callback then ext.callback() end
	ext.callback = nil
	ext.ringbuf = nil
	ext.reason = nil
end


function cback.init(...)
	util.config_load()

	local opts = argv.parse{...}

	local host = opts.host or config.host
	local port = opts.port or config.port
	Gs.user = opts.nick or config.nick or "nil"
	if not capi.dial(host, port) then
		printf("couldn't connect to %s:%s :(", host, port)
		os.exit(1)
	end

	printf(i18n.connecting, ui.highlight(Gs.user))
	irc.writecmd("USER", config.ident.username or Gs.user, "0", "*",
	                     config.ident.realname or Gs.user)
	irc.writecmd("NICK", Gs.user)
	capi.history_resize(config.input_history)

	Gs.chan = nil

	buffers:make(":mentions")
	Gs.buffers[":mentions"].printcmd = function (self, ent)
		ui.printcmd(ent, ent.buf)
	end
	Gs.buffers[":mentions"].onswitch = function (self)
		for _,v in pairs(Gs.buffers) do
			v.mentions = 0
		end
	end
end

function cback.disconnected()
	-- TODO do something reasonable
	Gs.active = false
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
		ui.hint(i18n.hint.quit)
		return
	end
	capi.history_add(line)

	if string.sub(line, 1, 1) == "/" then
		if string.sub(line, 2, 2) == "/" then
			line = string.sub(line, 2)
			irc.writecmd("PRIVMSG", Gs.chan, line)
		else
			local args = util.parsecmd(line)
			local cmd = string.lower(args[0])
			local impl

			impl = config.commands[cmd] or commands[cmd]
			local i = 0
			while type(impl) == "string" do -- resolve aliases recursively
				impl = config.commands[impl] or commands[impl]
				i = i + 1
				if i >= 100 then
					printf(i18n.alias_loop, cmd)
					break
				end
			end
			if type(impl) == "function" then
				impl(line, args)
			else
				printf([[unknown command "/%s"]], cmd)
			end
		end
	elseif Gs.chan then
		if string.sub(Gs.chan, 1, 1) == ":" then
			printf(i18n.err_rochan, Gs.chan)
		else
			irc.writecmd("PRIVMSG", Gs.chan, line)
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
		for k, v in pairs(src) do
			k = prefix..k..suffix
			if v and wlen < string.len(k) and word == string.sub(k, 1, wlen) then
				table.insert(tbl, rest..k)
			end
		end
	end

	local buf = Gs.buffers[Gs.chan]
	if buf then
		if word == line then
			addfrom(buf.users, "", ": ")
		else
			addfrom(buf.users)
		end
	end
	addfrom(Gs.buffers)
	addfrom(commands, "/")
	return tbl
end

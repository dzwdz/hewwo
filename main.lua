-- the C api provides:
-- writesock, setprompt, history_{add,resize}
-- print_internal, ext_run_internal, ext_eof

-- requires: init, in_net, in_user, completion, ext_quit

-- TODO just put the provided stuff in capi.
--      and the required stuff in, idk, cback.

require "tests"
require "util"
require "irc"
require "commands"
require "buffers"
require "i18n"
-- also see eof

conn = {
	user = nil,
	nick_verified = false,
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
ext.eof = ext_eof
function print(...)
	if ext.running then
		if ext._pipe then
			local args = {...}
			for k,v in ipairs(args) do
				if type(v) == "string" then
					args[k] = ansi_strip(v)
				end
			end
			print_internal(table.unpack(args))
		else
			ext.ringbuf:push({...})
		end
	else
		print_internal(...)
	end
end

function ext.run(cmdline, reason)
	if ext.running then return end
	ext.running = true
	ext.ringbuf = ringbuf:new(500)
	ext_run_internal(cmdline)
	ext._pipe = false
	ext.reason = reason
end

-- true:  print()s should be passed to the external process
-- false: print()s should be cached until the ext process quits
function ext.setpipe(b)
	ext._pipe = b
end

function ext_quit()
	ext.running = false
	-- TODO notify the user if the ringbuf overflowed
	print_internal("printing the messages you've missed...")
	for v in ext.ringbuf:iter(ext.ringbuf) do
		print_internal(table.unpack(v))
	end
	ext.ringbuf = nil
	ext.reason = nil
end


function init()
	local default_name = os.getenv("USER") or "townie"
	config.nick = config.nick or default_name -- a hack
	conn.user = config.nick
	printf(i18n.connecting, hi(conn.user))
	writecmd("USER", config.ident.username or default_name, "0", "*",
	                 config.ident.realname or default_name)
	writecmd("NICK", conn.user)
	history_resize(config.history_size)

	conn.chan = nil
end

function in_net(line)
	if config.debug then
		print("<=", escape(line))
	end
	newcmd(line, true)
	updateprompt()
end

function in_user(line)
	if line == "" then return end
	if line == nil then
		hint(i18n.quit_hint)
		return
	end
	history_add(line)

	if string.sub(line, 1, 1) == "/" then
		if string.sub(line, 2, 2) == "/" then
			line = string.sub(line, 2)
			writecmd("PRIVMSG", conn.chan, line)
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
		writecmd("PRIVMSG", conn.chan, line)
	else
		print("you need to enter a channel to chat. try \"/join #tildetown\"")
	end
	updateprompt()
end

-- Called for new commands, both from the server and from the client.
function newcmd(line, remote)
	local args = parsecmd(line)
	local from = args.user
	local cmd = string.upper(args[1])
	local to = args[2] -- not always valid!

	if not remote and not (cmd == "PRIVMSG" or cmd == "NOTICE") then
		-- (afaik) all other messages are echoed back at us
		return
	end

	if cmd == "PRIVMSG" or cmd == "NOTICE" then
		-- TODO strip first `to` character for e.g. +#tildetown

		if not args.ctcp or args.ctcp.cmd == "ACTION" then
			-- TODO factor out dm checking for consistency
			if to == conn.user then -- direct message
				buffers:push(from, line, 1)
			else
				local msg
				if not args.ctcp then
					msg = args[3]
				else
					msg = args.ctcp.params or ""
				end

				local urgency = 0
				if string.match(msg, nick_pattern(conn.user)) or from == conn.user then
					urgency = 1
				end
				buffers:push(to, line, urgency)
			end
		end

		if cmd == "PRIVMSG" and args.ctcp and remote then
			if args.ctcp.cmd == "VERSION" then
				writecmd("NOTICE", from, "\1VERSION hewwo\1")
			elseif args.ctcp.cmd == "PING" then
				writecmd("NOTICE", from, args[3])
			end
		end
	elseif cmd == "JOIN" then
		buffers:push(to, line)
		if from == conn.user then
			buffers.tbl[to].connected = true
		end
		buffers.tbl[to].users[from] = true
	elseif cmd == "PART" then
		buffers:push(to, line)
		if from == conn.user then
			buffers.tbl[to].connected = false
			buffers.tbl[to].users = {}
		end
		buffers.tbl[to].users[from] = nil
	elseif cmd == "INVITE" then
		buffers:push(from, line, 1)
	elseif cmd == "QUIT" then
		local urgency = 0
		if from == conn.user then
			-- print manually
			urgency = -1
			printcmd(line, os.time())
		end
		for chan,buf in pairs(buffers.tbl) do
			if buf.users[from] then
				buffers:push(chan, line, urgency)
				buf.users[from] = nil
			end
		end
	elseif cmd == "NICK" then
		local urgency = 0
		if from == conn.user then
			conn.user = to
			-- print manually
			urgency = -1
			printcmd(line, os.time())
		end
		for chan,buf in pairs(buffers.tbl) do
			if buf.users[from] then
				buffers:push(chan, line, urgency)
				buf.users[from] = nil
				buf.users[to] = true
			end
		end
	elseif cmd == RPL_ENDOFMOTD or cmd == ERR_NOMOTD then
		conn.nick_verified = true
		print(i18n.connected)
		print()
	elseif cmd == RPL_TOPIC then
		buffers:push(args[3], line)
	elseif cmd == "TOPIC" then
		local urgency = 0
		if from == conn.user then urgency = 1 end
		buffers:push(to, line, urgency)
	elseif cmd == RPL_LIST or cmd == RPL_LISTEND then
		-- TODO list output should probably be pushed into a server buffer
		-- but switching away from the current buffer could confuse users?

		if ext.reason == "list" then ext.setpipe(true) end
		printcmd(line, os.time())
		if ext.reason == "list" then ext.setpipe(false) end
	elseif cmd == ERR_NICKNAMEINUSE then
		if conn.nick_verified then
			printf("%s is taken, leaving your nick as %s", hi(args[3]), hi(conn.user))
		else
			local new = config.nick .. conn.nick_idx
			conn.nick_idx = conn.nick_idx + 1
			printf("%s is taken, trying %s", hi(conn.user), hi(new))
			conn.user = new
			writecmd("NICK", new)
		end
	elseif string.sub(cmd, 1, 1) == "4" then
		-- TODO the user should never see this. they should instead see friendlier
		-- messages with instructions how to proceed
		printf("irc error %s: %s", cmd, args[#args])
	elseif cmd == "PING" then
		writecmd("PONG", to)
	elseif cmd == RPL_NAMREPLY then
		to = args[4]
		buffers:make(to)
		-- TODO incorrect nick parsing
		for nick in string.gmatch(args[5], "[^ ,*?!@]+") do
			buffers.tbl[to].users[nick] = true
		end
	end
end

function completion(line)
	local tbl = {}
	local word = string.match(line, "[^ ]*$") or ""
	if word == "" then return {} end
	local wlen = string.len(word)
	local rest = string.sub(line, 1, -string.len(word)-1)

	local function addfrom(src, prefix, suffix)
		if not src then return end
		prefix = prefix or ""
		suffix = suffix or " "
		local word = string.sub(word, string.len(prefix) + 1)
		local wlen = string.len(word)
		for k, v in pairs(src) do
			k = prefix..k..suffix
			if v and wlen < string.len(k) and word == string.sub(k, 1, wlen) then
				table.insert(tbl, rest..k)
			end
		end
	end

	if conn.chan ~= nil then
		if word == line then
			addfrom(buffers.tbl[conn.chan].users, "", ": ")
		else
			addfrom(buffers.tbl[conn.chan].users)
		end
	end
	addfrom(buffers.tbl)
	addfrom(commands, "/")
	return tbl
end

function updateprompt()
	local chan = conn.chan or "nowhere"
	local unread, mentions = buffers:count_unread()
	setprompt(string.format("[%d!%d %s]: ", unread, mentions, chan))
end

-- Prints an IRC command.
function printcmd(rawline, ts, urgent_buf)
	local timefmt = os.date(config.timefmt, ts)
	local prefix = timefmt
	if urgent_buf then
		prefix = string.format("%s%s: ", prefix, urgent_buf)
	end

	local args = parsecmd(rawline)
	local from = args.user
	local cmd = string.upper(args[1])
	local to = args[2] -- not always valid!
	local fmt = ircformat

	if cmd == "PRIVMSG" or cmd == "NOTICE" then
		local action = false
		local private = false
		local notice = cmd == "NOTICE"

		local userpart = ""
		local msg = args[3]

		-- TODO strip unprintable
		if string.sub(to, 1, 1) ~= "#" then
			private = true
		end
		if args.ctcp and args.ctcp.cmd == "ACTION" then
			action = true
			msg = args.ctcp.params
		end

		msg = fmt(msg)
		-- highlight own nick
		msg = string.gsub(msg, nick_pattern(conn.user), hi(conn.user))

		if private then
			-- the original prefix might also include the buffer,
			-- which is redundant
			prefix = timefmt

			if notice then
				userpart = string.format("-%s:%s-", hi(from), hi(to))
			elseif action then
				userpart = string.format("[%s -> %s] * %s", hi(from), hi(to), hi(from))
			else
				userpart = string.format("[%s -> %s]", hi(from), hi(to))
			end
		else
			if notice then
				userpart = string.format("-%s:%s-", hi(from), to)
			elseif action then
				userpart = string.format("* %s", hi(from))
			else
				userpart = string.format("<%s>", hi(from))
			end
		end
		print(prefix .. userpart .. " " .. msg)

		if private and from ~= conn.user then
			hint(i18n.query_hint, from)
		end
	elseif cmd == "JOIN" then
		printf("%s--> %s has joined %s", prefix, hi(from), to)
	elseif cmd == "PART" then
		printf("%s<-- %s has left %s", prefix, hi(from), to)
	elseif cmd == "INVITE" then
		printf("%s%s has invited you to %s", prefix, hi(from), args[3])
	elseif cmd == "QUIT" then
		printf("%s<-- %s has quit (%s)", prefix, hi(from), fmt(args[2]))
	elseif cmd == "NICK" then
		printf("%s%s is now known as %s", prefix, hi(from), hi(to))
	elseif cmd == RPL_TOPIC then
		printf([[%s-- %s's topic is "%s"]], prefix, args[3], fmt(args[4]))
	elseif cmd == "TOPIC" then
		-- TODO it'd be nice to store the old topic
		printf([[%s%s set %s's topic to "%s"]], prefix, from, to, fmt(args[3]))
	elseif cmd == RPL_LIST then
		if ext.reason == "list" then
			prefix = "" -- don't include the hour
		end
		if args[5] ~= "" then
			printf([[%s%s, %s users, %s]], prefix, args[3], args[4], fmt(args[5]))
		else
			printf([[%s%s, %s users]], prefix, args[3], args[4])
		end
	elseif cmd == RPL_LISTEND then
		printf(i18n.list_after)
		ext.eof()
	else
		-- TODO config.debug levels
		printf([[error in hewwo: printcmd can't handle "%s"]], cmd)
	end
end

config = {}
config.ident = {}
require "config_default"
require "config" -- last so as to let it override stuff

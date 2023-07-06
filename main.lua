-- the C api provides: writesock, setprompt, history_{add,resize}
--           requires: init, in_net, in_user, completion

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

function init()
	if not config.nick then
		-- hack
		config.nick = os.getenv("USER") or "townie"
	end
	conn.user = config.nick
	printf(i18n.connecting, hi(conn.user))
	writecmd("USER", conn.user, "0", "*", config.ident.real_name)
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
	local prefix, from, args = parsecmd(line)
	local cmd = string.upper(args[1])
	local to = args[2] -- not always valid!

	if not remote and cmd ~= "PRIVMSG" then
		-- (afaik) all other messages are echoed back at us
		return
	end

	if cmd == "PRIVMSG" then
		local msg = args[3]
		-- TODO will incorrectly detect pings in CTCP verbs

		if to == conn.user then -- direct message
			buffers:push(from, line, 1)
		else
			local urgency = 0
			if string.match(msg, nick_pattern(conn.user)) or from == conn.user then
				urgency = 1
			end
			buffers:push(to, line, urgency)
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

	if word == line then
		addfrom(buffers.tbl[conn.chan].users, "", ": ")
	else
		addfrom(buffers.tbl[conn.chan].users)
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
	local out_prefix = timefmt
	if urgent_buf then
		out_prefix = string.format("%s %s:", out_prefix, urgent_buf)
	end

	local prefix, from, args = parsecmd(rawline)
	local cmd = string.upper(args[1])
	local to = args[2] -- not always valid!

	if cmd == "PRIVMSG" then
		local msg = args[3]
		local action = false
		local private = false

		-- TODO strip unprintable
		if string.sub(to, 1, 1) ~= "#" then
			private = true
		end
		if string.sub(msg, 1, 1) == "\1" then
			-- CTCP
			msg = string.gsub(string.sub(msg, 2), "\1$", "")
			local ctcp_cmd = string.upper(string.match(msg, "^[^\0\1\r\n ]+"))
			if ctcp_cmd == "ACTION" then
				action = true
				msg = string.sub(msg, 8)
			else
				return -- unknown command
			end
		end

		msg = escape(msg)
		-- highlight own nick
		msg = string.gsub(msg, nick_pattern(conn.user), hi(conn.user))

		if private then
			if action then
				msg = string.format("* %s %s", hi(from), msg)
			end
			msg = string.format("[%s -> %s] %s", hi(from), hi(to), msg)
			-- printing the buffer is redundant
			printf("%s %s", timefmt, msg)
		else
			if action then
				msg = string.format("* %s %s", hi(from), msg)
			else
				msg = string.format("<%s> %s", hi(from), msg)
			end
			printf("%s %s", out_prefix, msg)
		end

		if private and from ~= conn.user then
			hint(i18n.query_hint, from)
		end
	elseif cmd == "JOIN" then
		printf("%s --> %s has joined %s", out_prefix, hi(from), to)
	elseif cmd == "PART" then
		printf("%s <-- %s has left %s", out_prefix, hi(from), to)
	elseif cmd == "INVITE" then
		printf("%s %s has invited you to %s", out_prefix, hi(from), args[3])
	elseif cmd == "QUIT" then
		printf("%s <-- %s has quit (%s)", out_prefix, hi(from), args[2])
	elseif cmd == "NICK" then
		printf("%s %s is now known as %s", out_prefix, hi(from), hi(to))
	else
		-- TODO config.debug levels
		printf([[error in hewwo: printcmd can't handle "%s"]], cmd)
	end
end

config = {}
config.ident = {}
require "config_default"
require "config" -- last so as to let it override stuff

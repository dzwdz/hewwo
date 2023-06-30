-- the C api provides: writesock, setprompt
--           requires: init, in_net, in_user, completion

require "irc"
require "commands"
require "util"
require "buffers"
-- also see eof

conn = {
	user = nil,
	nick_verified = false,
	nick_idx = 1, -- for the initial nick
	-- i don't care if the nick gets ugly, i need to connect ASAP to prevent
	-- the connection from dropping

	chan = nil,
	pm_hint = nil,
	quit_hint = nil,
	chanusers = {},
}

function init()
	if not config.nick then
		-- hack
		config.nick = os.getenv("USER") or "townie"
	end
	conn.user = config.nick
	printf("logging you in as %s. if you don't like that, try /nick", hi(conn.user))
	writecmd("USER", conn.user, "localhost", "servername", "Real Name")
	writecmd("NICK", conn.user)

	conn.chan = nil
end

function in_net(line)
	if config.debug then
		print("<=", line)
	end
	newcmd(line, true)
	updateprompt()
end

function in_user(line)
	if line == "" then return end
	if line == nil then
		if not conn.quit_hint then
			print("hint: if you meant to quit, try /QUIT")
		end
		conn.quit_hint = true
		return
	end

	if string.sub(line, 1, 1) == "/" then
		if string.sub(line, 2, 2) == "/" then
			line = string.sub(line, 2)
			writecmd("PRIVMSG", conn.chan, line)
		else
			local args = {}
			for arg in string.gmatch(string.sub(line, 2), "[^ ]+") do
				table.insert(args, arg)
			end
			local cmd = commands[string.lower(args[1])]
			if cmd then
				cmd(line, table.unpack(args, 2))
			else
				print("unknown command \"/"..args[1].."\"")
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
	printcmd(line, os.time(), remote)

	local prefix, from, args = parsecmd(line)
	local cmd = string.upper(args[1])
	local to = args[2] -- not always valid!

	if cmd == "PRIVMSG" then
		if to == conn.user then
			buffers:append(from, line)
		else
			buffers:append(to, line)
		end
	end

	if remote then
		if cmd == "JOIN" then
			buffers:append(to, line)
			if from == conn.user then
				buffers.tbl[to].state = "connected"
			end
			if conn.chanusers[to] then
				conn.chanusers[to][from] = true
			end
		elseif cmd == "PART" then
			buffers:append(to, line)
			if from == conn.user then
				buffers.tbl[to].state = "parted"
				conn.chanusers[to] = {}
			end
			if conn.chanusers[to] then
				conn.chanusers[to][from] = nil
			end
		elseif cmd == "QUIT" then
			for chan,set in pairs(conn.chanusers) do
				if set[from] then
					buffers:append(chan, line)
					set[from] = nil
				end
			end
		elseif cmd == "NICK" then
			if from == conn.user then
				conn.user = to
			end
			for chan,set in pairs(conn.chanusers) do
				if set[from] then
					buffers:append(chan, line)
					set[from] = nil
					set[to] = true
				end
			end
		elseif cmd == RPL_ENDOFMOTD or cmd == ERR_NOMOTD then
			conn.nick_verified = true
			-- NOT in printcmd, as it's more of a reaction to state change
			print([[ok, i'm connected! try "/join #newbirc" or "/help"]])
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
			conn.chanusers[to] = conn.chanusers[to] or {}
			-- TODO incorrect nick parsing
			-- TODO update on JOIN/PART
			for nick in string.gmatch(args[5], "[^ ,*?!@]+") do
				conn.chanusers[to][nick] = true
			end
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
		addfrom(conn.chanusers[conn.chan], "", ": ")
	else
		addfrom(conn.chanusers[conn.chan])
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

function is_mention(line)
	local prefix, from, args = parsecmd(line)
	local cmd = string.upper(args[1])
	if cmd == "PRIVMSG" and string.match(args[3], nick_pattern(conn.user)) then
		return true
	end
	-- TODO kicks, mode changes, et al
	return false
end

-- Prints an IRC command, if applicable.
-- returns true if anything was output, false otherwise
function printcmd(rawline, ts, remote)
	local timefmt = os.date(config.timefmt, ts)

	local prefix, from, args = parsecmd(rawline)
	local cmd = string.upper(args[1])
	local to = args[2] -- not always valid!

	if cmd == "PRIVMSG" then
		local msg = args[3]
		local action = false
		local private = false

		local nickpat = nick_pattern(conn.user)

		-- TODO strip unprintable
		if string.sub(to, 1, 1) ~= "#" then -- direct message, always print
			private = true
			mention = true
		elseif string.match(msg, nickpat) then
			mention = true
		elseif to ~= conn.chan then
			return false
		end

		if string.sub(msg, 1, 7) == "\1ACTION" then
			action = true
			msg = string.sub(msg, 9)
		end

		-- highlight own nick
		msg = string.gsub(msg, nickpat, hi(conn.user))

		if private and action then
			msg = string.format("* %s %s", hi(from), msg)
			msg = string.format("[%s -> %s] %s", hi(from), hi(to), msg)
		elseif private then
			msg = string.format("[%s -> %s] %s", hi(from), hi(to), msg)
		elseif action then
			msg = string.format("* %s %s", hi(from), msg)
		else
			msg = string.format("<%s> %s", hi(from), msg)
		end
		if not private and to ~= conn.chan then
			-- mention = true
			msg = string.format("%s: %s", to, msg)
		end
		printf("%s %s", timefmt, msg)

		if private and not conn.pm_hint and from ~= conn.user then
			printf([[hint: you've just received a private message!]])
			printf([[      try "/msg %s [your reply]"]], from)
			conn.pm_hint = true
		end
		return true
	elseif cmd == "JOIN" then
		if to ~= conn.chan then return false end
		printf("%s --> %s has joined %s", timefmt, hi(from), to)
		return true
	elseif cmd == "PART" then
		if to ~= conn.chan then return false end
		printf("%s <-- %s has left %s", timefmt, hi(from), to)
		return true
	elseif cmd == "INVITE" then
		if to ~= conn.user then return false end
		printf("%s %s has invited you to %s", timefmt, hi(from), args[3])
		return true
	elseif cmd == "QUIT" then
		-- TODO print QUITs only in the relevant channel?
		-- making this work in scrollback would be complicated
		--
		-- maybe printcmd could only be called from writecmd after parsing?
		printf("%s <-- %s has quit (%s)", timefmt, hi(from), args[2])
	elseif cmd == "NICK" then
		if remote then
			printf("%s %s is now known as %s", timefmt, hi(from), hi(to))
		end
	end
	return false
end

config = {}
require "config_default"
require "config" -- last so as to let it override stuff

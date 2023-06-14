-- the C api provides: writesock, setprompt
--           requires: init, in_net, in_user, completion

require "irc"
require "commands"
require "util"
require "ringbuf"
-- also see eof

conn = {
	user = nil,
	chan = nil,
	pm_hint = nil,
	chanusers = {},
}
buffers = {
	tbl = {},
}

function init()
	conn.user = config.nick or os.getenv("USER") or "townie"
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
	printcmd(line, os.time())

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
		if cmd == "JOIN" or cmd == "PART" then
			buffers:append(to, line)
			if from == conn.user then
				if cmd == "JOIN" then
					buffers.tbl[to].state = "connected"
				else
					buffers.tbl[to].state = "parted"
				end
			end
		elseif cmd == RPL_ENDOFMOTD or cmd == ERR_NOMOTD then
			-- NOT in printcmd, as it's more of a reaction to state change
			print("ok, i'm connected! try \"/join #tildetown\"")
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
			if v and wlen < string.len(k) and word == string.sub(k, 1, wlen) then
				table.insert(tbl, rest..prefix..k..suffix)
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
	local chan = conn.chan or ""
	local unread = 0
	for _, buf in pairs(buffers.tbl) do
		-- TODO this is inefficient
		-- either compute another way, or call updateprompt() less
		if buf.unread > 0 then
			unread = unread + 1
		end
	end
	setprompt(string.format("%d %s: ", unread, chan))
end

function buffers:switch(chan)
	printf("--- switching to %s", chan)
	conn.chan = chan
	if self.tbl[chan] then
		-- TODO remember last seen message to prevent spam?
		for ent in self.tbl[chan]:iter() do
			printcmd(ent.line, ent.ts)
		end
		self.tbl[chan].unread = 0
	else
		-- TODO error out
		print("-- (creating buffer)")
	end
end

function buffers:append(buf, line)
	local ts = os.time()
	self:make(buf)
	local b = self.tbl[buf]
	b:push({line=line, ts=ts})
	if buf ~= conn.chan then
		self.tbl[buf].unread = self.tbl[buf].unread + 1
	end
end

function buffers:make(buf)
	if not self.tbl[buf] then
		self.tbl[buf] = ringbuf:new(200)
		self.tbl[buf].state = "unknown"
		self.tbl[buf].unread = 0
	end
end

-- Prints an IRC command, if applicable.
-- returns true if anything was output, false otherwise
function printcmd(rawline, ts)
	local timefmt = os.date(config.timefmt, ts)

	local prefix, from, args = parsecmd(rawline)
	local cmd = string.upper(args[1])
	local to = args[2] -- not always valid!

	if cmd == "PRIVMSG" then
		local msg = args[3]

		-- TODO strip unprintable
		if string.sub(to, 1, 1) ~= "#" then -- direct message, always print
			if string.sub(msg, 1, 7) == "\1ACTION" then
				msg = string.sub(msg, 9)
				msg = string.format("* %s %s", hi(from), msg)
			end
			printf("%s [%s -> %s] %s", timefmt, hi(from), hi(to), msg)
			if not conn.pm_hint and from ~= conn.user then
				print("(hint: you've just received a private message!")
				print("       try \"/msg "..from.." [your reply]\")")
				conn.pm_hint = true
			end
			return true
		elseif to == conn.chan then
			-- string.len("ACTION ") == 7
			if string.sub(msg, 1, 7) == "\1ACTION" then
				msg = string.sub(msg, 9)
				printf("%s * %s %s", timefmt, hi(from), msg)
			else
				printf("%s <%s> %s", timefmt, hi(from), msg)
			end
			return true
		else
			return false
		end
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
	end
	return false
end

config = {}
require "config_default"
require "config" -- last so as to let it override stuff

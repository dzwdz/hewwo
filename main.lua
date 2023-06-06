-- the C api provides: writesock, setprompt
--           requires: init, in_net, in_user, completion

require "irc"
require "commands"
require "util"
require "ringbuf"
-- also see eof

conn = {
	user = nil,
	pm_hint = nil,
}
buffers = {}

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
end

function in_user(line)
	if string.sub(line, 1, 1) == "/" then
		if string.sub(line, 2, 2) == "/" then
			line = string.sub(line, 2)
			message(conn.user, conn.chan, line)
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
end

-- Called for new commands, both from the server and from the client.
function newcmd(line, remote)
	printcmd(line, os.time())

	local prefix, from, args = parsecmd(line)
	local cmd = string.upper(args[1])
	local to = args[2] -- not always valid!

	if cmd == "JOIN" or cmd == "PART" then
		buffers:append(to, line)
	elseif cmd == "PRIVMSG" then
		if to ~= conn.user then
			buffers:append(to, line)
		end
	end

	if remote then
		if cmd == RPL_ENDOFMOTD or cmd == ERR_NOMOTD then
			-- NOT in printcmd, as it's more of a reaction to state change
			print("ok, i'm connected! try \"/join #tildetown\"")
		elseif string.sub(cmd, 1, 1) == "4" then
			-- TODO the user should never see this. they should instead see friendlier
			-- messages with instructions how to proceed
			print("irc error: "..args[4])
		elseif cmd == "ping" then
			writecmd("PONG", to)
		end
	end
end

function completion(line)
	local tbl = {}
	if string.sub(line, 1, 1) == "/" and not string.find(line, " ") then
		local cmd = string.sub(line, 2)
		local clen = string.len(line)-1
		for k, _ in pairs(commands) do
			local klen = string.len(k)
			if clen < klen and cmd == string.sub(k, 1, clen) then
				table.insert(tbl, "/"..k)
			end
		end
	end
	return tbl
end

function buffers:switch(chan)
	printf("--- switching to %s", chan)
	conn.chan = chan
	setprompt(chan..": ")
	if buffers[chan] then
		-- TODO remember last seen message to prevent spam?
		for ent in buffers[chan]:iter() do
			printcmd(ent.line, ent.ts)
		end
	else
		-- TODO error out
		print("-- (creating buffer)")
	end
end

function buffers:append(buf, line, ts)
	ts = ts or os.time()
	self:make(buf)
	self[buf]:push({line=line, ts=ts})
end

function buffers:make(buf)
	if not self[buf] then
		self[buf] = ringbuf:new(200)
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
	end
	return false
end

config = {}
require "config_default"
require "config" -- last so as to let it override stuff

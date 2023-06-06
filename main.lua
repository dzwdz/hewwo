-- the C api provides: writesock, setprompt
--           requires: init, in_net, in_user

require "irc"
require "commands"
require "util"

conn = {
	user = nil,
	pm_hint = nil,
}
config = {
	debug = false,
	colors = {"31", "32", "33", "34", "35", "36"},
	timefmt = "\x1b[38;5;8m%H:%M\x1b[0m"
}

function init()
	conn.user = os.getenv("USER") or "townie"
	writecmd("USER", conn.user, "localhost", "servername", "Real Name")
	writecmd("NICK", conn.user)

	conn.chan = nil
end

function in_net(line)
	if config.debug then
		print("<=", line)
	end

	local prefix, user, args = parsecmd(line)
	local cmd = string.lower(args[1])

	if cmd == RPL_ENDOFMOTD or cmd == ERR_NOMOTD then
		print("ok, i'm connected!")
	elseif string.sub(cmd, 1, 1) == "4" then
		-- TODO the user should never see this. they should instead see friendlier
		-- messages with instructions how to proceed
		print("irc error: "..args[4])
	elseif cmd == "privmsg" then
		message(user, args[2], args[3])
	elseif cmd == "join" then
		printf("--> %s has joined %s", hi(user), args[2])
	elseif cmd == "ping" then
		writecmd("PONG", args[2])
	end
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
		message(conn.user, conn.chan, line)
		writecmd("PRIVMSG", conn.chan, line)
	else
		print("you need to enter a channel to chat. try \"/join #tildetown\"")
	end
end

function open_chan(chan)
	printf("--- switched to %s", chan)
	conn.chan = chan
	setprompt(chan..": ")
end

function message(from, to, msg, ts)
	local prefix = os.date(config.timefmt, ts or os.time())

	-- TODO strip unprintable
	if string.sub(to, 1, 1) ~= "#" then -- direct message, always print
		if string.sub(msg, 1, 7) == "\1ACTION" then
			msg = string.sub(msg, 9)
			msg = string.format("* %s %s", hi(from), msg)
		end
		printf("%s [%s -> %s] %s", prefix, hi(from), hi(to), msg)
		if not conn.pm_hint and from ~= conn.user then
			print("hint: you've just received a private message!")
			print("      try \"/msg "..from.." [your reply]\"")
			conn.pm_hint = true
		end
	elseif to == conn.chan then
		-- string.len("ACTION ") == 7
		if string.sub(msg, 1, 7) == "\1ACTION" then
			msg = string.sub(msg, 9)
			printf("%s * %s %s", prefix, hi(from), msg)
		else
			printf("%s <%s> %s", prefix, hi(from), msg)
		end
	end
end

-- the C api provides: writesock, setprompt
--           requires: init, in_net, in_user

-- yes this needs to be organized better. i just wanted to get the port done first

conn = {}
commands = {}
options = {}

RPL_ENDOFMOTD = "376"
ERR_NOMOTD = "422"
ERR_NICKNAMEINUSE = "433"

function writecmd(...)
	local cmd = ""
	-- TODO enforce no spaces
	for i, v in ipairs({...}) do
		if i ~= 1 then
			cmd = cmd .. " "
		end
		if i == #{...} then
			cmd = cmd .. ":"
		end
		cmd = cmd .. v
	end
	if options.debug then
		print("=>", cmd)
	end
	writesock(cmd)
end

function init()
	conn.user = os.getenv("USER") or "townie"
	writecmd("USER", conn.user, "localhost", "servername", "Real Name")
	writecmd("NICK", conn.user)

	conn.chan = nil
end

function in_net(line)
	if options.debug then
		print("<=", line)
	end

	local prefix = nil
	local user = nil
	local args = {}

	-- parse the command
	local pos = 1
	if string.sub(line, 1, 1) == ":" then
		pos = string.find(line, " ")
		if not pos then return end -- invalid message
		prefix = string.sub(line, 2, pos-1)
		pos = pos+1

		excl = string.find(prefix, "!")
		if excl then
			user = string.sub(prefix, 1, excl-1)
		end
	end
	while pos <= string.len(line) do
		local nextpos = nil
		if string.sub(line, pos, pos) ~= ":" then
			nextpos = string.find(line, " ", pos+1)
		else
			pos = pos+1
		end
		if not nextpos then
			nextpos = string.len(line)+1
		end
		table.insert(args, string.sub(line, pos, nextpos-1))
		pos = nextpos+1
	end

	local cmd = string.lower(args[1])

	if cmd == RPL_ENDOFMOTD or cmd == ERR_NOMOTD then
		print("ok, i'm connected!")
	elseif string.sub(cmd, 1, 1) == "4" then
		-- TODO the user should never see this. they should instead see friendlier
		-- messages with instructions how to proceed
		print("irc error: "..args[4])
	elseif cmd == "privmsg" then
		-- TODO printf?
		if args[2] == conn.chan then
			print(string.format("<%s> %s", user, args[3]))
		end
	elseif cmd == "join" then
		print(string.format("--> %s has joined %s", user, args[2]))
	end
end

function in_user(line)
	if string.sub(line, 1, 1) == "/" then
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
	elseif conn.chan then
		print(string.format("<%s> %s", conn.user, line))
		writecmd("PRIVMSG", conn.chan, line)
	else
		print("you need to enter a channel to chat. try \"/join #tildetown\"")
	end
end

function open_chan(chan)
	conn.chan = chan
	setprompt(chan..": ")
end

commands["nick"] = function(_, ...)
	if #{...} ~= 1 then
		print("/nick takes exactly one argument")
		return
	end
	local nick = ...
	-- TODO validate nick
	writecmd("NICK", nick)
	conn.user = nick
	print("your nick is now "..nick)
end

commands["join"] = function(_, ...)
	if #{...} == 0 then
		print("missing argument. try /join #tildetown")
		return
	end
	for i, v in ipairs({...}) do
		writecmd("JOIN", v)
	end
	local last = ({...})[#{...}] -- wonderful syntax
	open_chan(last)
end

commands["quit"] = function(line, ...)
	if line == "/QUIT" then
		writecmd("QUIT")
		os.exit(0)
	end
	print("if you are sure you want to exit, type \"/QUIT\" (all caps)")
end

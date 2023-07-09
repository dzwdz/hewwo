RPL_LIST = "322"
RPL_LISTEND = "323"
RPL_TOPIC = "332"
RPL_NAMREPLY = "353"
RPL_ENDOFMOTD = "376"
ERR_NOMOTD = "422"
ERR_NICKNAMEINUSE = "433"

function writecmd(...)
	local cmd = ""
	-- TODO enforce no spaces
	for i, v in ipairs({...}) do
		if i ~= 1 then
			cmd = cmd .. " "
			if i == #{...} then
				cmd = cmd .. ":"
			end
		end
		cmd = cmd .. v
	end
	if config.debug then
		print("=>", escape(cmd))
	end
	writesock(cmd)

	local verb = string.upper(({...})[1])
	newcmd(":"..conn.user.."!@ "..cmd, false)
end

function parsecmd(line)
	local data = {}

	local pos = 1
	if string.sub(line, 1, 1) == ":" then
		pos = string.find(line, " ")
		if not pos then return end -- invalid message
		data.prefix = string.sub(line, 2, pos-1)
		pos = pos+1

		excl = string.find(data.prefix, "!")
		if excl then
			data.user = string.sub(data.prefix, 1, excl-1)
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
		table.insert(data, string.sub(line, pos, nextpos-1))
		pos = nextpos+1
	end

	local cmd = string.upper(data[1])
	if cmd == "PRIVMSG" and string.sub(data[3], 1, 1) == "\1" then
		data.ctcp = {}
		local inner = string.gsub(string.sub(data[3], 2), "\1$", "")
		local split = string.find(inner, " ", 2)
		if split then
			data.ctcp.cmd = string.upper(string.sub(inner, 1, split-1))
			data.ctcp.params = string.sub(inner, split+1)
		else
			data.ctcp.cmd = string.upper(inner)
		end
	end

	return data
end

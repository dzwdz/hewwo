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
	if config.debug then
		print("=>", cmd)
	end
	writesock(cmd)
end

function parsecmd(line)
	local prefix = nil
	local user = nil
	local args = {}

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

	return prefix, user, args
end

function printf(...)
	print(string.format(...))
end

function djb2(s)
	local hash = 5381|0
	for _,c in ipairs({string.byte(s, 1, -1)}) do
		hash = hash * 31 + c
	end
	return hash
end

function hi(s) -- highlight
	-- TODO highlighting commands in help prompts?
	local cid = djb2(s) % #config.colors
	local color = config.colors[cid+1]
	return "\x1b["..color.."m"..s.."\x1b[0m"
end

function nick_pattern(nick)
	-- TODO only works with alphanumeric nicks
	return "%f[%w]"..nick.."%f[^%w]"
end

function escape(s) -- escape non-ascii chars
	local out = ""
	for _, c in ipairs({string.byte(s, 1, -1)}) do
		if c < 20 then
			out = out .. "\x1b[35m^" .. string.char(c + 64) .. "\x1b[0m"
		elseif c == 127 then
			out = out .. "\x1b[35m^?\x1b[0m"
		else
			out = out .. string.char(c)
		end
	end
	return out
end

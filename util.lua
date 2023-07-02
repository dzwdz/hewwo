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

function escape(s) -- escape non-utf8 chars
	s, _ = string.gsub(s, "[\x00-\x1F\x7F]", function (c)
		-- https://en.wikipedia.org/wiki/Caret_notation
		-- can be done with just a XOR (which looks weird in Lua)
		c = string.char(string.byte(c) ~ 64)
		return "\x1b[35m^"..c.."\x1b[0m"
	end)
	return s
end

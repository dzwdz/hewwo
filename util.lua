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


-- https://en.wikipedia.org/wiki/Caret_notation
-- meant to be used as an argument to string.gsub
function escape_char(c)
	local b = string.byte(c)
	if b < 0x20 or b == 0x7F then
		-- TODO go via hi()
		return "\x1b[35m^"..string.char(b ~ 64).."\x1b[0m"
	end
	return c
end

function escape(s) -- escape non-utf8 chars
	s, _ = string.gsub(s, "[\x00-\x1F\x7F]", escape_char)
	return s
end

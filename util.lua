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
	if not s then return "" end
	local colors = config.color.nicks
	if not colors or #colors == 0 then return s end

	-- TODO highlighting commands in help prompts?
	local cid = djb2(s) % #colors
	local color = colors[cid+1]
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
		return "\x1b[7m^"..string.char(b ~ 64).."\x1b[27m"
	end
	return c
end

-- escape non-utf8 chars
function escape(s)
	s = string.gsub(s, "[\x00-\x1F\x7F]", escape_char)
	return s
end

function ansi_strip(s)
	return string.gsub(s, "\x1b%[[^\x40-\x7E]*[\x40-\x7E]", "")
end


used_hints = {}
function hint(s, ...)
	if not used_hints[s] then
		printf(s, ...)
		used_hints[s] = true
	end
end


function file_exists(path)
	local f = io.open(path)
	if f then
		f:close()
		return true
	else
		return false
	end
end

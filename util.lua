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

function file_exists(path)
	local f = io.open(path)
	if f then
		f:close()
		return true
	else
		return false
	end
end

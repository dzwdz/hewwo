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
	local cid = djb2(s) % #config.colors
	local color = config.colors[cid+1]
	return "\x1b["..color.."m"..s.."\x1b[0m"
end

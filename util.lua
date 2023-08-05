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

-- TODO move to ui.highlight
function hi(s, what)
	if not s then return "" end
	local mods = {}
	local colors = config.color.nicks
	what = what or "nick"

	if what == "nick" or what == "mention" then
		-- it's a person!
		if (colors or #colors == 0) then
			local cid = djb2(s) % #colors
			table.insert(mods, colors[cid+1])
		end
		if what == "mention" and (config.invert_mentions&1 == 1) then
			table.insert(mods, "7")
		end
	else
		-- it's a bug!
		error(string.format("unrecognized highlight type %q", what))
	end

	if #mods == 0 then
		return s
	else
		return "\x1b["..table.concat(mods, ";").."m"..s.."\x1b[m"
	end
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

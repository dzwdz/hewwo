-- functions used primarily for tests, as the filename might suggest

local tests = safeinit(...)

function tests.deepcmp(a, b)
	if a == b then
		return true
	elseif type(a) == "table" and type(b) == "table" then
		for k,_ in pairs(a) do
			if not tests.deepcmp(a[k], b[k]) then return false end
		end
		for k,_ in pairs(b) do
			if a[k] == nil then return false end
		end
		return true
	else
		return false
	end
end

function tests.inspect(a)
	if type(a) == "table" then
		local s = "{"
		local used = {}
		for k,v in ipairs(a) do
			used[k] = true
			s = s .. tests.inspect(v) .. ", "
		end
		for k,v in pairs(a) do
			if not used[k] then
				s = s .. "[" .. tests.inspect(k) .. "]=" .. tests.inspect(v) .. ", "
			end
		end
		s = string.gsub(s, ", $", "")
		return s .. "}"
	elseif type(a) == "function" then
		return tostring(a)
	else
		return string.format("%q", a)
	end
end

function tests.run(fn)
	-- TODO gate behind config.debug or something of that sort
	fn(function (a, b, info)
		if not tests.deepcmp(a, b) then
			print("An internal test failed. You probably shouldn't be seeing this. Sorry.")
			print("-- got:")
			print(tests.inspect(a))
			print("-- want:")
			print(tests.inspect(b))
			if info then
				print("-- info:")
				print(info)
			end
			print(debug.traceback())
			os.exit(0)
		end
	end)
end

return tests

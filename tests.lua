-- functions used primarily for tests, as the filename might suggest


function deep_compare(a, b)
	if a == b then
		return true
	elseif type(a) == "table" and type(b) == "table" then
		for k,_ in pairs(a) do
			if not deep_compare(a[k], b[k]) then return false end
		end
		for k,_ in pairs(b) do
			if a[k] == nil then return false end
		end
		return true
	else 
		return false
	end
end

function inspect(a)
	if type(a) == "table" then
		local s = "{"
		local used = {}
		for k,v in ipairs(a) do
			used[k] = true
			s = s .. inspect(v) .. ", "
		end
		for k,v in pairs(a) do
			if not used[k] then
				s = s .. inspect(k) .. "=" .. inspect(v) .. ", "
			end
		end
		s = string.gsub(s, ", $", "")
		return s .. "}"
	else
		return string.format("%q", a)
	end
end

function run_test(fn)
	-- TODO gate behind config.debug or something of that sort
	fn(function (a, b)
		if not deep_compare(a, b) then
			print("An internal test failed. You probably shouldn't be seeing this. Sorry.")
			print("-- got:")
			print(inspect(a))
			print("-- want:")
			print(inspect(b))
			print(debug.traceback())
			os.exit(0)
		end
	end)
end

-- TODO could use some automated tests

ringbuf = {
	cap = 0,
	first = 1,
	last = 0,
}

function ringbuf:new(capacity)
	return setmetatable({cap=capacity, first=1, last=0}, {__index=self})
end

function ringbuf:push(el)
	if self.last == 0 then
		self.last = 1
	elseif self.last == self.cap then
		self.last = 1
		self.first = 2
	else
		self.last = self.last + 1
		if self.last == self.first then
			if self.first == self.cap then
				self.first = 1
			else
				self.first = self.last + 1
			end
		end
	end
	self[self.last] = el
end

function ringbuf:iter()
	local i = self.first
	local done = false
	return function()
		if done then return nil end
		local el = self[i]
		first = false
		if i == self.last then
			done = true
		elseif i == self.cap then
			i = 1
		else
			i = i + 1
		end
		return el
	end
end

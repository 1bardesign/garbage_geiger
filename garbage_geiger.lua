--[[
	sound-based "geiger counter" for lua garbage impact
]]

--barebones class
local geiger = {}
geiger._mt = {
	__index = geiger
}

--period of updating the audio samples
local _generation_period = 1 / 30

-- construct a new garbage_geiger object
function geiger:new(
	--volume scale
	--(defaults to 1)
	_volume,
	--kb per click
	--(defaults to 50, stochastic)
	_noise_scale,
	--audio samples per second
	--(defaults to 22050)
	--(half CD rate, "good enough for a debug feature")
	_samples_per_second
)
	local volume = _volume or 1
	local noise_scale = _noise_scale or 50
	local samples_per_second = _samples_per_second or 22050
	local buffer_samples = samples_per_second * _generation_period
	self = setmetatable({
		--
		samples_per_second = samples_per_second,
		geiger_source = love.audio.newQueueableSource(samples_per_second, 8, 1),
		--
		buffer_samples = buffer_samples,
		sample_accum = love.sound.newSoundData(buffer_samples, samples_per_second, 8, 1, 32),
		--
		time_accum = 0,
		size_accum = 0,
		--
		active = 0,
		--
		noise_scale = noise_scale,
		--
		volume = volume,
		--
		r = love.math.newRandomGenerator(),
		--init with however much garbage we have now
		old_size = collectgarbage("count")
	}, self._mt)

	--queue some silence
	self.geiger_source:queue(self.sample_accum)

	self.geiger_source:play()

	return self
end

--(avoiding any deps)
local function lerp(a, b, t)
	return a * (1 - t) + b * t
end

--
function geiger:random(a, b)
	return self.r:random(a, b)
end

--update, generating sound based on the change in memory level
function geiger:update(dt)
	--accumulate change in memory
	local new_size = collectgarbage("count")
	local delta = math.abs(new_size - self.old_size)
	self.old_size = new_size
	self.size_accum = self.size_accum + delta
	--accumulate time
	self.time_accum = self.time_accum + dt
	if self.time_accum < _generation_period then
		return
	end

	--convert into sound
	delta = self.size_accum
	self.size_accum = 0

	--how long has it been? (maybe we had a long frame or similar)
	local periods_to_iterate = math.floor(self.time_accum / _generation_period)
	
	local counts_per_buffer = delta / periods_to_iterate / self.noise_scale
	local pr = 1 / self.buffer_samples * counts_per_buffer
	local amp = 0.3 * self.volume
	
	--random period and duration per gen
	local per = 0.00095 + lerp(-0.00001, 0.00001, self:random())
	local dur = lerp(0.0045, 0.0065, self:random())
	dur = dur * self.samples_per_second
	--init
	if not self.dur then
		self.dur = dur
	end

	--
	while self.time_accum > _generation_period do
		self.time_accum = self.time_accum - _generation_period

		local pulse_last = 0
		for i = 1, self.buffer_samples do
			local v = 0
			
			--issue pulse
			if 
				(self.active == 0 or self.active > self.dur * 0.8)
				and self:random() < pr
			then
				self.dur = dur
				self.per = per
				self.pers = math.floor(self.per * self.samples_per_second)
				self.hpers = math.floor(self.pers * 0.5)
				self.active = 1
				self.hpers_offset = self:random(0, self.hpers)
			end

			--render pulse
			if self.active > 0 then
				self.active = self.active + 1
				local f = (self.active / self.dur)
				--pulse amp
				local pulse = math.sin(f * math.pi)
				pulse = pulse * pulse

				--sin
				local wf = (self.active % self.pers) / self.pers
				local sv = math.sin(wf * math.pi * 2)
				--whitenoise
				if 
					not self._wn_v
					or (self.active + self.hpers_offset) % self.hpers == 0
				then
					self._wn_v = self:random() * (self._wn_v == 1 and -1 or 1)
				end
				local nv = self._wn_v
				--mix
				local noise_ratio = 0.5
				local wv = lerp(sv, nv, noise_ratio) * 2 - 1

				v = wv * amp * pulse

				if self.active >= self.dur then
					self.active = 0
				end
			end

			--write
			self.sample_accum:setSample(i - 1, v)
		end

		--send
		self.geiger_source:queue(self.sample_accum)
	end

	--make sure it's playing (might have stopped from running out of buffers)
	self.geiger_source:play()
end

return geiger

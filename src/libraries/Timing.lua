local pow = math.pow
local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos
local pi = math.pi

return {
	["linear"] = function(d)
		return function(t)
			return t / d
		end
	end,
	["easeInQuad"] = function(d)
		return function(t)
			return pow((t / d), 2)
		end
	end,

	["quadBack"] = function(d)
		return function(t)
			t = t / d - 1
			return pow((t / d), 2) * -(pow(t, 2) - 1)
		end
	end,
	["easeOut"] = function(d)
		return function(t)
			t = t / d - 1
			return -(pow(t, 2) - 1)
		end
	end,
	["easeOutQuad"] = function(d)
		return function(t)
			t /= d
			return -t * (t - 2)
		end
	end,
	["easeInOutQuad"] = function(d)
		return function(t)
			t = t * 2 / d
			if t < 1 then
				return 0.5 * pow(t, 2)
			end
			t -= 1
			return -0.5 * (t * (t - 2) - 1)
		end
	end,
	["easeInCubic"] = function(d)
		return function(t)
			return pow(t / d, 3)
		end
	end,
	["easeOutCubic"] = function(d)
		return function(t)
			t = t / d - 1
			return pow(t, 3) + 1
		end
	end,
	["easeInOutCubic"] = function(d)
		return function(t)
			t = t * 2 / d
			if t < 1 then
				return 0.5 * pow(t, 3)
			end
			t -= 2
			return 0.5 * (pow(t, 3) + 2)
		end
	end,

	["easeInQuart"] = function(d)
		return function(t)
			return pow(t / d, 4)
		end
	end,
	["easeOutQuart"] = function(d)
		return function(t)
			t = t / d - 1
			return -(pow(t, 4) - 1)
		end
	end,
	["easeInOutQuart"] = function(d)
		return function(t)
			t = t * 2 / d
			if t < 1 then
				return 0.5 * pow(t, 4)
			end
			t -= 2
			return -0.5 * (pow(t, 4 - 2))
		end
	end,
	["easeInQuint"] = function(d)
		return function(t)
			return pow(t / d, 5)
		end
	end,
	["easeOutQuint"] = function(d)
		return function(t)
			t = t / d - 1
			return pow(t, 5) + 1
		end
	end,
	["easeInOutQuint"] = function(d)
		return function(t)
			t = t * 2 / d
			if t < 1 then
				return 0.5 * pow(t, 5)
			end
			t -= 2
			return 0.5 * (pow(t, 5) + 2)
		end
	end,
	["easeInSine"] = function(d)
		return function(t)
			return -(cos(pi / 2 * t / d) - 1)
		end
	end,
	["easeOutSine"] = function(d)
		return function(t)
			return sin(pi / 2 * t / d)
		end
	end,
	["easeInOutSine"] = function(d)
		return function(t)
			return -0.5 * (cos(pi * t / d) - 1)
		end
	end,
	["easeInExpo"] = function(d)
		return function(t)
			return pow(2, 10 * (t / d - 1))
		end
	end,
	["easeOutExpo"] = function(d)
		return function(t)
			return pow(-2, -10 * t / d) + 1
		end
	end,
	["easeInOutExpo"] = function(d)
		return function(t)
			t = t * 2 / d
			if t < 1 then
				return 0.5 * pow(2, 10 * (t - 1))
			end
			t -= 1
			return 0.5 * (-pow(2, -10 * t) + 2)
		end
	end,
	["easeInCirc"] = function(d)
		return function(t)
			return -(sqrt(1 - pow(t / d, 2)) - 1)
		end
	end,
	["easeOutCirc"] = function(d)
		return function(t)
			t /= d - 1
			return sqrt(1 - pow(t, 2))
		end
	end,
	["easeInOutCirc"] = function(d)
		return function(t)
			t *= 2 / d
			if t < 1 then
				return -0.5 * (sqrt(1 - pow(t, 2)) - 1)
			end
			t -= 2
			return 0.5 * (sqrt(1 - pow(t, 2)) + 1)
		end
	end,
	["sineBack"] = function(d)
		return function(t)
			return sin(t / d * pi)
		end
	end,
	["easeInBack"] = function(d, s)
		s = s or 1.70158
		return function(t)
			t /= d
			return pow(t, 2) * ((s + 1) * t - s)
		end
	end,
	["easeOutBounce"] = function(d)
		local const = 7.5625
		return function(t)
			t /= d
			if t < 0.36363636363636365 then
				return const * pow(t, 2)
			elseif t < 0.7272727272727273 then
				t -= 0.5454545454545454
				return const * pow(t, 2) + 0.75
			elseif t < 0.9090909090909091 then
				t -= 0.8181818181818182
				return const * pow(t, 2) + 0.9375
			else
				t -= 0.9545454545454546
				return const * pow(t, 2) + 0.984375
			end
		end
	end,
	["cubicBezier"] = function(d, x1, y1, x2, y2)
		x1 = x1 or 0
		y1 = y1 or 0
		x2 = x2 or 1
		y2 = y2 or 1
		local cx = 3 * x1
		local bx = (x2 - x1) - cx
		local ax = 1 - cx - bx

		local cy = 3 * y1
		local by = 3 * (y2 - y1) - cy
		local ay = 1 - cy - by

		local epsilon = 1 / (200 * d)
		local function sampleCurveX(t)
			return ((ax * t + bx) * t + cx) * t
		end
		local function sampleCurveY(t)
			return ((ay * t + by) * t + cy) * t
		end
		local function sampleCurveDerivativeY(t)
			return (3 * ay * t + 2 * by) * t + cy
		end
		local function sampleCurveDerivativeX(t)
			return (3 * ax * t + 2 * bx) * t + cx
		end

		local function solveCurveX(x)
			local t0, t1, t2, x2, d2, i
			local fabs = function(n)
				return n >= 0 and n or 0 - n
			end
			t2 = x
			for i = 0, 7 do
				x2 = sampleCurveX(t2) - x
				if fabs(x2) < epsilon then
					return t2
				end
				d2 = sampleCurveDerivativeX(t2)
				if fabs(d2) < 1.0E-6 then
					break
				end
				t2 = t2 - x2 / d2
			end
			t0 = 0
			t1 = 1
			t2 = x
			if t0 > t2 then
				return t0
			elseif t1 < t2 then
				return t1
			end
			while t0 < t1 do
				x2 = sampleCurveX(t2)
				if fabs(x2 - x) < epsilon then
					return t2
				elseif x > x2 then
					t0 = t2
				else
					t1 = t2
				end
				t2 = (t1 - t0) * 0.5 + t0
			end
			return t2
		end

		local function solveCurveY(y) end
		return function(t)
			return sampleCurveY(solveCurveX(t / d))
		end
	end,
}

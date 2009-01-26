min   = pge.math.min   or math.min
max   = pge.math.max   or math.max
floor = pge.math.floor or math.floor

function clamp (val, lo, hi)
   return max(lo, min(hi, val or lo))
end

function wrap (val, lo, hi)
   if lo > hi then
      lo, hi = hi, lo
   elseif lo == hi then
      return lo
   end

   return lo + (val - lo) % (hi - lo)
end

function each(tbl)
   local key, val
   return function()
      key, val = next(tbl, key)
      return val
   end
end

function subset (tbl, first, len)
   local i, j = max(1, first), min(#tbl, first + len - 1)
   return function()
      if i <= j then
         i = i + 1
         return i - 1, tbl[i - 1]
      end
   end
end

local _tostring = tostring
function tostring(val)
   if type(val) == 'table' then
      local s = '{'
      for k, v in pairs(val) do
         s = s .. '[%s] = %s, ' % {tostring(k), tostring(v)}
      end
      return s .. '}'
   else
      return _tostring(val)
   end
end

--------------------------------------------------------------------------------

function table.find(tbl, item)
   for i, v in ipairs(tbl) do
      if v == item then return i end
   end
   return 0
end

function table.copy(tbl, copy)
   if copy == nil then copy = {} end
   for k, v in pairs(tbl) do
      copy[k] = v
   end
   return copy
end

--------------------------------------------------------------------------------

smt = getmetatable('')

function smt:__mod(rhs)
   if type(rhs) ~= 'table' then
      rhs = { rhs }
   end

   local s = self:gsub('%%%(([^%%%)]+)%)(%d*%.?%d*[cdEefGgioqsuXx])',
      function (name, fmt)
         name = tonumber(name) or name
         return ('%' .. fmt):format(rhs[name])
      end)

   return s:format(unpack(rhs))
end

function smt:__mul(rhs)
   return self:rep(tonumber(rhs))
end

function string.gfind(s, pattern, init, plain)
   return function()
      local r = {s:find(pattern, init, plain)}
      if r[2] then init = r[2] + 1 end
      return unpack(r)
   end
end



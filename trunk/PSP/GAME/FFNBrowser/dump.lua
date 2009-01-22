local base = _G

module 'dump'

local dump = base.setmetatable(_M, {})
local meta = base.getmetatable(dump)

local _keywords = {
   ['and'] = true,
   ['break'] = true,
   ['do'] = true,
   ['else'] = true,
   ['elseif'] = true,
   ['end'] = true,
   ['false'] = true,
   ['for'] = true,
   ['function'] = true,
   ['if'] = true,
   ['in'] = true,
   ['local'] = true,
   ['nil'] = true,
   ['not'] = true,
   ['or'] = true,
   ['repeat'] = true,
   ['return'] = true,
   ['then'] = true,
   ['true'] = true,
   ['until'] = true,
   ['while'] = true,
}

local _dumpfuncs = {
   ['table'] = function (tbl)
      local s = '{'
      for key, val in base.pairs(tbl) do
         local k, v = dump(key), dump(val)
         if v ~= 'nil' then
            if base.type(key) == 'string' and key:match('^[%a_][%w_]*$') and not _keywords[key] then
               k = key
            elseif k ~= 'nil' then
               k = '[' .. k .. ']'
            else
               k = nil
            end
            if k then
               s = s .. k .. '=' .. v
               if base.next(tbl, key) then
                  s = s .. ','
               end
            end
         end
      end
      return s .. '}'
   end,
   ['string'] = function (str)
      return ('%q'):format(str)
   end,
   ['number'] = function (num)
      return base.tostring(num)
   end,
   ['boolean'] = function (bool)
      return base.tostring(bool)
   end,
   ['function'] = function (func)
      return ('loadstring(%q)'):format(base.string.dump(func))
   end,
   ['nil'] = function (_nil)
      return 'nil'
   end,
   ['userdata'] = function (_nil)
      return 'nil'
   end,
   ['thread'] = function (_nil)
      return 'nil'
   end,
}

-- returns a string that can be read with loadstring
function meta:__call(var)
   return _dumpfuncs[base.type(var)](var)
end

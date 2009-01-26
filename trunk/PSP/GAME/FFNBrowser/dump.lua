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

local _dumpfuncs
_dumpfuncs = {
   ['table'] = function (tbl)
      local s = '{'
      for k, v in pairs(tbl) do
         local key = _dumpfuncs[type(k)]
         local val = _dumpfuncs[type(v)]

         if key and val then
            if type(k) == 'string' and k:find('^[_%a][_%w]*$') and not _keywords[k] then
               key = k
            else
               key = '[' .. key(k) .. ']'
            end
            s = s .. key .. '=' .. val(v)
            if next(tbl, k) then
               s = s .. ','
            end
         end
      end
      return s .. '}'
   end,
   ['string'] = function (str)
      return ('%q'):format(str)
   end,
   ['number'] = function (num)
      return tostring(num)
   end,
   ['boolean'] = function (bool)
      return tostring(bool)
   end,
   ['function'] = function (func)
      return ('loadstring(%q)'):format(string.dump(func))
   end,
}

-- returns a string that can be read with loadstring
function dump(var)
   return _dumpfuncs[type(var)](var)
end

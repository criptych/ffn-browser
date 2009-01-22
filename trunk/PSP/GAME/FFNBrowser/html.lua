local _tagrep = {
   ['p'] = '\n\n    ',
   ['/p'] = '',
   ['br'] = '\n',
   ['hr'] = '\n-----\n',
   ['a'] = '',
   ['/a'] = '',

   ['b'] = '*',
   ['/b'] = '*',
   ['i'] = '/',
   ['/i'] = '/',
   ['u'] = '_',
   ['/u'] = '_',
}

function untag(tag)
   if tag:match('<[!%?].->') then
      return ''
   end
   return _tagrep[tag:match("<(/?%a%w*)%W"):lower()]
end

local _entities = {
   -- standard XHTML entities
   quot = '"',
   apos = "'",
   lt   = '<',
   gt   = '>',
   amp  = '&',

   -- XASCII / Unicode characters
   nbsp   = 0x00a0,
   copy   = 0x00a9,
   laquo  = 0x00ab,
   raquo  = 0x00bb,
   shy    = 0x00ad,
   reg    = 0x00ae,
   micro  = 0x00b5,
   frac14 = 0x00bc,
   frac12 = 0x00bd,
   frac34 = 0x00be,

   Agrave = 0x00c0,
   Aacute = 0x00c1,
   Acirc  = 0x00c2,
   Atilde = 0x00c3,
   Auml   = 0x00c4,
   Aring  = 0x00c5,
   AElig  = 0x00c6,
   Ccedil = 0x00c7,
   Egrave = 0x00c8,
   Eacute = 0x00c9,
   Ecirc  = 0x00ca,
   Euml   = 0x00cb,
   Igrave = 0x00cc,
   Iacute = 0x00cd,
   Icirc  = 0x00ce,
   Iuml   = 0x00cf,
   ETH    = 0x00d0,
   Ntilde = 0x00d1,
   Ograve = 0x00d2,
   Oacute = 0x00d3,
   Ocirc  = 0x00d4,
   Otilde = 0x00d5,
   Ouml   = 0x00d6,
   times  = 0x00d7,
   Oslash = 0x00d8,
   Ugrave = 0x00d9,
   Uacute = 0x00da,
   Ucirc  = 0x00db,
   Uuml   = 0x00dc,
   Yacute = 0x00dd,
   THORN  = 0x00de,
   szlig  = 0x00df,

   agrave = 0x00e0,
   aacute = 0x00e1,
   acirc  = 0x00e2,
   atilde = 0x00e3,
   auml   = 0x00e4,
   aring  = 0x00e5,
   aelig  = 0x00e6,
   ccedil = 0x00e7,
   egrave = 0x00e8,
   eacute = 0x00e9,
   ecirc  = 0x00ea,
   euml   = 0x00eb,
   igrave = 0x00ec,
   iacute = 0x00ed,
   icirc  = 0x00ee,
   iuml   = 0x00ef,
   eth    = 0x00f0,
   ntilde = 0x00f1,
   ograve = 0x00f2,
   oacute = 0x00f3,
   ocirc  = 0x00f4,
   otilde = 0x00f5,
   ouml   = 0x00f6,
   divide = 0x00f7,
   oslash = 0x00f8,
   ugrave = 0x00f9,
   uacute = 0x00fa,
   ucirc  = 0x00fb,
   uuml   = 0x00fc,
   yacute = 0x00fd,
   thorn  = 0x00fe,
   yuml   = 0x00ff,

   OElig  = 0x0152,
   oelig  = 0x0153,
   Scaron = 0x0160,
   scaron = 0x0161,
   Yuml   = 0x0178,
   fnof   = 0x0192,

   circ   = 0x02c6,
   tilde  = 0x02dc,

   ensp   = 0x2002,
   emsp   = 0x2003,
   thinsp = 0x2009,

   ndash  = 0x2013,
   mdash  = 0x2014,
   lsquo  = 0x2018,
   rsquo  = 0x2019,
   ldquo  = 0x201c,
   rdquo  = 0x201d,
   hellip = 0x2026,
   prime  = 0x2032,
   Prime  = 0x2033,
   lsaquo = 0x2039,
   rsaquo = 0x203a,
   frasl  = 0x2044,
   euro   = 0x20ac,
   trade  = 0x2122,
   minus  = 0x2212,
   lowast = 0x2217,

   -- PGE 0.02 doesn't support XASCII, so replace
   -- some common chars with similar ASCII text

   [0x00a0] = ' ',
   [0x00a9] = '(c)',
   [0x00ab] = '<<',
   [0x00bb] = '>>',
   [0x00ad] = '',
   [0x00ae] = '(R)',
   [0x00b5] = 'u',
   [0x00bc] = '1/4',
   [0x00bd] = '1/2',
   [0x00be] = '3/4',

   [0x00c0] = 'A',
   [0x00c1] = 'A',
   [0x00c2] = 'A',
   [0x00c3] = 'A',
   [0x00c4] = 'A',
   [0x00c5] = 'A',
   [0x00c6] = 'AE',
   [0x00c7] = 'C',
   [0x00c8] = 'E',
   [0x00c9] = 'E',
   [0x00ca] = 'E',
   [0x00cb] = 'E',
   [0x00cc] = 'I',
   [0x00cd] = 'I',
   [0x00ce] = 'I',
   [0x00cf] = 'I',
   [0x00d1] = 'N',
   [0x00d2] = 'O',
   [0x00d3] = 'O',
   [0x00d4] = 'O',
   [0x00d5] = 'O',
   [0x00d6] = 'O',
   [0x00d7] = 'x',
   [0x00d8] = 'O',
   [0x00d9] = 'U',
   [0x00da] = 'U',
   [0x00db] = 'U',
   [0x00dc] = 'U',
   [0x00dd] = 'Y',
   [0x00df] = 'ss',

   [0x00e0] = 'a',
   [0x00e1] = 'a',
   [0x00e2] = 'a',
   [0x00e3] = 'a',
   [0x00e4] = 'a',
   [0x00e5] = 'a',
   [0x00e6] = 'a',
   [0x00e7] = 'c',
   [0x00e8] = 'e',
   [0x00e9] = 'e',
   [0x00ea] = 'e',
   [0x00eb] = 'e',
   [0x00ec] = 'i',
   [0x00ed] = 'i',
   [0x00ee] = 'i',
   [0x00ef] = 'i',
   [0x00f1] = 'n',
   [0x00f2] = 'o',
   [0x00f3] = 'o',
   [0x00f4] = 'o',
   [0x00f5] = 'o',
   [0x00f6] = 'o',
   [0x00f7] = '/',
   [0x00f8] = 'o',
   [0x00f9] = 'u',
   [0x00fa] = 'u',
   [0x00fb] = 'u',
   [0x00fc] = 'u',
   [0x00fd] = 'y',
   [0x00ff] = 'y',

   [0x0152] = 'OE',
   [0x0153] = 'oe',
   [0x0160] = 'S',
   [0x0161] = 's',
   [0x0178] = 'Y',
   [0x0192] = 'f',

   [0x02c6] = '^',
   [0x02dc] = '~',

   [0x2002] = ' ',
   [0x2003] = ' ',
   [0x2009] = ' ',

   [0x2013] = '-',
   [0x2014] = '--',
   [0x2018] = '\'',
   [0x2019] = '\'',
   [0x201c] = '"',
   [0x201d] = '"',
   [0x2026] = '...',
   [0x2032] = '\'',
   [0x2033] = '"',
   [0x2039] = '<',
   [0x203a] = '>',
   [0x2044] = '/',
   [0x2122] = '(tm)',
   [0x2212] = '-',
   [0x2217] = '*',
}

function unentity(entity)
   if entity:sub(1,1) == '#' then
      entity = tonumber('0' .. entity:sub(2))
   end
   repeat
      if _entities[entity] then
         entity = _entities[entity]
      else
         return '<U+%04X>' % entity
      end
   until type(entity) ~= 'number'
   return entity
end

function unutf8(str)
   local ret = ''
   local i, l = 1, str:len()
   while i <= l do
      if str:byte(i) >= 240 and i <= l - 3 then
         c = (str:byte(i  ) %  8) * 262144 +
             (str:byte(i+1) % 64) * 4096 +
             (str:byte(i+2) % 64) * 64 +
             (str:byte(i+3) % 64)
         i = i + 4
      elseif str:byte(i) >= 224 and i <= l - 2 then
         c = (str:byte(i  ) % 16) * 4096 +
             (str:byte(i+1) % 64) * 64 +
             (str:byte(i+2) % 64)
         i = i + 3
      elseif str:byte(i) >= 192 and i <= l - 1 then
         c = (str:byte(i  ) % 32) * 64 +
             (str:byte(i+1) % 64)
         i = i + 2
      else
         c = str:byte(i)
         i = i + 1
      end

      if c < 128 then
         ret = ret .. string.char(c)
      else -- delegate to entity parser
         ret = ret .. '&#%d;' % c
      end
   end
   return ret
end

function unhtmlize(str, tagfunc)
   return (str:gsub('%s+', ' '):gsub("%b<>", tagfunc or untag):gsub('^%s+', ''):gsub('[\128-\255]+', unutf8):gsub("&(#?%w+);", unentity))
end


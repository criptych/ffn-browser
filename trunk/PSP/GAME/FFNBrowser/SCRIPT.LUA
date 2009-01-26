require "class"
require "extend"
require "filepath"
require "dump"

require "XML"
require "FFN"
--require "HTTP"
require "HTML"

--------------------------------------------------------------------------------

offline = false

function ap_connect()
   if not offline and not pge.net.isconnected() then
      pge.net.init()
      if screen:showDialog(Dialog.network()) ~= 0 then
         offline = true
      end
   end
   return pge.net.isconnected()
end

function ap_disconnect()
   pge.net.shutdown()
   offline = false
end

--------------------------------------------------------------------------------

function needfile(file, overwrite)
   return overwrite or not pge.file.exists(file)
end

function getfile(file, url, overwrite)
   if url and needfile(file, overwrite) then
      file = file or basname(url):gsub('[\\/:%*%?"<>|]', '_')

      if ap_connect() then
         mkdirs(dirname(file))
         pge.file.remove(file)
         pge.net.getfile(url, file)
      end
   end
   return readfile(file)
end

function getchapter(file, url, overwrite)
   local text = getfile(file, url, overwrite)

   if text then
      local story = text:match('<!%-%- start story %-%->(.-)<!%-%- end story %-%->')
      if story then
         writefile(file, story)
         text = story
      end
   end

   return text
end

--------------------------------------------------------------------------------

local nscreenshots = 0
local screenshotdir = '/picture/FFN Browser/'

function screenshotname()
   return screenshotdir .. 'SCREEN%02d.PNG' % nscreenshots
end

function screenshot()
   while nscreenshots < 100 do
      local name = screenshotname()
      nscreenshots = nscreenshots + 1
      if not pge.file.exists(name) then
         mkdirs(screenshotdir)
         pge.gfx.screenshot(name)
         break
      end
   end
end

--------------------------------------------------------------------------------

Database = class()

Database.file = {}

function Database:init(file)
   self:load(file)
end

function Database:load(file)
   file = file or Database.file[self]
   local t = loadfile(file)
   for k, v in pairs(t and t() or {}) do
      self[k] = v
   end
   Database.file[self] = file
end

function Database:save()
   return writefile(Database.file[self], 'return ' .. dump(self))
end

function Database:get(key, def)
   if self[key] == nil then
      self[key] = def
   end
   return self[key]
end

function Database:set(key, val)
   self[key] = val
end

--------------------------------------------------------------------------------

function parse_feed_date(date)
   local d = {date:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d)%:(%d%d)%:(%d%d%.?%d-)(.-)$')}
   if d[7] ~= 'Z' then
      local m = d[7]:match('([%-%+])(%d%d):(%d%d)')
      if m then
         local sign = (m[1] == '-' and -1 or 1)
         d[5] = d[5] + m[2] * sign
         d[6] = d[6] + m[3] * sign
      end
   end
   return os.time({ year = d[1], month  = d[2], day    = d[3],
                    hour = d[4], minute = d[5], second = d[6] })
end

Person = class()

function Person:init(name, uri, email)
   self.name = name
   self.uri = uri
   self.email = email
end

Entry = class()

function Entry:init(id, title, updated)
   self.id = id
   self.title = title
   self.updated = updated
   self.link = {}
end

Feed = class()

--[[
Feed = "/atom/{etc}"
<category term="{category}"/>
<category term="{language}"/>
<category term="Fiction Rated: {rating}"/>
]]

function Feed:init(file, url, overwrite)
   self.file = file
   self.url = url
   self.entry = {}
   self.link = {}

   self:load(overwrite)
end

function Feed:load(overwrite)
   offline = false
   local xml = getfile(self.file, self.url, overwrite)

   if xml then
      local feed = XML(xml).feed

      self.id = feed.id['$']
      self.title = feed.title['$']

      local links = (#feed.link == 0) and { feed.link } or feed.link
      for i, link in ipairs(links) do
         self.link[link['@rel']] = link['@href']
      end

      self.url = self.link.self or self.url

      local entries = (#feed.entry == 0) and { feed.entry } or feed.entry
      for i, entry in ipairs(entries) do
         local ev = Entry(entry.id['$'], entry.title['$'], entry.updated['$'])

         table.insert(self.entry, ev)

         local name, uri, email
         name  = entry.author.name  and entry.author.name ['$']
         uri   = entry.author.uri   and entry.author.uri  ['$']
         email = entry.author.email and entry.author.email['$']

         ev.author = Person(name, uri, email)

         local links = (#entry.link == 0) and { entry.link } or entry.link
         for i, link in ipairs(links) do
            ev.link[link['@rel']] = link['@href']
         end

         ev.summary = entry.summary['$']
      end

      db.feed[self.file] = {
         title = self.title:gsub('^FanFiction%.Net %- ', ''),
         url = self.url,
         }
   end
end

--------------------------------------------------------------------------------

Dialog = class()

function Dialog:init(_init, _update, busy)
   self._init = _init
   self._update = _update
   self.result = {}
   self.busy = busy

   local meta = getmetatable(self)
   function meta:__call(...)
      self.running = self._init(...)
      return self
   end

   self.running = true
end

function Dialog:update()
   if self.running then
      --error("dialog")
      self.result = {self._update()}
      if (not pge.running()) or (self.result[1] ~= self.busy) then
         self.running = false
      end
   end
end

Dialog.osk = Dialog(pge.utils.oskinit, pge.utils.oskupdate, false)
Dialog.message = Dialog(pge.utils.msginit, pge.utils.msgupdate, PGE_UTILS_DIALOG_RUNNING)
Dialog.error = Dialog(pge.utils.errormsginit, pge.utils.msgupdate, PGE_UTILS_DIALOG_RUNNING)
Dialog.network = Dialog(pge.utils.netinit, pge.utils.netupdate, PGE_UTILS_DIALOG_RUNNING)
Dialog.browser = Dialog(pge.utils.browserinit, pge.utils.browserupdate, PGE_UTILS_DIALOG_RUNNING)
Dialog.save = Dialog(pge.utils.saveinit, pge.utils.savedataupdate, PGE_UTILS_DIALOG_RUNNING)
Dialog.load = Dialog(pge.utils.loadinit, pge.utils.savedataupdate, PGE_UTILS_DIALOG_RUNNING)
Dialog.autosave = Dialog(pge.utils.autosaveinit, pge.utils.savedataupdate, PGE_UTILS_DIALOG_RUNNING)
Dialog.autoload = Dialog(pge.utils.autoloadinit, pge.utils.savedataupdate, PGE_UTILS_DIALOG_RUNNING)

--------------------------------------------------------------------------------

Screen = class()

function Screen:init(backcolor)
   self.backcolor = backcolor or pge.gfx.createcolor(0, 0, 0)
   self.grayed = pge.gfx.createcolor(0, 0, 0, 128)
   self.views = {}
   self.timer = pge.timer.create()
end

function Screen:view()
   return self.views[#self.views]
end

function Screen:push_view(view)
   table.insert(self.views, view)
end

function Screen:pop_view(view)
   return table.remove(self.views)
end

function Screen:set_view(view)
   self.views[#self.views] = view
end

function Screen:interact(view, dialog)
   pge.controls.update()
   if not dialog then view:interact() end
end

function Screen:update(view)
   self.timer:update()
   local delta = self.timer:getdelta()
   view:update(delta)
end

function Screen:draw(view, dialog)
   pge.gfx.startdrawing()
   pge.gfx.clearscreen(self.backcolor)
   view:draw()
   if dialog then pge.gfx.drawrect(0, 0, 480, 272, self.grayed) end
   pge.gfx.enddrawing()
   if dialog then dialog:update() end
   pge.gfx.swapbuffers()
end

function Screen:doFrame(dialog)
   local view = self:view()
   if view then
      self:interact(view, dialog)
      self:update(view)
      self:draw(view, dialog)
      return true
   end
end

function Screen:showDialog(dialog)
   while dialog.running and self:running() do
      self:doFrame(dialog)
   end
   return unpack(dialog.result)
end

function Screen:running()
   return pge.running() and self:view()
end

function Screen:run()
   while self:running() do self:doFrame() end
end

--------------------------------------------------------------------------------

Widget = class()

function Widget:init(x, y, w, h)
   self.x = x
   self.y = y
   self.w = w
   self.h = h

   self.time = 0
end

function Widget:interact()
end

function Widget:update(delta)
   self.time = self.time + delta
end

function Widget:draw()
   pge.gfx.drawrect(self.x, self.y, self.w, self.h, colors[theme().backcolor])
end

--------------------------------------------------------------------------------

ProgressBar = class(Widget)

function ProgressBar:init(x, y, w, h, lo, hi, val)
   Widget.init(self, x, y, w, h)
   self.lo = lo or 0
   self.hi = hi or 100
   self.val = val or self.lo
end

function ProgressBar:draw()
   local y, h = self.y, self.h
   if h > font:height() + 1 then
      h = font:height() + 1
      y = self.y + (self.h - h) / 2
   end

   local pw = (self.w - 2) * (self.val - self.lo) / max(1, self.hi - self.lo)

   pge.gfx.drawrect(self.x, self.y, self.w, self.h, colors[theme().backcolor])
   pge.gfx.drawrect(self.x, y, self.w, h, colors[theme().forecolor])
   pge.gfx.drawrect(self.x + 1, y + 1, pw, h - 2, colors[theme().highlight])
end

--------------------------------------------------------------------------------

ScrollBar = class(Widget)

function ScrollBar:init(x, y, w, h, lo, hi, val, step)
   Widget.init(self, x, y, w, h)
   self.lo = lo or 0
   self.hi = hi or 100
   self.val = val or self.lo
   self.step = step or 1
end

function ScrollBar:draw()
   self.val = clamp(self.val, self.lo, self.hi)

   local h = self.h - 2
   local range = max(1, self.hi - self.lo + 1)
   local ty = h * (self.val - self.lo) / range
   local th = clamp(h * self.step / range, 1, h)

   pge.gfx.drawrect(self.x, self.y, self.w, self.h, colors[theme().forecolor])
   pge.gfx.drawrect(self.x + 1, self.y + ty + 1, self.w - 2, th, colors[theme().highlight])
end

--------------------------------------------------------------------------------

function wrap_lines(text, maxwidth)
   maxwidth = maxwidth or 480
   local f = font

   local lines = {}
   local line = {}
   local first, last, width = 1, 0, 0
   local escape = false
   local n = 1

   local bold, italic, uline = false, false, false

   function setfont(b, i)
      if b then
         if i then
            f = fontbi
         else
            f = fontb
         end
      else
         if i then
            f = fonti
         else
            f = font
         end
      end

      bold = b
      italic = i
   end

   function putline()
      table.insert(lines, line)
      line = {}
   end

   function putspan(t)
      if #t > 0 then
         local w = f:measure(t)
         table.insert(line, { text = t, font = f, width = w, uline = uline })
      end
   end

   function putchar(c)
      width = width + f:measure(c)
      if c == "\n" or (c ~= " " and width >= maxwidth) then
         putspan(text:sub(first, last))
         putline()
         first = last + 1
         width = f:measure(text:sub(first, n))
      end
   end

   while n <= text:len() do
      local c = text:sub(n, n)
      if c == " " or c == "\n" then
         last = n
      end
      if escape then
         if c == '\\' then
            putchar('\\')
         elseif c == 'b' then
            putspan(text:sub(first, n - 2))
            first = n + 1
            last = first
            setfont(not bold, italic)
         elseif c == 'i' then
            putspan(text:sub(first, n - 2))
            first = n + 1
            last = first
            setfont(bold, not italic)
         elseif c == 'u' then
            putspan(text:sub(first, n - 2))
            first = n + 1
            last = first
            uline = not uline
         else
            putchar('\\')
            putchar(c)
         end

         escape = false
      else
         if c == '\\' then
            escape = true
         else
            putchar(c)
         end
      end
      n = n + 1
   end
   if first <= text:len() then
      putspan(text:sub(first))
   end
   if #line > 0 then
      putline()
   end
   return lines
end

local _tagrep = {
   ['p'] = '\n\n    ',
   ['/p'] = '',
   ['br'] = '\n',
   ['hr'] = '\n-----\n',
   ['a'] = '',
   ['/a'] = '',

   ['b'] = '\\b',
   ['/b'] = '\\b',
   ['i'] = '\\i',
   ['/i'] = '\\i',
   ['u'] = '\\u',
   ['/u'] = '\\u',
}

function format_tags(tag)
   if tag:match('^<[%!%?]') then
      return ''
   end
   return _tagrep[tag:match("<(/?%a%w*)%W"):lower()]
end

TextBox = class(Widget)

function TextBox:init(x, y, w, h, text)
   Widget.init(self, x, y, w, h)
   self.first_line = 1

   self.leading = 3

   self.max_lines = floor((self.h - 2) / (font:height() + self.leading))
   self.scroll = ScrollBar(self.x + self.w - 8, self.y, 8, self.h, 1, 0, 1, self.max_lines)

   self:settext(text)
end

function TextBox:settext(text)
   self.lines = wrap_lines(text or "", self.w - 10)
end

function TextBox:interact()
   if pge.controls.pressed(PGE_CTRL_UP) then
      self.first_line = self.first_line - 1
   elseif pge.controls.pressed(PGE_CTRL_DOWN) then
      self.first_line = self.first_line + 1
   elseif pge.controls.pressed(PGE_CTRL_LEFT) then
      self.first_line = self.first_line - self.max_lines + 1
   elseif pge.controls.pressed(PGE_CTRL_RIGHT) then
      self.first_line = self.first_line + self.max_lines - 1
   end
end

function TextBox:update(delta)
   Widget.update(self, delta)

   self.first_line = clamp(self.first_line, 1, #self.lines - self.max_lines + 1)

   self.scroll.val = self.first_line
   self.scroll.hi = #self.lines
   self.scroll:update(delta)
end

function TextBox:draw()
   pge.gfx.drawrect(self.x, self.y, self.w, self.h, colors[theme().backcolor])

   local y = self.y + 1
   local af = font
   for i, line in subset(self.lines, self.first_line, self.max_lines) do
      local x = self.x + 1
      for j, span in ipairs(line) do
         if span.font ~= af then af = span.font ; af:activate() end
         af:print(x, y, colors[theme().forecolor], span.text)
         if span.uline then
            pge.gfx.drawline(x, y + font:height(), x + span.width, y + font:height(), colors[theme().forecolor])
         end
         x = x + span.width
      end
      y = y + font:height() + self.leading
   end

   self.scroll:draw()
end

--------------------------------------------------------------------------------

ListBox = class(Widget)

function ListBox:init(x, y, w, h, items)
   Widget.init(self, x, y, w, h)
   self.items = items or {}
   self.selected = 1
   self.first_line = 1
   self.leading = 3
   self.max_lines = floor((self.h - 2) / (font:height() + self.leading))

   self.scroll = ScrollBar(self.x + self.w - 8, self.y, 8, self.h, 1, 0, 1, self.max_lines)
end

function ListBox:interact()
   if pge.controls.pressed(PGE_CTRL_UP) then
      if self.selected > 1 then
         self.selected = self.selected - 1
      else
         self.selected = #self.items
      end
   elseif pge.controls.pressed(PGE_CTRL_DOWN) then
      if self.selected < #self.items then
         self.selected = self.selected + 1
      else
         self.selected = 1
      end
   elseif pge.controls.pressed(PGE_CTRL_LEFT) then
      if self.selected > self.first_line then
         self.selected = self.first_line
      else
         self.selected = self.selected - self.max_lines + 1
      end
   elseif pge.controls.pressed(PGE_CTRL_RIGHT) then
      if self.selected < self.first_line + self.max_lines - 1 then
         self.selected = self.first_line + self.max_lines - 1
      else
         self.selected = self.selected + self.max_lines - 1
      end
   end
end

function ListBox:update(delta)
   Widget.update(self, delta)

   self.selected = clamp(self.selected, 1, #self.items)
   self.first_line = clamp(self.first_line, self.selected - self.max_lines + 1, self.selected)
   self.first_line = clamp(self.first_line, 1, #self.items - self.max_lines + 1)

   self.scroll.val = self.first_line
   self.scroll.hi = #self.items
   self.scroll:update(delta)
end

function ListBox:draw()
   pge.gfx.drawrect(self.x, self.y, self.w, self.h, colors[theme().backcolor])

   font:activate()

   local y = self.y + 1
   for i, item in subset(self.items, self.first_line, self.max_lines) do
      if i == self.selected then
         pge.gfx.drawrect(self.x, y, self.w, font:height() + self.leading, colors[theme().highlight])
      end

      item = tostring(item)
      if self.numbered then item = '%d. %s' % { i, item } end

      font:print(self.x + 1, y, colors[theme().forecolor], item)
      y = y + font:height() + self.leading
   end

   self.scroll:draw()
end

--------------------------------------------------------------------------------

TitleBar = class(Widget)

function TitleBar:init(x, y, w, h, text)
   Widget.init(self, x, y, w, h)
   self.text = text or ""
end

function TitleBar:update(delta)
   Widget.update(self, delta)
end

function TitleBar:draw()
   pge.gfx.drawrect(self.x, self.y, self.w, self.h, colors[theme().infoback])

   fontb:activate()
   fontb:print(self.x + 1, self.y, colors[theme().infofore], self.text)
end

--------------------------------------------------------------------------------

StatusBar = class(Widget)

function StatusBar:init(x, y, w, h, buttons)
   Widget.init(self, x, y, w, h)
   self:setbuttons(buttons)
end

function StatusBar:setbuttons(buttons)
   self.buttons = buttons or {}

   local btns = {}
   if self.buttons.X then table.insert(btns, "X: "  .. self.buttons.X) end
   if self.buttons.O then table.insert(btns, "O: "  .. self.buttons.O) end
   if self.buttons.S then table.insert(btns, "[]: " .. self.buttons.S) end
   if self.buttons.T then table.insert(btns, "/\\: " .. self.buttons.T) end

   if self.buttons.LR then
      table.insert(btns, "L/R: " .. self.buttons.LR)
   else
      if self.buttons.L then table.insert(btns, "L: "  .. self.buttons.L) end
      if self.buttons.R then table.insert(btns, "R: "  .. self.buttons.R) end
   end

   if self.buttons.St then table.insert(btns, "Start: " .. self.buttons.St) end
   if self.buttons.Se then table.insert(btns, "Select: " .. self.buttons.Se) end

   self.text = table.concat(btns, "   ")
end

function StatusBar:update(delta)
   Widget.update(self, delta)
end

function StatusBar:draw()
   pge.gfx.drawrect(self.x, self.y, self.w, self.h, colors[theme().infoback])

   font:activate()
   font:print(self.x + 1, self.y, colors[theme().infofore], self.text)

   --local s = '%d KB free' % (pge.utils.freeram()/1024)
   --font:print(self.x + self.w - font:measure(s) - 2, self.y, colors[theme().infofore], s)
end

--------------------------------------------------------------------------------

View = class(Widget)

function View:init(title, buttons, ctrltype, ...)
   Widget.init(self, 0, 0, 480, 272)
   self.title = TitleBar(0, 0, 480, fontb:height() + 1, title)
   self.status = StatusBar(0, 271 - font:height(), 480, font:height() + 1, buttons)
   self.control = ctrltype(0, self.title.h, 480, self.status.y - self.title.h, ...)
end

function View:interact()
   self.control:interact()
end

function View:update(delta)
   Widget.update(self, delta)

   self.title:update(delta)
   self.status:update(delta)
   self.control:update(delta)

   if not pge.running() then self:close() end
end

function View:draw()
   self.title:draw()
   self.status:draw()
   self.control:draw()
end

function View:close()
   self:on_close()
   screen:pop_view()
end

function View:on_close() end

--------------------------------------------------------------------------------

ImportView = class(View)

function ImportView:init()
   View.init(self, "Importing FFNDATA.DAT...", {}, Widget)
end

--------------------------------------------------------------------------------

MainMenuView = class(View)

function MainMenuView:init()
   View.init(self, "FanFiction.Net Browser", { O = "Select" }, ListBox)

   self.calls = {
      LibraryView,
      CategoriesView,
      --FindAuthorView,
      --SearchView,
      FeedsView,
      OptionsView,
      pge.exit,
      }
   table.insert(self.control.items, "Library")
   table.insert(self.control.items, "Categories")
   --table.insert(self.control.items, "Find Author")
   --table.insert(self.control.items, "Search")
   table.insert(self.control.items, "Feeds")
   table.insert(self.control.items, "Options")
   table.insert(self.control.items, "Exit")
end

function MainMenuView:interact()
   View.interact(self)

   if pge.controls.pressed(PGE_CTRL_CIRCLE) then
      screen:push_view(self.calls[self.control.selected]())
   end
end

--------------------------------------------------------------------------------

OptionsView = class(View)

function OptionsView:init()
   View.init(self, "Options", { X = "Return", O = "Select" }, ListBox)

   self.calls = { ThemesView }
   table.insert(self.control.items, "Themes")
end

function OptionsView:interact()
   View.interact(self)

   if pge.controls.pressed(PGE_CTRL_CIRCLE) then
      screen:push_view(self.calls[self.control.selected]())
   elseif pge.controls.pressed(PGE_CTRL_CROSS) then
      self:close()
   end
end

--------------------------------------------------------------------------------

ThemesView = class(View)

function ThemesView:init()
   View.init(self, "Themes", { X = "Return", O = "Edit", S = "New", T = "Remove" }, ListBox)

   for i, theme in ipairs(db.theme) do
      self.control.items[i] = db.theme[i].name
   end

   self.control.numbered = true
   self.control.selected = gettheme()
end

function ThemesView:update(delta)
   View.update(self, delta)
end

function ThemesView:interact()
   View.interact(self)

   if pge.controls.pressed(PGE_CTRL_CIRCLE) then
      screen:push_view(CustomThemeView(self.control.selected))
   elseif pge.controls.pressed(PGE_CTRL_TRIANGLE) then
      if #db.theme > 1 then
         local rslt = screen:showDialog(Dialog.message(
            'Remove theme "%s"?' % db.theme[self.control.selected].name,
            PGE_UTILS_MSG_DIALOG_YESNO_BUTTONS +
            PGE_UTILS_MSG_DIALOG_DEFAULT_BUTTON_NO))
         if rslt == PGE_UTILS_MSG_DIALOG_RESULT_YES then
            table.remove(db.theme, self.control.selected)
            table.remove(self.control.items, self.control.selected)
            if self.control.selected > #db.theme then
               self.control.selected = #db.theme
               settheme(self.control.selected)
            end
         end
      end
   elseif pge.controls.pressed(PGE_CTRL_SQUARE) then
      local t = table.copy(theme())
      local n = #db.theme + 1
      t.name = "New Theme"
      db.theme[n] = t
      self.control.selected = n
      screen:push_view(CustomThemeView(self.control.selected))
   elseif pge.controls.pressed(PGE_CTRL_CROSS) then
      self:close()
   --elseif pge.controls.pressed(PGE_CTRL_START) then
   --   upload_themes()
   end

   settheme(self.control.selected)
end

function ThemesView:on_close()
   db.theme:save()
end

--------------------------------------------------------------------------------

CustomThemeView = class(View)

function CustomThemeView:init(index)
   self.oldtheme = gettheme()
   settheme(index)
   self.backup = table.copy(theme())

   View.init(self, 'Edit Theme - "%s"' % self.backup.name,
      { X = "Return", O = "Accept", LR = "Change" }, ListBox)

   self.colors = { 'name', 'forecolor', 'backcolor', 'infofore', 'infoback', 'highlight' }
   table.insert(self.control.items, "Name: " .. theme().name)
   table.insert(self.control.items, "Foreground")
   table.insert(self.control.items, "Background")
   table.insert(self.control.items, "Infobar foreground")
   table.insert(self.control.items, "Infobar background")
   table.insert(self.control.items, "Highlight")
end

function CustomThemeView:update(delta)
   self.control.items[1] = "Name: " .. theme().name

   View.update(self, delta)
end

function CustomThemeView:close()
   settheme(self.oldtheme)
   View.close(self)
end

function CustomThemeView:interact()
   View.interact(self)

   local sel = self.colors[self.control.selected]
   if pge.controls.pressed(PGE_CTRL_CIRCLE) then
      self:close()
   elseif pge.controls.pressed(PGE_CTRL_LTRIGGER) then
      if sel == 'name' then
         local ok, name = screen:showDialog(Dialog.osk("Theme Name", theme().name))
         if name ~= "" then theme().name = name end
      else
         theme()[sel] = (theme()[sel] - 1) % 16
      end
   elseif pge.controls.pressed(PGE_CTRL_RTRIGGER) then
      if sel == 'name' then
         local ok, name = screen:showDialog(Dialog.osk("Theme Name", theme().name))
         if name ~= "" then theme().name = name end
      else
         theme()[sel] = (theme()[sel] + 1) % 16
      end
   elseif pge.controls.pressed(PGE_CTRL_CROSS) then
      table.copy(self.backup, theme())
      self:close()
   end
end

--------------------------------------------------------------------------------

LibraryView = class(View)

function LibraryView:init()
   View.init(self, "Library", { X = "Return", O = "Read", T = "Remove" }, ListBox)

   for i, sid in ipairs(db.library) do
      local story = db.story[sid]
      self.control.items[i] = '"%s" by %s' % {
         story.title, db.author[story.author].name
         }
   end

   self.control.numbered = true
end

--[[
function LibraryView:update(delta)
   for i, sid in subset(
      self.stories, self.control.first_line, self.control.max_lines)
   do
      local story = db.story[sid]
      self.control.items[i] = '%d. "%s" by %s' % {
         i, story.title, db.author[story.author].name
         }
   end

   View.update(self, delta)
end
]]
function LibraryView:interact()
   View.interact(self)

   if pge.controls.pressed(PGE_CTRL_CIRCLE) then
      if db.library[self.control.selected] then
         local sid = db.library[self.control.selected]
         screen:push_view(StoryView(sid))
         table.remove(db.library, self.control.selected)
         table.insert(db.library, 1, sid)
         local item = table.remove(self.control.items, self.control.selected)
         table.insert(self.control.items, 1, item)
         self.control.selected = 1
         db.library:save()
      end
   elseif pge.controls.pressed(PGE_CTRL_TRIANGLE) then
      if db.library[self.control.selected] then
         local rslt = screen:showDialog(Dialog.message(
            "Remove this story from your library?",
            PGE_UTILS_MSG_DIALOG_YESNO_BUTTONS +
            PGE_UTILS_MSG_DIALOG_DEFAULT_BUTTON_NO))
         if rslt == PGE_UTILS_MSG_DIALOG_RESULT_YES then
            table.remove(self.control.items, self.control.selected)
            table.remove(db.library, self.control.selected)
            db.library:save()
         end
      end
   elseif pge.controls.pressed(PGE_CTRL_CROSS) then
      self:close()
   end
end

--------------------------------------------------------------------------------

function sort_categories (c1, c2)
   return FFN.subcategory[c1]:lower() < FFN.subcategory[c2]:lower()
end

local categories = {}
for c, name in pairs(FFN.subcategory) do
   table.insert(categories, c)
end

table.sort(categories, sort_categories)

CategoriesView = class(View)

function CategoriesView:init()
   View.init(self, "Categories",
      { X = "Return", O = "Select", L = "Prev Letter", R = "Next Letter" },
      ListBox)

   for i, c in ipairs(categories) do
      self.control.items[i] = FFN.subcategory[c]
   end

   self.control.numbered = true
end

function CategoriesView:interact()
   View.interact(self)

   if pge.controls.pressed(PGE_CTRL_CIRCLE) then
      screen:push_view(FeedView(
         Feed(FFN.list(categories[self.control.selected]))
         ))
   elseif pge.controls.pressed(PGE_CTRL_LTRIGGER) then
      local t = self.control.selected
      repeat
         self.control.selected = wrap(self.control.selected - 1, 1, #self.control.items)
      until self.control.selected == t or
         FFN.subcategory[categories[self.control.selected]]:sub(1,1):lower() ~=
         FFN.subcategory[categories[t]]:sub(1,1):lower()
   elseif pge.controls.pressed(PGE_CTRL_RTRIGGER) then
      local t = self.control.selected
      repeat
         self.control.selected = wrap(self.control.selected + 1, 1, #self.control.items)
      until self.control.selected == t or
         FFN.subcategory[categories[self.control.selected]]:sub(1,1):lower() ~=
         FFN.subcategory[categories[t]]:sub(1,1):lower()
   elseif pge.controls.pressed(PGE_CTRL_CROSS) then
      self:close()
   end
end

--------------------------------------------------------------------------------

FindAuthorView = class(View)

function FindAuthorView:init()
   View.init(self, "Find Author", { X = "Return" }, ListBox)

   table.insert(self.control.items, "This feature is not yet supported.")
end

function FindAuthorView:interact(delta)
   View.interact(self)

   if pge.controls.pressed(PGE_CTRL_CIRCLE) then

   elseif pge.controls.pressed(PGE_CTRL_TRIANGLE) then

   elseif pge.controls.pressed(PGE_CTRL_SQUARE) then

   elseif pge.controls.pressed(PGE_CTRL_CROSS) then
      self:close()
   end
end

--------------------------------------------------------------------------------

SearchView = class(View)

function SearchView:init()
   View.init(self, "Search", { X = "Return" }, ListBox)

   self.search = { type = "story", plus_keywords = "", minus_keywords = "", match = "any", categoryid = 0, }
   self.include = ""
   self.exclude = ""

   table.insert(self.control.items, "This feature is not yet supported.")
end

function SearchView:interact()
   View.interact(self)

   if pge.controls.pressed(PGE_CTRL_CIRCLE) then

   elseif pge.controls.pressed(PGE_CTRL_TRIANGLE) then

   elseif pge.controls.pressed(PGE_CTRL_SQUARE) then

   elseif pge.controls.pressed(PGE_CTRL_CROSS) then
      self:close()
   end
end

--------------------------------------------------------------------------------

function sort_feeds(f1, f2)
   if dirname(f1):lower() < dirname(f2):lower() then
      return true
   end
   return (db.feed[f1].title or "") < (db.feed[f2].title or "")
end

FeedsView = class(View)

function FeedsView:init(feed)
   View.init(self, "Feeds", { X = "Return", O = "View feed" }, ListBox)

   self.feeds = {}
   for file, feed in pairs(db.feed) do
      table.insert(self.feeds, file)
   end
   --table.sort(self.feeds, sort_feeds)
   table.sort(self.feeds)

   for i, file in ipairs(self.feeds) do
      self.control.items[i] = db.feed[file].title or file
   end

   self.control.numbered = true
end

function FeedsView:interact()
   View.interact(self)

   if pge.controls.pressed(PGE_CTRL_CIRCLE) then
      if self.feeds[self.control.selected] then
         local file = self.feeds[self.control.selected]
         screen:push_view(FeedView(Feed(file, db.feed[file].url)))
      end
   elseif pge.controls.pressed(PGE_CTRL_CROSS) then
      self:close()
   end
end

--------------------------------------------------------------------------------

FeedView = class(View)

function FeedView:init(feed)
   self.feed = feed
   View.init(self, self.feed.title and self.feed.title or "Feed not available",
      { X = "Return", O = "Read", T = "Details", S = "Update feed" }, ListBox)

   self.stories = {}
   if self.feed.entry then
      for i, entry in ipairs(self.feed.entry) do
         local sid = FFN.storyid(entry.link.alternate)
         local story = db.story[sid]
         self.stories[i] = sid
         self.control.items[i] = '"%s" by %s' % {
            story.title, db.author[story.author].name
            }
      end
   end

   self.control.numbered = true
end
--[[
function FeedView:update(delta)
   for i, sid in subset(
      self.stories, self.control.first_line, self.control.max_lines)
   do
      local story = db.story[sid]
      self.control.items[i] = '%d. "%s" by %s' % {
         i, story.title, db.author[story.author].name
         }
   end

   View.update(self, delta)
end
]]
function FeedView:interact()
   View.interact(self)

   if pge.controls.pressed(PGE_CTRL_CIRCLE) then
      if self.stories[self.control.selected] then
         screen:push_view(StoryView(self.stories[self.control.selected]))
      end
   elseif pge.controls.pressed(PGE_CTRL_TRIANGLE) then
      if self.feed.entry[self.control.selected] then
         screen:push_view(EntryView(self.feed.entry[self.control.selected]))
      end
   elseif pge.controls.pressed(PGE_CTRL_SQUARE) then
      self.feed:load(true)
      for i, entry in ipairs(self.feed.entry) do
         self.stories[i] = FFN.storyid(entry.link.alternate)
      end
   elseif pge.controls.pressed(PGE_CTRL_CROSS) then
      self:close()
   end
end

--------------------------------------------------------------------------------

EntryView = class(View)

function EntryView:init(entry)
   self.entry = entry
   View.init(self,
      '"%s" by %s' % {self.entry.title, self.entry.author.name},
      { X = "Return", O = "Download", T = "More by this author" },
      TextBox, convert_html(entry.summary, format_tags))

   self.sid = FFN.storyid(entry.link.alternate)

   local userid = FFN.userid(entry.author.uri)
   local nchapters = FFN.nchapters(entry.summary)

   db.author[userid] = {
      name = entry.author.name,
      }
   db.story[self.sid] = {
      title = entry.title,
      author = userid,
      nchapters = nchapters,
      }
end

function EntryView:interact()
   View.interact(self)

   if pge.controls.pressed(PGE_CTRL_CIRCLE) then
      local view = DownloadView(self.entry)
      screen:push_view(view)
      if view.count > 0 then
         screen:showDialog(Dialog.message('Downloaded %d new chapter(s).' % view.count))
      end
   elseif pge.controls.pressed(PGE_CTRL_TRIANGLE) then
      local userid = FFN.userid(self.entry.author.uri)
      screen:push_view(FeedView(Feed(FFN.author(userid))))
   elseif pge.controls.pressed(PGE_CTRL_CROSS) then
      self:close()
   end
end

--------------------------------------------------------------------------------

StoryView = class(View)

function StoryView:init(sid)
   self.sid = sid
   self.story = db.story[self.sid]
   self.bookmark = db.bookmark:get(self.sid, {})

   View.init(self, self.story.title, { X = "Return", L = "Prev Chapter", R = "Next Chapter" }, TextBox)

   self:loadchapter()
end

function StoryView:loadchapter(chapter)
   self.bookmark.chapter = clamp(chapter or self.bookmark.chapter, 1, self.story.nchapters)
   self.title.text = '%s - Chapter %d/%d' % { self.story.title, self.bookmark.chapter, self.story.nchapters }

   offline = false
   local str = getchapter(FFN.chapter(self.sid, self.bookmark.chapter)) or 'Chapter not available.'
   self.control:settext(convert_html(str, format_tags))
   self.control.first_line = self.bookmark[self.bookmark.chapter] or 1
end

function StoryView:interact()
   View.interact(self)

   if pge.controls.pressed(PGE_CTRL_LTRIGGER) then
      if self.bookmark.chapter > 1 then
         self:loadchapter(self.bookmark.chapter - 1)
      end
   elseif pge.controls.pressed(PGE_CTRL_RTRIGGER) then
      if self.bookmark.chapter < self.story.nchapters then
         self:loadchapter(self.bookmark.chapter + 1)
      end
   elseif pge.controls.pressed(PGE_CTRL_CROSS) then
      self:close()
   end

   if self.control.first_line > 1 then
      self.bookmark[self.bookmark.chapter] = self.control.first_line
   else
      self.bookmark[self.bookmark.chapter] = nil
   end
end

function StoryView:on_close()
   db.bookmark:save()
end

--------------------------------------------------------------------------------

DownloadView = class(View)

function DownloadView:init(entry)
   self.sid = FFN.storyid(entry.link.alternate)
   self.story = db.story[self.sid]

   shelve_story(self.sid)

   View.init(self, 'Downloading "%s"...' % self.story.title, { X = 'Cancel' },
      ProgressBar, 0, self.story.nchapters)

   self.count = 0
   self.chapter = 0
   offline = false
end

function DownloadView:interact()
   View.interact(self)

   if pge.controls.pressed(PGE_CTRL_CROSS) then
      self:close()
   end
end

function DownloadView:update(delta)
   self.chapter = self.chapter + 1

   if self.chapter <= self.story.nchapters then
      local filename, url = FFN.chapter(self.sid, self.chapter)
      if needfile(filename) then
         getchapter(filename, url)
         self.count = self.count + 1
      end
   else
      self:close()
   end

   self.control.val = self.chapter

   View.update(self, delta)
end

--------------------------------------------------------------------------------

function shelve_story(sid)
   if table.find(db.library, sid) < 1 then
      table.insert(db.library, sid)
      db.library:save()
   end
end

--------------------------------------------------------------------------------

colors = {
   [00] = pge.gfx.createcolor(  0,   0,   0),
   [01] = pge.gfx.createcolor(  0,   0, 170),
   [02] = pge.gfx.createcolor(  0, 170,   0),
   [03] = pge.gfx.createcolor(  0, 170, 170),
   [04] = pge.gfx.createcolor(170,   0,   0),
   [05] = pge.gfx.createcolor(170,   0, 170),
   [06] = pge.gfx.createcolor(170,  85,   0),
   [07] = pge.gfx.createcolor(170, 170, 170),
   [08] = pge.gfx.createcolor( 85,  85,  85),
   [09] = pge.gfx.createcolor( 85,  85, 255),
   [10] = pge.gfx.createcolor( 85, 255,  85),
   [11] = pge.gfx.createcolor( 85, 255, 255),
   [12] = pge.gfx.createcolor(255,  85,  85),
   [13] = pge.gfx.createcolor(255,  85, 255),
   [14] = pge.gfx.createcolor(255, 255,  85),
   [15] = pge.gfx.createcolor(255, 255, 255),
}

font   = pge.font.load('font/vera.ttf',   14, PGE_VRAM)
fontb  = pge.font.load('font/verabd.ttf', 14, PGE_VRAM)
fonti  = pge.font.load('font/verait.ttf', 14)
fontbi = pge.font.load('font/verabi.ttf', 14)

function settheme(n)
   db.theme.__current = clamp(n, 1, #db.theme)
end
function gettheme()
   return db.theme.__current or 1
end
function theme()
   return __temptheme or db.theme[gettheme()]
end

--[[
THEME_UPLOAD_URL = 'http://fanfiction.ath.cx/ffn-browser/theme.php'

function urlencode(str)
   return str:gsub('%W', function(c) return '%%%02X' % c:byte() end)
end

function upload_themes()
   offline = false
   if ap_connect() then
      db.theme:save()

      local ok, result = pge.net.postform(
         THEME_UPLOAD_URL,
         'id=' .. urlencode(pge.utils.psid()) ..
         '&name=' .. urlencode(pge.utils.nickname()) ..
         '&themes=' .. urlencode(dump(db.theme))
         )

      if ok then
         local themes = assert(loadstring(result))()

         if type(themes) == 'table' and #themes > 0 then
            screen:showDialog(Dialog.message(
               "Uploaded themes:\n   " .. table.concat(themes, '\n   ')
               ))
         else
            local err = type(themes) == 'string' and themes or 'unknown error'
            screen:showDialog(Dialog.message("Upload error: " .. err))
         end
      end
   end
end
]]

function set_default_themes()
   table.insert(db.theme, {
      name="Default",
      forecolor=0,
      backcolor=15,
      infofore=15,
      infoback=1,
      highlight=7,
   })
   table.insert(db.theme, {
      name="Monochrome Light",
      forecolor=0,
      backcolor=15,
      infofore=15,
      infoback=0,
      highlight=7,
   })
   table.insert(db.theme, {
      name="Monochrome Dark",
      forecolor=15,
      backcolor=8,
      infofore=15,
      infoback=0,
      highlight=0,
   })
   table.insert(db.theme, {
      name="Mint & Lime",
      forecolor=0,
      backcolor=2,
      infofore=0,
      infoback=10,
      highlight=10,
   })
   table.insert(db.theme, {
      name="Silky Doll",
      forecolor=0,
      backcolor=12,
      infofore=15,
      infoback=4,
      highlight=4,
   })
   table.insert(db.theme, {
      name="Darkness Beyond Twilight",
      forecolor=7,
      backcolor=0,
      infofore=0,
      infoback=4,
      highlight=4,
   })
   table.insert(db.theme, {
      name="Hyrulean Hero",
      forecolor=0,
      backcolor=2,
      infofore=14,
      infoback=6,
      highlight=14,
   })
   table.insert(db.theme, {
      name="Red, White & Bluejeans",
      forecolor=15,
      backcolor=8,
      infofore=15,
      infoback=1,
      highlight=4,
   })

   settheme(1)
end

db = {
   theme    = Database('config/theme.lua'),
   library  = Database('config/library.lua'),
   bookmark = Database('config/bookmark.lua'),
   story    = Database('config/story.lua'),
   author   = Database('config/author.lua'),
   feed     = Database('config/feed.lua'),
   }

if #db.theme == 0 then
   set_default_themes()
end

screen = Screen()

-- Try to import old data
if pge.file.exists('FFNDATA.DAT') then
   screen:push_view(ImportView())
   screen:doFrame()

   local ffndata = loadfile('FFNDATA.DAT')

   if ffndata then
      ffndata = ffndata()

      if ffndata then
         for k, v in pairs(db) do
            local g = db[k]
            if k == 'theme' then k = 'themes' end
            for kk, vv in pairs(ffndata[k] or {}) do
               g[kk] = vv
            end

            g:save()
         end

         local rslt = screen:showDialog(Dialog.message(
            'Import complete. Delete FFNDATA.DAT?',
            PGE_UTILS_MSG_DIALOG_YESNO_BUTTONS +
            PGE_UTILS_MSG_DIALOG_DEFAULT_BUTTON_NO))

         if rslt == PGE_UTILS_MSG_DIALOG_RESULT_YES then
            pge.file.remove('FFNDATA.DAT')
         else
            pge.file.rename('FFNDATA.DAT', 'FFNDATA.OLD')
         end
      else
         screen:showDialog(Dialog.message('Import error:\nNo data found in FFNDATA.DAT.'))
      end
   else
      screen:showDialog(Dialog.message('Import error:\nCould not open FFNDATA.DAT.'))
   end
end

screen:push_view(MainMenuView())
screen:run()

ap_disconnect()

db.story:save()
db.author:save()
db.feed:save()

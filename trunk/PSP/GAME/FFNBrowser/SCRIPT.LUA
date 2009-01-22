require "class"
require "FFN"
require "XML"
require "HTML"
--require "HTTP"
require "dump"

--------------------------------------------------------------------------------

local min   = pge.math.min   or math.min
local max   = pge.math.max   or math.max
local floor = pge.math.floor or math.floor

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

local smt = getmetatable('')
function smt:__mod(rhs)
   if type(rhs) == 'table' then
      return self:format(unpack(rhs))
   else
      return self:format(rhs)
   end
end
function smt:__mul(rhs)
   return self:rep(tonumbe(rhs))
end

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

function subset (tbl, first, last)
   local i, j = max(1, first), min(#tbl, last)
   return function()
      if i <= j then
         i = i + 1
         return i - 1, tbl[i - 1]
      end
   end
end

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

function mkdirs(path)
   local p = ''
   for dir in path:gmatch('/?[^/]+/') do
      p = p .. dir
      if not (pge.dir.exists(p) or pge.dir.mkdir(p)) then
         return false
      end
   end
   return true
end

function basename(path)
   return path:sub((path:find('[/\\][^/\\]*$') + 1) or 1)
end

function dirname(path)
   return path:sub(1, path:find('[/\\][^/\\]*$') or 0)
end

function readfile(filename)
   local fh = pge.file.open(filename, PGE_FILE_RDONLY)
   if fh then
      local str = fh:read(fh:size())
      fh:close()
      return str
   end
end

function writefile(filename, content)
   local fh = pge.file.open(
      filename, PGE_FILE_WRONLY+PGE_FILE_CREATE+PGE_FILE_TRUNC)
   if fh then
      fh:write(content)
      fh:close()
      return true
   end
end

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

function wrap_lines(text, maxwidth)
   maxwidth = maxwidth or 480
   local lines = {}
   local first, last, width = 1, 0, 0
   for i = 1, text:len() do
      local c = text:sub(i, i)
      if c == " " or c == "\n" then
         last = i
      end
      width = width + font:measure(c)
      if c == "\n" or (c ~= " " and width >= maxwidth) then
         table.insert(lines, text:sub(first, last))
         first = last + 1
         width = font:measure(text:sub(first, i))
      end
   end
   if first <= text:len() then
      table.insert(lines, text:sub(first))
   end
   return lines
end

--------------------------------------------------------------------------------

Database = class()

function Database:init(file)
   self._data = {}
   self._file = ''

   self._meta = {}
   local _meta = self._meta
   function _meta:__index(key)
      self[key] = {}
      setmetatable(self[key], _meta)
      return self[key]
   end

   self:load(file or self._file)
end

function Database:load(file)
   self._file = file or self._file
   self._data = loadfile(self._file) or {}
   setmetatable(self._data, self._meta)
end

function Database:group(grp)
   if self._data[grp] == nil then self._data[grp] = {} end
   return self._data[grp]
end

function Database:set(grp, key, val)
   if val then self:group(grp)[key] = val end
end

function Database:unset(grp, key)
   self:group(grp)[key] = nil
end

function Database:get(grp, key, def)
   local g = self:group(grp)
   if not g[key] then g[key] = def end
   return g[key]
end

function Database:save(file)
   self._file = file or self._file
   writefile(self._file, 'return '..dump(self._data))
end

--------------------------------------------------------------------------------

Feed = class()

--[[
Feed = "/atom/{etc}"
<category term="{category}"/>
<category term="{language}"/>
<category term="Fiction Rated: {rating}"/>
]]

function Feed:init(file, url)
   self.file = file
   self.url = url
   self:load()
end

function Feed:load(overwrite)
   offline = false
   local xml = getfile(self.file, self.url, overwrite)
   if xml then
      local feed = XML(xml)
      for k, v in pairs(feed.feed) do
         self[k] = v
      end

      if #self.entry < 1 then
         self.entry = { self.entry }
      end

      db.feed[self.file] = { title = self.title['$'], url = self.url }
      for i, entry in ipairs(self.entry) do
         local userid = FFN.userid(entry.author.uri['$'])
         local storyid = FFN.storyid(entry.link['@href'])
         local nchapters = tonumber(entry.summary['$']:match('Chapters: (%d+)'))
         db.author[userid] = { name = entry.author.name['$'] }
         db.story[storyid] = { title = entry.title['$'], author = userid, nchapters = nchapters }
      end
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
   self.views = {}
   self.timer = pge.timer.create()
   self.grayed = pge.gfx.createcolor(0, 0, 0, 192)
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

function Screen:doFrame(dialog)
   pge.controls.update()
   if pge.controls.pressed(PGE_CTRL_SELECT) then
      db:save()
   --elseif pge.controls.pressed(PGE_CTRL_START) then
   --   screenshot()
   end

   local view = self:view()

   if not dialog then view:interact() end

   self.timer:update()
   local delta = self.timer:getdelta()
   view:update(delta)

   if not view.running then self:pop_view() end

   pge.gfx.startdrawing()
   pge.gfx.clearscreen(self.backcolor)

   view:draw()

   if dialog then
      pge.gfx.drawrect(0, 0, 480, 272, self.grayed)
      pge.gfx.enddrawing()
      dialog:update()
   else
      pge.gfx.enddrawing()
   end

   pge.gfx.swapbuffers()
end

function Screen:showDialog(dialog)
   while dialog.running do
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
end

--------------------------------------------------------------------------------

ProgressBar = class(Widget)

function ProgressBar:init(x, y, w, h, lo, hi, val)
   Widget.init(self, x, y, w, h)
   self.lo = lo or 0
   self.hi = hi or 100
   self.val = val or self.lo
end

function ProgressBar:update(delta)
   self.pw = (self.w - 2) * (self.val - self.lo) / max(1, self.hi - self.lo)
end

function ProgressBar:draw()
   local y, h = self.y, self.h
   if h > font:height() + 1 then
      h = font:height() + 1
      y = self.y + (self.h - h) / 2
   end
   pge.gfx.drawrect(self.x, self.y, self.w, self.h, colors[theme().backcolor])
   pge.gfx.drawrect(self.x, y, self.w, h, colors[theme().forecolor])
   pge.gfx.drawrect(self.x + 1, y + 1, self.pw, h - 2, colors[theme().highlight])
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

function ScrollBar:update(delta)
   Widget.update(self, delta)

   local h = self.h - 2
   local range = max(1, self.hi - self.lo + 1)
   self.val = clamp(self.val, self.lo, self.hi)
   self.ty = h * (self.val - self.lo) / range
   self.th = clamp(h * self.step / range, 1, h)
end

function ScrollBar:draw()
   pge.gfx.drawrect(self.x, self.y, self.w, self.h, colors[theme().forecolor])
   pge.gfx.drawrect(self.x + 1, self.y + self.ty + 1, self.w - 2, self.th, colors[theme().highlight])
end

--------------------------------------------------------------------------------

TextBox = class(Widget)

function TextBox:init(x, y, w, h, text)
   Widget.init(self, x, y, w, h)
   self.first_line = 1
   self.max_lines = floor((self.h - 2) / (font:height() + 1))

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

   font:activate()
   local y = self.y + 1
   for i, line in subset(self.lines, self.first_line, self.first_line + self.max_lines - 1) do
      font:print(self.x + 1, y, colors[theme().forecolor], self.lines[i])
      y = y + font:height() + 1
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
   self.max_lines = floor((self.h - 2) / (font:height() + 1))

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
   for i, item in subset(self.items, self.first_line, self.first_line + self.max_lines - 1) do
      if i == self.selected then
         pge.gfx.drawrect(self.x, y, self.w, font:height() + 1, colors[theme().highlight])
      end
      font:print(self.x + 1, y, colors[theme().forecolor], tostring(item))
      y = y + font:height() + 1
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
   self.buttons = buttons or {}
end

function StatusBar:update(delta)
   Widget.update(self, delta)
end

function StatusBar:draw()
   pge.gfx.drawrect(self.x, self.y, self.w, self.h, colors[theme().infoback])

   local btns = {}
   if self.buttons.St then table.insert(btns, "Start: " .. self.buttons.St) end
   if self.buttons.Se then table.insert(btns, "Select: " .. self.buttons.Se) end
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

   font:activate()
   font:print(self.x + 1, self.y, colors[theme().infofore], table.concat(btns, "   "))

   local s = '%d KB free' % (pge.utils.freeram()/1024)
   font:print(self.x + self.w - font:measure(s) - 2, self.y, colors[theme().infofore], s)
end

--------------------------------------------------------------------------------

View = class(Widget)

function View:init(title, buttons, ctrltype, ...)
   Widget.init(self, 0, 0, 480, 272)
   self.title = TitleBar(0, 0, 480, fontb:height() + 1, title)
   self.status = StatusBar(0, 271 - font:height(), 480, font:height() + 1, buttons)
   self.control = ctrltype(0, self.title.h, 480, self.status.y - self.title.h, ...)
   self.running = true
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
   self.running = false
end

--------------------------------------------------------------------------------

MainMenuView = class(View)

function MainMenuView:init()
   View.init(self, "FanFiction.Net Browser", {O = "Select" }, ListBox)

   self.calls = {
      LibraryView,
      CategoriesView,
      --FindAuthorView,
      --SearchView,
      FeedsView,
      OptionsView,
      }
   table.insert(self.control.items, "Library")
   table.insert(self.control.items, "Categories")
   --table.insert(self.control.items, "Find Author")
   --table.insert(self.control.items, "Search")
   table.insert(self.control.items, "Feeds")
   table.insert(self.control.items, "Options")
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
   View.init(self, "Options", {X = "Return", O = "Select" }, ListBox)

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
   View.init(self, "Themes", {X = "Return", O = "Edit", S = "New", T = "Remove" }, ListBox)

   self.themes = themes

   self.control.selected = gettheme()
end

function ThemesView:update(delta)
   for i, t in ipairs(self.themes) do
      self.control.items[i] = t.name
   end

   View.update(self, delta)
end

function ThemesView:interact()
   View.interact(self)

   if pge.controls.pressed(PGE_CTRL_CIRCLE) then
      screen:push_view(CustomThemeView(self.control.selected))
   elseif pge.controls.pressed(PGE_CTRL_TRIANGLE) then
      local rslt = screen:showDialog(Dialog.message(
         'Remove theme "%s"?' % self.themes[self.control.selected].name,
         PGE_UTILS_MSG_DIALOG_YESNO_BUTTONS +
         PGE_UTILS_MSG_DIALOG_DEFAULT_BUTTON_NO))
      if rslt == PGE_UTILS_MSG_DIALOG_RESULT_YES then
         table.remove(self.themes, self.control.selected)
         table.remove(self.control.items, self.control.selected)
         if self.control.selected > #self.themes then
            self.control.selected = #self.themes
            settheme(self.control.selected)
         end
      end
   elseif pge.controls.pressed(PGE_CTRL_SQUARE) then
      local t = table.copy(theme())
      t.name = "New Theme"
      table.insert(self.themes, t)
      self.control.selected = #self.themes
      screen:push_view(CustomThemeView(self.control.selected))
   elseif pge.controls.pressed(PGE_CTRL_CROSS) then
      self:close()
   end

   settheme(self.control.selected)
end

--------------------------------------------------------------------------------

CustomThemeView = class(View)

function CustomThemeView:init(index)
   self.oldtheme = gettheme()
   settheme(index)
   self.backup = table.copy(theme())

   View.init(self, 'Edit Theme - "%s"' % self.backup.name,
      {X = "Return", O = "Accept", LR = "Change" }, ListBox)

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
   View.init(self, "Library", {X = "Return", O = "Read", T = "Remove" }, ListBox)

   self.stories = library
end

function LibraryView:update(delta)
   for i, sid in ipairs(self.stories) do
      local story = db.story[sid]
      self.control.items[i] = '%3d. "%s" by %s' % {
         i, story.title, db.author[story.author].name
         }
   end

   View.update(self, delta)
end

function LibraryView:interact()
   View.interact(self)

   if pge.controls.pressed(PGE_CTRL_CIRCLE) then
      if self.stories[self.control.selected] then
         local sid = self.stories[self.control.selected]
         screen:push_view(StoryView(sid))
         self.control.selected = table.find(self.stories, sid)
      end
   elseif pge.controls.pressed(PGE_CTRL_TRIANGLE) then
      if self.stories[self.control.selected] then
         local rslt = screen:showDialog(Dialog.message(
            "Remove this story from your library?",
            PGE_UTILS_MSG_DIALOG_YESNO_BUTTONS +
            PGE_UTILS_MSG_DIALOG_DEFAULT_BUTTON_NO))
         if rslt == PGE_UTILS_MSG_DIALOG_RESULT_YES then
            table.remove(self.stories, self.control.selected)
            table.remove(self.control.items, self.control.selected)
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
   View.init(self, "Categories", {X = "Return", O = "Select", L = "Prev Letter", R = "Next Letter" }, ListBox)

   self.categories = categories

   for i, c in ipairs(self.categories) do
      self.control.items[i] = FFN.subcategory[c]
   end
end

function CategoriesView:update(delta)
   View.update(self, delta)
end

function CategoriesView:interact()
   View.interact(self)

   if pge.controls.pressed(PGE_CTRL_CIRCLE) then
      screen:push_view(FeedView(
         Feed(FFN.list(self.categories[self.control.selected]))
         ))
   elseif pge.controls.pressed(PGE_CTRL_LTRIGGER) then
      local t = self.control.selected
      repeat
         self.control.selected = wrap(self.control.selected - 1, 1, #self.control.items)
      until self.control.selected == t or
         FFN.subcategory[self.categories[self.control.selected]]:sub(1,1):lower() ~=
         FFN.subcategory[self.categories[t]]:sub(1,1):lower()
   elseif pge.controls.pressed(PGE_CTRL_RTRIGGER) then
      local t = self.control.selected
      repeat
         self.control.selected = wrap(self.control.selected + 1, 1, #self.control.items)
      until self.control.selected == t or
         FFN.subcategory[self.categories[self.control.selected]]:sub(1,1):lower() ~=
         FFN.subcategory[self.categories[t]]:sub(1,1):lower()
   elseif pge.controls.pressed(PGE_CTRL_CROSS) then
      self:close()
   end
end

--------------------------------------------------------------------------------

FindAuthorView = class(View)

function FindAuthorView:init()
   View.init(self, "Find Author", {X = "Return" }, ListBox)

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
   View.init(self, "Search", {X = "Return" }, ListBox)

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

FeedsView = class(View)

function FeedsView:init(feed)
   View.init(self, "Feeds", {X = "Return", O = "View feed"}, ListBox)

   self.feeds = {}
   for file, feed in pairs(db:group('feed')) do
      table.insert(self.feeds, file)
   end
   table.sort(self.feeds)
end

function FeedsView:update(delta)
   for i, file in ipairs(self.feeds) do
      self.control.items[i] = '%3d. %s' % {
         i, db.feed[file].title:gsub('^FanFiction%.Net %- ', '')
         }
   end

   View.update(self, delta)
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
   View.init(self, self.feed.title and self.feed.title['$'] or "Feed not available",
      {X = "Return", O = "Read", T = "Details", S = "Update feed"}, ListBox)

   self.stories = {}
   for i, entry in ipairs(self.feed.entry) do
      self.stories[i] = FFN.storyid(entry.link['@href'])
   end
end

function FeedView:update(delta)
   for i, sid in ipairs(self.stories) do
      local story = db.story[sid]
      self.control.items[i] = '%3d. "%s" by %s' % {
         i, story.title, db.author[story.author].name
         }
   end

   View.update(self, delta)
end

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
         self.stories[i] = FFN.storyid(entry.link['@href'])
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
      '"%s" by %s' % {self.entry.title['$'], self.entry.author.name['$']},
      {X = "Return", O = "Download", T = "More by this author"},
      TextBox, unhtmlize(entry.summary['$']))
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
      local userid = FFN.userid(self.entry.author.uri['$'])
      screen:push_view(FeedView(Feed(FFN.author(userid))))
   elseif pge.controls.pressed(PGE_CTRL_CROSS) then
      self:close()
   end
end

--------------------------------------------------------------------------------

StoryView = class(View)

function StoryView:init(sid)
   self.sid = sid
   self.story = db.story[sid]
   self.bookmark = db.bookmark[self.sid]

   shelve_story(self.sid)

   View.init(self, self.story.title, {X = "Return", L = "Prev Chapter", R = "Next Chapter"}, TextBox)

   self:loadchapter()
end

function StoryView:loadchapter(chapter)
   self.bookmark.chapter = clamp(chapter or self.bookmark.chapter, 1, self.story.nchapters)
   self.title.text = '%s - Chapter %d/%d' % { self.story.title, self.bookmark.chapter, self.story.nchapters }

   offline = false
   local str = getchapter(FFN.chapter(self.sid, self.bookmark.chapter)) or 'Chapter not available.'
   self.control:settext(unhtmlize(str))
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

   self.bookmark[self.bookmark.chapter] = self.control.first_line
end

--------------------------------------------------------------------------------

DownloadView = class(View)

function DownloadView:init(entry)
   self.sid = FFN.storyid(entry.link['@href'])
   self.story = db.story[self.sid]

   shelve_story(self.sid)

   View.init(self, 'Downloading "%s"...' % self.story.title, {X = 'Cancel'},
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
   table.remove(library, table.find(library, sid))
   table.insert(library, 1, sid)
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

font   = pge.font.load('font/vera.ttf',   14)
fontb  = pge.font.load('font/verabd.ttf', 14)
--fonti  = pge.font.load('font/verait.ttf', 12)
--fontbi = pge.font.load('font/verabi.ttf', 12)

db = Database('ffndata.dat')

themes = db:group('themes')
library = db:group('library')

function settheme(n) themes.__current = clamp(n, 1, #themes) end
function gettheme() return themes.__current or 1 end
function theme() return themes[gettheme()] end

if not next(themes) then
   table.insert(themes, {
      name="Default",
      forecolor=0,
      backcolor=15,
      infofore=15,
      infoback=1,
      highlight=7,
   })
   table.insert(themes, {
      name="Monochrome Light",
      forecolor=0,
      backcolor=15,
      infofore=15,
      infoback=0,
      highlight=7,
   })
   table.insert(themes, {
      name="Monochrome Dark",
      forecolor=15,
      backcolor=8,
      infofore=15,
      infoback=0,
      highlight=0,
   })
   table.insert(themes, {
      name="Mint & Lime",
      forecolor=0,
      backcolor=2,
      infofore=0,
      infoback=10,
      highlight=10,
   })
   table.insert(themes, {
      name="Silky Doll",
      forecolor=0,
      backcolor=12,
      infofore=15,
      infoback=4,
      highlight=4,
   })
   table.insert(themes, {
      name="Darkness Beyond Twilight",
      forecolor=7,
      backcolor=0,
      infofore=0,
      infoback=4,
      highlight=4,
   })

   settheme(1)
end

screen = Screen()
screen:push_view(MainMenuView())
screen:run()

ap_disconnect()

db:save()



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
   mkdirs(dirname(filename))
   local fh = pge.file.open(
      filename, PGE_FILE_WRONLY+PGE_FILE_CREATE+PGE_FILE_TRUNC)
   if fh then
      fh:write(content)
      fh:close()
      return true
   end
end

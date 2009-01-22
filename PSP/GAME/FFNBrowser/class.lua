--[[
Name:           class.lua
Description:    Lua class module
Author:         Criptych <criptych@gmail.com>
Creation Date:  31 December, 2008

Provides simple single-inheritance classes and minimal reflection.
Classes may declare the special method init(...) as a constructor.

Usage:
   -- Create a class named className.
   className = class()

   -- Define a static (class-level) field in className.
   className.static = "moon"

   -- Define a constructor for className.
   function className:init(name)
      self.name = name
   end

   -- Define a method in className.
   function className:foo(str)
      self.str = str
   end

   -- Create a subclass of className.
   subClassName = class(className)

   -- Override the constructor.
   function subClassName:init(name)
      self.name = name:upper()
   end

   -- Define a new method in subClassName.
   function subClassName:bar(num)
      self.num = num
   end

   -- Create an instance of subClassName.
   instance = subClassName("name") -- Sets instance.name to "NAME"

   -- Get the class of instance.
   cls = class.of(instance)

   -- Get the superclass of subClassName.
   super = class.super(subClassName)

   -- Check that instance is an instance of className.
   is = class.is(instance, className)
]]

class = {}

-- Reflection metadata
class.ref = {}

-- Allow collection of classes. Note that classes with subclasses will
-- NOT be collected: they are referenced by the 'super' attribute.
setmetatable(class.ref, { __mode = 'k' })

-- Get the superclass of cls.
function class.super(cls)
   return class.ref[cls] and class.ref[cls].super
end

-- Get the class of an instance.
function class.of(obj)
   local cls = getmetatable(obj).__index
   return class.ref[cls] and cls
end

-- Check that obj is an instance of cls (or any subclass).
function class.is(obj, cls)
   local c = class.of(obj)
   while c do
      if cls == c then return true end
      c = class.super(c)
   end
   return false
end

local meta = getmetatable(setmetatable(class, {}))

-- Create a new class. Returns the class table.
function meta:__call(super)
   local cls = {}

   setmetatable(cls, {
      __call = function (self, ...)
         local o = {}
         setmetatable(o, { __index = self })
         if o.init then o:init(...) end
         return o
      end,
      __index = super or nil
   })

   class.ref[cls] = { super = super }

   return cls
end

function meta:__newindex(k, v)
   error("Cannot modify table 'class'")
end

-- This is a stub that allows running server.lua using normal lua or luajit
-- For PUC lua:
--
--   luarocks luv luabitop
--   lua main.lua
--
-- For luajit:
--
-- build luv from source and copy `luv.so` to package.cpath
--
--  luajit main.lua
--
-- For luvit: (skip this file)
--
--   luvit server.lua
--
dofile("luvit-loader.lua")
require('./server')
require('uv').run()

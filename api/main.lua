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

-- Memory comparisions running server on different platforms

-- On OSX x64
-- luvit(v2.9.1) 6.5 MB
-- luvi(v2.6.1-tiny) 5.2 MB
-- luajit(v2.0.4-homebrew) 5.0 MB
-- lua(v5.2.4-homebrew) 12.3 MB

-- On Linux x64

-- luvit(v2.9.1) 10.b Mb
-- luvi(v2.6.1-tiny) 7.1 Mb
-- luajit(v2.0.4-ubuntu) 6.8 Mb
-- lua(v5.1.5-ubuntu) 10.1 Mb

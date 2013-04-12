luabnet is a Lua library for retrieving data from Blizzard Entertainment's Battle.net Community Platform API.

This module implements utility functions used by the luabnet_wow and luabnet_d3 modules (luabnet_d3 has not yet been created).

To install the module, use `luarocks install luabnet_tools` or copy the contents of the lua directory to your package.path.

If you don't want to install LuaFileSystem with Penlight, use `luarocks install --deps-mode=none penlight` before installing this module. The Penlight modules pl.app, pl.dir, pl.file, pl.test and pl.path all depend on LuaFileSystem; so you won't be able to use these modules without installing LFS as well (but this module doesn't use them, so LFS is unnecessary).

You will also need to install one of these three decompression libraries:
* [lzlib](https://github.com/LuaDist/lzlib)
* [lua_zlib](https://github.com/brimworks/lua-zlib)
* [compress.deflatelua](http://lua-users.org/wiki/ModuleCompressDeflateLua)

The first two depend on the C library zlib. The third is pure Lua, but it's fairly slow.
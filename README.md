__DISCLAIMER:__ This module is not yet complete. It may change dramatically between now and release.

Description
===========
luabnet is a Lua library for retrieving data from Blizzard Entertainment's Battle.net Community Platform API.

This module implements utility functions used by the luabnet_wow and luabnet_d3 modules (luabnet_d3 has not yet been created).

Installation
============
To install the module, use `luarocks install luabnet_tools` or copy the contents of the `lua` directory to your `package.path`.

Dependencies
============
Required
--------
* [Penlight](https://github.com/stevedonovan/Penlight) (with or without [LFS](https://github.com/keplerproject/luafilesystem))
* [LuaJSON](https://github.com/harningt/luajson)
* [LPeg](http://www.inf.puc-rio.br/~roberto/lpeg/)
* [LuaSocket](http://w3.impa.br/~diego/software/luasocket/)
* One of these three decompression libraries: 
    * [lzlib](https://github.com/LuaDist/lzlib)
    * [lua_zlib](https://github.com/brimworks/lua-zlib)
    * [compress.deflatelua](http://lua-users.org/wiki/ModuleCompressDeflateLua)

All of these except the decompression libraries are installed by LuaRocks with this module (since LuaRocks can't handle optional dependencies yet and only one of these is currently available as a rock).

lzlib and lua-zlib are bindings to the C library zlib (which must be installed separately). compress.deflatelua is written in pure Lua and doesn't depend on zlib, but it's fairly slow.

lzlib can be installed with `luarocks install lzlib`, the other two must be installed manually.

If you don't want to install LuaFileSystem with Penlight, use `luarocks install --deps-mode=none penlight` before installing this module.

The Penlight modules pl.app, pl.dir, pl.file, pl.test and pl.path all depend on LuaFileSystem; so you won't be able to use these modules without installing LFS as well (but this library doesn't make use of them).

Optional
--------
In order to make authenticated requests to the API, you must also install LuaSec; either from LuaRocks with `luarocks install luasec` or [manually](https://github.com/brunoos/luasec).

Authenticated requests use HMAC-SHA1 signatures in the Authorization header, as per the [documentation](http://blizzard.github.io/api-wow-docs/#features/authentication).

The HMAC-SHA1 module bundled with this library implements its own bitwise operations in Lua, but it will use one of these bitwise operations libraries when possible:

* Lua 5.2's built-in [bit32](http://www.lua.org/manual/5.2/manual.html#6.7)
* [Lua BitOp](http://bitop.luajit.org/) (LuaJIT built-in, but also available for standard 5.1 and 5.2)
* [bitlib](https://github.com/LuaDist/bitlib)

compress.deflatelua can also make use of bit32 and Lua BitOp.
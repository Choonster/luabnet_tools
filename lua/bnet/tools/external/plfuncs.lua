-- This is a subset of functions from the Penlight modules pl.app and pl.path modified so that they don't depend on LuaFileSystem.
-- Penlight's licence (the MIT licence) is included below.

--[[
Copyright (C) 2009 Steve Donovan, David Manura.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT
SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
OR OTHER DEALINGS IN THE SOFTWARE.
]]

local plfuncs = {}

local DIRSEP = package.config:sub(1, 1)
local IS_WINDOWS = DIRSEP == "\\"

local getenv, tmpname = os.getenv, os.tmpname

-- This is adapted from Penlight's path.expanduser function and works similary to app.appfile, but doesn't create any directories.
--
-- It takes a file name and returns that name prefixed with the user's home directory.
-- Since it doesn't create any directories, it should only be used with a file name unless you can be sure that any subdirectories exist beforehand.
function plfuncs.appfile(name)
	local home = getenv('HOME')
    if not home then -- has to be Windows
		home = getenv 'USERPROFILE' or (getenv 'HOMEDRIVE' .. getenv 'HOMEPATH')
    end
	
	return home .. DIRSEP .. name
end

-- This is identical to Penlight's path.tmpname function.
function plfuncs.tmpname()
	local res = tmpname()
    if IS_WINDOWS then res = getenv('TMP')..res end
    return res
end

return plfuncs
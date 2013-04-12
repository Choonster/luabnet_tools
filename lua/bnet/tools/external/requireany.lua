--[[
Requires the first module listed that exists, else raises like `require`.
If a non-string is encountered, it is returned.
Second return value is module name loaded (or '').

This function has been copied from the compress.deflatelua module.
(c) 2008-2012 David Manura. Licensed under the same terms as Lua (MIT).

http://lua-users.org/wiki/ModuleCompressDeflateLua

lua-compress-deflatelua License

===============================================================================

Copyright (C) 2008, David Manura.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

===============================================================================
]]

local function requireany(...)
	local errs = {}
	for i = 1, select("#", ...) do
		local name = select(i, ...)
		if type(name) ~= "string" then return name, "" end
		local ok, mod = pcall(require, name)
		if ok then return mod, name end
		errs[#errs+1] = mod
	end
	error(table.concat(errs, "\n"), 2)
end

return requireany
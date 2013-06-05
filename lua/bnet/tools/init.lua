--- Implements the basic functions used by the rest of this library.
-- @module init

local getmetatable, setmetatable = getmetatable, setmetatable
local next, pairs, ipairs = next, pairs, ipairs
local tostring, assert, select, type = tostring, assert, select, type
local pcall = pcall
local table_concat, table_insert = table.concat, table.insert
local unpack = unpack or table.unpack -- 5.1/5.2 compatibility
local io_open = io.open
local time, date = os.time, os.date

-- Penlight modules
local pretty = require("pl.pretty")
local tablex = require("pl.tablex")
local utils = require("pl.utils")

-- LPeg
local lpeg = require("lpeg")

-- Bundled external code
local plfuncs = require("bnet.tools.external.plfuncs")
local requireany = require("bnet.tools.external.requireany")

local debugprint; -- Declare this as local here so it's available to the whole file. This is defined in the Data Storage section.

--- A read-only proxy pointing to a decoded JSON result table.
-- Proxies are regular empty tables with their __index, __pairs and __ipairs metamethods pointing to the decoded result table.
-- Access to a subtable of the result table will return a Proxy pointing to the subtable. Non-table values are returned as normal.
-- Attempting to change the value of a Proxy's key will throw an error.
-- @type Proxy

--- It's a test
-- @function test


--- Table Manipulation
-- @section table

--- Empty a table.
-- @tab t The table to empty
-- @treturn table The newly empty table
local function wipe(t)
	for k, v in pairs(t) do
		t[k] = nil
	end
	return t
end

local createProxy;
do
	-- This doesn't rely on the `tab` upvalue like the other metamethods, so we can just use a single function for every metatable.
	local function __newindex(p, key, val)
		error("attempt to modify a read-only proxy", 2);
	end
	
	local proxies = setmetatable({}, {
		__mode = "kv",
		__index = function(self, tab)
			local proxy = setmetatable({}, {
				__index = function(p, key)
					local val = tab[key]
					return createProxy(val)
				end,
				__newindex = __newindex,
				__pairs = function(p) return pairs(tab) end, -- Lua 5.2 (__pairs/__ipairs need to be functions, not tables)
				__ipairs = function(p) return ipairs(tab) end,
			})
			self[tab] = proxy
			return proxy
		end
	})
	
	-- If `t` is a table, returns a read-only proxy table with its __index, __pairs and __ipairs metamethods pointing to `t`; otherwise returns `t`.
	function createProxy(t)
		if type(t) == "table" then
			return proxies[t]
		else
			return t
		end
	end
end
	
--- Filesystem
-- @section filesystem

local lib, libname = requireany(
	"bnet.tools requires gzip (lzlib), zlib (lua-zlib) or compress.deflatelua to function. See README.md for a full list of dependencies.",
	-- Library names:  lzlib,   lua-zlib,   compress.deflatelua
	"gzip", "lua-zlib", "compress.deflatelua"
)
local decompress;

local TEMP_PATH_UNCOMPRESSED = plfuncs.tmpname()
local TEMP_PATH_COMPRESSED = TEMP_PATH_UNCOMPRESSED .. ".gz"
print("TEMP_PATH_UNCOMPRESSED", TEMP_PATH_UNCOMPRESSED) -- DEBUG
print("TEMP_PATH_COMPRESSED", TEMP_PATH_COMPRESSED)

--- Decompress a gzipped string
-- @function decompress
-- @string data The data string to decompress
-- @treturn string The decompressed data string

if libname == "gzip" then
	local function write_bin(path, ...)
		local f = assert(io_open(path, "wb"))
		f:write(...)
		f:close()
	end
	local function gzip_read(path)
		local f = assert(lib.open(path, "r"))
		local s = f:read("*a")
		f:close()
		return s
	end
	decompress = function(data)
		debugprint("decompressing with gzip (lzlib)", #data)
		write_bin(TEMP_PATH_COMPRESSED, data)
		debugprint("decompressing - done")
		return gzip_read(TEMP_PATH_COMPRESSED)
	end
elseif libname == "zlib" then
	local stream = lib.inflate()
	decompress = function(data)
		debugprint("decompressing with zlib (lua-zlib)")
		local inflated, eof, bytesIn, bytesOut = stream(data)
		debugprint("decompressing - done")
		return inflated
	end
elseif libname == "compress.deflatelua" then
	local temp = {}
	local read = utils.readfile
	decompress = function(data)
		debugprint("decompressing with compress.deflatelua")
		local output = assert(io_open(TEMP_PATH_UNCOMPRESSED, "w"))
		temp.input, temp.output = data, output
		lib.gunzip(temp)
		output:close()
		debugprint("decompressing - done")
		return read(TEMP_PATH_UNCOMPRESSED)
	end
end

--- Cache manipulation
-- @section cache

local cachedefault = {
	wow = {
		us = {
			en_US = {},
			es_MX = {},
			pt_BR = {},
		},
		eu = {
			en_GB = {},
			es_ES = {},
			fr_FR = {},
			ru_RU = {},
			de_DE = {},
			pt_PT = {},
		},
		kr = {
			ko_KR = {},
		},
		tw = {
			zh_TW = {},
		},
		cn = {
			zh_CN = {},
		}
	},
	-- d3 = {} -- Not yet implemented
}

local CACHE = tablex.deepcopy(cachedefault)
local CACHE_PATH = plfuncs.appfile(".bnet_cache.lua")

-- The default cache loading function.
-- Loads a cache table from the CACHE_PATH file.
-- If the loaded table is newer than the current table, it's copied into the current one. If it's older, the current table is retained.
-- If no cache was loaded, the default cache is used.
local function default_loadcache(currentCache)
	local ok, loaded = pcall(utils.readfile, CACHE_PATH)
	if ok and type(loaded) == "string" then
		ok, loaded = pcall(pretty.read, loaded)
	end
	if ok and type(loaded) == "table" then
		if loaded.lastModified > (currentCache.lastModified or 0) then
			debugprint("loadcache: load and copy")
			return tablex.update(currentCache, loaded)
		else
			debugprint("loadcache: load and retain")
			return currentCache
		end
	end
	debugprint("loadcache: nothing loaded")
	return cachedefault
end

-- The default cache saving function.
-- Writes the cache table to the CACHE_PATH file.
local function default_savecache()
	pretty.dump(CACHE, CACHE_PATH)
end

-- Returns a deep copy of the current cache table.
local function GetCacheTable()
	return tablex.deepcopy(CACHE)
end

-- Deep copies the table and sets it as the cache table.
local function SetCacheTable(tab)
	CACHE = tablex.deepcopy(tab)
	CACHE.lastModified = time()
end

-- Resets the cache table to the default.
local function ResetCacheTable()
	CACHE = tablex.deepcopy(cachedefault)
	CACHE.lastModified = time()
end

local reqTypes = {
	wow = {
		--achievement
		"achievement",
		
		--battlepet
		"battlePetAbilityInfo",
		"battlePetSpeciesInfo",
		"battlePetSpeciesStats",
		
		--character
		"charProfile",
		
		--challengemode
		"challengeModeLeaderboard",
		
		
		--guild
		"guildProfile",
		
		--realm
		"realmStatus",
		
		--auction
		"auctionURL",
		"auctionData",
		
		--item
		"itemInfo",
		
		--pvp
		"arenaTeam",
		"arenaRanking",
		"ratedBGLadder",
		
		--data
		"battlegroups",
		"battlePetTypes",
		"charRaces",
		"charAchievements",
		"charClasses",
		"guildPerks",
		"guildRewards",
		"guildAchievements",
		"itemClasses",
		"talents",
			
		--quest
		"questInfo",
		
		--recipe
		"recipeInfo",
	
		"custom"
	},
	--d3 = {} -- Not Yet Implemented
}

local function InitCache(self, locale)
	local game = self:GetGame()
	local region = self:GetRegion()
	locale = locale or self:GetLocale()
	for _, reqType in ipairs(reqTypes[game]) do
		CACHE[game][region][locale][reqType] = CACHE[game][region][locale][reqType] or {}
	end
end

local splitPath, joinPath;
do
	local PATH_DELIM = ";;"
	
	local P, C, match = lpeg.P, lpeg.C, lpeg.match
	
	-- strsplit function copied from the examples in LPeg's documentation
	-- http://www.inf.puc-rio.br/~roberto/lpeg/#ex
	local function strsplit(str, sep)
		sep = P(sep)
		local elem = C((1 - sep)^0)
		local p = elem * (sep * elem)^0
		return match(p, str)
	end
	
	--- Splits a cache path into its component strings
	-- @string path The path to split
	-- @treturn string ...: The components of the path
	function splitPath(path)
		return strsplit(path, PATH_DELIM)
	end
	
	local temp = {}
	
	--- Joins an arbitrary number of strings into a cache path
	-- @string ... The component strings
	-- @treturn string path: The joined path string
	function joinPath(...)
		local numArgs = select("#", ...)
		
		-- We handle the common cases of 1, 2 or 3 arguments manually to save on performance
		if numArgs == 1 then
			local a = ...
			return a or ""
		elseif numArgs == 2 then
			local a, b = ...
			return (a or "") .. PATH_DELIM .. (b or "")
		elseif numArgs == 3 then
			local a, b, c = ...
			return (a or "") .. PATH_DELIM .. (b or "") .. PATH_DELIM .. (c or "")
		else
			-- If we received 4 or more arguments, add them to the temp array and join them using table.concat
			for i = 1, numArgs do
				temp[i] = select(i, ...) or ""
			end
			
			return table_concat(temp, PATH_DELIM, 1, numArgs)
		end
	end
end

-- Traverse the cache along the provided split path.
-- Returns the table `CACHE[game][region][locale][reqType][path1][path2] ... [pathN-1]` (where N is the number of path components) and the last path component.
local function TraverseCache(self, reqType, locale, ...)
	local game = self:GetGame()
	local region = self:GetRegion()
	locale = locale or self:GetLocale()
	
	local pathLength = select("#", ...)
	local finalIndex = pathLength - 1
	
	local tab = CACHE[game][region][locale][reqType]
	
	if not tab then
		InitCache(self, locale)
		tab = CACHE[game][region][locale][reqType]
	end
	
	for i = 1, finalIndex do
		local temp = select(i, ...)
		tab[temp] = tab[temp] or {}
		tab = tab[temp]
		assert(type(tab) == "table", "Encountered non-table value while traversing cache path")
	end
	
	return tab, select(pathLength, ...)
end

-- Store the value at the specified path in the cache.
local function SetCache(self, reqType, locale, path, value)
	if not path then return end
	
	debugprint("SetCache:", reqType, path, value)
	
	CACHE.lastModified = time()
	
	local tab, key = TraverseCache(self, reqType, locale, splitPath(path))
	tab[key] = value
end

-- Return the value at the specified path in the cache.
local function GetCache(self, reqType, locale, path)
	if not path then return end

	debugprint("GetCache:", reqType, path)
	
	local tab, key = TraverseCache(self, reqType, locale, splitPath(path))
	return tab[key]
end


--- Data Storage
-- @section data

-- Private storage table
local private = {}
private.DEBUGFILE = plfuncs.appfile(".bnet_debug.log") -- Initialise the debug path so debugprint will work before the debug file has been explicitly set.

--- If debugging output is enabled, prints its arguments to the debug file with a timestamp.
-- @within Debugging
-- @param ... The arguments to print
debugprint = function(...) -- This is declared as local near the top of the file.
	if not private.DEBUG then return end
	local path = private.DEBUGFILE
	local f = io_open(path, "a+")
	f:write(date())
	for i = 1, select("#", ...) do
		f:write("\t", tostring(select(i, ...)))
	end
	f:write("\n")
	f:close()
end

-- If `self` is a library instance, stores `value` at `key` in its private storage. Otherwise `key` is stored at `self` in the global private storage.
local function Set(self, key, value)
	debugprint("Set:", type(self) == "table" and "" or self, key, value)
	if type(private[self]) == "table" then
		private[self][key] = value
	else
		private[self] = key
	end
end

-- If `self` is a library instance, returns the value stored at `key` in its private storage. Otherwise returns the value stored at `self` in the global private storage.
local function Get(self, key)
	local tab = private[self]
	if type(tab) == "table" then
		tab = tab[key]
	end
	debugprint("Get:", type(self) == "table" and "" or self, key, tab)
	return tab
end

Set("CACHE_LOAD", default_loadcache)
Set("CACHE_SAVE", default_savecache)

--- Argument checking
-- @section argcheck

local assert_arg = utils.assert_arg

--- Assert that an argument is a string. This is an alias to Penlight's `utils.assert_string` function.
-- @function assertString
-- @int n The argument index
-- @string val A value that must be a string
local assertString = utils.assert_string

--- Assert that an argument is a number
-- @int n The argument index
-- @number val A value that must be a number
local function assertNumber(n, val) -- Based on Penlight's utils.assert_string function
	assert_arg(n, val, "number", nil, nil, 3)
end

--- Module
-- @section module
local modules = {
	"core",
	"authentication",
}

local tools = {}

local privateFuncs = {Get, Set, GetCache, SetCache, InitCache, GetCacheTable, SetCacheTable, ResetCacheTable}
local publicFuncs = {debugprint, wipe, createProxy, decompress, splitPath, joinPath, assertString, assertNumber}

local storage = {module = tools, privateFuncs = privateFuncs, publicFuncs = publicFuncs}

for _, name in ipairs(modules) do
	local path = assert(package.searchpath("bnet.tools.".. name, package.path)) -- Find the path to each module file. This is standard in 5.2 and implemented by Penlight utils in 5.1
	local func = assert(loadfile(path, "t")) -- Lua 5.1 will ignore the second argument, Lua 5.2 uses it as the mode ("t" is text only, no binary chunks).
	func(storage) -- Pass the tools table and basic functions to the file
end

local MAX_LOADED = 1

local function search(name) -- Check if the module file exists
	local path, err = package.searchpath(name, package.path)
	return not not path
end

local validNames = {
	wow = search("bnet.wow"),
	d3  = search("bnet.d3")
}

local restrictedKeys = {
	["privateFuncs"] = true
}

local accessed = {}

for name, valid in pairs(validNames) do
	if valid then
		accessed[name] = {}
	end
end

local function q(value) -- DEBUG
	return ("%q"):format(tostring(value))
end

local meta = {
	__index = function(t, k)
		-- To access a restricted key, we use "wow&&key" (or "d3&&key") instead of "key" as the key.
		-- This allows us to restrict how many times the private functions are retrieved.
		
		local name, key;
		if k:find("&&") then
			name, key = k:match("^(%a*)&&(.+)$")
		else
			key = k
		end

		print("name: ", q(name), "\tkey: ", q(key), "\trestrictedkeys[key] ", q(restrictedKeys[key]))

		if not key then return end
		
		if restrictedKeys[key] then
			print("restricted key")
			if validNames[name] then 
				print("valid name")
				accessed[name][key] = (accessed[name][key] or 0) + 1
				if accessed[name][key] <= MAX_LOADED then
					print("restricted key access")
					return storage[key]
				else
					error(("Attempt to access a restricted key %q"):format(key))
				end
			end
		else
			print("unrestricted key")
			return storage[key]
		end
	end,		
	__newindex = function() end,
	__metatable = false
}

--DEBUG--
--DO NOT PACKAGE

local function setglobals(...)
	local halfnum = select("#", ...) / 2
	
	for i = 1, halfnum do
		local name, func = select(i, ...), select(halfnum + i, ...)
		if name and func then
			_G[name] = func
			print("Set global", tostring(name), "\t to value ", tostring(func))
		end
	end
end	

setglobals(
	"Get", "Set", "GetCache", "SetCache", "InitCache", "AddUsage", "debugprint",  "createProxy", "decompress", "bnprivate",
	 Get,   Set,   GetCache,   SetCache,   InitCache,   AddUsage,   debugprint,    createProxy,   decompress,    private
)

function newtools()
	Set(tools, {})
	Set(tools, "GAME", "wow")
	tools:LoadCache()
	tools:SetLocale("us", "en_US")
	_G["tools"] = tools
end

--END DEBUG--

return setmetatable({}, meta)
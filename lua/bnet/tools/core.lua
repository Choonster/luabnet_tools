--- Blizzard Battle.net Community Platform API Library
-- Easily retrieve various types of data from Blizzard's API in the format of Lua tables.
-- @class: module
-- @name: bnet.tools.core
-- Implements the basic methods used by the library.

--[[
This is just here so LuaDoc recognises this as a module.
module("bnet.tools.core")
]]

local storage = ...
local tools = storage.module
local debugprint, wipe, createRef, decompress, splitPath, joinPath = unpack(storage.publicFuncs)
local Get, Set, GetCache, SetCache, InitCache, GetCacheTable, SetCacheTable = unpack(storage.privateFuncs)

local type, assert, error = type, assert, error

--- The valid locales for each region and the localised and English language names (in UTF-8 encoding).
-- @class table
local regions = {
	us = {
		en_US = "English (US)",
		es_MX = "Espa�ol (AL) - Latin American Spanish", 
		pt_BR = "Portugu�s (AL) - Brazilian Portuguese",
	},
	eu = {
		en_GB = "English (EU)",
		es_ES = "Espa�ol (EU) - Spanish",
		fr_FR = "Fran�ais - French",
		ru_RU = "\208\160\209\131\209\129\209\129\208\186\208\184\208\185 - Russian",
		de_DE = "Deutsch - German",
		pt_PT = "Portugu�s (AL) - Portuguese",
		it_IT = "Italiano - Italian",
	},
	kr = {
		ko_KR = "\237\149\156\234\181\173\236\150\180 - Korean",
	},
	tw = {
		zh_TW = "\231\185\129\233\171\148\228\184\173\230\150\135 - Traditional Chinese",
	},
	cn = {
		zh_CN = "\231\174\128\228\189\147\228\184\173\230\150\135 - Simplified Chinese",
	}
}

--- Set the game region and locale used by this copy of the library.
-- Each region has a different set of valid locales.
-- @param region (string) A two letter region code.
-- @param locale (string) The default locale to use when querying the API.
-- @usage tools:SetLocale("us", "en_US")
-- -- See the regions table in bnet.lua for the valid regions/locales.
function tools:SetLocale(region, locale)
	if not regions[region] then
		error("Invalid region code")
	elseif not regions[region][locale] then
		error("Invalid locale code")
	elseif region == "cn" then -- China has a different domain name to the other regions
		Set(self, "HOST", "www.battlenet.com.cn")
	else
		Set(self, "HOST", ("%s.battle.net"):format(region))
	end	
	
	Set(self, "LOCALE", locale)
	Set(self, "REGION", region)
	InitCache(self)
	self:SaveCache()
end

--- Get the current locale of this copy of the library.
-- @return locale: (string) The current locale code.
-- @usage local locale = tools:GetLocale()
-- assert(locale == "en_US")
function tools:GetLocale()
	return Get(self, "LOCALE")
end

--- Get the current region of this copy of the library
-- @return region: (string) The current region.
-- @usage local region = tools:GetRegion()
-- assert(region == "us")
function tools:GetRegion()
	return Get(self, "REGION")
end

--- Get extended locale info for this copy of the library.
-- @return locale: (string) The current locale code.
-- @return region: (string) The current region code.
-- @return localeName: (string) The full name of the current locale.
-- @usage local locale, region, localeName = tools:GetFullLocale()
-- assert(locale == "en_US")
-- assert(region == "us")
-- assert(localeName == "English (US)")
function tools:GetFullLocale()
	local locale, region = Get(self, "LOCALE"), Get(self, "REGION")
	return locale, region, (locale and region) and regions[region][locale]
end

--- Get the current host address for this copy of the library (defined by the region).
-- @return host: (string) The current host address.
-- @usage local host = tools:GetHost()
-- assert(host == "us.battle.net")
function tools:GetHost()
	return Get(self, "HOST")
end

--- Enable/disable debugging output.
-- @param value (boolean) If true-equivalent, enable debugging output; else disable it.
function tools:EnableDebug(value)
	Set("DEBUG", not not value) -- Double not converts it to a boolean
end

--- Returns whether or not debugging output is enabled.
-- @return enabled: (boolean) true if output is enabled, false if not.
function tools:IsDebugEnabled()
	return Get("DEBUG")
end

--- Change the file debugging information is output to.
-- @param path (string) The path to a file.
function tools:SetDebugLogFile(path)
	local t = type(path)
	assert(t == "string", ("String expected, got %s"):format(t))
	Set("DEBUGFILE", path)
end

--- Gets the game this copy of the library is for.
-- @return game: (string) Either "wow" or "d3", depending on which module the library was created with.
function tools:GetGame()
	return Get(self, "GAME")
end

--- Sets the function used to load the cache.
-- You only need to change this if you want to load the cache in a different way from the default function (e.g. from a database or a file in a different format).
-- The function receives a single argument, which is the current cache table. It should return a single table in the same format as the default cache table.
-- Both this function and the cache itself are shared between all instances of the library.
-- @param func (function(currentCache)) A function to load a new cache table from some form of storage.
function tools:SetCacheLoadFunction(func)
	Set("CACHE_LOAD", func)
end

--- Sets the function used to save the cache.
-- You only need to change this if you want to save the cache in a different way from the default function (e.g. to a database or a file in a different format).
-- The function receives a single argument, which is the current cache table.
-- Both this function and the cache itself are shared between all instances of the library.
-- @param func (function(currentCache)) A function to save the cache to some form of storage.
function tools:SetCacheSaveFunction(func)
	Set("CACHE_SAVE", func)
end

--- Load the cache using the cache loading function set with :SetCacheLoadFunction, or the default function if no function has been set.
function tools:LoadCache()
	local loadFunc = Get("CACHE_LOAD")
	local newCache = loadFunc(GetCacheTable())
	SetCacheTable(newCache)
end

--- Save the cache using the cache loading function set with :SetCacheSaveFunction, or the default function if no function has been set.
function tools:SaveCache()
	local saveFunc = Get("CACHE_SAVE")
	saveFunc(GetCacheTable())
end
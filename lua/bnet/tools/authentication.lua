--- Blizzard Battle.net Community Platform API Library
-- Easily retrieve various types of data from Blizzard's API in the format of Lua tables.
-- @class: module
-- @name: bnet.tools.authentication
-- Implements authentication and HTTP GET requests.
--
--[[ Thanks to Cyaga, author of the battlenet RubyGem whose authentication module helped me to understand how to handle the authentication process.
		http://us.battle.net/wow/en/forum/topic/2369922944
		https://github.com/BinaryMuse/battlenet
]]
--[[
This is just here so LuaDoc recognises this as a module.
module("bnet.tools.authentication")
]]

require("bnet.tools.external.sha1") -- SHA1/HMAC-SHA1 algorithms, packaged with this library. See sha1.lua for licence and attribution.
local tablex = require("pl.tablex") -- Penlight
local json   = require("json") -- LuaJSON
local http   = require("socket.http") -- LuaSocket
local url    = require("socket.url")
local mime   = require("mime") 
local ltn12  = require("ltn12")

local https_ok, https = pcall(require, "ssl.https") -- LuaSec (optional dependency)
if not https_ok then
	https_ok, https = pcall(require, "https") -- LuaForWindows seems to install it in <path>/ssl/https.lua, but Ubuntu's software center installs it in <path>/https.lua
end
https = https_ok and https or nil -- If it wasn't loaded, https will contain an error message instead of the module, so set it to nil instead.

local storage = ...
local tools = storage.module
local debugprint, wipe, createRef, decompress, splitPath, joinPath = unpack(storage.publicFuncs)
local Get, Set, GetCache, SetCache, InitCache, GetCacheTable, SetCacheTable = unpack(storage.privateFuncs)

local match, format, table_concat = string.match, string.format, table.concat
local difftime, time, date, clock = os.difftime, os.time, os.date, os.clock
local base64 = mime.b64
local hmac_sha1 = hmac_sha1
local json_decode = json.decode
local url_absolute = url.absolute

local sinkTable, urlTable, headerTable = {}, {}, {}
local sink = ltn12.sink.table(sinkTable)

local requestTable = {
	protocol = "tlsv1",
	options = "all",
	verify = "none",
	sink = sink,
}

--				"Fri, 01 Jun 2011 20:59:24 GMT"
local HTTP_DATE = "!%a, %d %b %Y %H:%M:%S GMT"

local function StringToSign(path, time, verb)
	local datestr = date(HTTP_DATE, time)
	verb = verb or "GET"
	return format("%s\n%s\n%s\n", verb, datestr, path)
end

local function Sign(self, path, time, verb)
	local privateKey = Get(self, "PRIVATE")
	local str = StringToSign(path, time, verb)
	local sig = hmac_sha1(privateKey, str)
	sig = base64(sig)
	return sig
end

--- Get the path section of an absolute URL.
-- Primarily used in :GetAuctionData to convert an absolute URL returned by :GetAuctionDataURL into a path for :SendRequestRaw.
-- @param URL (string) An absolute URL. Must contain the current host as returned by :GetHost.
-- @return path: (string) The path section of the URL.
function tools:GetPath(URL)
	debugprint("URL:", URL)
	return match(URL, self:GetHost() .. "(%/.+)$")
end

--- Get the authorization HTTP header
-- @param path (string) The path to sign (usually starting with /api/wow/).
-- @param time (number, optional) The time to sign (as returned by os.time()). If nil or omitted, the current time is used.
-- @param verb (string, optional) The HTTP verb to sign. If nil or omitted, defaults to "GET".
-- @return authorization: (string) The authorization section of the HTTP header.
-- @usage local header = { authorization = tools:GetHeaderAuthorization("/api/wow/character/Frostmourne/Choonster") }
function tools:GetHeaderAuthorization(path, time, verb)
	if not self:IsAuthenticated() then return end
	local sig = Sign(self, path, time, verb)
	local publicKey = Get(self, "PUBLIC")
	return format("BNET %s:%s", publicKey, sig)
end

--- Register your public and private application keys for use in the authorization header.
-- Both keys are stored in a private table that outside code has no access to.
-- @param publicKey (string)Your public key.  
-- @param privateKey (string) Your private key.
-- @usage tools:RegisterKeys("xxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxx")
function tools:RegisterKeys(publicKey, privateKey)
	Set(self, "PUBLIC", publicKey)
	Set(self, "PRIVATE", privateKey)
	Set(self, "AUTHENTICATED", (publicKey and privateKey) and true or false)
end

--- Has this copy had application keys registered?
-- @return isAuthenticated (boolean)
function tools:IsAuthenticated()
	return Get(self, "AUTHENTICATED")
end

--- Send a HTTP GET request.
-- Used as a backend for :SendRequest and also for retrieving auction data dumps, which are too large for the JSON decoder to handle whole.
-- @param path (string) The path to send the request to (usually starting with /api/wow/).
-- @param fields (string, optional) A list of comma-separated fields to query.
-- @param locale (string, optional) The locale to retrieve the data in. If nil or omitted, the locale set with :SetLocale will be used.
-- @param reqType (string, optional) The type of request you're sending. Used internally for caching and usage statistics. If nil or omitted, "custom" will be used.
-- @param lastModified (string, optional) A HTTP date string used in the If-Modified-Since header. Only used when forceRefresh is nil/false.
-- @param forceRefresh (boolean, optional) If true, force a refresh by sending the request without an If-Modified-Since header.
-- @return success (boolean) Did the query succeed?
-- @return result: (string) The raw JSON data.
-- @return code: (number) The HTTP response status code.
-- @return status: (string) The full HTTP response status.
-- @return headers: (table) The HTTP headers of the response.
function tools:SendRequestRaw(path, fields, locale, lastModified, forceRefresh)
	local secure = https and self:IsAuthenticated()
	fields = fields or ""
	locale = locale or self:GetLocale()
	reqType = reqType or "custom"
	wipe(sinkTable)
	
	
	urlTable.scheme = secure and "https" or "http"
	urlTable.host = self:GetHost()
	urlTable.path = path
	urlTable.query = ("fields=%s&locale=%s"):format(fields, locale)
	
	
	headerTable["Authorization"] = secure and self:GetHeaderAuthorization(url_absolute(path, "?fields=" .. fields)) or nil
	headerTable["Cache-Control"] = forceRefresh and "no-cache" or nil
	headerTable["If-Modified-Since"] = (not forceRefresh) and lastModified or nil
	headerTable["Accept-Encoding"] = "gzip"
	
	requestTable.url = url_absolute(urlTable)
	requestTable.headers = headerTable
	
	debugprint("sending request", path)
	local success, code, headers, status = (secure and https or http).request(requestTable)
	local resultJSON = table_concat(sinkTable)
	
	if headers["content-encoding"] == "gzip" then
		resultJSON = decompress(resultJSON)
	end
	
	return success, resultJSON, code, status, headers
end

--- Send a HTTP GET request or retrieve cached results where appropriate.
-- Used as a backend for most data retrieval functions.
-- @param path (string) The path to send the request to (usually starting with /api/wow/).
-- @param fields (string, optional) A list of comma-separated fields to query.
-- @param locale (string, optional) The locale to retrieve the data in. If nil or omitted, the locale set with :SetLocale will be used. Note that although all data retrieval functions support this parameter, not all APIs make use of it.
-- @param reqType (string, optional) The type of request you're sending. Used internally for caching and usage statistics. If nil or omitted, "custom" will be used.
-- @param cachePath (string, optional) A cache path assembled with the joinPath function. If nil or omitted, the cache won't be used.
-- @param expires (number, optional) The number of seconds before the result should be refreshed. If less than this amount of time has passed since the numeric time in the "lastModified" field of the result, a cached result will be returned. If nil or omitted, a request will always be sent.
-- @param forceRefresh (boolean, optional) If true, force a refresh by sending the request without an If-Modified-Since header.
-- @return success: (boolean) Did the query succeed?
-- @return result: (table) The decoded JSON data.
-- @return code: (number) The HTTP response status code. If no request was sent, this will be 304.5.
-- @return status: (string) The full HTTP response status. If no request was sent, this will be "No request sent".
-- @return headers: (table or nil) The HTTP headers of the response. If no request was sent, this will be nil.
-- @return time: (number) The number of seconds between the function being called and the results being returned, calculated with os.time().
-- @return clock: (number) The number of seconds of CPU time used between the function being called and the results being returned, calculated with os.clock().
function tools:SendRequest(path, fields, locale, reqType, cachePath, expires, forceRefresh)
	local startTime = os.time()
	local startClock = os.clock()
	
	expires = expires or 0
	reqType = reqType or "custom"
	
	local lastModStrPath, lastModStr, lastModNumPath, lastModNum, dataPath;
	if cachePath then
		dataPath = joinPath(cachePath, "data")
		lastModStrPath = joinPath(cachePath, "lastModifiedStr")
		lastModNumPath = joinPath(cachePath, "lastModifiedNum")
		
		lastModStr = GetCache(self, reqType, lastModStrPath)
		lastModNum = GetCache(self, reqType, lastModNumPath)
	end
	
	lastModNum = tonumber(lastModNum or 0)
	
	local _, result, resultJSON, code, status, headers;
	local diff = difftime(time(), lastModNum)
	
	debugprint("diff", diff, "expires", expires, "lastMod", lastModNum)
	
	-- If the result has expired or we've been told to force a refresh, send a request; otherwise use the cached data.
	if diff > expires or forceRefresh then
		_, resultJSON, code, status, headers = self:SendRequestRaw(path, fields, locale, lastModStr, forceRefresh)
		result = (resultJSON and resultJSON ~= "") and json_decode(resultJSON) or resultJSON
	else
		code, status = 304, "No request sent" -- Not a real HTTP status message, only used to indicate that the cache is still valid
	end
	
	local success;
	
	if code == 200 then
		success = true
		debugprint("request success:", path)
		
		local lastMod;
		if reqType == "auctionURL" then -- Auction URL results have a different structure to other types
			aucTab = result.files[1]
			result = aucTab.url
			lastMod = aucTab.lastModified
		else
			lastMod = result.lastModified
		end
		
		if cachePath then
			SetCache(self, reqType, locale, dataPath, result)
			SetCache(self, reqType, locale, lastModStrPath, headers["last-modified"])
			SetCache(self, reqType, locale, lastModNumPath, lastMod and (lastMod / 1000) or 0) -- Blizzard's value is in miliseconds, we want seconds
		end
	elseif code == 304 then
		success = true
		debugprint(304, status, path)
		result = GetCache(self, reqType, locale, dataPath)
	else
		success = false
		debugprint("request failed:", path)
		result = (result and result.reason)
	end
	
	return success, createRef(result), code, status, headers, difftime(time(), startTime), difftime(clock(), startClock)
end
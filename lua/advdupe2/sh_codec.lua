--[[
	Title: Adv. Dupe 2 Codec

	Desc: Dupe encoder/decoder.

	Author: emspike

	Version: 2.0
]]

local REVISION = 5

include "sh_codec_legacy.lua"
AddCSLuaFile "sh_codec_legacy.lua"

local pairs = pairs
local type = type
local error = error
local Vector = Vector
local Angle = Angle
local format = string.format
local char = string.char
local byte = string.byte
local sub = string.sub
local gsub = string.gsub
local find = string.find
local gmatch = string.gmatch
local match = string.match
local concat = table.concat
local compress = util.Compress
local decompress = util.Decompress

AdvDupe2.CodecRevision = REVISION


--[[
	Name:	GenerateDupeStamp
	Desc:	Generates an info table.
	Params:	<player> ply
	Return:	<table> stamp
]]
function AdvDupe2.GenerateDupeStamp(ply)
	local stamp = {}
	stamp.name = ply:GetName()
	stamp.time = os.date("%I:%M %p")
	stamp.date = os.date("%d %B %Y")
	stamp.timezone = os.date("%z")
	hook.Call("AdvDupe2_StampGenerated",GAMEMODE,stamp)
	return stamp
end

local function makeInfo(tbl)
	local info = ""
	for k,v in pairs(tbl) do
		info = concat{info,k,"\1",v,"\1"}
	end
	return info.."\2"
end

local AD2FF = "AD2F%s\n%s\n%s"

local tables
local buff

local function noserializer() end

local enc = {}
for i=1,255 do enc[i] = noserializer end

local function isArray(tbl)
	local ret = true
	local m = 0
	
	for k, v in pairs(tbl) do
		m = m + 1
		if k ~= m or enc[TypeID(v)]==noserializer then
			ret = false
			break
		end
	end

	return ret
end

local function write(obj)
	enc[TypeID(obj)](obj)
end

local len
local tables,tablesLookup

enc[TYPE_TABLE] = function(obj) --table
	tables = tables + 1
	if not tablesLookup[obj] then
		tablesLookup[obj] = tables
	else
		buff:WriteByte(247)
		buff:WriteShort(tablesLookup[obj])
		return
	end
	
	if isArray(obj) then
		buff:WriteByte(254)
		for i,v in pairs(obj) do
			write(v)
		end
	else
		buff:WriteByte(255)
		for k,v in pairs(obj) do
			if(enc[TypeID(k)]!=noserializer and enc[TypeID(v)]!=noserializer)then
				write(k)
				write(v)
			end
		end
	end
	buff:WriteByte(246)
end
enc[TYPE_BOOL] = function(obj) --boolean
	buff:WriteByte(obj and 253 or 252)
end
enc[TYPE_NUMBER] = function(obj) --number
	buff:WriteByte(251)
	buff:WriteDouble(obj)
end
enc[TYPE_VECTOR] = function(obj) --vector
	buff:WriteByte(250)
	buff:WriteDouble(obj.x)
	buff:WriteDouble(obj.y)
	buff:WriteDouble(obj.z)
end
enc[TYPE_ANGLE] = function(obj) --angle
	buff:WriteByte(249)
	buff:WriteDouble(obj.p)
	buff:WriteDouble(obj.y)
	buff:WriteDouble(obj.r)
end
enc[TYPE_STRING] = function(obj) --string
	
	len = #obj
	
	if len < 246 then
		buff:WriteByte(len)
		buff:Write(obj)
	else
		buff:WriteByte(248)
		buff:WriteULong(len)
		buff:Write(obj)
	end
	
end

local function error_nodeserializer()
	buff:Seek(buff:Tell()-1)
	error(format("couldn't find deserializer for type {typeid:%d}", buff:ReadByte()))
end

local read4, read5

local reference = 0
do --Version 4
	local dec = {}
	for i=1,255 do dec[i] = error_nodeserializer end

	local function read()
		local tt = buff:ReadByte()
		if not tt then
			error("expected value, got EOF")
		end
		if tt == 0 then
			return nil
		end
		return dec[tt]()
	end
	read4 = read

	dec[255] = function() --table
		local t = {}
		local k
		reference = reference + 1
		local ref = reference
		repeat
			k = read()
			if k ~= nil then
				t[k] = read()
			end
		until (k == nil)
		tables[ref] = t
		return t
	end

	dec[254] = function() --array
		local t = {}
		local k,v = 0
		reference = reference + 1
		local ref = reference
		repeat
			k = k + 1
			v = read()
			if(v != nil) then
				t[k] = v
			end

		until (v == nil)
		tables[ref] = t
		return t
	end

	dec[253] = function()
		return true
	end
	dec[252] = function()
		return false
	end
	dec[251] = function()
		return buff:ReadDouble()
	end
	dec[250] = function()
		return Vector(buff:ReadDouble(),buff:ReadDouble(),buff:ReadDouble())
	end
	dec[249] = function()
		return Angle(buff:ReadDouble(),buff:ReadDouble(),buff:ReadDouble())
	end
	dec[248] = function() --null-terminated string
		local start = buff:Tell()
		local slen = 0
		
		while buff:ReadByte() != 0 do
			slen = slen + 1
		end
		
		buff:Seek(start)
		
		local retv = buff:Read(slen)
		if(not retv)then retv="" end
		buff:ReadByte()

		return retv
	end
	dec[247] = function() --table reference
		reference = reference + 1
		return tables[buff:ReadShort()]
	end

	for i=1,246 do dec[i] = function() return buff:Read(i) end end
end

do --Version 5
	local dec = {}
	for i=1,255 do dec[i] = error_nodeserializer end

	local function read()
		local tt = buff:ReadByte()
		if not tt then
			error("expected value, got EOF")
		end
		return dec[tt]()
	end
	read5 = read

	dec[255] = function() --table
		local t = {}
		reference = reference + 1
		tables[reference] = t

		for k in read do
			t[k] = read()
		end

		return t
	end

	dec[254] = function() --array
		local t = {}
		reference = reference + 1
		tables[reference] = t

		local k = 1
		for v in read do
			t[k] = v
			k = k + 1
		end

		return t
	end

	dec[253] = function()
		return true
	end
	dec[252] = function()
		return false
	end
	dec[251] = function()
		return buff:ReadDouble()
	end
	dec[250] = function()
		return Vector(buff:ReadDouble(),buff:ReadDouble(),buff:ReadDouble())
	end
	dec[249] = function()
		return Angle(buff:ReadDouble(),buff:ReadDouble(),buff:ReadDouble())
	end
	dec[248] = function() -- Length>246 string
		local slen = buff:ReadULong()
		local retv = buff:Read(slen)
		if(not retv)then retv="" end
		return retv
	end
	dec[247] = function() --table reference
		return tables[buff:ReadShort()]
	end
	dec[246] = function() --nil
		return
	end

	for i=1,245 do dec[i] = function() return buff:Read(i) end end
	dec[0] = function() return "" end
end

local function serialize(tbl)
	tables = 0
	tablesLookup = {}

	buff = file.Open("ad2temp.txt", "wb", "DATA")
	write(tbl)
	buff:Close()

	buff = file.Open("ad2temp.txt","rb","DATA")
	local ret = buff:Read(buff:Size())
	buff:Close()
	return ret
end


local function deserialize(str, read)
	
	if(str==nil)then
		error("File could not be decompressed.")
		return {}
	end
	
	tables = {}
	reference = 0
	buff = file.Open("ad2temp.txt","wb","DATA")
	buff:Write(str)
	buff:Flush()
	buff:Close()
	
	buff = file.Open("ad2temp.txt","rb", "DATA")
	local success, tbl = pcall(read)
	buff:Close()
	
	if success then
		return tbl
	else
		error(tbl)
	end
end

--[[
	Name:	Encode
	Desc:	Generates the string for a dupe file with the given data.
	Params:	<table> dupe, <table> info, <function> callback, <...> args
	Return:	runs callback(<string> encoded_dupe, <...> args)
]]
function AdvDupe2.Encode(dupe, info, callback, ...)
	
	local encodedTable = compress(serialize(dupe))
	info.check = "\r\n\t\n"
	info.size = #encodedTable
	
	callback(AD2FF:format(char(REVISION), makeInfo(info), encodedTable),...)
	
end

--seperates the header and body and converts the header to a table
local function getInfo(str)
	local last = str:find("\2")
	if not last then
		error("attempt to read AD2 file with malformed info block")
	end
	local info = {}
	local ss = str:sub(1,last-1)
	for k,v in ss:gmatch("(.-)\1(.-)\1") do
		info[k] = v
	end
	
	if info.check ~= "\r\n\t\n" then
		if info.check == "\10\9\10" then
			error("detected AD2 file corrupted in file transfer (newlines homogenized)(when using FTP, transfer AD2 files in image/binary mode, not ASCII/text mode)")
		else
			error("attempt to read AD2 file with malformed info block")
		end
	end
	return info, str:sub(last+2)
end

--decoders for individual versions go here
local versions = {}

versions[1] = AdvDupe2.LegacyDecoders[1]
versions[2] = AdvDupe2.LegacyDecoders[2]

versions[3] = function(encodedDupe)
	encodedDupe = encodedDupe:Replace("\r\r\n\t\r\n", "\t\t\t\t")
	encodedDupe = encodedDupe:Replace("\r\n\t\n", "\t\t\t\t")
	encodedDupe = encodedDupe:Replace("\r\n", "\n")
	encodedDupe = encodedDupe:Replace("\t\t\t\t", "\r\n\t\n")
	return versions[4](encodedDupe)
end

versions[4] = function(encodedDupe)
	local info, dupestring = getInfo(encodedDupe:sub(7))
	return deserialize(decompress(dupestring), read4), info
end

versions[5] = function(encodedDupe)
	local info, dupestring = getInfo(encodedDupe:sub(7))
	return deserialize(decompress(dupestring), read5), info
end


function AdvDupe2.CheckValidDupe(dupe, info)
	if not dupe.HeadEnt then return false, "Missing HeadEnt table" end
	if not dupe.HeadEnt.Index then return false, "Missing HeadEnt.Index" end
	if not dupe.HeadEnt.Z then return false, "Missing HeadEnt.Z" end
	if not dupe.HeadEnt.Pos then return false, "Missing HeadEnt.Pos" end
	if not dupe.Entities then return false, "Missing Entities table" end
	if not dupe.Entities[dupe.HeadEnt.Index] then return false, "Missing HeadEnt index from Entities table" end
	if not dupe.Entities[dupe.HeadEnt.Index].PhysicsObjects then return false, "Missing PhysicsObject table from HeadEnt Entity table" end
	if not dupe.Entities[dupe.HeadEnt.Index].PhysicsObjects[0] then return false, "Missing PhysicsObject[0] table from HeadEnt Entity table" end
	if not dupe.Entities[dupe.HeadEnt.Index].PhysicsObjects[0].Pos then return false, "Missing PhysicsObject[0].Pos from HeadEnt Entity table" end
	if not dupe.Entities[dupe.HeadEnt.Index].PhysicsObjects[0].Angle then return false, "Missing PhysicsObject[0].Angle from HeadEnt Entity table" end
	return true, dupe
end

--[[
	Name:	Decode
	Desc:	Generates the table for a dupe from the given string. Inverse of Encode
	Params:	<string> encodedDupe, <function> callback, <...> args
	Return:	runs callback(<boolean> success, <table/string> tbl, <table> info)
]]
function AdvDupe2.Decode(encodedDupe)
	
	local sig, rev = encodedDupe:match("^(....)(.)")
	
	if not rev then
		return false, "malformed dupe (wtf <5 chars long?!)"
	end
	
	rev = rev:byte()
	
	if sig ~= "AD2F" then
		if sig == "[Inf" then --legacy support, ENGAGE (AD1 dupe detected)
			local success, tbl, info, moreinfo = pcall(AdvDupe2.LegacyDecoders[0], encodedDupe)

			if success then
				info.size = #encodedDupe
				info.revision = 0
				info.ad1 = true

				local index = tonumber(info.Head) or (istable(tbl.Entities) and next(tbl.Entities))
				if not index then return false, "Missing head index" end
				local pos
				if isstring(info.StartPos) then
					local spx,spy,spz = info.StartPos:match("^(.-),(.-),(.+)$")
					pos = Vector(tonumber(spx) or 0, tonumber(spy) or 0, tonumber(spz) or 0)
				else
					pos = Vector()
				end
				local z
				if isstring(info.HoldPos) then
					z = (tonumber(info.HoldPos:match("^.-,.-,(.+)$")) or 0)*-1
				else
					z = 0
				end
				tbl.HeadEnt = {
					Index = index,
					Pos = pos,
					Z = z
				}

			else
				ErrorNoHalt(tbl)
			end

			if success then
				success, tbl = AdvDupe2.CheckValidDupe(tbl, info)
			end

			return success, tbl, info, moreinfo
		else
			return false, "unknown duplication format"
		end
	elseif rev > REVISION then
		return false, format("Newer codec needed. (have rev %u, need rev %u) Update Advdupe2.",REVISION,rev)
	elseif rev < 1 then
		return false, format("attempt to use an invalid format revision (rev %d)", rev)
	else
		local success, tbl, info = pcall(versions[rev], encodedDupe)

		if success then
			success, tbl = AdvDupe2.CheckValidDupe(tbl, info)
		end
		
		if success then
			info.revision = rev
		else
			ErrorNoHalt(tbl)
		end

		return success, tbl, info
	end
end
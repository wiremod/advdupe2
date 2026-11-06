--[[
	Title: Adv. Dupe 2 Codec

	Desc: Dupe encoder/decoder.

	Author: emspike

	Version: 2.0
]]

local REVISION = 5
AdvDupe2.CodecRevision = REVISION
AdvDupe2.MaxDupeSize = 32e6 -- 32 MB
AdvDupe2.MaxInfoSize = 64 * 1024 -- bytes, size of the info block at the start of an AD2 file
AdvDupe2.MaxDecodeTime = 1 -- seconds, wall-clock time one dupe may take to decode
AdvDupe2.MaxDecodeOps = 10e6 -- values / chunks / copied entries one dupe may contain
AdvDupe2.MaxDecodeDepth = 128 -- how deeply tables may be nested inside a dupe

include( "sh_codec_legacy.lua" )
AddCSLuaFile( "sh_codec_legacy.lua" )

local pairs = pairs
local error = error
local Vector = Vector
local Angle = Angle
local format = string.format
local char = string.char
local concat = table.concat
local compress = util.Compress
local decompress = util.Decompress
local find = string.find
local sub = string.sub
local pcall = pcall
local tostring = tostring
local SysTime = SysTime
local byte = string.byte
local floor = math.floor
local frexp = math.frexp
local ldexp = math.ldexp

--[[
	String buffer implementation.
	Based on the SFS
]]
local chars = {}; do
	for i = 0, 255 do
		chars[i] = char(i)
	end
end

-- Encoder
local function write_str(buf, str)
	local buf_len = buf[0] + 1

	buf[0] = buf_len
	buf[buf_len] = str
end

local function write_byte(buf, chr)
	local buf_len = buf[0] + 1

	buf[0] = buf_len
	buf[buf_len] = chars[chr]
end

local function write_u16(buf, num)
	num = num % 0x10000

	write_byte(buf, num % 0x100)
	write_byte(buf, floor(num / 0x100))
end

local function write_u32(buf, num)
	num = num % 0x100000000

	write_byte(buf, num % 0x100)
	write_byte(buf, floor(num / 0x100) % 0x100)
	write_byte(buf, floor(num / 0x10000) % 0x100)
	write_byte(buf, floor(num / 0x1000000) % 0x100)
end

local function write_double(buf, num)
	local u32_1 = 0
	local u32_2 = 0

	if num == 0 then
		u32_1 = 0x00000000

		if 1 / num < 0 then
			u32_1 = 0x80000000
		end
	elseif num ~= num then
		-- NaN
		u32_1 = 0x7FFFFFFF
		u32_2 = 1
	else
		local sign = num < 0 and 1 or 0
		num = sign == 1 and -num or num

		if num == math.huge then
			u32_1 = (sign * (2 ^ 31)) + (0x7FF * (2 ^ 20))
		else
			local mantissa, exponent = frexp(num)
			local ieee_exponent = exponent + 1022

			if ieee_exponent > 0 then
				-- Normal numbers
				local mantissa_scaled = (mantissa * 2 - 1) * (2 ^ 52)
				local mantissa_upper = floor(mantissa_scaled / (2 ^ 32))
				local mantissa_lower = mantissa_scaled % (2 ^ 32)

				u32_1 = (sign * (2 ^ 31)) + (ieee_exponent * (2 ^ 20)) + (mantissa_upper % (2 ^ 20))
				u32_2 = mantissa_lower
			else
				-- Subnormal numbers
				local mantissa_scaled = mantissa * ldexp(1, 52 + ieee_exponent)
				local mantissa_upper = floor(mantissa_scaled / (2 ^ 32))
				local mantissa_lower = mantissa_scaled % (2 ^ 32)

				u32_1 = (sign * (2 ^ 31)) + (mantissa_upper % (2 ^ 20))
				u32_2 = mantissa_lower
			end
		end
	end

	-- AD2 uses little-endian doubles
	write_u32(buf, u32_2)
	write_u32(buf, u32_1)
end

local function new_buffer()
	return {
		[0] = 0
	}
end

local function end_buffer(buf)
	return concat(buf, nil, 1, buf[0])
end

-- Decoder
local function setup_context(bytes, max_size)
	if type(bytes) ~= "string" then
		return nil, "bytes must be a string"
	end

	if max_size == nil then
		max_size = #bytes
	elseif type(max_size) ~= "number" then
		return nil, "max_size must be a number"
	elseif max_size < 1 then
		return nil, "max_size must be greater than 0"
	end

	return {
		1,
		bytes,
		#bytes,
		max_size
	}
end

local function read_bytes(ctx, size)
	local index = ctx[1]
	local end_index = index + size - 1

	if end_index > ctx[3] then
		return nil, "bytes underflow"
	elseif end_index > ctx[4] then
		return nil, "bytes overflow"
	end

	ctx[1] = end_index + 1

	return byte(ctx[2], index, end_index)
end

local function read_str(ctx, size)
	local index = ctx[1]
	local end_index = index + size - 1

	if end_index > ctx[3] then
		return nil, "bytes underflow"
	elseif end_index > ctx[4] then
		return nil, "bytes overflow"
	end

	ctx[1] = index + size

	return sub(ctx[2], index, end_index)
end

local function read_byte(ctx)
	local value = read_bytes(ctx, 1)

	return value
end

local function read_u16(ctx)
	local b1, b2 = read_bytes(ctx, 2)

	if b1 == nil then
		error(b2, 0)
	end

	return b1 + b2 * 0x100
end

local function read_short(ctx)
	local num = read_u16(ctx)

	if num >= 0x8000 then
		num = num - 0x10000
	end

	return num
end

local function read_u32(ctx)
	local b1, b2, b3, b4 = read_bytes(ctx, 4)

	if b1 == nil then
		error(b2, 0)
	end

	return b1 + b2 * 0x100 + b3 * 0x10000 + b4 * 0x1000000
end

local function read_double(ctx)
	local u32_2 = read_u32(ctx)
	local u32_1 = read_u32(ctx)

	local sign = floor(u32_1 / (2 ^ 31)) % 2 == 1 and -1 or 1
	local exponent = floor(u32_1 / (2 ^ 20)) % (2 ^ 11)
	local mantissa_upper = u32_1 % (2 ^ 20)

	if exponent == 0x7FF then
		if mantissa_upper == 0 and u32_2 == 0 then
			return sign * math.huge
		end

		return 0 / 0
	end

	if exponent == 0 and mantissa_upper == 0 and u32_2 == 0 then
		return sign * 0
	end

	local mantissa_scaled = mantissa_upper * (2 ^ 32) + u32_2

	if exponent ~= 0 then
		mantissa_scaled = (mantissa_scaled / (2 ^ 52)) + 1

		return sign * ldexp(mantissa_scaled, exponent - 1023)
	else
		mantissa_scaled = mantissa_scaled / (2 ^ 52)

		return sign * ldexp(mantissa_scaled, -1022)
	end
end

local function read_data(ctx, size)
	local str, err = read_str(ctx, size)

	if err then
		error(err, 0)
	end

	return str
end

local function tell(ctx)
	return ctx[1] - 1
end

local function seek(ctx, position)
	ctx[1] = math.max(floor(position), 0) + 1
end

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

function AdvDupe2.SanitizeFilename(filename)
	filename = string.gsub( filename, "[\":]", "_" )
	filename = string.gsub( filename, "%s+", " " )
	filename = string.gsub( filename, "%s*([\\/%.])%s*", "%1" )
	return filename
end

local function makeInfo(tbl)
	local info = ""
	for k, v in pairs(tbl) do
		info = concat{info,k,"\1",v,"\1"}
	end
	return info.."\2"
end

local AD2FF = "AD2F%s\n%s\n%s"

local tables, buff

local function noserializer() end

local enc = {}
for i = 1, 255 do enc[i] = noserializer end

local function isArray(tbl)
	local ret = true
	local m = 0

	for k, v in pairs(tbl) do
		m = m + 1
		if k ~= m or enc[TypeID(v)] == noserializer then
			ret = false
			break
		end
	end

	return ret
end

local function write(obj)
	enc[TypeID(obj)](obj)
end

local len, tables, tables_lookup

enc[TYPE_TABLE] = function(obj) --table
	if not tables_lookup[obj] then
		tables = tables + 1
		tables_lookup[obj] = tables
	else
		write_byte(buff, 247)
		write_u16(buff, tables_lookup[obj])
		return
	end

	if isArray(obj) then
		write_byte(buff, 254)
		for i, v in pairs(obj) do
			write(v)
		end
	else
		write_byte(buff, 255)
		for k, v in pairs(obj) do
			if(enc[TypeID(k)] ~= noserializer and enc[TypeID(v)] ~= noserializer) then
				write(k)
				write(v)
			end
		end
	end
	write_byte(buff, 246)
end

enc[TYPE_BOOL] = function(obj) --boolean
	write_byte(buff, obj and 253 or 252)
end

enc[TYPE_NUMBER] = function(obj) --number
	write_byte(buff, 251)
	write_double(buff, obj)
end

enc[TYPE_VECTOR] = function(obj) --vector
	write_byte(buff, 250)
	write_double(buff, obj.x)
	write_double(buff, obj.y)
	write_double(buff, obj.z)
end

enc[TYPE_ANGLE] = function(obj) --angle
	write_byte(buff, 249)
	write_double(buff, obj.p)
	write_double(buff, obj.y)
	write_double(buff, obj.r)
end

enc[TYPE_STRING] = function(obj) --string
	len = #obj
	if len < 246 then
		write_byte(buff, len)
		write_str(buff, obj)
	else
		write_byte(buff, 248)
		write_u32(buff, len)
		write_str(buff, obj)
	end
end

local function error_nodeserializer()
	seek(buff, tell(buff)-1)
	error(format("Couldn't find deserializer for type {typeid:%d}!", read_byte(buff)))
end

local chunk = 4096
local depth = 0
local deadline, ops_left, budget = 0, 0, 0

local function start_budget()
	depth = 0
	deadline = SysTime() + AdvDupe2.MaxDecodeTime
	ops_left = AdvDupe2.MaxDecodeOps
	budget = chunk
end

local function check_time()
	if SysTime() > deadline then
		error("Dupe took too long to decode (time limit reached)", 0)
	end
end

local function check_budget()
	ops_left = ops_left - (chunk - budget)

	if ops_left < 0 then
		error("Dupe is too large or too complex to decode (work limit reached)", 0)
	end

	budget = chunk
	check_time()
end

local reference = 0
local read4, read5

do --Version 4
	local dec = {}
	for i = 1, 255 do dec[i] = error_nodeserializer end

	local function read()
		local tt = read_byte(buff)
		if not tt then
			error("Expected value, got EOF!")
		end
		if tt == 0 then
			return nil
		end

		budget = budget - 1
		if budget <= 0 then
			check_budget()
		end

		return dec[tt]()
	end
	read4 = read

	dec[255] = function() --table
		local t = {}
		local k
		reference = reference + 1
		local ref = reference
		depth = depth + 1

		if depth > AdvDupe2.MaxDecodeDepth then
			error("Dupe tables are nested too deeply", 0)
		end

		repeat
			k = read()
			if k ~= nil then
				t[k] = read()
			end
		until (k == nil)
		depth = depth - 1
		tables[ref] = t
		return t
	end

	dec[254] = function() --array
		local t = {}
		local k = 0
		local v
		reference = reference + 1
		local ref = reference

		depth = depth + 1

		if depth > AdvDupe2.MaxDecodeDepth then
			error("Dupe tables are nested too deeply", 0)
		end

		repeat
			k = k + 1
			v = read()
			if(v ~= nil) then
				t[k] = v
			end

		until (v == nil)

		depth = depth - 1
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
		return read_double(buff)
	end
	dec[250] = function()
		return Vector(read_double(buff),read_double(buff),read_double(buff))
	end
	dec[249] = function()
		return Angle(read_double(buff),read_double(buff),read_double(buff))
	end
	dec[248] = function() --null-terminated string
		local start = tell(buff)
		local slen = 0

		while true do
			local byte = read_byte(buff)

			if byte == 0 or not byte then
				break
			end

			slen = slen + 1
			if slen % 65536 == 0 then
				check_time()
			end
		end

		seek(buff, start)

		local retv = read_data(buff, slen)
		if(not retv) then retv="" end
		read_byte(buff)

		return retv
	end
	dec[247] = function() --table reference
		reference = reference + 1
		return tables[read_short(buff)]
	end

	for i = 1, 246 do dec[i] = function() return read_data(buff, i) end end
end

do --Version 5
	local dec = {}
	for i = 1, 255 do dec[i] = error_nodeserializer end

	local function read()
		local tt = read_byte(buff)

		if not tt then
			error("Expected value, got EOF!")
		end

		budget = budget - 1

		if budget <= 0 then
			check_budget()
		end

		return dec[tt]()
	end
	read5 = read

	dec[255] = function() --table
		local t = {}
		reference = reference + 1
		tables[reference] = t

		depth = depth + 1

		if depth > AdvDupe2.MaxDecodeDepth then
			error("Dupe tables are nested too deeply", 0)
		end

		for k in read do
			t[k] = read()
		end

		depth = depth - 1

		return t
	end

	dec[254] = function() --array
		local t = {}
		reference = reference + 1
		tables[reference] = t

		depth = depth + 1

		if depth > AdvDupe2.MaxDecodeDepth then
			error("Dupe tables are nested too deeply", 0)
		end

		local k = 1

		for v in read do
			t[k] = v
			k = k + 1
		end

		depth = depth - 1

		return t
	end

	dec[253] = function()
		return true
	end
	dec[252] = function()
		return false
	end
	dec[251] = function()
		return read_double(buff)
	end
	dec[250] = function()
		return Vector(read_double(buff),read_double(buff),read_double(buff))
	end
	dec[249] = function()
		return Angle(read_double(buff),read_double(buff),read_double(buff))
	end
	dec[248] = function() -- Length>246 string
		local slen = read_u32(buff)
		local retv = read_data(buff, slen)
		if(not retv) then retv = "" end
		return retv
	end
	dec[247] = function() --table reference
		return tables[read_short(buff)]
	end
	dec[246] = function() --nil
		return
	end

	for i = 1, 245 do dec[i] = function() return read_data(buff, i) end end

	dec[0] = function() return "" end
end

local function serialize(tbl)
	tables = 0
	tables_lookup = {}

	local buffer = new_buffer()
	buff = buffer

	local success, err = pcall(write, tbl)

	buff = nil

	if not success then
		error(err, 0)
	end

	return end_buffer(buffer)
end

local function deserialize(str, read)
	if not str then
		error("File could not be decompressed!")
		return {}
	end

	start_budget()

	tables = {}
	reference = 0

	local context, err = setup_context(str, #str)

	if not context then
		error(err, 0)
	end

	buff = context

	local success, tbl = pcall(read)

	buff = nil
	tables = nil

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
	local last = find(str, "\2", 1, true)
	if not last then
		error("Attempt to read AD2 file with malformed info block!")
	end
	if last > AdvDupe2.MaxInfoSize then
		error("Attempt to read AD2 file with an oversized info block!")
	end
	local info = {}
	local ss = sub(str, 1, last - 1)

	local p = 1
	while true do
		local e1 = find(ss, "\1", p, true)
		if not e1 then break end
		local e2 = find(ss, "\1", e1 + 1, true)
		if not e2 then break end
		info[sub(ss, p, e1 - 1)] = sub(ss, e1 + 1, e2 - 1)
		p = e2 + 1
	end

	if info.check ~= "\r\n\t\n" then
		if info.check == "\10\9\10" then
			error("Detected AD2 file corrupted in file transfer (newlines homogenized)(when using FTP, transfer AD2 files in image/binary mode, not ASCII/text mode)!")
		elseif info.check ~= nil then
			error("Detected AD2 file corrupted by newline replacements (copy/pasting the data in various editors can cause this!)")
		else
			error("Attempt to read AD2 file with malformed info block!")
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
	local info, dupestring = getInfo(sub(encodedDupe, 7))
	return deserialize(decompress(dupestring, AdvDupe2.MaxDupeSize), read4), info
end

versions[5] = function(encodedDupe)
	local info, dupestring = getInfo(sub(encodedDupe, 7))
	return deserialize(decompress(dupestring, AdvDupe2.MaxDupeSize), read5), info
end

local function ent_desc(key, data)
	return "[".. sub(tostring(key), 1, 40) .. "][" .. sub(tostring(data.Class), 1, 40) .. "][" .. sub(tostring(data.Model), 1, 80) .. "]"
end

function AdvDupe2.CheckValidDupe(dupe, info)
	local head = dupe.HeadEnt
	if not istable(head) then return false, "Missing HeadEnt table" end
	if not istable(dupe.Entities) then return false, "Missing Entities table" end
	if not istable(dupe.Constraints) then return false, "Missing Constraints table" end
	if not head.Z then return false, "Missing HeadEnt.Z" end
	if not head.Pos then return false, "Missing HeadEnt.Pos" end
	if not head.Index then return false, "Missing HeadEnt.Index" end
	if not dupe.Entities[head.Index] then return false, "Missing HeadEnt index [" .. sub(tostring(head.Index), 1, 40) .. "] from Entities table" end

	for key, data in pairs(dupe.Entities) do
		if not istable(data) then return false, "Entity [".. sub(tostring(key), 1, 40) .."] is not a table" end

		local physobjs = data.PhysicsObjects
		if not istable(physobjs) then return false, "Missing PhysicsObject table from Entity ".. ent_desc(key, data) end

		local phys0 = physobjs[0]
		if not istable(phys0) then return false, "Missing PhysicsObject[0] table from Entity ".. ent_desc(key, data) end

		if info.ad1 then -- Advanced Duplicator 1
			if not phys0.LocalPos then return false, "Missing PhysicsObject[0].LocalPos from Entity ".. ent_desc(key, data) end
			if not phys0.LocalAngle then return false, "Missing PhysicsObject[0].LocalAngle from Entity ".. ent_desc(key, data) end
		else -- Advanced Duplicator 2
			if not phys0.Pos then return false, "Missing PhysicsObject[0].Pos from Entity ".. ent_desc(key, data) end
			if not phys0.Angle then return false, "Missing PhysicsObject[0].Angle from Entity ".. ent_desc(key, data) end
		end
	end

	return true, dupe
end

--[[
	Name:	Decode
	Desc:	Generates the table for a dupe from the given string. Inverse of Encode
	Params:	<string> encodedDupe, <function> callback, <...> args
	Return:	runs callback(<boolean> success, <table/string> tbl, <table> info)
]]
function AdvDupe2.Decode(encodedDupe)
	if not isstring(encodedDupe) then
		return false, "Malformed dupe! (decompression failed)"
	end

	if #encodedDupe > AdvDupe2.MaxDupeSize then
		return false, "Dupe is too large!"
	end

	local sig, rev = encodedDupe:match("^(....)(.)")

	if not rev then
		return false, "Malformed dupe! (<5 chars long)"
	end

	rev = rev:byte()

	if sig ~= "AD2F" then
		if sig == "[Inf" then --legacy support, ENGAGE (AD1 dupe detected)
			local success, tbl, info, moreinfo = pcall(AdvDupe2.LegacyDecoders[0], encodedDupe)

			if success then
				info.ad1 = true
				info.size = #encodedDupe
				info.revision = 0

				local index = tonumber(moreinfo.Head) or (istable(tbl.Entities) and next(tbl.Entities))
				if not index then return false, "Missing head index" end
				local pos
				if isstring(moreinfo.StartPos) then
					local spx,spy,spz = moreinfo.StartPos:match("^(.-),(.-),(.+)$")
					pos = Vector(tonumber(spx) or 0, tonumber(spy) or 0, tonumber(spz) or 0)
				else
					pos = Vector()
				end
				local z
				if isstring(moreinfo.HoldPos) then
					z = (tonumber(moreinfo.HoldPos:match("^.-,.-,(.+)$")) or 0)*-1
				else
					z = 0
				end
				tbl.HeadEnt = {
					Index = index,
					Pos = pos,
					Z = z
				}
			else
				print(tbl)
			end

			if success then
				success, tbl = AdvDupe2.CheckValidDupe(tbl, info)
			end

			return success, tbl, info, moreinfo
		else
			return false, "Unknown duplication format!"
		end
	elseif rev > REVISION then
		return false, format("Newer codec needed. (have rev %u, need rev %u) Update Advdupe2.",REVISION,rev)
	elseif rev < 1 then
		return false, format("Attempt to use an invalid format revision (rev %d)!", rev)
	else
		local success, tbl, info = pcall(versions[rev], encodedDupe)

		if success then
			success, tbl = AdvDupe2.CheckValidDupe(tbl, info)
		end
		if success then
			info.revision = rev
		end

		return success, tbl, info
	end
end

if CLIENT then

	concommand.Add("advdupe2_to_json", function(_,_,arg)
		if not arg[1] then print("Need AdvDupe2 file name argument!") return end
		local readFileName = "advdupe2/"..arg[1]
		local writeFileName = "advdupe2/"..string.StripExtension(arg[1])..".json"

		writeFileName = AdvDupe2.SanitizeFilename(writeFileName)

		local readFile = file.Open(readFileName, "rb", "DATA")
		if not readFile then print("File could not be read or found! ("..readFileName..")") return end
		local readData = readFile:Read(readFile:Size())
		readFile:Close()
		local ok, tbl = AdvDupe2.Decode(readData)
		local writeFile = file.Open(writeFileName, "wb", "DATA")
		if not writeFile then print("File could not be written! ("..writeFileName..")") return end
		writeFile:Write(util.TableToJSON(tbl))
		writeFile:Close()
		print("File written! ("..writeFileName..")")
	end)

	concommand.Add("advdupe2_from_json", function(_,_,arg)
		if not arg[1] then print("Need json file name argument!") return end
		local readFileName = "advdupe2/"..arg[1]
		local writeFileName = "advdupe2/"..string.StripExtension(arg[1])..".txt"

		local readFile = file.Open(readFileName, "rb", "DATA")
		if not readFile then print("File could not be read or found! ("..readFileName..")") return end
		local readData = readFile:Read(readFile:Size())
		readFile:Close()

		AdvDupe2.Encode(util.JSONToTable(readData), {}, function(data)
			local writeFile = file.Open(writeFileName, "wb", "DATA")
			if not writeFile then print("File could not be written! ("..writeFileName..")") return end
			writeFile:Write(data)
			writeFile:Close()
			print("File written! ("..writeFileName..")")
		end)
	end)

end

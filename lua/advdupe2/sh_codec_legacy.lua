--[[
	Title: Adv. Dupe 2 Codec Legacy Support

	Desc: Facilitates opening of dupes from AD1 and earlier AD2 versions.

	Author: emspike

	Version: 2.0
]]

local pairs = pairs
local type = type
local tonumber = tonumber
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

local AD2FF = "AD2F%s\n%s\n%s"

local decode_types_v1, decode_types_v2
local tables = 0
local str,pos
local a,b,c,m,n,w,tblref

local function read_v2()
	local t = byte(str, pos+1)
	if t then
		local dt = decode_types_v2[t]
		if dt then
			pos = pos + 1
			return dt()
		else
			error(format("encountered invalid data type (%u)\n",t))
		end
	else
		error("expected value, got EOF\n")
	end
end

decode_types_v2 = {
	[1	] = function()
		error("expected value, got terminator\n")
	end,
	[2	] = function() -- table
		
		m = find(str, "\1", pos)
		if m then
			w = sub(str, pos+1, m-1)
			pos = m
		else
			error("expected table identifier, got EOF\n")
		end
		
		local t = {}
		tables[w] = t
		
		while true do
			if byte(str, pos+1) == 1 then
				pos = pos + 1
				return t
			else
				t[read_v2()] = read_v2()
			end
		end
	end,
	[3	] = function() -- array
		
		m = find(str, "\1", pos)
		if m then
			w = sub(str, pos+1, m-1)
			pos = m
		else
			error("expected table identifier, got EOF\n")
		end
		
		local t, i = {}, 1
		
		tables[w] = t
		
		while true do
			if byte(str,pos+1) == 1 then
				pos = pos+1
				return t
			else
				t[i] = read_v2()
				i = i + 1
			end
		end
	end,
	[4	] = function() -- false boolean
		return false
	end,
	[5	] = function() -- true boolean
		return true
	end,
	[6	] = function() -- number
		m = find(str, "\1", pos)
		if m then
			a = tonumber(sub(str, pos+1, m-1)) or 0
			pos = m
			return a
		else
			error("expected number, got EOF\n")
		end
	end,
	[7	] = function() -- string
		m = find(str,"\1",pos)
		if m then
			w = sub(str, pos+1, m-1)
			pos = m
			return w
		else
			error("expected string, got EOF\n")
		end
	end,
	[8	] = function() -- Vector
		m,n = find(str,".-\1.-\1.-\1", pos)
		if m then
			a,b,c = match(str,"^(.-)\1(.-)\1(.-)\1",pos+1)
			pos = n
			return Vector(tonumber(a), tonumber(b), tonumber(c))
		else
			error("expected vector, got EOF\n")
		end
	end,
	[9	] = function() -- Angle
		m,n = find(str, ".-\1.-\1.-\1", pos)
		if m then
			a,b,c = match(str, "^(.-)\1(.-)\1(.-)\1",pos+1)
			pos = n
			return Angle(tonumber(a), tonumber(b), tonumber(c))
		else
			error("expected angle, got EOF\n")
		end
	end,
	[10	] = function() -- Table Reference
		m = find(str,"\1",pos)
		if m then
			w = sub(str,pos+1,m-1)
			pos = m
		else
			error("expected table identifier, got EOF\n")
		end
		tblref = tables[w]
		
		if tblref then
			return tblref
		else
			error(format("table identifier %s points to nil\n", w))
		end
		
	end
}



local function read_v1()
	local t = byte(str,pos+1)
	if t then
		local dt = decode_types_v1[t]
		if dt then
			pos = pos + 1
			return dt()
		else
			error(format("encountered invalid data type (%u)\n",t))
		end
	else
		error("expected value, got EOF\n")
	end
end

decode_types_v1 = {
	[1	] = function()
		error("expected value, got terminator\n")
	end,
	[2	] = function() -- table
		local t = {}
		while true do
			if byte(str,pos+1) == 1 then
				pos = pos+1
				return t
			else
				t[read_v1()] = read_v1()
			end
		end
	end,
	[3	] = function() -- array
		local t, i = {}, 1
		while true do
			if byte(str,pos+1) == 1 then
				pos = pos+1
				return t
			else
				t[i] = read_v1()
				i = i + 1
			end
		end
	end,
	[4	] = function() -- false boolean
		return false
	end,
	[5	] = function() -- true boolean
		return true
	end,
	[6	] = function() -- number
		m = find(str,"\1",pos)
		if m then
			a = tonumber(sub(str,pos+1,m-1)) or 0
			pos = m
			return a
		else
			error("expected number, got EOF\n")
		end
	end,
	[7	] = function() -- string
		m = find(str,"\1",pos)
		if m then
			w = sub(str,pos+1,m-1)
			pos = m
			return w
		else
			error("expected string, got EOF\n")
		end
	end,
	[8	] = function() -- Vector
		m,n = find(str,".-\1.-\1.-\1",pos)
		if m then
			a,b,c = match(str,"^(.-)\1(.-)\1(.-)\1",pos+1)
			pos = n
			return Vector(tonumber(a), tonumber(b), tonumber(c))
		else
			error("expected vector, got EOF\n")
		end
	end,
	[9	] = function() -- Angle
		m,n = find(str,".-\1.-\1.-\1",pos)
		if m then
			a,b,c = match(str,"^(.-)\1(.-)\1(.-)\1",pos+1)
			pos = n
			return Angle(tonumber(a), tonumber(b), tonumber(c))
		else
			error("expected angle, got EOF\n")
		end
	end
}

local function deserialize_v1(data)
	str = data
	pos = 0
	tables = {}
	return read_v1()
end

local function deserialize_v2(data)
	str = data
	pos = 0
	tables = {}
	return read_v2()
end

local function lzwDecode(encoded)
	local dictionary_length = 256
	local dictionary = {}
	for i = 0, 255 do
		dictionary[i] = char(i)
	end
	
	local pos = 2
	local decompressed = {}
	local decompressed_length = 1
	
	local index = byte(encoded)
	local word = dictionary[index]
	
	decompressed[decompressed_length] = dictionary[index]
	
	local entry
	local encoded_length = #encoded
	local firstbyte --of an index
	while pos <= encoded_length do
		firstbyte = byte(encoded,pos)
		if firstbyte > 252 then --now we know it's a length indicator for a multibyte index
			index = 0
			firstbyte = 256 - firstbyte
			
			--[[if pos+firstbyte > encoded_length then	--will test for performance impact
				error("expected index got EOF")
			end]]
			
			for i = pos+firstbyte, pos+1, -1 do
				index = bit.bor(bit.lshift(index, 8), byte(encoded,i))
			end
			pos = pos + firstbyte + 1
		else
			index = firstbyte
			pos = pos + 1
		end
		entry = dictionary[index] or (word..sub(word,1,1))
		decompressed_length = decompressed_length + 1
		decompressed[decompressed_length] = entry
		dictionary[dictionary_length] = word..sub(entry,1,1)
		dictionary_length = dictionary_length + 1
		word = entry
	end
	return concat(decompressed)
end

--http://en.wikipedia.org/wiki/Huffman_coding#Decompression

local invcodes = {[2]={[0]="\254"},[5]={[22]="\1",[11]="\2"},[6]={[13]="\7",[35]="\6",[37]="\5",[58]="\3",[31]="\8",[9]="\13",[51]="\9",[55]="\10",[57]="\4",[59]="\15"},[7]={[1]="\14",[15]="\16",[87]="\31",[89]="\30",[62]="\26",[17]="\27",[97]="\19",[19]="\43",[10]="\12",[39]="\33",[41]="\24",[82]="\40",[3]="\32",[46]="\41",[47]="\38",[94]="\25",[65]="\23",[50]="\39",[26]="\11",[7]="\28",[33]="\18",[61]="\17",[25]="\42"},[8]={[111]="\101",[162]="\29",[2]="\34",[133]="\21",[142]="\36",[5]="\20",[21]="\37",[170]="\44",[130]="\22",[66]="\35"},[9]={[241]="\121",[361]="\104",[365]="\184",[125]="\227",[373]="\198",[253]="\117",[381]="\57",[270]="\49",[413]="\80",[290]="\47",[294]="\115",[38]="\112",[429]="\74",[433]="\0",[437]="\48",[158]="\183",[453]="\107",[166]="\111",[469]="\182",[477]="\241",[45]="\86",[489]="\69",[366]="\100",[497]="\61",[509]="\76",[49]="\53",[390]="\78",[279]="\196",[283]="\70",[414]="\98",[53]="\55",[422]="\109",[233]="\79",[349]="\89",[369]="\52",[14]="\105",[238]="\56",[319]="\162",[323]="\83",[327]="\63",[458]="\65",[335]="\231",[339]="\225",[337]="\114",[347]="\193",[493]="\139",[23]="\209",[359]="\250",[490]="\68",[42]="\54",[63]="\91",[286]="\97",[254]="\50",[510]="\108",[109]="\73",[67]="\103",[255]="\122",[69]="\170",[70]="\110",[407]="\176",[411]="\119",[110]="\120",[83]="\146",[149]="\163",[151]="\224",[85]="\51",[155]="\177",[79]="\251",[27]="\118",[447]="\159",[451]="\228",[455]="\175",[383]="\174",[463]="\243",[467]="\157",[173]="\210",[475]="\167",[177]="\84",[90]="\45",[487]="\206",[93]="\226",[495]="\245",[207]="\64",[127]="\147",[191]="\155",[511]="\153",[195]="\208",[197]="\85",[199]="\178",[181]="\82",[102]="\116",[103]="\71",[285]="\144",[105]="\102",[211]="\199",[213]="\123",[301]="\66",[305]="\46",[219]="\137",[81]="\67",[91]="\88",[157]="\130",[325]="\95",[29]="\58",[231]="\201",[117]="\99",[341]="\222",[237]="\77",[239]="\211",[71]="\223"},[10]={[710]="\149",[245]="\60",[742]="\172",[774]="\81",[134]="\151",[917]="\145",[274]="\216",[405]="\242",[146]="\194",[838]="\246",[298]="\248",[870]="\189",[1013]="\150",[894]="\190",[326]="\244",[330]="\166",[334]="\217",[465]="\179",[346]="\59",[354]="\180",[966]="\212",[974]="\143",[370]="\148",[998]="\154",[625]="\138",[382]="\161",[194]="\141",[198]="\126",[402]="\96",[206]="\185",[586]="\129",[721]="\187",[610]="\135",[618]="\181",[626]="\72",[226]="\62",[454]="\127",[658]="\113",[462]="\164",[234]="\214",[474]="\140",[242]="\106",[714]="\188",[730]="\87",[498]="\237",[746]="\125",[754]="\229",[786]="\128",[202]="\93",[18]="\255",[810]="\173",[846]="\131",[74]="\192",[842]="\142",[977]="\252",[858]="\235",[78]="\134",[874]="\234",[882]="\90",[646]="\92",[1006]="\160",[126]="\165",[914]="\221",[718]="\94",[738]="\238",[638]="\197",[482]="\230",[34]="\220",[962]="\133",[6]="\213",[706]="\219",[986]="\171",[994]="\233",[866]="\200",[1010]="\247",[98]="\169",[518]="\236",[494]="\207",[230]="\205",[542]="\191",[501]="\202",[530]="\203",[450]="\204",[209]="\158",[106]="\186",[590]="\136",[218]="\232",[733]="\124",[309]="\168",[221]="\152",[757]="\240",[113]="\215",[114]="\156",[362]="\239",[486]="\132",[358]="\249",[262]="\75",[30]="\218",[821]="\195",[546]="\253"}}

local function huffmanDecode(encoded)
	
	local h1,h2,h3 = byte(encoded, 1, 3)
	
	if (not h3) or (#encoded < 4) then
		error("invalid input")
	end
	
	local original_length = bit.bor(bit.lshift(h3,16), bit.lshift(h2,8), h1)
	local encoded_length = #encoded+1
	local decoded = {}
	local decoded_length = 0
	local buffer = 0
	local buffer_length = 0
	local code
	local code_len = 2
	local temp
	local pos = 4
	
	while decoded_length < original_length do
		if code_len <= buffer_length then
			temp = invcodes[code_len]
			code = bit.band(buffer, bit.lshift(1, code_len)-1)
			if temp and temp[code] then --most of the time temp is nil
				decoded_length = decoded_length + 1
				decoded[decoded_length] = temp[code]
				buffer = bit.rshift(buffer, code_len)
				buffer_length = buffer_length - code_len
				code_len = 2
			else
				code_len = code_len + 1
				if code_len > 10 then
					error("malformed code")
				end
			end
		else
			buffer = bit.bor(buffer, bit.lshift(byte(encoded, pos), buffer_length))
			buffer_length = buffer_length + 8
			pos = pos + 1
			if pos > encoded_length then
				error("malformed code")
			end
		end
	end
	
	return concat(decoded)
end

local function invEscapeSub(str)
	local escseq,body = match(str,"^(.-)\n(.-)$")
	
	if not escseq then error("invalid input") end
	
	return gsub(body,escseq,"\26")
end

local dictionary
local subtables

local function deserializeChunk(chunk)
	
	local ctype,val = byte(chunk),sub(chunk,3)
	
	if     ctype == 89 then return dictionary[ val ]
	elseif ctype == 86 then
		local a,b,c = match(val,"^(.-),(.-),(.+)$")
		return Vector( tonumber(a), tonumber(b), tonumber(c) )
	elseif ctype == 65 then
		local a,b,c = match(val,"^(.-),(.-),(.+)$")
		return Angle( tonumber(a), tonumber(b), tonumber(c) )
	elseif ctype == 84 then 
		local t = {}
		local tv = subtables[val]
		if not tv then
			tv = {}
			subtables[ val ] = tv
		end
		tv[#tv+1] = t
		return t
	elseif ctype == 78 then return tonumber(val)
	elseif ctype == 83 then return gsub(sub(val,2,-2),"»",";")
	elseif ctype == 66 then return val == "t"
	elseif ctype == 80 then return 1
	end
	
	error(format("AD1 deserialization failed: invalid chunk (%u:%s)",ctype,val))
	
end

local function deserializeAD1(dupestring)
	
	dupestring = dupestring:Replace("\r\n", "\n")
	local header, extraHeader, dupeBlock, dictBlock = dupestring:match("%[Info%]\n(.+)\n%[More Information%]\n(.+)\n%[Save%]\n(.+)\n%[Dict%]\n(.+)")
	
	if not header then
		error("unknown duplication format")
	end
	
	local info = {}
	for k,v in header:gmatch("([^\n:]+):([^\n]+)") do
		info[k] = v
	end
		
	local moreinfo = {}
	for k,v in extraHeader:gmatch("([^\n:]+):([^\n]+)") do
		moreinfo[k] = v
	end
	
	dictionary = {}
	for k,v in dictBlock:gmatch("(.-):\"(.-)\"\n") do
		dictionary[k] = v
	end

	local dupe = {}
	for key,block in dupeBlock:gmatch("([^\n:]+):([^\n]+)") do
		
		local tables = {}
		subtables = {}
		local head
		
		for id,chunk in block:gmatch('(%w+){(.-)}') do
			
			--check if this table is the trunk
			if byte(id) == 72 then
				id = sub(id,2)
				head = id
			end
			
			tables[id] = {}
			
			for kv in gmatch(chunk,'[^;]+') do
				
				local k,v = match(kv,'(.-)=(.+)')
				
				if k then
					k = deserializeChunk( k )
					v = deserializeChunk( v )
					
					tables[id][k] = v
				else
					v = deserializeChunk( kv )
					local tid = tables[id]
					tid[#tid+1]=v
				end
				
			end
		end
		
		--Restore table references
		for id,tbls in pairs( subtables ) do
			for _,tbl in pairs( tbls ) do
				if not tables[id] then error("attempt to reference a nonexistent table") end
				for k,v in pairs(tables[id]) do
					tbl[k] = v
				end
			end
		end
		
		dupe[key] = tables[ head ]
		
	end
	
	return dupe, info, moreinfo
	
end

--seperates the header and body and converts the header to a table
local function getInfo(str)
	local last = str:find("\2")
	if not last then
		error("attempt to read AD2 file with malformed info block error 1")
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
			error("attempt to read AD2 file with malformed info block error 2")
		end
	end
	return info, str:sub(last+2)
end

--decoders for individual versions go here
local versions = {}

versions[2] = function(encodedDupe)
	encodedDupe = encodedDupe:Replace("\r\r\n\t\r\n", "\t\t\t\t")
	encodedDupe = encodedDupe:Replace("\r\n\t\n", "\t\t\t\t")
	encodedDupe = encodedDupe:Replace("\r\n", "\n")
	encodedDupe = encodedDupe:Replace("\t\t\t\t", "\r\n\t\n")
	local info, dupestring = getInfo(encodedDupe:sub(7))
	return deserialize_v2(
				lzwDecode(
					huffmanDecode(
						invEscapeSub(dupestring)
					)
				)
			), info
end

versions[1] = function(encodedDupe)
	encodedDupe = encodedDupe:Replace("\r\r\n\t\r\n", "\t\t\t\t")
	encodedDupe = encodedDupe:Replace("\r\n\t\n", "\t\t\t\t")
	encodedDupe = encodedDupe:Replace("\r\n", "\n")
	encodedDupe = encodedDupe:Replace("\t\t\t\t", "\r\n\t\n")
	local info, dupestring = getInfo(encodedDupe:sub(7))
	return deserialize_v1(
				lzwDecode(
					huffmanDecode(
						invEscapeSub(dupestring)
					)
				)
			), info
end

versions[0] = deserializeAD1

AdvDupe2.LegacyDecoders = versions
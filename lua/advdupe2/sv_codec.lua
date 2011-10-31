--[[
	Title: Adv. Dupe 2 Codec

	Desc: Dupe encoder/decoder.

	Author: emspike

	Version: 1.0
]]

local REVISION = 1

local pairs = pairs
local type = type
local tostring = tostring
local tonumber = tonumber
local error = error
local Vector = Vector
local Angle = Angle
local unpack = unpack
local format = string.format
local char = string.char
local byte = string.byte
local sub = string.sub
local gsub = string.gsub
local find = string.find
local gmatch = string.gmatch
local concat = table.concat
local remove = table.remove
local sort = table.sort
local merge = table.Merge
local match = string.match
local insert = table.insert

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

local period = CreateConVar("advdupe2_codec_pipeperiod",1,"Every this many ticks, the codec pipeline processor will run.",FCVAR_ARCHIVE,FCVAR_DONTRECORD)
local clock = 1
local pipelines = {}
local function addPipeline(pipeline)
	insert(pipelines,pipeline)
end
local function pipeproc()
	if clock % period:GetInt() == 0 then
		done = {}
		for idx,pipeline in pairs(pipelines) do
			local i = pipeline.idx + 1
			pipeline.idx = i
			if i == pipeline.cbk then
				done[#done+1] = idx
				pipeline.info.size = #pipeline.eax
				local success, err = pcall(pipeline[i], AD2FF:format(char(pipeline.REVISION), makeInfo(pipeline.info), pipeline.eax), unpack(pipeline.args))
				if not success then ErrorNoHalt(err) end
			else
				local success, err = pcall(pipeline[i], pipeline.eax)
				if success then
					pipeline.eax = err
				else
					ErrorNoHalt(err)
					done[#done+1] = idx
				end
			end
		end
		sort(done)
		for i = #done, 1, -1 do
			remove(pipelines,done[i])
		end
		clock = 1
	else
		clock = clock + 1
	end
end
hook.Add("Tick","AD2CodecPipelineProc",pipeproc)

local encode_types, decode_types
local str,pos
local a,b,c,m,n,w

local function write(data)
	local t = encode_types[type(data)]
	if t then
		local data, id_override = t[2](data)
		return char(id_override or t[1])..data
	end
end

encode_types = {
	table = {2, function(o)
		local is_array = true
		m = 0
		for k in pairs(o) do
			m = m + 1
			if k ~= m then
				is_array = false
				break
			end
		end
		local u = {}
		if is_array then
			for g = 1,#o do
				u[g] = write(o[g])
			end
			return concat(u).."\1", 3
		else
			local i = 0
			for k,v in pairs(o) do
				w = write(v)
				if w then
					i = i + 2
					u[i-1] = write(k)
					u[i] = w
				end
			end
			return concat(u).."\1"
		end
	end},
	boolean = {4, function(o)
		return "", o and 5
	end},
	number = {6, function(o)
		return (o==0 and "" or o).."\1"
	end},
	string = {7, function(o)
		return o.."\1"
	end},
	Vector = {8, function(o)
		return format("%g\1%g\1%g\1",o.x,o.y,o.z)
	end},
	Angle = {9, function(o)
		return format("%g\1%g\1%g\1",o.p,o.y,o.r)
	end}
}

local function read()
	local t = byte(str,pos+1)
	if t then
		local dt = decode_types[t]
		if dt then
			pos = pos + 1
			return dt()
		else
			error(format("encountered invalid data type (%u)",t))
		end
	else
		error("expected value, got EOF")
	end
end

decode_types = {
	[1	] = function()
		error("expected value, got terminator")
	end,
	[2	] = function() -- table
		local t = {}
		while true do
			if byte(str,pos+1) == 1 then
				pos = pos+1
				return t
			else
				t[read()] = read()
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
				t[i] = read()
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
			error("expected number, got EOF")
		end
	end,
	[7	] = function() -- string
		m = find(str,"\1",pos)
		if m then
			w = sub(str,pos+1,m-1)
			pos = m
			return w
		else
			error("expected string, got EOF")
		end
	end,
	[8	] = function() -- Vector
		m,n = find(str,".-\1.-\1.-\1",pos)
		if m then
			a,b,c = match(str,"^(.-)\1(.-)\1(.-)\1",pos+1)
			pos = n
			return Vector(tonumber(a), tonumber(b), tonumber(c))
		else
			error("expected vector, got EOF")
		end
	end,
	[9	] = function() -- Angle
		m,n = find(str,".-\1.-\1.-\1",pos)
		if m then
			a,b,c = match(str,"^(.-)\1(.-)\1(.-)\1",pos+1)
			pos = n
			return Angle(tonumber(a), tonumber(b), tonumber(c))
		else
			error("expected angle, got EOF")
		end
	end
}
local function deserialize(data)
	str = data
	pos = 0
	return read()
end
local function serialize(data)
	return write(data)
end

local idxmem = {}
for i=0,252 do
	idxmem[i] = char(i)
end

local function encodeIndex(index)
	local buffer = {}
	local buffer_len = 0
	local temp
	while index>0 do
		temp = index>>8
		buffer_len = buffer_len + 1
		buffer[buffer_len] = index - (temp << 8)
		index = temp
	end	
	return char(256 - buffer_len, unpack(buffer))
end
local function lzwEncode(raw)
	local dictionary_length = 256
	local dictionary = {}
	local compressed = {}
	local word = ""
	for i = 0, 255 do
		dictionary[char(i)] = i
	end
	local curchar
	local wordc
	local compressed_length = 0
	local temp
	for i = 1, #raw do
		curchar = sub(raw,i,i)
		wordc = word..curchar
		if dictionary[wordc] then
			word = wordc
		else
			dictionary[wordc] = dictionary_length
			dictionary_length = dictionary_length + 1
			
			temp = idxmem[dictionary[word]]
			
			compressed_length = compressed_length + 1
			if temp then
				compressed[compressed_length] = temp
			else
				temp = encodeIndex(dictionary[word])
				compressed[compressed_length] = temp
				idxmem[dictionary[word]] = temp
			end
			
			word = curchar
		end
	end
	temp = idxmem[dictionary[word]]
	if temp then
		compressed[compressed_length+1] = temp
	else
		temp = encodeIndex(dictionary[word])
		compressed[compressed_length+1] = temp
		idxmem[dictionary[word]] = temp
	end
	return concat(compressed)
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
			for i = pos+firstbyte, pos+1, -1 do
				index = (index << 8) | byte(encoded,i)
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

--http://en.wikipedia.org/wiki/Huffman_coding#Compression

local codes = {{22,5},{11,5},{58,6},{57,6},{37,6},{35,6},{13,6},{31,6},{51,6},{55,6},{26,7},{10,7},{9,6},{1,7},{59,6},{15,7},{61,7},{33,7},{97,7},{5,8},{133,8},{130,8},{65,7},{41,7},{94,7},{62,7},{17,7},{7,7},{162,8},{89,7},{87,7},{3,7},{39,7},{2,8},{66,8},{142,8},{21,8},{47,7},{50,7},{82,7},{46,7},{25,7},{19,7},{170,8},{90,9},{305,9},{290,9},{437,9},{270,9},{254,9},{85,9},{369,9},{49,9},{42,9},{53,9},{238,9},{381,9},{29,9},{346,10},{245,10},{497,9},{226,10},{327,9},{207,9},{458,9},{301,9},{81,9},{490,9},{489,9},{283,9},{103,9},{626,10},{109,9},{429,9},{262,10},{509,9},{237,9},{390,9},{233,9},{413,9},{774,10},{181,9},{323,9},{177,9},{197,9},{45,9},{730,10},{91,9},{349,9},{882,10},{63,9},{646,10},{202,10},{718,10},{325,9},{402,10},{286,9},{414,9},{117,9},{366,9},{111,8},{105,9},{67,9},{361,9},{14,9},{242,10},{453,9},{510,9},{422,9},{70,9},{166,9},{38,9},{658,10},{337,9},{294,9},{102,9},{253,9},{27,9},{411,9},{110,9},{241,9},{255,9},{213,9},{733,10},{746,10},{198,10},{454,10},{786,10},{586,10},{157,9},{846,10},{486,10},{962,10},{78,10},{610,10},{590,10},{219,9},{625,10},{493,9},{474,10},{194,10},{842,10},{974,10},{285,9},{917,10},{83,9},{127,9},{370,10},{710,10},{1013,10},{134,10},{221,10},{511,9},{998,10},{191,9},{114,10},{467,9},{209,10},{447,9},{1006,10},{382,10},{319,9},{149,9},{462,10},{126,10},{330,10},{475,9},{309,10},{98,10},{69,9},{986,10},{742,10},{810,10},{383,9},{455,9},{407,9},{155,9},{199,9},{465,10},{354,10},{618,10},{469,9},{158,9},{365,9},{206,10},{106,10},{721,10},{714,10},{870,10},{894,10},{542,10},{74,10},{347,9},{146,10},{821,10},{279,9},{638,10},{373,9},{211,9},{866,10},{231,9},{501,10},{530,10},{450,10},{230,10},{487,9},{494,10},{195,9},{23,9},{173,9},{239,9},{966,10},{6,10},{234,10},{113,10},{274,10},{334,10},{30,10},{706,10},{34,10},{914,10},{341,9},{71,9},{151,9},{339,9},{93,9},{125,9},{451,9},{754,10},{482,10},{335,9},{218,10},{994,10},{874,10},{858,10},{518,10},{498,10},{738,10},{362,10},{757,10},{477,9},{405,10},{463,9},{326,10},{495,9},{838,10},{1010,10},{298,10},{358,10},{359,9},{79,9},{977,10},{546,10},{0,2},{18,10},[0]={433,9}}
local function huffmanEncode(raw)
	
	local rawlen = #raw
	
	--output is headed by the unencoded size as a 24-bit integer (65kB+ LZW encodings are easily possible here, 16MB not so much)
	local encoded = {
		char(rawlen & 0xff),
		char((rawlen >> 8) & 0xff),
		char((rawlen >> 16) & 0xff)
	}
	local encoded_length = 3
	local buffer = 0
	local buffer_length = 0
	
	local code
	--the encoding would be way faster in C (most of the execution time of this function is spent calling string.byte)
	for i = 1, rawlen do
		code = codes[byte(raw,i)]
		buffer = buffer + (code[1] << buffer_length)
		buffer_length = buffer_length + code[2]
		while buffer_length>=8 do
			encoded_length = encoded_length + 1
			encoded[encoded_length] = char(buffer & 0xff)
			buffer = buffer >> 8
			buffer_length = buffer_length - 8
		end
	end
	
	if buffer_length>0 then
		encoded[encoded_length+1] = char(buffer)
	end
	
	return concat(encoded)
end

--http://en.wikipedia.org/wiki/Huffman_coding#Decompression

local invcodes = {[2]={[0]="\254"},[5]={[22]="\1",[11]="\2"},[6]={[13]="\7",[35]="\6",[37]="\5",[58]="\3",[31]="\8",[9]="\13",[51]="\9",[55]="\10",[57]="\4",[59]="\15"},[7]={[1]="\14",[15]="\16",[87]="\31",[89]="\30",[62]="\26",[17]="\27",[97]="\19",[19]="\43",[10]="\12",[39]="\33",[41]="\24",[82]="\40",[3]="\32",[46]="\41",[47]="\38",[94]="\25",[65]="\23",[50]="\39",[26]="\11",[7]="\28",[33]="\18",[61]="\17",[25]="\42"},[8]={[111]="\101",[162]="\29",[2]="\34",[133]="\21",[142]="\36",[5]="\20",[21]="\37",[170]="\44",[130]="\22",[66]="\35"},[9]={[241]="\121",[361]="\104",[365]="\184",[125]="\227",[373]="\198",[253]="\117",[381]="\57",[270]="\49",[413]="\80",[290]="\47",[294]="\115",[38]="\112",[429]="\74",[433]="\0",[437]="\48",[158]="\183",[453]="\107",[166]="\111",[469]="\182",[477]="\241",[45]="\86",[489]="\69",[366]="\100",[497]="\61",[509]="\76",[49]="\53",[390]="\78",[279]="\196",[283]="\70",[414]="\98",[53]="\55",[422]="\109",[233]="\79",[349]="\89",[369]="\52",[14]="\105",[238]="\56",[319]="\162",[323]="\83",[327]="\63",[458]="\65",[335]="\231",[339]="\225",[337]="\114",[347]="\193",[493]="\139",[23]="\209",[359]="\250",[490]="\68",[42]="\54",[63]="\91",[286]="\97",[254]="\50",[510]="\108",[109]="\73",[67]="\103",[255]="\122",[69]="\170",[70]="\110",[407]="\176",[411]="\119",[110]="\120",[83]="\146",[149]="\163",[151]="\224",[85]="\51",[155]="\177",[79]="\251",[27]="\118",[447]="\159",[451]="\228",[455]="\175",[383]="\174",[463]="\243",[467]="\157",[173]="\210",[475]="\167",[177]="\84",[90]="\45",[487]="\206",[93]="\226",[495]="\245",[207]="\64",[127]="\147",[191]="\155",[511]="\153",[195]="\208",[197]="\85",[199]="\178",[181]="\82",[102]="\116",[103]="\71",[285]="\144",[105]="\102",[211]="\199",[213]="\123",[301]="\66",[305]="\46",[219]="\137",[81]="\67",[91]="\88",[157]="\130",[325]="\95",[29]="\58",[231]="\201",[117]="\99",[341]="\222",[237]="\77",[239]="\211",[71]="\223"},[10]={[710]="\149",[245]="\60",[742]="\172",[774]="\81",[134]="\151",[917]="\145",[274]="\216",[405]="\242",[146]="\194",[838]="\246",[298]="\248",[870]="\189",[1013]="\150",[894]="\190",[326]="\244",[330]="\166",[334]="\217",[465]="\179",[346]="\59",[354]="\180",[966]="\212",[974]="\143",[370]="\148",[998]="\154",[625]="\138",[382]="\161",[194]="\141",[198]="\126",[402]="\96",[206]="\185",[586]="\129",[721]="\187",[610]="\135",[618]="\181",[626]="\72",[226]="\62",[454]="\127",[658]="\113",[462]="\164",[234]="\214",[474]="\140",[242]="\106",[714]="\188",[730]="\87",[498]="\237",[746]="\125",[754]="\229",[786]="\128",[202]="\93",[18]="\255",[810]="\173",[846]="\131",[74]="\192",[842]="\142",[977]="\252",[858]="\235",[78]="\134",[874]="\234",[882]="\90",[646]="\92",[1006]="\160",[126]="\165",[914]="\221",[718]="\94",[738]="\238",[638]="\197",[482]="\230",[34]="\220",[962]="\133",[6]="\213",[706]="\219",[986]="\171",[994]="\233",[866]="\200",[1010]="\247",[98]="\169",[518]="\236",[494]="\207",[230]="\205",[542]="\191",[501]="\202",[530]="\203",[450]="\204",[209]="\158",[106]="\186",[590]="\136",[218]="\232",[733]="\124",[309]="\168",[221]="\152",[757]="\240",[113]="\215",[114]="\156",[362]="\239",[486]="\132",[358]="\249",[262]="\75",[30]="\218",[821]="\195",[546]="\253"}}

local function huffmanDecode(encoded)
	
	local h1,h2,h3 = byte(encoded, 1, 3)
	
	if (not h3) or (#encoded < 4) then
		error("invalid input")
	end
	
	local original_length = (h3<<16) | (h2<<8) | h1
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
			code = buffer & (1 << code_len)-1
			if temp and temp[code] then --most of the time temp is nil
				decoded_length = decoded_length + 1
				decoded[decoded_length] = temp[code]
				buffer = buffer >> code_len
				buffer_length = buffer_length - code_len
				code_len = 2
			else
				code_len = code_len + 1
				if code_len > 10 then
					error("malformed code")
				end
			end
		else
			buffer = buffer | (byte(encoded, pos) << buffer_length)
			buffer_length = buffer_length + 8
			pos = pos + 1
			if pos > encoded_length then
				error("malformed code")
			end
		end
	end
	
	return concat(decoded)
end

--escape sequences can't be palindromes
local escseq = {
	"bbq",
	"wtf",
	"cat",
	"car",
	"bro",
	"moo",
	"sky",
}

local function escapeSub(str)
	local genseq
	for i=1,#escseq do
		if not find(str, escseq[i]) then
			genseq = escseq[i]
			return genseq.."\n"..gsub(str,"\26",genseq)
		end
	end
	for i=30,200 do
		genseq = char(i, i-1, i+1)
		if not find(str, genseq) then
			return genseq.."\n"..gsub(str,"\26",genseq)
		end
		genseq = char(i, i, i+1)
		if not find(str, genseq) then
			return genseq.."\n"..gsub(str,"\26",genseq)
		end
	end
	error("<sub> could not be escaped")
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
	for k,v in dictBlock:gmatch("([^\n]+):\"(.-)\"") do
		dictionary[k] = v
	end

	local dupe = {}
	for key,block in dupeBlock:gmatch("([^\n:]+):([^\n]+)") do
		
		local tables = {}
		subtables = {}
		local head
		
		for id,chunk in block:gmatch('([A-H0-9]+){(.-)}') do
			
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

--[[
	Name:	Encode
	Desc:	Generates the string for a dupe file with the given data.
	Params:	<table> dupe, <table> info, <function> callback, <...> args
	Return:	runs callback(<string> encoded_dupe, <...> args)
]]
function AdvDupe2.Encode(dupe, info, callback, ...)
		
	info.check = "\r\n\t\n"
	
	addPipeline{
		serialize,
		lzwEncode,
		huffmanEncode,
		escapeSub,
		callback,
		eax = dupe,
		REVISION = REVISION,
		info = info,
		args = {...},
		idx = 0,
		cbk = 5
	}
	
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
	if not info.check or info.check ~= "\r\n\t\n" then
		error("attempt to read AD2 file with malformed info block")
	end
	return info, str:sub(last+2)
end

--decoders for individual versions go here
versions = {}

versions[1] = function(encodedDupe)
	local info, dupestring = getInfo(encodedDupe:sub(7))
	return deserialize(
				lzwDecode(
					huffmanDecode(
						invEscapeSub(dupestring)
					)
				)
			), info
end

--[[
	Name:	Decode
	Desc:	Generates the table for a dupe from the given string. Inverse of Encode
	Params:	<string> encodedDupe, <function> callback, <...> args
	Return:	runs callback(<boolean> success, <table/string> tbl, <table> info)
]]
function AdvDupe2.Decode(encodedDupe, callback, ...)
	
	local sig, rev = encodedDupe:match("^(....)(.)")
	
	if not rev then
		error("malformed dupe (wtf <5 chars long?!)")
	end
	
	rev = rev:byte()
	
	if sig ~= "AD2F" then
		if sig == "[Inf" then --legacy support, ENGAGE (AD1 dupe detected)
			local success, tbl, info, moreinfo = pcall(deserializeAD1, encodedDupe)

			if success then
				info.size = #encodedDupe
				info.revision = 0
				info.ad1 = true
			else
				ErrorNoHalt(tbl)
			end

			callback(success, tbl, info, moreinfo, ...)
		else
			error("unknown duplication format")
		end
	elseif rev > REVISION then
		error(format("this install lacks the codec version to parse the dupe (have rev %u, need rev %u)",REVISION,rev))
	elseif rev == 0 then
		error("attempt to use an invalid format revision (rev 0)")
	else
		local success, tbl, info = pcall(versions[rev], encodedDupe)
		
		if success then
			info.revision = rev
		else
			ErrorNoHalt(tbl)
		end
		
		callback(success, tbl, info, ...)
	end

end
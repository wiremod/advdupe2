--[[
	Title: Null Escaper

	Desc: Escapes null characters.

	Author: AD2 Team

	Version: 1.0
]]

local char = string.char
local find = string.find
local gsub = string.gsub
local match = string.match

local Null = {}

local escseq = { --no palindromes
	"bbq",
	"wtf",
	"cat",
	"car",
	"bro",
	"moo",
	"sky",
}

function Null.esc(str)
	local genseq
	for i=1,#escseq do
		if not find(str, escseq[i]) then
			local genseq = escseq[i]
			return genseq.."\n"..gsub(str,"%z",genseq)
		end
	end
	for i=30,200 do
		genseq = char(i, i-1, i+1)
		if not find(str, genseq) then
			return genseq.."\n"..gsub(str,"%z",genseq)
		end
		genseq = char(i, i, i+1)
		if not find(str, genseq) then
			return genseq.."\n"..gsub(str,"%z",genseq)
		end
	end
	error("nullesc could not escape the string")
end

function Null.invesc(str)
	local delim,huff = match(str,"^(.-)\n(.-)$")
	return gsub(huff,delim,"\0")
end

AdvDupe2.Null = Null

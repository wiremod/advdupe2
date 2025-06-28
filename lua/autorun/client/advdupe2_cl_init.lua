AdvDupe2 = AdvDupe2 or {}

AdvDupe2.InfoText = {}
AdvDupe2.FileRenameTryLimit = 256
AdvDupe2.ProgressBar = {}

if not file.Exists(AdvDupe2.DataFolder, "DATA") then
	file.CreateDir(AdvDupe2.DataFolder)
end

include( "advdupe2/file_browser.lua" )
include( "advdupe2/sh_codec.lua" )
include( "advdupe2/cl_file.lua" )
include( "advdupe2/cl_ghost.lua" )

function AdvDupe2.Notify(msg,typ,dur)
	surface.PlaySound(typ == 1 and "buttons/button10.wav" or "ambient/water/drip1.wav")
	GAMEMODE:AddNotify(msg, typ or NOTIFY_GENERIC, dur or 5)
	print("[AdvDupe2Notify]\t" .. msg)
end

net.Receive("AdvDupe2Notify", function()
	AdvDupe2.Notify(net.ReadString(), net.ReadUInt(8), net.ReadFloat())
end)
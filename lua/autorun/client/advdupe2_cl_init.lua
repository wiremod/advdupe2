AdvDupe2 = {
	Version = "1.1.0",
	Revision = 51,
	InfoText = {},
	DataFolder = "advdupe2",
	FileRenameTryLimit = 256,
	ProgressBar = {}
}

if(!file.Exists(AdvDupe2.DataFolder, "DATA"))then
	file.CreateDir(AdvDupe2.DataFolder)
end

include "advdupe2/file_browser.lua"
include "advdupe2/sh_codec.lua"
include "advdupe2/cl_file.lua"
include "advdupe2/cl_ghost.lua"

function AdvDupe2.Notify(msg,typ,dur)
	surface.PlaySound(typ == 1 and "buttons/button10.wav" or "ambient/water/drip1.wav")
	GAMEMODE:AddNotify(msg, typ or NOTIFY_GENERIC, dur or 5)
	//if not game.SinglePlayer() then
		print("[AdvDupe2Notify]\t"..msg)
	//end
end

net.Receive("AdvDupe2Notify", function()
	AdvDupe2.Notify(net.ReadString(), net.ReadUInt(8), net.ReadFloat())
end)

AdvDupe2 = {
	Version = "1.1.0",
	Revision = 51,
	Info = {}
}

AdvDupe2.DataFolder = "advdupe2" --name of the folder in data where dupes will be saved

AdvDupe2.FileRenameTryLimit = 256

include "advdupe2/cl_file.lua"
include "advdupe2/cl_networking.lua"
include "advdupe2/file_browser.lua"
include "advdupe2/sh_codec.lua"

function AdvDupe2.Notify(msg,typ,dur)
	surface.PlaySound(typ == 1 and "buttons/button10.wav" or "ambient/water/drip1.wav")
	GAMEMODE:AddNotify(msg, typ or NOTIFY_GENERIC, dur or 5)
	//if not game.SinglePlayer() then
		print("[AdvDupe2Notify]\t"..msg)
	//end
end

usermessage.Hook("AdvDupe2Notify",function(um)
	AdvDupe2.Notify(um:ReadString(),um:ReadChar(),um:ReadChar())
end)

timer.Simple(0, function()
	AdvDupe2.ProgressBar={}
end)
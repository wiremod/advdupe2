AdvDupe2 = {
	Version = "1.0.0",
	Revision = 1
}

AdvDupe2.DataFolder = "advdupe2" --name of the folder in data where dupes will be saved

AdvDupe2.FileRenameTryLimit = 256

include "advdupe2/cl_browser.lua"
include "advdupe2/cl_file.lua"
include "advdupe2/cl_networking.lua"

function AdvDupe2.Notify(msg,typ,dur)
	surface.PlaySound(typ == 1 and "buttons/button10.wav" or "ambient/water/drip1.wav")
	GAMEMODE:AddNotify(msg, typ or NOTIFY_GENERIC, dur or 5)
	if not SinglePlayer() then
		print("[AdvDupe2Notify]\t"..msg)
	end
end

function AdvDupe2.ShowSplash()
	local ad2folder
	for k,v in pairs(GetAddonList()) do
		if GetAddonInfo(v).Name == "Adv. Duplicator 2" then
			ad2folder = v
			break
		end
	end

	local splash = vgui.Create("DFrame")
	splash:SetSize(512, 316) // Make it 1/4 the users screen size
	splash:SetPos((ScrW()/2) - splash:GetWide()/2, (ScrH()/2) - splash:GetTall()/2)
	splash:SetVisible( true )
	splash:SetTitle("")
	splash:SetDraggable( true )
	splash:ShowCloseButton( true )
	splash.Paint = function( self )
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawRect(0, 0, self:GetWide(), self:GetTall())
	end
	splash:MakePopup()
	
	local logo = vgui.Create("TGAImage", splash)
	logo:SetPos(0, 24)
	logo:SetSize(512, 128)
	logo:LoadTGAImage(("addons/%s/materials/gui/ad2logo.tga"):format(ad2folder),"LOL it doesn't actually have to be 'MOD'")
	
	local version = vgui.Create("DLabel", splash)
	version:SetPos(512 - (512-446)/2 - 85,140) // Position
	version:SetColor(Color(0,0,0,255)) // Color
	version:SetText(("v%s (rev. %u)"):format(AdvDupe2.Version, AdvDupe2.Revision)) // Text
	version:SizeToContents()
	
	local credit = vgui.Create("DLabel", splash)
	credit:SetPos((512-446)/2 + 16,190)
	credit:SetColor(Color(64,32,16,255))
	credit:SetFont("Trebuchet24")
	credit:SetText("Developed by: TB and emspike\n\nHosted by: Google Code")
	credit:SizeToContents()
end

usermessage.Hook("AdvDupe2Notify",function(um)
	AdvDupe2.Notify(um:ReadString(),um:ReadChar(),um:ReadChar())
end)

timer.Simple(0, function()
	AdvDupe2.ProgressBar={}
end)
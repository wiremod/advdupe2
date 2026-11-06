local Files = {
	"util.lua",
	"skin.lua",
	"settings.lua",
	"node.lua",
	"rootfolder.lua",
	"userprompt.lua",
	"tree.lua",
	"browser.lua",
	"panel.lua",
}

if SERVER then
	for _, File in ipairs(Files) do
		AddCSLuaFile(File)
	end

	return
end

local FileBrowser = {}

for _, File in ipairs(Files) do
	include(File)(FileBrowser)
end

return FileBrowser

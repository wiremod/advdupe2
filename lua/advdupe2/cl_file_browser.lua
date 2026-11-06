local FileBrowser    = include("advdupe2/file_browser/init.lua")
local DataFolderRoot = FileBrowser.DataFolderRoot

AdvDupe2.FileBrowserLibrary = FileBrowser

-- This turns a data-folder path name into something AdvDupe2.UploadFile can tolerate
local function GetNodeDataPath(Node)
	local Path = Node.Path
	if not Path then return "" end

	local RelativePath = string.sub(Path, #Node.Root.RootImpl.BasePath + 2)
	if Node:IsFile() then
		RelativePath = string.StripExtension(RelativePath)
	end

	return RelativePath
end

-- wraps File.Exists and throws a notification
local function FileExists(Path)
	if not Path then
		AdvDupe2.Notify("Expected path, got nil!")
		return false
	end

	if not file.Exists(Path, "DATA") then
		AdvDupe2.Notify("File '" .. Path .. "' does not exist.")
		return false
	end

	return true
end

local function OpenPreview(Node)
	local ReadPath = Node.Path
	if not FileExists(ReadPath) then return end

	local Read = file.Read(ReadPath, "DATA")
	local Name = string.StripExtension(string.GetFileFromFilename(ReadPath))

	local Success, Dupe, Info, MoreInfo = AdvDupe2.Decode(Read)

	if Success then
		AdvDupe2.LoadGhosts(Dupe, Info, MoreInfo, Name, true)
	end
end

local AdvDupe2Root = DataFolderRoot("Advanced Duplicator 2", AdvDupe2.DataFolder)
AdvDupe2Root.Area  = AdvDupe2.AREA_ADVDUPE2

function AdvDupe2Root:Init(Browser, Node)
	DataFolderRoot.Init(self, Browser, Node)
	Node:Expand()
end

function AdvDupe2Root:CanDeleteNode(Node)
	if Node:IsFolder() and string.sub(Node.Text, 1, 1) == "-" then return false end
	return DataFolderRoot.CanDeleteNode(self, Node)
end

function AdvDupe2Root:GetPlaceholderText(Field)
	if Field == "SaveName" then return "Dupe name" end
	if Field == "SaveDescription" then return "Dupe description" end
end

function AdvDupe2Root:UserLoad(Browser, Node)
	AdvDupe2.UploadFile(GetNodeDataPath(Node), self.Area)
end

function AdvDupe2Root:UserPreview(Browser, Node)
	OpenPreview(Node)
end

function AdvDupe2Root:UserSave(Browser, Node, Filename, Description)
	local DataPath = Node.Path .. "/" .. Filename
	AdvDupe2.SavePath = DataPath

	-- This is kinda weird but it's the only way I've been able to reliably avoid deadlocks here
	hook.Add("AdvDupe2_InitProgressBar", "AdvDupe2_BrowserDownloadPrompt", function(Txt)
		hook.Remove("AdvDupe2_InitProgressBar", "AdvDupe2_BrowserDownloadPrompt")
		if Txt ~= "Saving:" then return end

		Browser:ShowSavePrompt()
		hook.Add("AdvDupe2_RemoveProgressBar", "AdvDupe2_BrowserDownloadPrompt", function()
			hook.Remove("AdvDupe2_RemoveProgressBar", "AdvDupe2_BrowserDownloadPrompt")
			Browser:HideSavePrompt()
		end)
	end)
	-- Enqueue handler
	Browser:AwaitingFile(AdvDupe2.GetFilename(DataPath), function(NewFilepath)
		if not NewFilepath then
			Browser:HideSavePrompt()
			return
		end
		Node:Expand()
		Node:AddDataFile(NewFilepath)
		Browser:HideSavePrompt()
	end)

	RunConsoleCommand("AdvDupe2_SaveFile", Filename, Description)
end

local function AddHelpButton(Panel)
	Panel.Help = Panel:AddRightsideButton("help", "Help Section", function()
		local Menu = DermaMenu()
		Menu:AddOption("Bug Reporting", function()
			gui.OpenURL("https://github.com/wiremod/advdupe2/issues")
		end)
		Menu:AddOption("Controls", function()
			gui.OpenURL("https://github.com/wiremod/advdupe2/wiki/Controls")
		end)
		Menu:AddOption("Commands", function()
			gui.OpenURL("https://github.com/wiremod/advdupe2/wiki/Server-settings")
		end)
		Menu:Open()
	end, 2)
end

local function GetNodePath(_, Node)
	return GetNodeDataPath(Node), Node.Root.RootImpl.Area
end

local function GetFullPath(_, Node)
	local BasePath     = Node.Root.RootImpl.BasePath
	local RelativePath = GetNodeDataPath(Node)

	if RelativePath == "" then
		return BasePath .. "/"
	end

	return BasePath .. "/" .. RelativePath .. "/"
end

function AdvDupe2.CreateFileBrowser(Parent)
	local Settings = FileBrowser.CreateSettings("advdupe2")
	Settings:AddRootFolder(AdvDupe2Root)
	Settings:OnBrowserCreated(AddHelpButton)

	hook.Run("AdvDupe2_FileBrowserSettings", Settings)

	local Panel = FileBrowser.Create(Settings, Parent)
	Panel.GetNodePath = GetNodePath
	Panel.GetFullPath = GetFullPath
	return Panel
end

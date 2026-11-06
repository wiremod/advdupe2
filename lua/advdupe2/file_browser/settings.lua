return function(FileBrowser)
	local function CreateNodeTextRepresentation(Label, Offset)
		return table.concat{
			Label, "\n\n",
			"   [+]  [i]  New folder/file", "\n",
			string.rep(" ", Offset), "^\n",
			string.rep(" ", Offset), "^--- You are here"
		}
	end

	local Definitions = {
		{"PromptOpenTime",            "promptopentime",               "0.2",               "The time it takes for a user-prompt to fully open, in seconds.", 0, 1000000},
		{"PromptCloseTime",           "promptclosetime",              "0.3",               "The time it takes for a user-prompt to fully close, in seconds.", 0, 1000000},
		{"ViewType",                  "viewtype",                     "0",                 "The file browser view. 0 = tree, 1 = list, 2 = tiles.", 0, 2},
		{"MaxTimeToDoubleClick",      "maxtimetodoubleclick",         "0.25",              "Max time delta between clicks to count as a double click, in seconds.", 0, 1000000},
		{"NodeTall",                  "nodetall",                     "24",                "How tall a single file/directory node is in the file browser, in pixels.", 0, 1000000},
		{"NodePadding",               "nodepadding",                  "0",                 "The height padding inbetween two nodes, in pixels.", 0, 1000000},
		{"NodeDepthWidth",            "nodedepthwidth",               "12",                "The width of a single node layet, in pixels. For example a file in folder1/folder2 has a depth of 2, so the pixel width, given the default value, will be (12 * 2) == 24.", 0, 1000000},
		{"NodeFont",                  "nodefont",                     "DermaDefault",      "The surface.CreateFont-registered font the file browser uses."},
		{"NodeFontSmall",             "nodefontsmall",                "DefaultSmall",      "The surface.CreateFont-registered font the file browser uses for smaller fonts."},
		{"IconFolderEmpty",           "nodeicon_folderempty",         "icon16/folder.png", "The materials/ localized path for an empty folder."},
		{"IconFolderContains",        "nodeicon_folder",              "icon16/folder_page.png", "The materials/ localized path for a folder with contents."},
		{"IconFile",                  "nodeicon_file",                "icon16/page.png",   "The materials/ localized path for a file."},
		{"DrawTimeAlways",            "nodedrawtimealways",           "0",                 "When 0: the time is only drawn when sorting by time.\nWhen 1: the time will always draw\nWhen -1: the time will never draw."},
		{"DateFormat",                "dateformat",                   "%Y/%m/%d %H:%M",    "The format passed into os.date."},
		{"TileIconSize",              "tileiconsize",                 "32",                "The size, in pixels, of a folder or file icon in tile view.", 8, 256},
		{"ExpanderSize",              "nodeexpander_size",            "16",                CreateNodeTextRepresentation("The size, in pixels, for a node expander button.", 4), 0, 1000000},
		{"IconSize",                  "nodeicon_size",                "16",                CreateNodeTextRepresentation("The size, in pixels, for a folder or file icon.", 9), 0, 1000000},
		{"LeftmostToExpanderPadding", "nodepadding_toexpander",       "4",                 CreateNodeTextRepresentation("Distance, in pixels, between the leftmost side of the node and where the node expander is placed.", 1), 0, 1000000},
		{"ExpanderToIconPadding",     "nodepadding_expandertoicon",   "4",                 CreateNodeTextRepresentation("Distance, in pixels, between the node expander and the node icon.", 7), 0, 1000000},
		{"IconToTextPadding",         "nodepadding_icontotext",       "6",                 CreateNodeTextRepresentation("Distance, in pixels, between the node icon and the node text.", 12), 0, 1000000},
	}

	local SETTINGS = {}
	SETTINGS.__index = SETTINGS

	function FileBrowser.CreateSettings(ConVarPrefix)
		if not ConVarPrefix then return error("Cannot create file browser settings without a prefix") end

		local Settings = setmetatable({
			Prefix           = ConVarPrefix,
			ConVars          = {},
			Materials        = {},
			RootFolders      = {},
			CreatedCallbacks = {},
		}, SETTINGS)

		for _, Definition in ipairs(Definitions) do
			local Key, Name, Default, Help, Min, Max = unpack(Definition)
			Settings.ConVars[Key] = CreateClientConVar(ConVarPrefix .. "_menu_" .. Name, Default, true, false, Help, Min, Max)
		end

		Settings:Flush()
		return Settings
	end

	function SETTINGS:AddRootFolder(RootFolderType)
		self.RootFolders[#self.RootFolders + 1] = FileBrowser.IRootFolder(RootFolderType or error("RootFolderType must contain a IRootFolder implementation"))
	end

	function SETTINGS:OnBrowserCreated(Callback)
		self.CreatedCallbacks[#self.CreatedCallbacks + 1] = Callback
	end

	function SETTINGS:GetConVar(Key)
		return self.ConVars[Key] or error("Unknown file browser setting " .. tostring(Key))
	end

	function SETTINGS:GetConVarName(Key)
		return self:GetConVar(Key):GetName()
	end

	function SETTINGS:GetMaterial(Path)
		local Mat = self.Materials[Path]
		if not Mat then
			Mat = Material(Path, "smooth")
			self.Materials[Path] = Mat
		end

		return Mat
	end

	function SETTINGS:GetViewType()
		return math.Clamp(self.ConVars.ViewType:GetInt(), FileBrowser.VIEWTYPE_TREE, FileBrowser.VIEWTYPE_TILES)
	end

	function SETTINGS:SetViewType(ViewType)
		self.ConVars.ViewType:SetInt(ViewType)
	end

	function SETTINGS:Flush()
		local ConVars = self.ConVars

		self.PromptOpenTime       = ConVars.PromptOpenTime:GetFloat()
		self.PromptCloseTime      = ConVars.PromptCloseTime:GetFloat()

		self.MaxTimeToDoubleClick = ConVars.MaxTimeToDoubleClick:GetFloat()
		self.NodeTall             = ConVars.NodeTall:GetFloat()
		self.NodePadding          = ConVars.NodePadding:GetFloat()
		self.TallOfOneNode        = self.NodeTall + self.NodePadding
		self.NodeDepthWidth       = ConVars.NodeDepthWidth:GetFloat()
		self.NodeFont             = ConVars.NodeFont:GetString()
		self.NodeFontSmall        = ConVars.NodeFontSmall:GetString()

		self.ExpanderSize              = ConVars.ExpanderSize:GetFloat()
		self.IconSize                  = ConVars.IconSize:GetFloat()
		self.LeftmostToExpanderPadding = ConVars.LeftmostToExpanderPadding:GetFloat()
		self.ExpanderToIconPadding     = ConVars.ExpanderToIconPadding:GetFloat()
		self.IconToTextPadding         = ConVars.IconToTextPadding:GetFloat()

		self.ExpanderXOffset = self.LeftmostToExpanderPadding
		self.IconXOffset     = self.ExpanderXOffset + self.ExpanderSize + self.ExpanderToIconPadding
		self.TextXOffset     = self.IconXOffset + self.IconSize + self.IconToTextPadding

		self.DrawTimeAlways = ConVars.DrawTimeAlways:GetInt()
		self.DateFormat     = ConVars.DateFormat:GetString()

		self.TileIconSize = math.Clamp(ConVars.TileIconSize:GetFloat(), 8, 256)
		self.TileWidth    = math.max(self.TileIconSize + 48, 72)
		self.TileHeight   = self.TileIconSize + 36

		self.IconFolderEmpty    = self:GetMaterial(ConVars.IconFolderEmpty:GetString())
		self.IconFolderContains = self:GetMaterial(ConVars.IconFolderContains:GetString())
		self.IconFile           = self:GetMaterial(ConVars.IconFile:GetString())
	end
end

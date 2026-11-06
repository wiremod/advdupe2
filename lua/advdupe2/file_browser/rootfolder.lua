return function(FileBrowser)
	-- This interface describes the logic behind a root folder.

	local IRootFolder_MT = {}
	local IRootFolder    = setmetatable({}, IRootFolder_MT)

	do
		FileBrowser.IRootFolder = IRootFolder -- If other addons want to post-verify their IRootFolder implementations like we do

		-- todo; debug.getinfo and determine argument counts to further sanity check?
		IRootFolder.Init             = function(Impl, Browser, Node) end
		IRootFolder.GetFolderName    = function(Impl) end
		IRootFolder.GetPlaceholderText = function(Impl, Field) end
		IRootFolder.GetNameFilter    = function(Impl) end
		-- These define node operations
		-- These are RAW operations, as in the underlying Browser might do some prompts first
		-- But for example, calling IRootFolder:UserDelete() is expected to actually delete the node
		-- (and the browser will create the prompt)
		IRootFolder.UserLoad         = function(Impl, Browser, Node) end
		IRootFolder.UserPreview      = function(Impl, Browser, Node) end
		IRootFolder.UserSave         = function(Impl, Browser, Node, Filename, Description) end
		IRootFolder.UserRename       = function(Impl, Browser, Node, RenameTo) end
		IRootFolder.UserMove         = function(Impl, Browser, Node, TargetFolder) end
		IRootFolder.UserMenu         = function(Impl, Browser, Node, Menu) end
		IRootFolder.UserDelete       = function(Impl, Browser, Node) end
		IRootFolder.UserMakeFolder   = function(Impl, Browser, Node, Foldername) end
		IRootFolder.UserGetModTime   = function(Impl, Browser, Node) return 0 end
		IRootFolder.UserGetSize      = function(Impl, Browser, Node) return 0 end

		-- Ensures the implementor implemented the interface correctly
		-- if they didn't throw non-halting errors since it might be an optional method
		function IRootFolder_MT:__call(RootFolderType)
			for FuncName, _ in pairs(IRootFolder) do
				if not RootFolderType[FuncName] then
					ErrorNoHaltWithStack("File browser: IRootFolder implementation failed to implement " .. FuncName .. ", this may not work as intended...")
				end
			end

			return RootFolderType
		end
	end

	local DataFolderRoot_MT = {}
	local DataFolderRoot    = setmetatable({}, DataFolderRoot_MT)

	do
		FileBrowser.DataFolderRoot = DataFolderRoot

		function DataFolderRoot_MT:__call(Name, BasePath)
			if Name == nil then return error("Cannot create a nameless data folder root") end
			if BasePath == nil then return error("Cannot create a data folder root without a base path") end

			return setmetatable({
				Name       = Name,
				BasePath   = BasePath,
				NameFilter = "[^%w_ ]",
				-- Key-weak LUT's for size/modtimes.
				-- They're key-weak so if a node gets deleted it isn't hung up by GC thinking
				-- we care about the reference still
				SizeCache = setmetatable({}, {__mode = 'k'}),
				TimeCache = setmetatable({}, {__mode = 'k'})
			}, {__index = DataFolderRoot})
		end

		local function DeleteDataFolder(Path)
			local Files, Directories = file.Find(Path .. "/*", "DATA")

			for _, File in ipairs(Files or {}) do file.Delete(Path .. "/" .. File) end
			for _, Directory in ipairs(Directories or {}) do DeleteDataFolder(Path .. "/" .. Directory) end

			file.Delete(Path)
		end

		local function GetFreeDataPath(Directory, Name, Extension)
			local Suffix = Extension and ("." .. Extension) or ""
			local Path   = Directory .. Name .. Suffix
			if not file.Exists(Path, "DATA") then return Path end

			for I = 1, 256 do
				Path = string.format("%s%s_%03d%s", Directory, Name, I, Suffix)
				if not file.Exists(Path, "DATA") then return Path end
			end
		end

		function DataFolderRoot:GetFolderName() return self.Name end
		function DataFolderRoot:GetPlaceholderText(Field) end
		function DataFolderRoot:GetNameFilter() return self.NameFilter end

		function DataFolderRoot:CanDeleteNode(Node)
			return not Node:IsRoot()
		end

		function DataFolderRoot:Init(Browser, Node)
			Node.Path = self.BasePath
			Node:LoadDataFolder(self.BasePath .. "/")
		end

		function DataFolderRoot:UserLoad(Browser, Node) end
		function DataFolderRoot:UserPreview(Browser, Node) end
		function DataFolderRoot:UserSave(Browser, Node, Filename, Description) end

		function DataFolderRoot:UserRename(Browser, Node, RenameTo)
			if not Node:IsFile() then return false end
			if RenameTo == Node.Text then return true end

			local Extension = string.GetExtensionFromFilename(Node.Path)
			local NewPath   = GetFreeDataPath(string.GetPathFromFilename(Node.Path), RenameTo, Extension)

			if not NewPath or not file.Rename(Node.Path, NewPath) then return false end

			Node:SetDataPath(NewPath)
			Node.ParentNode:MarkSortDirty()
			Browser:ScrollTo(Node)
			return true
		end

		function DataFolderRoot:UserMove(Browser, Node, TargetFolder)
			if not Node:IsFile() or not TargetFolder:IsFolder() then return false end

			local Extension = string.GetExtensionFromFilename(Node.Path)
			local Name      = string.StripExtension(string.GetFileFromFilename(Node.Path))
			local NewPath   = GetFreeDataPath(TargetFolder.Path .. "/", Name, Extension)

			if not NewPath or not file.Rename(Node.Path, NewPath) then return false end

			Node:Remove()
			local NewNode = TargetFolder:AddDataFile(NewPath)
			TargetFolder:Expand()
			Browser:ScrollTo(NewNode)
			return true
		end

		function DataFolderRoot:UserMenu(Browser, Node, Menu)
			if Node:IsFile() then
				Menu:AddOption("Open",    function() self:UserLoad(Browser, Node)  end, "icon16/page_go.png")
				Menu:AddOption("Preview", function() self:UserPreview(Browser, Node) end, "icon16/information.png")
				Menu:AddSpacer()
				Menu:AddOption("Rename...", function() Browser:StartRename(Node) end, "icon16/textfield_rename.png")
				Menu:AddOption("Move...",   function() Browser:StartMove(Node)   end, "icon16/arrow_right.png")
				if self:CanDeleteNode(Node) then
					Menu:AddOption("Delete", function() Browser:StartDelete(Node) end, "icon16/bin_closed.png")
				end
			else
				Menu:AddOption("Save",       function() Browser:StartSave(Node)   end, "icon16/disk.png")
				Menu:AddOption("New Folder", function() Browser:StartFolder(Node) end, "icon16/folder_add.png")
				Menu:AddSpacer()
				Menu:AddOption("Search",     function() Browser:StartSearch(Node) end, "icon16/magnifier.png")
				if self:CanDeleteNode(Node) then
					Menu:AddOption("Delete", function() Browser:StartDelete(Node) end, "icon16/bin_closed.png")
				end
			end
		end

		function DataFolderRoot:UserDelete(Browser, Node)
			if not self:CanDeleteNode(Node) then return false end

			if Node:IsFolder() then
				DeleteDataFolder(Node.Path)
			else
				file.Delete(Node.Path)
			end

			local Success = not file.Exists(Node.Path, "DATA")
			if Success then
				Node:Remove()
			end
			return Success
		end

		function DataFolderRoot:UserMakeFolder(Browser, Node, Foldername)
			local DataPath = Node.Path .. "/" .. Foldername
			if file.Exists(DataPath, "DATA") then return false, "Folder name already exists." end

			file.CreateDir(DataPath)

			local NewNode = Node:AddDataFolder(DataPath)
			Node:Expand()
			NewNode:Expand()
			Browser:ScrollTo(NewNode)
			return true
		end

		function DataFolderRoot:UserGetModTime(Browser, Node)
			local Time = self.TimeCache[Node]
			if Time then return Time end

			Time = file.Time(Node.Path, "DATA")
			self.TimeCache[Node] = Time
			return Time
		end

		function DataFolderRoot:UserGetSize(Browser, Node)
			if Node:IsFolder() then return -1 end

			local Size = self.SizeCache[Node]
			if Size then return Size end

			Size = file.Size(Node.Path, "DATA")
			self.SizeCache[Node] = Size
			return Size
		end
	end
end

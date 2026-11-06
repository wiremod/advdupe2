return function(FileBrowser)
	local NODETYPE_FOLDER = FileBrowser.NODETYPE_FOLDER
	local NODETYPE_FILE   = FileBrowser.NODETYPE_FILE

	local NODE_MT = {}
	local NODE    = setmetatable({}, NODE_MT)
	do
		local LoadDataFolderInternal

		function NODE:Init(Type, Browser)
			self.Type      = Type
			self.Browser   = Browser
			self.Files     = {}
			self.Folders   = {}
			self.Sorted    = {}
			self.Expanded  = false
			self.Selected  = false

			self:MarkSortDirty()
		end

		function NODE_MT:__call(Type, Browser)
			if Type == nil then return error("Cannot create typeless node") end
			if not IsValid(Browser) then return error ("Cannot create a headless node (we need a browser)") end

			local Node   = setmetatable({}, {__index = NODE})
			Node:Init(Type, Browser)

			return Node
		end

		function NODE:IsRoot()   return (self.Root or error("No root?")) == self end
		function NODE:IsFolder() return self.Type == NODETYPE_FOLDER    end
		function NODE:IsFile()   return self.Type == NODETYPE_FILE      end

		function NODE:GetTime()
			if not self.Path then return 0 end
			if self.Time then return self.Time end

			local Time = file.Time(self.Path, "DATA")
			self.Time = Time or 0 -- I don't think it will return nil but I don't want to spam file.Time requests
			return Time
		end

		function NODE:GetTimeString()
			local Settings = self.Browser.Settings
			if self.TimeStr then return self.TimeStr end
			local Time = self:GetTime()
			if Time == 0 then return "" end
			local TimeStr = os.date(Settings.DateFormat, Time)
			self.TimeStr = TimeStr
			return TimeStr
		end

		function NODE:GetSize()
			if not self.Path or self:IsFolder() then return 0 end
			if self.Size then return self.Size end

			self.Size = file.Size(self.Path, "DATA") or 0
			return self.Size
		end

		function NODE:GetSizeString()
			if self:IsFolder() then return "" end
			if self.SizeStr then return self.SizeStr end

			self.SizeStr = string.NiceSize(self:GetSize())
			return self.SizeStr
		end

		function NODE:AddFolder(Text)
			local Node = NODE(NODETYPE_FOLDER, self.Browser)
			Node.Text = Text
			Node.ParentNode = self
			Node.Root = self.Root
			if self.Expanded then self:MarkSortDirty() end
			self.Folders[#self.Folders + 1] = Node

			return Node
		end

		function NODE:AddFile(Text)
			local Node = NODE(NODETYPE_FILE, self.Browser)
			Node.Text = Text
			Node.ParentNode = self
			Node.Root = self.Root
			if self.Expanded then self:MarkSortDirty() end
			self.Files[#self.Files + 1] = Node

			return Node
		end

		function NODE:Count() return #self.Files + #self.Folders end

		function NODE:MarkSortDirty()
			self.SortDirty         = true
			self.Browser:MarkSortDirty()
		end

		function NODE:Clear()
			table.Empty(self.Files)
			table.Empty(self.Folders)
			table.Empty(self.Sorted)
			self:MarkSortDirty()
		end

		function NODE:RemoveNode(Node)
			if Node:IsFolder() then
				table.RemoveByValue(self.Folders, Node)
			else
				table.RemoveByValue(self.Files, Node)
			end

			self:MarkSortDirty()
		end

		function NODE:Remove()
			local ParentNode = self.ParentNode

			if ParentNode then
				ParentNode:RemoveNode(self)
			else
				self:MarkSortDirty()
			end
		end

		function NODE:SetExpanded(Expanded)
			if Expanded == self.Expanded then return end

			self.Expanded = Expanded
			self:MarkSortDirty()
		end

		function NODE:Expand()         self:SetExpanded(true)              end
		function NODE:Collapse()       self:SetExpanded(false)             end
		function NODE:ToggleExpanded() self:SetExpanded(not self.Expanded) end

		function NODE:ExpandRecursive()
			self:SetExpanded(true)
			for _, Folder in ipairs(self.Folders) do Folder:ExpandRecursive() end
		end

		function NODE:CollapseRecursive()
			self:SetExpanded(false)
			for _, Folder in ipairs(self.Folders) do Folder:CollapseRecursive() end
		end

		function NODE:SetDataPath(Path)
			local Name   = string.GetFileFromFilename(Path)
			self.Path    = Path
			self.Text    = self:IsFile() and string.StripExtension(Name) or Name
			self.Time    = nil
			self.TimeStr = nil
			self.Size    = nil
			self.SizeStr = nil
		end

		function NODE:AddDataFile(Path)
			local Node = self:AddFile()
			Node:SetDataPath(Path)

			return Node
		end

		function NODE:AddDataFolder(Path)
			local Node = self:AddFolder()
			Node:SetDataPath(Path)
			Node.FirstObserved = function(DirNode) -- note FirstObserved will be destroyed after first call
				LoadDataFolderInternal(DirNode, Path .. "/")
			end

			return Node
		end

		function NODE:LoadAll()
			if self.FirstObserved then
				self:FirstObserved()
				self.FirstObserved = nil
			end

			for _, Folder in ipairs(self.Folders) do Folder:LoadAll() end
		end

		function NODE:FindFileByPath(Path)
			for _, File in ipairs(self.Files) do
				if File.Path == Path then return File end
			end
		end

		-- Expects a directory path ending in a forward slash.
		function LoadDataFolderInternal(Node, Path)
			local Files, Directories = file.Find(Path .. "*", "DATA", "nameasc")
			if not Files or not Directories then return end

			for _, File in ipairs(Files) do
				Node:AddDataFile(Path .. File)
			end

			for _, Directory in ipairs(Directories) do
				Node:AddDataFolder(Path .. Directory)
			end
		end

		function NODE:LoadDataFolder(Path)
			self:Clear()
			LoadDataFolderInternal(self, Path)
		end

		function NODE:PerformResort(SortFunction)
			if not self.SortDirty then return end

			local Sorted   = self.Sorted
			local Files    = self.Files
			local Folders  = self.Folders
			table.Empty(Sorted)

			for I = 1, #Files   do Sorted[#Sorted + 1] = Files[I]   end
			for I = 1, #Folders do Sorted[#Sorted + 1] = Folders[I] end

			-- For each node, check FirstObserved and call if it exists
			for _, Node in ipairs(Sorted) do
				if Node.FirstObserved then
					Node:FirstObserved()
					Node.FirstObserved = nil
				end
			end

			-- Perform actual resort
			if not self.KeepOrder then
				table.sort(Sorted, SortFunction)
			end
		end

		-- Returns an enumerator<Node>
		function NODE:GetSortedChildNodes(SortFunction)
			self:PerformResort(SortFunction)
			return ipairs(self.Sorted)
		end

		function NODE.InjectIntoBrowser(TreeView, Browser)
			for FuncName, Func in pairs(NODE) do
				TreeView[FuncName] = Func
			end

			NODE.Init(TreeView, NODETYPE_FOLDER, Browser)
		end
	end

	FileBrowser.NODE = NODE
end

return function(FileBrowser)
	local VIEWTYPE_TREE         = FileBrowser.VIEWTYPE_TREE
	local SORTTYPE_NAME         = FileBrowser.SORTTYPE_NAME
	local UserInterfaceTimeFunc = FileBrowser.UserInterfaceTimeFunc
	local IRootFolder           = FileBrowser.IRootFolder
	local USERPROMPT            = FileBrowser.USERPROMPT
	local IsAttached            = FileBrowser.IsAttached

	local BROWSER = {}
	AccessorFunc(BROWSER, "m_bBackground", "PaintBackground", FORCE_BOOL)
	AccessorFunc(BROWSER, "m_bgColor", "BackgroundColor")
	Derma_Hook(BROWSER, "Paint", "Paint", "Panel")
	Derma_Hook(BROWSER, "PerformLayout", "Layout", "Panel")

	local setbrowserpnlsize
	local function SetBrowserPnlSize(self, x, y)
		setbrowserpnlsize(self, x, y)
		self.TreeView:SetWide(x)
		self.TreeView.VBar:SetUp(y, self.TreeView:GetTall())
		self:MarkSortDirty()
	end

	function BROWSER:Init()
		setbrowserpnlsize = self.SetSize
		self.SetSize = SetBrowserPnlSize
		self.TreeView = vgui.CreateFromTable(FileBrowser.TreeTable, self)

		self:SetPaintBackground(true)
		self:SetPaintBackgroundEnabled(false)
		self:SetPaintBorderEnabled(false)
		self:SetBackgroundColor(self:GetSkin().text_bright)
	end

	function BROWSER:Setup(Settings)
		self.Settings          = Settings or error("No settings provided")
		self.TreeView.Settings = Settings

		self:SetViewType(Settings:GetViewType())
		self:SetSortType(SORTTYPE_NAME)
		self:SetAscending(true)
	end

	-- Public facing API

	function BROWSER:SetViewType(ViewType)
		local Settings = self.Settings
		ViewType = ViewType or error("No viewtype provided")

		local Tree     = self.TreeView
		local Previous = Tree.ViewType
		if Previous == ViewType then return end

		Tree.ViewType = ViewType
		Settings:SetViewType(ViewType)
		self:MarkSortDirty()

		if ViewType ~= VIEWTYPE_TREE and (Previous == nil or Previous == VIEWTYPE_TREE) then
			local Selected = Tree:GetSelectedItem()
			self:ResetNavigation(Selected and Selected.ParentNode)
		end

		local Selected = Tree:GetSelectedItem()
		if Selected and Settings.TallOfOneNode then
			self:ScrollTo(Selected)
		else
			Tree.VBar:SetScroll(0)
		end
	end

	function BROWSER:GetViewType()
		return self.TreeView.ViewType
	end

	local function FindFolderByPath(Node, Path)
		for _, Folder in ipairs(Node.Folders) do
			if Folder.Path == Path then return Folder end

			if Folder.Path and string.StartsWith(Path, Folder.Path .. "/") then
				if Folder.FirstObserved then
					Folder:FirstObserved()
					Folder.FirstObserved = nil
				end

				return FindFolderByPath(Folder, Path)
			end
		end
	end

	function BROWSER:FindFolderByPath(Path)
		return FindFolderByPath(self.TreeView, Path)
	end

	function BROWSER:GetCurrentFolder()
		return self.TreeView.CurrentFolder
	end

	function BROWSER:ResetNavigation(Folder)
		local Tree = self.TreeView
		table.Empty(Tree.BackHistory)
		table.Empty(Tree.ForwardHistory)

		if not Folder or not Folder:IsFolder() then
			Folder = #Tree.Folders == 1 and Tree.Folders[1] or Tree
		end

		Tree.CurrentFolder = Folder
		self:MarkSortDirty()
	end

	function BROWSER:NavigateTo(Folder, KeepHistory)
		local Tree = self.TreeView
		Folder = Folder or Tree
		if not Folder:IsFolder() or Folder == Tree.CurrentFolder then return end

		self:EndSearch()

		if Folder.FirstObserved then
			Folder:FirstObserved()
			Folder.FirstObserved = nil
		end

		if not KeepHistory then
			Tree.BackHistory[#Tree.BackHistory + 1] = Tree.CurrentFolder
			table.Empty(Tree.ForwardHistory)
		end

		Tree.CurrentFolder = Folder
		self:MarkSortDirty()
		Tree.VBar:SetScroll(0)
	end

	local function PopAttached(Tree, Stack)
		while #Stack > 0 do
			local Folder = table.remove(Stack)
			if IsAttached(Tree, Folder) then return Folder end
		end
	end

	function BROWSER:CanNavigateBack()    return #self.TreeView.BackHistory > 0    end
	function BROWSER:CanNavigateForward() return #self.TreeView.ForwardHistory > 0 end
	function BROWSER:CanNavigateUp()      return self.TreeView.CurrentFolder ~= self.TreeView end

	function BROWSER:NavigateBack()
		local Tree   = self.TreeView
		local Folder = PopAttached(Tree, Tree.BackHistory)
		if not Folder then return end

		Tree.ForwardHistory[#Tree.ForwardHistory + 1] = Tree.CurrentFolder
		self:NavigateTo(Folder, true)
	end

	function BROWSER:NavigateForward()
		local Tree   = self.TreeView
		local Folder = PopAttached(Tree, Tree.ForwardHistory)
		if not Folder then return end

		Tree.BackHistory[#Tree.BackHistory + 1] = Tree.CurrentFolder
		self:NavigateTo(Folder, true)
	end

	function BROWSER:NavigateUp()
		local Tree = self.TreeView
		if Tree.CurrentFolder == Tree then return end

		self:NavigateTo(Tree.CurrentFolder.ParentNode)
	end

	function BROWSER:KeepSelectedInPlace(Change)
		local Tree     = self.TreeView
		local Selected = Tree:GetSelectedItem()
		if not Selected then return Change() end

		Tree:SortRecheck()
		local OldIndex = Tree:GetNodeIndex(Selected)

		Change()
		if not OldIndex then return end

		Tree:SortRecheck()
		local NewIndex = Tree:GetNodeIndex(Selected)
		if not NewIndex then return end

		Tree.VBar:SetScroll(Tree.VBar:GetScroll() + (Tree:GetIndexY(NewIndex) - Tree:GetIndexY(OldIndex)))
	end

	function BROWSER:SetSortType(SortType)
		self:KeepSelectedInPlace(function()
			self.TreeView.SortType = SortType or error("No sorttype provided")
			self:MarkSortDirty()
		end)
	end

	function BROWSER:SetAscending(Ascending)
		self:KeepSelectedInPlace(function()
			self.TreeView.Ascending = Ascending == true
			self:MarkSortDirty()
		end)
	end

	function BROWSER:MarkSortDirty()
		if not self.TreeView then return end
		self.TreeView.SortDirty = true
	end

	-- Call this to enqueue a file callback, if you need one.
	-- The filepath should be unique.
	function BROWSER:AwaitingFile(Filepath, Callback)
		self.WaitingQueue = self.WaitingQueue or {}
		self.WaitingQueue[Filepath] = Callback
	end

	-- Call this to call any file callback with that name and remove it from the callback list.
	function BROWSER:IncomingFile(Filepath, ...)
		if not self.WaitingQueue then return end

		local Callback = self.WaitingQueue[Filepath]
		if not Callback then ErrorNoHalt("File Browser ['" .. self.Settings.Prefix .. "'] error: incoming file '" .. Filepath .. "' had no event handler.\n") return end

		self.WaitingQueue[Filepath] = nil
		return Callback(...)
	end

	function BROWSER:AddRootFolder(RootFolderType)
		RootFolderType = IRootFolder(RootFolderType or error("RootFolderType must contain a IRootFolder implementation")) -- This checks if the type implemented the interface
		local RealNode = self.TreeView:AddFolder(RootFolderType:GetFolderName())

		RealNode.Root     = RealNode
		RealNode.RootImpl = RootFolderType

		RootFolderType:Init(self, RealNode)

		return RealNode
	end

	function BROWSER:GetRootImpl(Node)
		return Node.Root.RootImpl or error "Cannot find IRootFolder implementation!"
	end

	local NotifIcons = {
		[NOTIFY_CLEANUP] = "bin",
		[NOTIFY_ERROR]   = "error",
		[NOTIFY_GENERIC] = "information",
		[NOTIFY_HINT]    = "lightbulb",
		[NOTIFY_UNDO]    = "arrow_undo",
	}

	function BROWSER:Notify(Message, Level, Time)
		Level = Level or NOTIFY_GENERIC
		Time  = Time or 5

		print("[" .. self.Settings.Prefix .. "] " .. tostring(Message))

		local Notif = self:PushUserPrompt()
		Notif:SetDock(TOP)

		local Text = Notif:Add("DLabel")
			Text:SetText(Message or "<nil>")
			Text:Dock(FILL)
			Text:SetContentAlignment(5)
			Text:SetDark(true)

		local Icon = Notif:Add("DImageButton")
			Icon:SetMouseInputEnabled(false) -- DImageButton provides SetStretchToFit while DImage doesn't - that's all we need here
			Icon:SetSize(20, 20)
			Icon:SetStretchToFit(false)
			Icon:SetKeepAspect(true)
			Icon:SetImage("icon16/" .. NotifIcons[Level] .. ".png")

		local OldLayout = Notif.Panel.PerformLayout
		function Notif.Panel:PerformLayout(W, H)
			OldLayout(self, W, H)
			local CW = Text:GetContentSize()
			Icon:SetPos((W / 2) - (CW / 2) - 12)
			Text:SetTextInset(12, 0)
		end
		-- bit too hacky?
		function Notif.Panel:ChildrenSize()
			return 0, 24
		end

		timer.Simple(Time, function() if IsValid(Notif.Panel) then Notif:Close() end end)
	end

	local History = {}

	local function AddHistory(Text)
		Text = string.lower(Text or "")
		if Text == "" or table.HasValue(History, Text) then return end

		History[#History + 1] = Text
		table.sort(History)
	end

	local function SetupNameEntry(Entry, NameFilter)
		local MenuKey      = string.lower(input.LookupBinding("menu") or "q")
		local PreviousText = Entry:GetText()
		local FirstChange  = true

		function Entry:OnChange()
			local Text = self:GetText()

			if FirstChange then
				FirstChange = false
				if string.lower(Text) == MenuKey then
					self:SetText(PreviousText)
					self:SelectAllText()
					return
				end
			end

			if NameFilter then
				local Filtered, Count = string.gsub(Text, NameFilter, "")
				if Count > 0 then
					self:SetText(Filtered)
					self:SetCaretPos(#Filtered)
				end
			end
		end

		function Entry:GetAutoComplete(Text)
			if Text == "" then return end
			Text = string.lower(Text)

			local Options = {}
			for _, Name in ipairs(History) do
				if Name ~= Text and string.sub(Name, 1, #Text) == Text then
					Options[#Options + 1] = Name
					if #Options >= 8 then break end
				end
			end

			return Options
		end
	end

	local function FollowSelection(Label, Tree, GetText)
		local LastText

		function Label:Think()
			DLabel.Think(self)

			local Text = GetText(Tree:GetSelectedItem())
			if Text ~= LastText then
				LastText = Text
				self:SetText(Text)
			end
		end
	end

	local function SharedFileFolderLogic(self, Node, DoDesc, NameTextPlaceholder, DescTextPlaceholder, Icon, Completed, LastName, LastDesc, NameFilter, PickFolder)
		local Prompt = self:PushUserPrompt()
		Prompt:SetBlocking(not PickFolder)
		Prompt:SetDock(BOTTOM)
		Prompt.Panel:DockPadding(4,4,4,4)

		if PickFolder then
			local function IsValidTarget(Target) return Target ~= nil and Target:IsFolder() end
			self:SetFolderPick(Prompt, IsValidTarget)

			local Where = Prompt:Add("DLabel")
				Where:Dock(TOP)
				Where:SetDark(true)
				Where:SetTall(18)

			FollowSelection(Where, self.TreeView, function(Target)
				if IsValidTarget(Target) then return "Save to " .. Target.Path end
				return "Select a folder to save to."
			end)
		end

		local Name, Desc, Cancel, Save

		local function FinishSave()
			-- Require filename
			local FileName = Name:GetText()
			if FileName == nil or FileName == "" then
				self:Notify("You must specify a file/folder path.", NOTIFY_ERROR, 2)
				return
			end

			local Target = Node
			if PickFolder then
				Target = self.TreeView:GetSelectedItem()
				if not Target or not Target:IsFolder() then
					self:Notify("You must select a folder.", NOTIFY_ERROR, 2)
					return
				end
			end

			local RootImpl = self:GetRootImpl(Target)
			if Completed(self, RootImpl, Target, FileName, Desc and Desc:GetText() or "") == false then return end

			AddHistory(FileName)
			Prompt:Close()
		end

		-- I tried SetTabPosition; it doesn't like to work, so we're doing it ourselves

		if DoDesc then
			Name = Prompt:Add("DTextEntry")
				Name:SetAllowNonAsciiCharacters(true)
				Name:SetTabbingDisabled(false)
				Name:Dock(TOP)
				Name:SetPlaceholderText(NameTextPlaceholder)
				Name:SetZPos(1)
				if LastName then Name:SetText(LastName) end

			local DescParent = Prompt:Add("Panel")
				DescParent:Dock(TOP)
				DescParent:DockMargin(0, 4, 0, 0)
				DescParent:SetSize(20, 20)
				DescParent:SetPaintBackgroundEnabled(false)
				DescParent:SetZPos(10000)

			Cancel = DescParent:Add("DImageButton")
				Cancel:Dock(RIGHT)
				Cancel:SetSize(20)
				Cancel:SetStretchToFit(false)
				Cancel:SetImage("icon16/cancel.png")

			Save = DescParent:Add("DImageButton")
				Save:Dock(RIGHT)
				Save:SetSize(24)
				Save:SetStretchToFit(false)
				Save:SetImage("icon16/" .. Icon .. ".png")

			Desc = DescParent:Add("DTextEntry")
				Desc:SetAllowNonAsciiCharacters(true)
				Desc:SetTabbingDisabled(false)
				Desc:Dock(FILL)
				Desc:SelectAllOnFocus()
				Desc:SetPlaceholderText(DescTextPlaceholder)
				if LastDesc then Desc:SetText(LastDesc) end
		else
			local DescParent = Prompt:Add("Panel")
				DescParent:Dock(TOP)
				DescParent:DockMargin(0, 4, 0, 0)
				DescParent:SetSize(20, 20)
				DescParent:SetPaintBackgroundEnabled(false)
				DescParent:SetZPos(10000)

			Cancel = DescParent:Add("DImageButton")
				Cancel:Dock(RIGHT)
				Cancel:SetSize(20)
				Cancel:SetStretchToFit(false)
				Cancel:SetImage("icon16/cancel.png")

			Save = DescParent:Add("DImageButton")
				Save:Dock(RIGHT)
				Save:SetSize(24)
				Save:SetStretchToFit(false)
				Save:SetImage("icon16/" .. Icon .. ".png")

			Name = DescParent:Add("DTextEntry")
				Name:SetAllowNonAsciiCharacters(true)
				Name:SetTabbingDisabled(false)
				Name:Dock(FILL)
				Name:SetPlaceholderText(NameTextPlaceholder)
				Name:SetZPos(1)
				if LastName then Name:SetText(LastName) end
		end

		SetupNameEntry(Name, NameFilter)

		function Name:OnEnter()
			self:KillFocus()
			if Desc then
				Desc:SelectAllOnFocus(true)
				Desc:OnMousePressed()
				Desc:RequestFocus()
			else
				FinishSave()
			end
		end

		if Desc then
			function Name:OnKeyCode(KeyCode)
				if KeyCode == KEY_TAB then
					return timer.Simple(0, function() if IsValid(self) then self:OnEnter() end end)
				end

				DTextEntry.OnKeyCode(self, KeyCode)
			end
		end

		function Name:OnMousePressed()
			self:OnGetFocus()
			self:SelectAllOnFocus(true)
		end

		if Desc then
			function Desc:OnEnter(_, WasTab)
				self:KillFocus()
				if WasTab then -- Wrap back to Name.
					Name:SelectAllOnFocus(true)
					Name:OnMousePressed()
					Name:RequestFocus()
				else
					FinishSave()
				end
			end
			function Desc:OnKeyCode(KeyCode)
				if KeyCode == KEY_TAB then
					return timer.Simple(0, function() if IsValid(self) then self:OnEnter(nil, true) end end)
				end

				DTextEntry.OnKeyCode(self, KeyCode)
			end
			function Desc:OnMousePressed()
				self:OnGetFocus()
				self:SelectAllOnFocus(true)
			end
		end

		function Save:DoClick()
			FinishSave()
		end
		function Cancel:DoClick()
			Prompt:Close()
		end

		Name:RequestFocus()
		Name:OnMousePressed()
	end

	function BROWSER:GetPlaceholderText(Node, Field, Default)
		return self:GetRootImpl(Node):GetPlaceholderText(Field) or Default
	end

	function BROWSER:StartSave(Node)
		if not Node:IsFolder() then ErrorNoHaltWithStack(self.Settings.Prefix .. ": Attempted to call StartSave on a non-folder. Operation canceled.") return false end

		local NamePlaceholder = self:GetPlaceholderText(Node, "SaveName", "File name")
		local DescPlaceholder = self:GetPlaceholderText(Node, "SaveDescription", "Description")
		local NameFilter      = self:GetRootImpl(Node):GetNameFilter()

		SharedFileFolderLogic(self, Node, true, NamePlaceholder, DescPlaceholder, "disk", function(_, RootImpl, _, FileName, Desc)
			RootImpl:UserSave(self, Node, FileName, Desc)
			self.LastFileName = FileName
			self.LastFileDesc = Desc
		end, self.LastFileName, self.LastFileDesc, NameFilter)
	end

	function BROWSER:IsSearching()
		return self.TreeView:IsSearching()
	end

	function BROWSER:EndSearch()
		if self.SearchPrompt then
			self.SearchPrompt:Close()
			self.SearchPrompt = nil
		end

		self.TreeView:EndSearch()
	end

	local function CreatePromptRow(Prompt)
		local Row = Prompt:Add("Panel")
			Row:Dock(TOP)
			Row:DockMargin(0, 4, 0, 0)
			Row:SetSize(20, 20)
			Row:SetPaintBackgroundEnabled(false)
			Row:SetZPos(10000)

		return Row
	end

	local function CreatePromptButton(Row, Icon, Size)
		local Button = Row:Add("DImageButton")
			Button:Dock(RIGHT)
			Button:SetSize(Size or 20)
			Button:SetStretchToFit(false)
			Button:SetImage("icon16/" .. Icon .. ".png")

		return Button
	end

	function BROWSER:ShowSearchResults(Count, Query)
		local Prompt = self:PushUserPrompt()
		Prompt:SetDock(BOTTOM)
		Prompt.Panel:DockPadding(4,4,4,4)
		self.SearchPrompt = Prompt

		local Row = CreatePromptRow(Prompt)

		local Return = CreatePromptButton(Row, "arrow_undo")
			Return:SetTooltip("Return to Browser")

		local Info = Row:Add("DLabel")
			Info:Dock(FILL)
			Info:SetDark(true)
			Info:SetText(Count .. " files found searching for \"" .. Query .. "\"")

		function Return.DoClick()
			self:EndSearch()
		end
	end

	local LastSearch = ""
	function BROWSER:StartSearch(Node)
		if not Node:IsFolder() then ErrorNoHaltWithStack(self.Settings.Prefix .. ": Attempted to call StartSearch on a non-folder. Operation canceled.") return false end

		self:EndSearch()

		local Prompt = self:PushUserPrompt()
		Prompt:SetDock(BOTTOM)
		Prompt.Panel:DockPadding(4,4,4,4)
		self.SearchPrompt = Prompt

		local Row    = CreatePromptRow(Prompt)
		local Cancel = CreatePromptButton(Row, "cancel")
		local Find   = CreatePromptButton(Row, "magnifier", 24)
			Find:SetTooltip("Search Files")

		local Search = Row:Add("DTextEntry")
			Search:SetAllowNonAsciiCharacters(true)
			Search:Dock(FILL)
			Search:SetPlaceholderText("Search...")
			Search:SetText(LastSearch)

		SetupNameEntry(Search)

		local function RunSearch()
			local Query = Search:GetText()
			LastSearch = Query
			AddHistory(Query)

			Prompt:Close()
			self.SearchPrompt = nil
			self:ShowSearchResults(self.TreeView:StartSearch(Node, Query), Query)
		end

		function Search:OnEnter()
			RunSearch()
		end

		function Search:OnMousePressed()
			self:OnGetFocus()
			self:SelectAllOnFocus(true)
		end

		function Find.DoClick()
			RunSearch()
		end

		function Cancel.DoClick()
			self:EndSearch()
		end

		Search:RequestFocus()
		Search:OnMousePressed()
	end

	function BROWSER:StartFolder(Node)
		if not Node:IsFolder() then ErrorNoHaltWithStack(self.Settings.Prefix .. ": Attempted to call StartFolder on a non-folder. Operation canceled.") return false end

		local NamePlaceholder = self:GetPlaceholderText(Node, "FolderName", "Folder name")
		local NameFilter      = self:GetRootImpl(Node):GetNameFilter()

		SharedFileFolderLogic(self, Node, false, NamePlaceholder, nil, "folder_add", function(_, RootImpl, _, FileName)
			local Success, Reason = RootImpl:UserMakeFolder(self, Node, FileName)
			if Success == false then
				self:Notify(Reason or "Could not create the folder.", NOTIFY_ERROR, 3)
				return false
			end
		end, nil, nil, NameFilter)
	end

	function BROWSER:StartRename(Node)
		local NameFilter = self:GetRootImpl(Node):GetNameFilter()

		SharedFileFolderLogic(self, Node, false, "New name", nil, "page_edit", function(_, RootImpl, _, FileName)
			if not RootImpl:UserRename(self, Node, FileName) then
				self:Notify("Rename failed.", NOTIFY_ERROR, 5)
				return false
			end

			self:Notify("File renamed to " .. Node.Text .. ".", NOTIFY_GENERIC, 3)
		end, Node.Text, nil, NameFilter)
	end

	function BROWSER:StartDelete(Node)
		local Prompt = self:PushUserPrompt()
		Prompt:SetBlocking(true)
		Prompt:SetDock(BOTTOM)
		Prompt.Panel:DockPadding(4,4,4,4)

		local DescParent = Prompt:Add("Panel")
			DescParent:Dock(TOP)
			DescParent:DockMargin(0, 4, 0, 0)
			DescParent:SetSize(20, 32)
			DescParent:SetPaintBackgroundEnabled(false)
			DescParent:SetZPos(10000)

		local Cancel = DescParent:Add("DImageButton")
			Cancel:Dock(RIGHT)
			Cancel:SetSize(20)
			Cancel:SetStretchToFit(false)
			Cancel:SetImage("icon16/cancel.png")

		local Delete = DescParent:Add("DImageButton")
			Delete:Dock(RIGHT)
			Delete:SetSize(24)
			Delete:SetStretchToFit(false)
			Delete:SetImage("icon16/bin.png")

		local Name = DescParent:Add("DLabel")
			Name:Dock(FILL)
			Name:SetDark(true)
			Name:SetText("Are you sure you want to delete\n" .. Node.Path .. "?")
			Name:SetAutoStretchVertical(true)
			Name:SetZPos(1)

		function Delete.DoClick()
			local RootImpl = self:GetRootImpl(Node)
			if RootImpl:UserDelete(self, Node) then
				self:Notify("Deleted " .. Node.Text .. ".", NOTIFY_CLEANUP, 5)
			else
				self:Notify("Delete failed.", NOTIFY_ERROR, 5)
			end
			Prompt:Close()
		end

		function Cancel:DoClick()
			Prompt:Close()
		end
	end

	function BROWSER:SetFolderPick(Prompt, Validate)
		local Tree = self.TreeView
		Tree.FolderPick = Validate

		Prompt.OnClose = function()
			if Tree.FolderPick == Validate then Tree.FolderPick = nil end
		end
	end

	function BROWSER:StartPickFolder(NamePlaceholder, DescPlaceholder, Icon, Callback, NameFilter)
		SharedFileFolderLogic(self, nil, true, NamePlaceholder, DescPlaceholder, Icon, function(_, _, Folder, FileName, Desc)
			Callback(Folder, FileName, Desc)
		end, nil, nil, NameFilter, true)
	end

	function BROWSER:StartMove(Node)
		if not Node:IsFile() then ErrorNoHaltWithStack(self.Settings.Prefix .. ": Attempted to call StartMove on a non-file. Operation canceled.") return false end

		local Prompt = self:PushUserPrompt()
		Prompt:SetDock(BOTTOM)
		Prompt.Panel:DockPadding(4,4,4,4)

		local DescParent = Prompt:Add("Panel")
			DescParent:Dock(TOP)
			DescParent:DockMargin(0, 4, 0, 0)
			DescParent:SetSize(20, 32)
			DescParent:SetPaintBackgroundEnabled(false)
			DescParent:SetZPos(10000)

		local Cancel = DescParent:Add("DImageButton")
			Cancel:Dock(RIGHT)
			Cancel:SetSize(20)
			Cancel:SetStretchToFit(false)
			Cancel:SetImage("icon16/cancel.png")

		local Move = DescParent:Add("DImageButton")
			Move:Dock(RIGHT)
			Move:SetSize(24)
			Move:SetStretchToFit(false)
			Move:SetImage("icon16/page_paste.png")

		local function IsValidTarget(Target)
			return Target ~= nil and Target:IsFolder() and Target.Root == Node.Root and Target ~= Node.ParentNode
		end
		self:SetFolderPick(Prompt, IsValidTarget)

		local Name = DescParent:Add("DLabel")
			Name:Dock(FILL)
			Name:SetDark(true)
			Name:SetAutoStretchVertical(true)
			Name:SetZPos(1)

		FollowSelection(Name, self.TreeView, function(Target)
			if IsValidTarget(Target) then return "Move \"" .. Node.Text .. "\" to\n" .. Target.Path end
			return "Select the folder you want to move\n" .. Node.Text .. " to."
		end)

		function Move.DoClick()
			local Target = self.TreeView:GetSelectedItem()
			if not Target or Target == Node then
				self:Notify("Select a folder to move the file to.", NOTIFY_ERROR, 3)
				return
			end

			if not Target:IsFolder() then
				self:Notify("You must select a folder as a destination.", NOTIFY_ERROR, 3)
				return
			end

			if Target.Root ~= Node.Root or Target == Node.ParentNode then
				self:Notify("Cannot move files between these directories.", NOTIFY_ERROR, 3)
				return
			end

			if not self:GetRootImpl(Node):UserMove(self, Node, Target) then
				self:Notify("Move failed.", NOTIFY_ERROR, 5)
				return
			end

			Prompt:Close()
		end

		function Cancel:DoClick()
			Prompt:Close()
		end
	end

	function BROWSER:GetUserPromptStack()
		local UserPrompts = self.UserPrompts

		if not UserPrompts then
			UserPrompts = {}
			self.UserPrompts = UserPrompts
		end

		return UserPrompts
	end

	-- Returns the index you should use for the stack.
	function BROWSER:IncrementUserPromptStackPtr()
		local StackPtr = self.UserPromptStackPtr
		if not StackPtr then StackPtr = 0 self.UserPromptStackPtr = StackPtr end

		StackPtr = StackPtr + 1
		self.UserPromptStackPtr = StackPtr

		return StackPtr
	end

	-- Returns the index to remove from the stack.
	function BROWSER:DecrementUserPromptStackPtr()
		local StackPtr = self.UserPromptStackPtr
		if not StackPtr then StackPtr = 0 self.UserPromptStackPtr = StackPtr end

		StackPtr = StackPtr - 1
		if StackPtr < 0 then ErrorNoHaltWithStack(self.Settings.Prefix .. ": User prompt stack underflow???") StackPtr = 0 end
		self.UserPromptStackPtr = StackPtr

		return StackPtr + 1 -- +1 because we want to remove what was previously at that stack pointer
	end

	function BROWSER:GetUserPromptStackLength()
		return self.UserPromptStackPtr or 0
	end

	function BROWSER:PushUserPrompt()
		local UserPrompts  = self:GetUserPromptStack()
		local StackPointer = self:IncrementUserPromptStackPtr()
		local Prompt = USERPROMPT(self)
		UserPrompts[StackPointer] = Prompt
		return Prompt
	end

	function BROWSER:PopUserPrompt()
		local UserPrompts  = self:GetUserPromptStack()
		local StackPointer = self:DecrementUserPromptStackPtr()
		local Prompt       = UserPrompts[StackPointer]
		UserPrompts[StackPointer] = nil
		return Prompt
	end

	function BROWSER:PopUserPromptByValue(UserPrompt)
		if table.RemoveByValue(self:GetUserPromptStack(), UserPrompt) then
			if IsValid(UserPrompt.Panel) then UserPrompt.Panel:Remove() end
			self:DecrementUserPromptStackPtr()
		end
	end

	function BROWSER:ClearAllUserPrompts()
		for _, Prompt in ipairs(self:GetUserPromptStack()) do
			Prompt:Close()
		end
	end

	local WORLD  = Material("icon16/world.png", "smooth")
	local FOLDER = Material("icon16/folder.png", "smooth")
	local PAGE   = Material("icon16/page.png", "smooth")

	function BROWSER:ShowSavePrompt()
		if self.BrowserWait then return end

		local BrowserWait = self:PushUserPrompt()
		self.BrowserWait = BrowserWait

		BrowserWait:SetDock(FILL)
		BrowserWait.Panel.ChildrenSize = function(notif)
			local Parent = notif:GetParent()
			local W, _ = Parent:GetSize()
			return W / 1.5, 128
		end
		BrowserWait:SetBlocking(true)
		BrowserWait.Panel:SetPaintBackground(true)

		local Text = BrowserWait.Panel:Add("DLabel")
		Text:SetText("Downloading...")
		Text:Dock(TOP)
		Text:SetTextInset(0, 6)
		Text:SetDark(true)
		Text:SetContentAlignment(8)

		function BrowserWait.Panel:Paint(w, h)
			DPanel.Paint(self, w, h)
			local AnimTime = 1.5
			local Time = (UserInterfaceTimeFunc() % AnimTime) / AnimTime
			local SinTime = math.sin(Time * math.pi)
			local Size = math.ease.OutQuad(SinTime) * 32

			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(WORLD)  surface.DrawTexturedRectRotated(24, h / 2, 32, 32, 0)
			surface.SetMaterial(FOLDER) surface.DrawTexturedRectRotated(w - 24, h / 2, 32, 32, 0)
			surface.SetMaterial(PAGE)   surface.DrawTexturedRectRotated(math.Remap(Time, 0, 1, 24, w - 24), math.Remap(SinTime, 0, 1, h / 2, h / 3), Size, Size, 0)
		end
	end

	function BROWSER:HideSavePrompt()
		if not self.BrowserWait then return end
		self.BrowserWait:Close()
		self.BrowserWait = nil
	end

	-- Sets input enabled on user prompt stack and determines if user input should be enabled/disabled on the main browser
	-- Returns true if input is enabled
	-- This stuff is kinda weird, but doesnt run that much and seems to be pretty OK. Real docking seems to cause
	-- layout issues that I would rather not deal with, especially during animation.
	function BROWSER:ThinkAboutUserPrompts()
		local StackDocks     = self.StackDocks or {}
		StackDocks[TOP] = 0
		StackDocks[LEFT] = 0
		StackDocks[RIGHT] = 0
		StackDocks[BOTTOM] = 0

		local UserPrompts    = self:GetUserPromptStack()
		local Blocking       = false

		local LastBlockingPanel = false

		local RemoveValues
		for K, Prompt in ipairs(UserPrompts) do
			local Panel = Prompt:GetPanel()
			Panel:SetMouseInputEnabled(LastBlockingPanel and false or true)

			Panel:SetZPos(1000 + K)
			Blocking = Blocking or Prompt.Blocking

			if Prompt.Blocking then
				LastBlockingPanel = Panel
			else
				LastBlockingPanel = false
			end

			if not Prompt:DoThink() then
				RemoveValues = RemoveValues or {} -- Only allocate this table if we need to remove prompts
				RemoveValues[#RemoveValues + 1] = Prompt
			end
		end

		local DockPadding = 4

		for I = #UserPrompts, 1, -1 do
			local Prompt = UserPrompts[I]
			if Prompt and IsValid(Prompt.Panel) then
				local Panel = Prompt.Panel

				local X, Y = Panel:GetPos()
				local W, H = Panel:GetSize()
				local Dock = Prompt.Dock

				if Dock ~= NODOCK and Dock ~= FILL then
					if Dock == TOP or Dock == BOTTOM then
						Y = Y + StackDocks[Dock]
						StackDocks[Dock] = StackDocks[Dock] + H + DockPadding
					else
						X = X + StackDocks[Dock]
						StackDocks[Dock] = StackDocks[Dock] + W + DockPadding
					end
				end

				Panel:SetPos(X, Y)
			end
		end

		if RemoveValues then
			for _, Prompt in ipairs(RemoveValues) do
				self:PopUserPromptByValue(Prompt)
			end
		end

		return not Blocking
	end

	function BROWSER:ScrollTo(Node)
		self.TreeView:SortRecheck()
		local Index = self.TreeView:GetNodeIndex(Node)
		if not Index then return end

		local ScrollPos = math.Max(0, self.TreeView:GetIndexY(Index) - (self:GetTall() / 2))
		self.TreeView.VBar:SetScroll(ScrollPos)
	end

	function BROWSER:Think()
		local CanInput = self:ThinkAboutUserPrompts()
		self.TreeView:SetMouseInputEnabled(CanInput)
	end

	FileBrowser.BrowserTable = vgui.RegisterTable(BROWSER, "Panel")
end

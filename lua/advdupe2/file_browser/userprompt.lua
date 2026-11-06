return function(FileBrowser)
	local UserInterfaceTimeFunc = FileBrowser.UserInterfaceTimeFunc

	-- This is a user prompt class, see Browser's UserPrompt stack methods

	local USERPROMPT_MT = {}
	local USERPROMPT    = setmetatable({}, USERPROMPT_MT)

	do
		function USERPROMPT:Init(Browser)
			local Settings = Browser.Settings
			self.Browser  = Browser
			self.Blocking = false

			self.StartOpen  = UserInterfaceTimeFunc()
			self.WillOpenAt = self.StartOpen + Settings.PromptOpenTime

			self.Panel = Browser:Add("DScrollPanel")
			local PanelColor = Color(255, 255, 255, 213)
			self.Panel.Paint = function(panel, w, h)
				local Skin = panel:GetSkin()
				local SkinTex = Skin.tex

				SkinTex.Panels.Normal(0, 0, w, h, PanelColor)
			end
		end

		function USERPROMPT:GetPanel() return self.Panel end

		function USERPROMPT:Add(Type)
			return self.Panel:Add(Type)
		end

		function USERPROMPT_MT:__call(Browser)
			if not IsValid(Browser) then return error ("Cannot create a headless node (we need a browser)") end

			local Node   = setmetatable({}, {__index = USERPROMPT})
			Node:Init(Browser)

			return Node
		end

		function USERPROMPT:GetBlocking() return self.Blocking or false end
		function USERPROMPT:SetBlocking(Blocking) self.Blocking = Blocking and true or false end

		function USERPROMPT:Destroy()
			if IsValid(self.Panel) then
				self.Panel:Remove()
			end
		end

		function USERPROMPT:SetDock(Dock)
			self.Dock = Dock
		end

		local function Normalize(X, Min, Max)
			return math.Clamp((X - Min) / (Max - Min), 0, 1)
		end

		function USERPROMPT:GetAnimationRatio(Now)
			local Closing = self.Closing

			local OpenRatio  = Normalize(Now, self.StartOpen, self.WillOpenAt)
			local CloseRatio = Closing and (1 - Normalize(Now, self.StartClose, self.WillCloseAt)) or 1

			local OpenX,  OpenY,  OpenA  = math.ease.OutQuad(OpenRatio),  math.ease.OutBack(OpenRatio), math.ease.OutQuad(OpenRatio)
			local CloseX, CloseY, CloseA = math.ease.OutQuad(CloseRatio), math.ease.OutBack(CloseRatio), math.ease.InQuart(CloseRatio)

			-- We return opening animation * closing animation to get smooth effects
			-- This works because CloseRatio will be a downward value while OpenRatio will be an upward value 
			return OpenX * CloseX, OpenY * CloseY, OpenA * CloseA
		end

		local DockPadding = 4

		function USERPROMPT:DoThink()
			local Now       = UserInterfaceTimeFunc()
			local Closing   = self.Closing

			if Closing and Now >= self.WillCloseAt then
				return false
			end

			local RatioX, RatioY, RatioA    = self:GetAnimationRatio(Now)
			local Browser                   = self.Browser
			local ParentWidth, ParentHeight = Browser:GetWide(), Browser:GetTall()

			local PosX,  PosY
			local SizeW, SizeH

			local ContentWide, ContentTall = self.Panel:ChildrenSize()
			ContentTall = math.Min(ContentTall, self.Browser:GetTall() - 32)
			local Dock = self.Dock
			if not Dock then error("No dock??") end

			if Dock == TOP then
				SizeW = math.ceil((RatioX * ParentWidth) - (DockPadding * 2))
				SizeH = math.ceil(ContentTall * RatioY)
				PosX  = ((ParentWidth / 2) - (SizeW / 2))
				PosY  = DockPadding
			elseif Dock == BOTTOM then
				SizeW = math.ceil((RatioX * ParentWidth) - (DockPadding * 2))
				SizeH = math.ceil(ContentTall * RatioY)
				PosX  = ((ParentWidth / 2) - (SizeW / 2))
				PosY  = ParentHeight - SizeH - DockPadding
			elseif Dock == FILL then
				SizeW = math.ceil((RatioX * ContentWide) - (DockPadding * 2))
				SizeH = math.ceil(ContentTall * RatioY)
				PosX  = ((ParentWidth / 2) - (SizeW / 2))
				PosY  = (ParentHeight / 2) - (SizeH / 2) - (DockPadding / 2)
			end

			self.Panel:SetPos(PosX, PosY)
			self.Panel:SetSize(SizeW, SizeH)
			self.Panel:SetAlpha(RatioA * 255)

			return true
		end

		-- Call this to close and pop later.
		-- This also forces Blocking back to false for main UI panel.
		function USERPROMPT:Close()
			local Settings = self.Browser.Settings
			if self.OnClose and not self.Closing then self:OnClose() end

			self.Blocking    = false
			self.Closing     = true
			self.StartClose  = UserInterfaceTimeFunc()
			self.WillCloseAt = self.StartClose + Settings.PromptCloseTime
		end
	end

	FileBrowser.USERPROMPT = USERPROMPT
end

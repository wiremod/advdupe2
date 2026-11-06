return function(FileBrowser)
	local SampleSize        = 16
	local HoverContrast     = 0.06
	local SelectedContrast  = 0.12
	local TextContrast      = 0.4
	local SampleTarget

	local Samples    = setmetatable({}, {__mode = "k"})
	local Pending    = {}
	local TextColors = setmetatable({}, {__mode = "k"})
	local HookName   = "FileBrowser_SampleSkins_" .. tostring(Pending)

	local function GetSkinTextColor(Skin, Alpha)
		local Cache = TextColors[Skin]
		if not Cache then
			Cache = {}
			TextColors[Skin] = Cache
		end

		local Col = Cache[Alpha]
		if not Col then
			local Base = Skin.colTextEntryText or color_black
			Col = Color(Base.r, Base.g, Base.b, Alpha)
			Cache[Alpha] = Col
		end

		return Col
	end

	local function GetFallbackPanelColor(Skin, Kind)
		local Normal = Skin.bg_color or Color(101, 100, 105)

		if Kind == "Dark" then return Skin.bg_color_dark or Color(Normal.r * 0.7, Normal.g * 0.7, Normal.b * 0.7) end
		if Kind == "Highlight" then return Skin.listview_selected or Skin.combobox_selected or Color(100, 170, 220) end

		return Normal
	end

	local function DrawSkinPanel(Skin, Kind, X, Y, W, H)
		local Sample  = Samples[Skin]
		local Missing = Sample and Sample.Missing[Kind]
		local Tex     = Skin.tex
		local Draw    = not Missing and Tex and Tex.Panels and Tex.Panels[Kind]
		if Draw then return Draw(X, Y, W, H, color_white) end

		surface.SetDrawColor(GetFallbackPanelColor(Skin, Kind))
		surface.DrawRect(X, Y, W, H)
	end

	local function DrawSkinExpander(Skin, Expanded, X, Y, W, H)
		local Tex  = Skin.tex
		local Draw = Tex and (Expanded and Tex.TreeMinus or Tex.TreePlus)
		if Draw then return Draw(X, Y, W, H) end

		local CenterX, CenterY = math.floor(X + (W / 2)), math.floor(Y + (H / 2))
		surface.SetDrawColor(GetSkinTextColor(Skin, 200))
		surface.DrawOutlinedRect(X + 2, Y + 2, W - 4, H - 4)
		surface.DrawRect(CenterX - 3, CenterY, 7, 1)
		if not Expanded then
			surface.DrawRect(CenterX, CenterY - 3, 1, 7)
		end
	end

	local function Luminance(Col)
		return ((0.2126 * Col.r) + (0.7152 * Col.g) + (0.0722 * Col.b)) / 255
	end

	local function IsMissingTexturePixel(R, G, B)
		return R > 200 and G < 60 and B > 200
	end

	local function SampleTexture(Draw)
		render.PushRenderTarget(SampleTarget)
		render.Clear(0, 0, 0, 255, true, true)
		cam.Start2D()
			Draw(0, 0, SampleSize, SampleSize)
		cam.End2D()
		render.CapturePixels()

		local Missing = false
		for _, Point in ipairs({{4, 4}, {12, 4}, {4, 12}, {12, 12}}) do
			if IsMissingTexturePixel(render.ReadPixel(Point[1], Point[2])) then Missing = true end
		end

		local R, G, B = render.ReadPixel(SampleSize / 2, SampleSize / 2)
		render.PopRenderTarget()

		return Color(R, G, B), Missing or IsMissingTexturePixel(R, G, B)
	end

	local function IsAcceptable(Base, Target)
		return math.abs(Luminance(Target) - Luminance(Base)) >= HoverContrast
	end

	local function GetOverlay(Base, Target, Contrast)
		local BaseLum, TargetLum = Luminance(Base), Luminance(Target)
		local CanLighten = BaseLum + Contrast <= 1
		local CanDarken  = BaseLum - Contrast >= 0

		if CanLighten and (TargetLum >= BaseLum or not CanDarken) then
			local Want = BaseLum + Contrast
			if TargetLum >= Want then return end

			return Color(255, 255, 255, math.Clamp((Want - TargetLum) / (1 - TargetLum), 0, 1) * 255)
		end

		if CanDarken then
			local Want = BaseLum - Contrast
			if TargetLum <= Want then return end

			return Color(0, 0, 0, math.Clamp(1 - (Want / TargetLum), 0, 1) * 255)
		end
	end

	local function Blend(Base, Overlay)
		if not Overlay then return Base end

		local A = Overlay.a / 255
		return Color(
			(Base.r * (1 - A)) + (Overlay.r * A),
			(Base.g * (1 - A)) + (Overlay.g * A),
			(Base.b * (1 - A)) + (Overlay.b * A)
		)
	end

	local function PickTextColor(Skin, Background)
		local BackgroundLum = Luminance(Background)
		local Colours       = istable(Skin.Colours) and Skin.Colours or {}
		local Tree          = istable(Colours.Tree) and Colours.Tree or {}
		local Label         = istable(Colours.Label) and Colours.Label or {}

		for _, Col in ipairs({Tree.Normal, Skin.colTextEntryText, Label.Dark, Label.Default, Label.Bright}) do
			if istable(Col) and isnumber(Col.r) and math.abs(Luminance(Col) - BackgroundLum) >= TextContrast then
				return Col
			end
		end

		return BackgroundLum > 0.5 and color_black or color_white
	end

	local function SampleSkin(Skin)
		SampleTarget = SampleTarget or GetRenderTarget("FileBrowser_SkinSample", SampleSize, SampleSize)

		local Sample = {Missing = {}}
		Samples[Skin] = Sample

		for _, Kind in ipairs({"Normal", "Bright", "Highlight", "Dark"}) do
			local Col, Missing = SampleTexture(function(X, Y, W, H) DrawSkinPanel(Skin, Kind, X, Y, W, H) end)
			if Missing then
				Sample.Missing[Kind] = true
				Col = SampleTexture(function(X, Y, W, H) DrawSkinPanel(Skin, Kind, X, Y, W, H) end)
			end

			Sample[Kind] = Col
		end

		if not IsAcceptable(Sample.Normal, Sample.Bright) then
			Sample.HoverOverlay    = GetOverlay(Sample.Normal, Sample.Bright, HoverContrast)
			Sample.SelectedOverlay = GetOverlay(Sample.Normal, Sample.Bright, SelectedContrast)
		end

		if not IsAcceptable(Sample.Normal, Sample.Highlight) then
			Sample.HighlightOverlay = GetOverlay(Sample.Normal, Sample.Highlight, SelectedContrast)
		end

		Sample.Text = {
			Normal   = PickTextColor(Skin, Sample.Normal),
			Hovered  = PickTextColor(Skin, Blend(Sample.Bright, Sample.HoverOverlay)),
			Selected = PickTextColor(Skin, Blend(Sample.Bright, Sample.SelectedOverlay)),
			Target   = PickTextColor(Skin, Blend(Sample.Highlight, Sample.HighlightOverlay)),
			Dark     = PickTextColor(Skin, Sample.Dark),
		}

		return Sample
	end

	local function SamplePending()
		for Skin in pairs(Pending) do
			local Ok, Sample = pcall(SampleSkin, Skin)
			Samples[Skin] = Ok and Sample or false
			Pending[Skin] = nil
		end

		hook.Remove("PostRenderVGUI", HookName)
	end

	local function GetSkinSample(Skin)
		local Sample = Samples[Skin]
		if Sample ~= nil then return Sample or nil end

		if not Pending[Skin] then
			Pending[Skin] = true
			hook.Add("PostRenderVGUI", HookName, SamplePending)
		end
	end

	local StatePanels   = {Normal = "Normal", Hovered = "Bright", Selected = "Bright", Target = "Highlight", Dark = "Dark"}
	local StateOverlays = {Hovered = "HoverOverlay", Selected = "SelectedOverlay", Target = "HighlightOverlay"}

	local function GetStateTextColor(Skin, State)
		local Sample = GetSkinSample(Skin)
		return Sample and Sample.Text and Sample.Text[State] or GetSkinTextColor(Skin, 255)
	end

	local function DrawSkinState(Skin, State, X, Y, W, H)
		DrawSkinPanel(Skin, StatePanels[State], X, Y, W, H)

		local Sample  = GetSkinSample(Skin)
		local Overlay = Sample and StateOverlays[State] and Sample[StateOverlays[State]]
		if Overlay then
			surface.SetDrawColor(Overlay)
			surface.DrawRect(X, Y, W, H)
		end

		return GetStateTextColor(Skin, State)
	end

	FileBrowser.DrawSkinState     = DrawSkinState
	FileBrowser.GetSkinSample     = GetSkinSample
	FileBrowser.GetSkinTextColor  = GetSkinTextColor
	FileBrowser.GetStateTextColor = GetStateTextColor
	FileBrowser.DrawSkinPanel     = DrawSkinPanel
	FileBrowser.DrawSkinExpander  = DrawSkinExpander
end

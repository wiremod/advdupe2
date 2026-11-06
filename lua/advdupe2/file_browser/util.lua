return function(FileBrowser)
	-- Enums
	-- These are internal really, so i don't think these need to be exposed?
	local NODETYPE_FOLDER          = 1
	local NODETYPE_FILE            = 2
	-- I may implement more of these later, just defining them now
	local VIEWTYPE_TREE  = 0
	local VIEWTYPE_LIST  = 1
	local VIEWTYPE_TILES = 2

	local SORTTYPE_NAME = 0
	local SORTTYPE_TIME = 1
	local SORTTYPE_SIZE = 2

	local UserInterfaceTimeFunc  =   RealTime

	local function GetNodeBounds(Settings, ScrollOffset, AbsIndex, Width, Depth)
		return
				Depth * Settings.NodeDepthWidth,
				(Settings.TallOfOneNode * (AbsIndex - 1)) - ScrollOffset,
				Width - (Depth * Settings.NodeDepthWidth),
				Settings.NodeTall
	end

	local function GetExpanderBounds(Settings, X, Y, W, H, Padding, Depth)
		Padding = Padding or 0
		local Size = Settings.ExpanderSize + Padding

		return (Depth * Settings.NodeDepthWidth) + (X + Settings.ExpanderXOffset) - (Padding / 2), ((Y + (H / 2)) - (Size / 2)) + 1, Size, Size
	end

	local function GetIconBounds(Settings, X, Y, W, H, Padding, Depth)
		local Size = Settings.IconSize + (Padding or 0)

		return (Depth * Settings.NodeDepthWidth) + X + Settings.IconXOffset, (Y + (H / 2)) - (Size / 2), Size, Size
	end

	local function GetTextPosition(Settings, X, Y, W, H, Depth)
		return (Depth * Settings.NodeDepthWidth) + X + Settings.TextXOffset, Y + (H / 2)
	end

	local ListTimeWidth, ListSizeWidth = 116, 72
	local ListHeaderTall, NavBarTall   = 20, 24

	local function GetListColumns(Width)
		local SizeRight = Width - 6
		local TimeRight = SizeRight - ListSizeWidth
		local NameRight = TimeRight - ListTimeWidth
		return NameRight, TimeRight, SizeRight
	end

	local function GetListTextX(Settings)
		return Settings.LeftmostToExpanderPadding + Settings.IconSize + Settings.IconToTextPadding
	end

	local TruncatedText, TruncatedCount = {}, 0
	local function TruncateText(Text, Font, MaxWidth)
		local Key    = Font .. "\0" .. math.floor(MaxWidth) .. "\0" .. Text
		local Cached = TruncatedText[Key]
		if Cached then return Cached end

		surface.SetFont(Font)
		local Result = Text
		if surface.GetTextSize(Text) > MaxWidth then
			local Starts = {}
			for Position in string.gmatch(Text, "()" .. utf8.charpattern) do
				Starts[#Starts + 1] = Position
			end

			Result = "..."
			for Count = #Starts - 1, 1, -1 do
				local Candidate = string.sub(Text, 1, Starts[Count + 1] - 1) .. "..."
				if surface.GetTextSize(Candidate) <= MaxWidth then
					Result = Candidate
					break
				end
			end
		end

		if TruncatedCount > 4096 then
			TruncatedText, TruncatedCount = {}, 0
		end
		TruncatedText[Key] = Result
		TruncatedCount = TruncatedCount + 1
		return Result
	end

	-- Defines GetNumericalFilename
	-- May need optimization and refactoring later - especially for non-ASCII strings...
	-- This handles things very similarly to how Windows does in terms of sorting, but also adds sorting by month
	-- May also be a good idea in the future to add a setting for the above functionality.
	local GetNumericalFilename
	do
		local isDigit = {
			['0'] = 0,
			['1'] = 1,
			['2'] = 2,
			['3'] = 3,
			['4'] = 4,
			['5'] = 5,
			['6'] = 6,
			['7'] = 7,
			['8'] = 8,
			['9'] = 9
		}

		-- faster than string.byte calls
		local char2byte = {}
		for i = 1, 255 do char2byte[string.char(i)] = string.byte(string.lower(string.char(i))) end
		char2byte['_'] = 2000

		local buildMonth = {}
		for k, v in ipairs{"january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"} do
			local tbl = buildMonth
			for i = 1, #v do
				local c = v[i]
				if i == #v then
					tbl[c] = k
				else
					if not tbl[c] then
						tbl[c] = {}
					end

					tbl = tbl[c]
				end
			end
		end

		local numericalStore = {}
		function GetNumericalFilename(name)
			if numericalStore[name] then return numericalStore[name] end

			local ret = {}
			local digit = nil
			local monthTester = buildMonth
			local monthStoreJustInCase = {}

			local function testMonth(i, c)
				monthTester = monthTester[c]
				monthStoreJustInCase[#monthStoreJustInCase + 1] = char2byte[c]
				if type(monthTester) == "number" then
					local nextC = name[i + 1]
					local nextIfine = nextC == ' ' or nextC == '_' or nextC == '-'
					if i == #name or nextIfine then
						ret[#ret + 1] = monthTester
						monthStoreJustInCase = {}
						monthTester = buildMonth
						if nextIfine then
							i = i + 1
						end
					else
						for i2 = 1, #monthStoreJustInCase do
							ret[#ret + 1] = monthStoreJustInCase[i2]
						end
						monthStoreJustInCase = {}
						monthTester = buildMonth
					end
				end
			end

			local function finalTest(i, c)
				if monthTester ~= buildMonth then
					for i2 = 1, #monthStoreJustInCase do
						ret[#ret + 1] = monthStoreJustInCase[i2]
					end
					monthStoreJustInCase = {}
					monthTester = buildMonth
				end
				ret[#ret + 1] = char2byte[c]
			end

			for i = 1, #name do
				local c = name[i]
				local cIsDigit = isDigit[c]
				if cIsDigit then
					if digit == nil then
						digit = 0
					end
					digit = (digit * 10) + cIsDigit
				else
					if monthTester[c] then
						testMonth(i, c)
					elseif digit ~= nil then
						ret[#ret + 1] = digit - (#ret == 0 and 100000000 or 0)
						digit = nil
					else
						finalTest(i, c)
					end
				end
			end

			if digit ~= nil then
				ret[#ret + 1] = digit - (#ret == 0 and 100000000 or 0)
			end
			if monthTester ~= buildMonth then
				for i = 1, #monthStoreJustInCase do
					ret[#ret + 1] = monthStoreJustInCase[i]
				end
			end

			numericalStore[name] = ret -- store so this doesnt have to be calculated multiple times for no reason
			return ret
		end
	end

	FileBrowser.NODETYPE_FOLDER       = NODETYPE_FOLDER
	FileBrowser.NODETYPE_FILE         = NODETYPE_FILE
	FileBrowser.VIEWTYPE_TREE         = VIEWTYPE_TREE
	FileBrowser.VIEWTYPE_LIST         = VIEWTYPE_LIST
	FileBrowser.VIEWTYPE_TILES        = VIEWTYPE_TILES
	FileBrowser.SORTTYPE_NAME         = SORTTYPE_NAME
	FileBrowser.SORTTYPE_TIME         = SORTTYPE_TIME
	FileBrowser.SORTTYPE_SIZE         = SORTTYPE_SIZE
	FileBrowser.UserInterfaceTimeFunc = UserInterfaceTimeFunc
	FileBrowser.GetNodeBounds         = GetNodeBounds
	FileBrowser.GetExpanderBounds     = GetExpanderBounds
	FileBrowser.GetIconBounds         = GetIconBounds
	FileBrowser.GetTextPosition       = GetTextPosition
	FileBrowser.ListTimeWidth         = ListTimeWidth
	FileBrowser.ListSizeWidth         = ListSizeWidth
	FileBrowser.ListHeaderTall        = ListHeaderTall
	FileBrowser.NavBarTall            = NavBarTall
	FileBrowser.GetListColumns        = GetListColumns
	FileBrowser.GetListTextX          = GetListTextX
	FileBrowser.TruncateText          = TruncateText
	FileBrowser.GetNumericalFilename  = GetNumericalFilename
end

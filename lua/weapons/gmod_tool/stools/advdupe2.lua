--[[
	Title: Adv. Dupe 2 Tool

	Desc: Defines the AD2 tool and assorted functionalities.

	Author: TB

	Version: 1.0
]]

TOOL.Category = "Construction"
TOOL.Name = "#Tool.advdupe2.name"
cleanup.Register( "AdvDupe2" )
require( "controlpanel" )

if(SERVER) then
	CreateConVar("sbox_maxgmod_contr_spawners",5)

	local phys_constraint_system_types = {
		Weld          = true,
		Rope          = true,
		Elastic       = true,
		Slider        = true,
		Axis          = true,
		AdvBallsocket = true,
		Motor         = true,
		Pulley        = true,
		Ballsocket    = true,
		Winch         = true,
		Hydraulic     = true,
		WireMotor     = true,
		WireHydraulic = true
	}
	--Orders constraints so that the dupe uses as little constraint systems as possible
	local function GroupConstraintOrder( ply, constraints )
		--First separate the nocollides, sorted, and unsorted constraints
		local sorted, unsorted = {}, {}
		for k, v in pairs(constraints) do
			if phys_constraint_system_types[v.Type] then
				sorted[#sorted+1] = v
			else
				unsorted[#unsorted+1] = v
			end
		end

		local sortingSystems = {}
		local fullSystems = {}
		local function buildSystems(input)
			while next(input) ~= nil do
				for k, v in pairs(input) do
					for systemi, system in pairs(sortingSystems) do
						for _, target in pairs(system) do
							for x = 1, 4 do
								if v.Entity[x] then
									for y = 1, 4 do
										if target.Entity[y] and v.Entity[x].Index == target.Entity[y].Index then
											system[#system + 1] = v
											if #system == 100 then
												fullSystems[#fullSystems + 1] = system
												table.remove(sortingSystems, systemi)
											end
											input[k] = nil
											goto super_loopbreak
										end
									end
								end
							end
						end
					end
				end

				--Normally skipped by the goto unless no cluster is found. If so, make a new one.
				local k = next(input)
				sortingSystems[#sortingSystems + 1] = {input[k]}
				input[k] = nil

				::super_loopbreak::
			end
		end
		buildSystems(sorted)

		local ret = {}
		for _, system in pairs(fullSystems) do
			for _, v in pairs(system) do
				ret[#ret + 1] = v
			end
		end
		for _, system in pairs(sortingSystems) do
			for _, v in pairs(system) do
				ret[#ret + 1] = v
			end
		end
		for k, v in pairs(unsorted) do
			ret[#ret + 1] = v
		end

		if #fullSystems ~= 0 then
			ply:ChatPrint("DUPLICATOR: WARNING, Number of constraints exceeds 100: (".. #ret .."). Constraint sorting might not work as expected.")
		end

		return ret
	end

	local function CreationConstraintOrder( constraints )
		local ret = {}
		for k, v in pairs( constraints ) do
			ret[#ret + 1] = k
		end
		table.sort(ret)
		for i = 1, #ret do
			ret[i] = constraints[ret[i]]
		end
		return ret
	end

	local function GetSortedConstraints( ply, constraints )
		if ply:GetInfo("advdupe2_sort_constraints") ~= "0" then
			return GroupConstraintOrder( ply, constraints )
		else
			return CreationConstraintOrder( constraints )
		end
	end

	local areacopy_classblacklist = {
		gmod_anchor = true
	}

	local function PlayerCanDupeCPPI(ply, ent)
		if not AdvDupe2.duplicator.IsCopyable(ent) or areacopy_classblacklist[ent:GetClass()] then return false end
		return ent:CPPIGetOwner()==ply
	end

	-- Code from WireLib.CanTool
	local zero = Vector(0, 0, 0)
	local norm = Vector(1, 0, 0)

	local tr = { ---@type TraceResult
		Hit = true, HitNonWorld = true, HitNoDraw = false, HitSky = false, AllSolid = true,
		HitNormal = zero, Normal = norm,

		Fraction = 1, FractionLeftSolid = 0,
		HitBox = 0, HitGroup = 0, HitTexture = "**studio**",
		MatType = 0, PhysicsBone = 0, SurfaceProps = 0, DispFlags = 0, Contents = 0,

		Entity = NULL, HitPos = zero, StartPos = zero,
	}

	local function PlayerCanDupeTool(ply, ent)
		if not AdvDupe2.duplicator.IsCopyable(ent) or areacopy_classblacklist[ent:GetClass()] then return false end

		local pos = ent:GetPos()
		tr.Entity, tr.HitPos, tr.StartPos = ent, pos, pos

		return hook.Run( "CanTool", ply, tr, "advdupe2" ) ~= false
	end

	--Find all the entities in a box, given the adjacent corners and the player
	local function FindInBox(min, max, ply)
		local PPCheck = (tobool(ply:GetInfo("advdupe2_copy_only_mine")) and ply.CPPIGetOwner~=nil) and PlayerCanDupeCPPI or PlayerCanDupeTool
		local EntTable = {}
		for _, ent in ents.Iterator() do
			local pos = ent:GetPos()
			if (pos.X>=min.X) and (pos.X<=max.X) and
				 (pos.Y>=min.Y) and (pos.Y<=max.Y) and
				 (pos.Z>=min.Z) and (pos.Z<=max.Z) and PPCheck( ply, ent ) then
				EntTable[ent:EntIndex()] = ent
			end
		end

		return EntTable
	end

	--[[
		Name: GetDupeAngleOffset
		Desc: Retrieves duplication angle offsets from player
		Returns: <angle> Created angle
	]]
	local function GetDupeAngleOffset(ply)
		local p = math.Clamp(ply:GetInfoNum("advdupe2_offset_pitch", 0), -180, 180)
		local y = math.Clamp(ply:GetInfoNum("advdupe2_offset_yaw"  , 0), -180, 180)
		local r = math.Clamp(ply:GetInfoNum("advdupe2_offset_roll" , 0), -180, 180)
		return Angle(p, y, r)
	end

	--[[
		Name: GetDupeElevation
		Desc: Retrieves duplication Z elevation
		Returns: <number> Dupe elevation
	]]
	local function GetDupeElevation(ply)
		local con = ply:GetInfoNum("advdupe2_offset_z", 0)
		local enz = (tonumber(ply.AdvDupe2.HeadEnt.Z) or 0)
		return math.Clamp(con + enz, -32000, 32000)
	end

	--[[
		Name: LeftClick
		Desc: Defines the tool's behavior when the player left-clicks.
		Params: <trace> trace
		Returns: <boolean> success
	]]
	function TOOL:LeftClick( trace )
		if(not trace) then return false end

		local ply = self:GetOwner()
		local dupe = ply.AdvDupe2

		if not (dupe and dupe.Entities) then return false end

		if(dupe.Pasting or dupe.Downloading) then
			AdvDupe2.Notify(ply,"Advanced Duplicator 2 is busy.",NOTIFY_ERROR)
			return false
		end

		dupe.Angle = GetDupeAngleOffset(ply)
		dupe.Position = Vector(trace.HitPos)
		dupe.Position.z = dupe.Position.z + GetDupeElevation(ply)

		if(tobool(ply:GetInfo("advdupe2_offset_world"))) then
			dupe.Angle = dupe.Angle - dupe.Entities[dupe.HeadEnt.Index].PhysicsObjects[0].Angle
		end

		dupe.Pasting = true
		AdvDupe2.Notify(ply,"Pasting...")
		local origin
		if(tobool(ply:GetInfo("advdupe2_original_origin"))) then
			origin = dupe.HeadEnt.Pos
		end

		AdvDupe2.InitPastingQueue(ply, dupe.Position, dupe.Angle, origin,
			tobool(ply:GetInfo("advdupe2_paste_constraints")),
			tobool(ply:GetInfo("advdupe2_paste_parents")),
			tobool(ply:GetInfo("advdupe2_paste_disparents")),
			tobool(ply:GetInfo("advdupe2_paste_protectoveride")))

		return true
	end

	--[[
		Name: RightClick
		Desc: Defines the tool's behavior when the player right-clicks.
		Params: <trace> trace
		Returns: <boolean> success
	]]
	function TOOL:RightClick( trace )
		local ply = self:GetOwner()
		local dupe = ply.AdvDupe2

		if not dupe then dupe = {}; ply.AdvDupe2 = dupe end

		if(dupe.Pasting or dupe.Downloading) then
			AdvDupe2.Notify(ply,"Advanced Duplicator 2 is busy.", NOTIFY_ERROR)
			return false
		end

		--Set Area Copy on or off
		if( ply:KeyDown(IN_SPEED) and not ply:KeyDown(IN_WALK) ) then
			if(self:GetStage()==0) then
				AdvDupe2.DrawSelectBox(ply)
				self:SetStage(1)
				return false
			elseif(self:GetStage()==1) then
				AdvDupe2.RemoveSelectBox(ply)
				self:SetStage(0)
				return false
			end
		end

		if(not trace or not trace.Hit) then return false end

		local Entities, Constraints, AddOne
		local HeadEnt = {}
		--If area copy is on
		if(self:GetStage()==1) then
			local area_size = math.Clamp(tonumber(ply:GetInfo("advdupe2_area_copy_size")) or 50, 0, 30720)
			local Pos = trace.HitNonWorld and trace.Entity:GetPos() or trace.HitPos
			local T = (Vector(area_size,area_size,area_size)+Pos)
			local B = (Vector(-area_size,-area_size,-area_size)+Pos)

			local Ents = FindInBox(B,T, ply)
			local _, Ent = next(Ents)
			if not Ent then
				self:SetStage(0)
				AdvDupe2.RemoveSelectBox(ply)
				return true
			end

			Ent = trace.HitNonWorld and trace.Entity or Ent
			HeadEnt.Index = Ent:EntIndex()
			HeadEnt.Pos = Ent:GetPos()

			Entities, Constraints = AdvDupe2.duplicator.AreaCopy(ply, Ents, HeadEnt.Pos, tobool(ply:GetInfo("advdupe2_copy_outside")))

			self:SetStage(0)
			AdvDupe2.RemoveSelectBox(ply)
		elseif trace.HitNonWorld then	--Area Copy is off
			-- Filter duplicator blocked entities out.
			if not AdvDupe2.duplicator.IsCopyable( trace.Entity ) then
				return false
			end

			--If Alt is being held, add a prop to the dupe
			if(ply:KeyDown(IN_WALK) and dupe.Entities~=nil and next(dupe.Entities)~=nil) then
				Entities = dupe.Entities
				Constraints = dupe.Constraints
				HeadEnt = dupe.HeadEnt

				AdvDupe2.duplicator.Copy( ply, trace.Entity, Entities, Constraints, HeadEnt.Pos)

				--Only add the one ghost
				AddOne = Entities[trace.Entity:EntIndex()]
			else
				Entities = {}
				Constraints = {}
				HeadEnt.Index = trace.Entity:EntIndex()
				HeadEnt.Pos = trace.HitPos

				AdvDupe2.duplicator.Copy( ply, trace.Entity, Entities, Constraints, trace.HitPos )
			end
		else --Non valid entity or clicked the world
			if dupe.Entities then
				--clear the dupe
				net.Start("AdvDupe2_RemoveGhosts")
				net.Send(ply)
				dupe.Entities = nil
				dupe.Constraints = nil
				net.Start("AdvDupe2_ResetDupeInfo")
				net.Send(ply)
				AdvDupe2.ResetOffsets(ply)
				return true
			else
				--select all owned props
				Entities = {}
				local PPCheck = (tobool(ply:GetInfo("advdupe2_copy_only_mine")) and CPPI~=nil) and PlayerCanDupeCPPI or PlayerCanDupeTool
				for _, ent in ents.Iterator() do
					if PPCheck( ply, ent ) then
						Entities[ent:EntIndex()] = ent
					end
				end

				local _, Ent = next(Entities)
				if not Ent then
				net.Start("AdvDupe2_RemoveGhosts")
				net.Send(ply)
					return true
				end

				HeadEnt.Index = Ent:EntIndex()
				HeadEnt.Pos = Ent:GetPos()

				Entities, Constraints = AdvDupe2.duplicator.AreaCopy(ply, Entities, HeadEnt.Pos, tobool(ply:GetInfo("advdupe2_copy_outside")))
			end
		end

		if not HeadEnt.Z then
			local WorldTrace = util.TraceLine({
				mask   = MASK_NPCWORLDSTATIC,
				start  = HeadEnt.Pos + Vector(0,0,1),
				endpos = HeadEnt.Pos-Vector(0,0,50000)
			})

			HeadEnt.Z = WorldTrace.Hit and math.abs(HeadEnt.Pos.Z - WorldTrace.HitPos.Z) or 0
		end

		dupe.HeadEnt = HeadEnt
		dupe.Entities = Entities
		dupe.Constraints = GetSortedConstraints(ply, Constraints)
		dupe.Revision = AdvDupe2.CodecRevision

		net.Start("AdvDupe2_SetDupeInfo")
			net.WriteString("")
			net.WriteString(ply:Nick())
			net.WriteString(os.date("%d %B %Y"))
			net.WriteString(os.date("%I:%M %p"))
			net.WriteString("")
			net.WriteString("")
			net.WriteString(table.Count(dupe.Entities))
			net.WriteString(#dupe.Constraints)
		net.Send(ply)

		if AddOne then
			AdvDupe2.SendGhost(ply, AddOne)
		else
			AdvDupe2.SendGhosts(ply)
		end

		AdvDupe2.ResetOffsets(ply)

		return true
	end

	--Checks table, re-draws loading bar, and recreates ghosts when tool is pulled out
	function TOOL:Deploy()
		local ply = self:GetOwner()
		local dupe = ply.AdvDupe2

		if not dupe then dupe = {}; ply.AdvDupe2 = dupe end

		if(not dupe.Entities) then return end

		net.Start("AdvDupe2_StartGhosting")
		net.Send(ply)

		if(dupe.Queued) then
			AdvDupe2.InitProgressBar(ply, "Queued: ")
			return
		end

		if(dupe.Pasting) then
			AdvDupe2.InitProgressBar(ply, "Pasting: ")
			return
		else
			if(dupe.Uploading) then
				AdvDupe2.InitProgressBar(ply, "Opening: ")
				return
			elseif(dupe.Downloading) then
				AdvDupe2.InitProgressBar(ply, "Saving: ")
				return
			end
		end

	end

	--Removes progress bar
	function TOOL:Holster()
		AdvDupe2.RemoveProgressBar(self:GetOwner())
	end

	--[[
		Name: Reload
		Desc: Creates an Advance Contraption Spawner.
		Params: <trace> trace
		Returns: <boolean> success
	]]
	function TOOL:Reload( trace )
		if(not trace.Hit) then return false end

		local ply = self:GetOwner()
		local dupe = ply.AdvDupe2

		if not dupe then dupe = {}; ply.AdvDupe2 = dupe end

		if(self:GetStage()==1) then
			local areasize = math.Clamp(tonumber(ply:GetInfo("advdupe2_area_copy_size")) or 50, 0, 30720)
			net.Start("AdvDupe2_CanAutoSave")
				net.WriteVector(trace.HitPos)
				net.WriteFloat(areasize)
				if(trace.Entity) then
					net.WriteUInt(trace.Entity:EntIndex(), 16)
				else
					net.WriteUInt(0, 16)
				end
			net.Send(ply)
			self:SetStage(0)
			AdvDupe2.RemoveSelectBox(ply)
			dupe.TempAutoSavePos = trace.HitPos
			dupe.TempAutoSaveSize = areasize
			dupe.TempAutoSaveOutSide = tobool(ply:GetInfo("advdupe2_copy_outside"))
			return true
		end

		--If a contraption spawner was clicked then update it with the current settings
		if(trace.Entity:GetClass()=="gmod_contr_spawner") then
			local delay = tonumber(ply:GetInfo("advdupe2_contr_spawner_delay"))
			local undo_delay = tonumber(ply:GetInfo("advdupe2_contr_spawner_undo_delay"))
			local min
			local max
			if(not delay) then
				delay = tonumber(GetConVarString("AdvDupe2_MinContraptionSpawnDelay")) or 0.2
			else
				if(not game.SinglePlayer()) then
					min = tonumber(GetConVarString("AdvDupe2_MinContraptionSpawnDelay")) or 0.2
					if (delay < min) then
						delay = min
					end
				elseif(delay<0) then
					delay = 0
				end
			end

			if(not undo_delay) then
				undo_delay = tonumber(GetConVarString("AdvDupe2_MinContraptionUndoDelay"))
			else
				if(not game.SinglePlayer()) then
					min = tonumber(GetConVarString("AdvDupe2_MinContraptionUndoDelay")) or 0.1
					max = tonumber(GetConVarString("AdvDupe2_MaxContraptionUndoDelay")) or 60
					if(undo_delay < min) then
						undo_delay = min
					elseif(undo_delay > max) then
						undo_delay = max
					end
				elseif(undo_delay < 0) then
					undo_delay = 0
				end
			end

			trace.Entity:GetTable():SetOptions(
				ply, delay, undo_delay,
				tonumber(ply:GetInfo("advdupe2_contr_spawner_key")),
				tonumber(ply:GetInfo("advdupe2_contr_spawner_undo_key")),
				tonumber(ply:GetInfo("advdupe2_contr_spawner_disgrav")) or 0,
				tonumber(ply:GetInfo("advdupe2_contr_spawner_disdrag")) or 0,
				tonumber(ply:GetInfo("advdupe2_contr_spawner_addvel")) or 1 )

			return true
		end

		--Create a contraption spawner
		if dupe and dupe.Entities then
			local headent = dupe.Entities[dupe.HeadEnt.Index]
			local Pos, Ang

			if(headent) then
				if(tobool(ply:GetInfo("advdupe2_original_origin"))) then
					Pos = dupe.HeadEnt.Pos + headent.PhysicsObjects[0].Pos
					Ang = headent.PhysicsObjects[0].Angle
				else
					local EntAngle = headent.PhysicsObjects[0].Angle
					if(tobool(ply:GetInfo("advdupe2_offset_world"))) then EntAngle = Angle(0,0,0) end
					trace.HitPos.Z = trace.HitPos.Z + GetDupeElevation(ply)
					Pos, Ang = LocalToWorld(headent.PhysicsObjects[0].Pos, EntAngle, trace.HitPos, GetDupeAngleOffset(ply))
				end
			else
				AdvDupe2.Notify(ply, "Invalid head entity to spawn contraption spawner.")
				return false
			end

			if(headent.Class=="gmod_contr_spawner") then
				AdvDupe2.Notify(ply, "Cannot make a contraption spawner from a contraption spawner.")
				return false
			end


			local spawner = MakeContraptionSpawner(
				ply, Pos, Ang, dupe.HeadEnt.Index,
				table.Copy(dupe.Entities),
				table.Copy(dupe.Constraints),
				tonumber(ply:GetInfo("advdupe2_contr_spawner_delay")),
				tonumber(ply:GetInfo("advdupe2_contr_spawner_undo_delay")), headent.Model,
				tonumber(ply:GetInfo("advdupe2_contr_spawner_key")),
				tonumber(ply:GetInfo("advdupe2_contr_spawner_undo_key")),
				tonumber(ply:GetInfo("advdupe2_contr_spawner_disgrav")) or 0,
				tonumber(ply:GetInfo("advdupe2_contr_spawner_disdrag")) or 0,
				tonumber(ply:GetInfo("advdupe2_contr_spawner_addvel")) or 1,
				tonumber(ply:GetInfo("advdupe2_contr_spawner_hideprops")) or 0)

			ply:AddCleanup( "AdvDupe2", spawner )
			undo.Create("gmod_contr_spawner")
				undo.AddEntity( spawner )
				undo.SetPlayer( ply )
			undo.Finish()

			return true
		end
	end

	--Called to clean up the tool when pasting is finished or undo during pasting
	function AdvDupe2.FinishPasting(Player, Paste)
		Player.AdvDupe2.Pasting=false
		AdvDupe2.RemoveProgressBar(Player)
		if(Paste) then AdvDupe2.Notify(Player,"Finished Pasting!") end
	end

	--function for creating a contraption spawner
	function MakeContraptionSpawner( ply, Pos, Ang, HeadEnt, EntityTable, ConstraintTable, delay, undo_delay, model, key, undo_key, disgrav, disdrag, addvel, hideprops)

		if not ply:CheckLimit("gmod_contr_spawners") then return nil end

		if(not game.SinglePlayer()) then
			if(table.Count(EntityTable)>tonumber(GetConVarString("AdvDupe2_MaxContraptionEntities"))) then
				AdvDupe2.Notify(ply,"Contraption Spawner exceeds the maximum amount of "..GetConVarString("AdvDupe2_MaxContraptionEntities").." entities for a spawner!",NOTIFY_ERROR)
				return false
			end
			if(#ConstraintTable>tonumber(GetConVarString("AdvDupe2_MaxContraptionConstraints"))) then
				AdvDupe2.Notify(ply,"Contraption Spawner exceeds the maximum amount of "..GetConVarString("AdvDupe2_MaxContraptionConstraints").." constraints for a spawner!",NOTIFY_ERROR)
				return false
			end
		end

		local spawner = ents.Create("gmod_contr_spawner")
		if not IsValid(spawner) then return end

		spawner:SetPos(Pos)
		spawner:SetAngles(Ang)
		spawner:SetModel(model)
		spawner:SetRenderMode(RENDERMODE_TRANSALPHA)
		spawner:SetCreator(ply)
		spawner:Spawn()

		duplicator.ApplyEntityModifiers(ply, spawner)

		if IsValid(spawner:GetPhysicsObject()) then
			spawner:GetPhysicsObject():EnableMotion(false)
		end

		local min
		local max
		if(not delay) then
			delay = tonumber(GetConVarString("AdvDupe2_MinContraptionSpawnDelay")) or 0.2
		else
			if(not game.SinglePlayer()) then
				min = tonumber(GetConVarString("AdvDupe2_MinContraptionSpawnDelay")) or 0.2
				if (delay < min) then
					delay = min
				end
			elseif(delay<0) then
				delay = 0
			end
		end

		if(not undo_delay) then
			undo_delay = tonumber(GetConVarString("AdvDupe2_MinContraptionUndoDelay"))
		else
			if(not game.SinglePlayer()) then
				min = tonumber(GetConVarString("AdvDupe2_MinContraptionUndoDelay")) or 0.1
				max = tonumber(GetConVarString("AdvDupe2_MaxContraptionUndoDelay")) or 60
				if(undo_delay < min) then
					undo_delay = min
				elseif(undo_delay > max) then
					undo_delay = max
				end
			elseif(undo_delay < 0) then
				undo_delay = 0
			end
		end

		-- Set options
		spawner:SetPlayer(ply)
		spawner:GetTable():SetOptions(ply, delay, undo_delay, key, undo_key, disgrav, disdrag, addvel, hideprops)

		local tbl = {
			ply        = ply,
			delay      = delay,
			undo_delay = undo_delay,
			disgrav    = disgrav,
			disdrag    = disdrag,
			addvel     = addvel,
			hideprops  = hideprops
		}
		table.Merge(spawner:GetTable(), tbl)
		spawner:SetDupeInfo(HeadEnt, EntityTable, ConstraintTable)
		spawner:AddGhosts(ply)

		ply:AddCount("gmod_contr_spawners", spawner)
		ply:AddCleanup("gmod_contr_spawner", spawner)
		return spawner
	end

	duplicator.RegisterEntityClass("gmod_contr_spawner", MakeContraptionSpawner,
		"Pos", "Ang", "HeadEnt", "EntityTable", "ConstraintTable", "delay",
		"undo_delay", "model", "key", "undo_key", "disgrav", "disdrag", "addvel", "hideprops")

	function AdvDupe2.InitProgressBar(ply,label)
		net.Start("AdvDupe2_InitProgressBar")
			net.WriteString(label)
		net.Send(ply)
	end

	function AdvDupe2.DrawSelectBox(ply)
		net.Start("AdvDupe2_DrawSelectBox")
		net.Send(ply)
	end

	function AdvDupe2.RemoveSelectBox(ply)
		net.Start("AdvDupe2_RemoveSelectBox")
		net.Send(ply)
	end

	function AdvDupe2.UpdateProgressBar(ply,percent)
		net.Start("AdvDupe2_UpdateProgressBar")
			net.WriteFloat(percent)
		net.Send(ply)
	end

	function AdvDupe2.RemoveProgressBar(ply)
		net.Start("AdvDupe2_RemoveProgressBar")
		net.Send(ply)
	end

	--Reset the offsets of height, pitch, yaw, and roll back to default
	function AdvDupe2.ResetOffsets(ply, keep)

		if(not keep) then
			ply.AdvDupe2.Name = nil
		end
		net.Start("AdvDupe2_ResetOffsets")
		net.Send(ply)
	end

	net.Receive("AdvDupe2_CanAutoSave", function(len, ply, len2)

		local desc = net.ReadString()
		local ent = net.ReadInt(16)
		local dupe = ply.AdvDupe2

		if(ent~=0) then
			dupe.AutoSaveEnt = ent
			if(ply:GetInfo("advdupe2_auto_save_contraption")=="1") then
				dupe.AutoSaveEnt = ents.GetByIndex( dupe.AutoSaveEnt )
			end
		else
			if(ply:GetInfo("advdupe2_auto_save_contraption")=="1") then
				AdvDupe2.Notify(ply, "No entity selected to auto save contraption.", NOTIFY_ERROR)
				return
			end
			dupe.AutoSaveEnt = nil
		end

		dupe.AutoSavePos = dupe.TempAutoSavePos
		dupe.AutoSaveSize = dupe.TempAutoSaveSize
		dupe.AutoSaveOutSide = dupe.TempAutoSaveOutSide
		dupe.AutoSaveContr = ply:GetInfo("advdupe2_auto_save_contraption")=="1"
		dupe.AutoSaveDesc = desc

		local time = math.Clamp(tonumber(ply:GetInfo("advdupe2_auto_save_time")) or 2, 2, 30)
		if(game.SinglePlayer()) then
			dupe.AutoSavePath = net.ReadString()
		end

		AdvDupe2.Notify(ply, "Your area will be auto saved every "..(time*60).." seconds.")
		local name = "AdvDupe2_AutoSave_"..ply:UniqueID()
		if(timer.Exists(name)) then
			timer.Adjust(name, time*60, 0)
			return
		end
		timer.Create(name, time*60, 0, function()
			if(not IsValid(ply)) then
				timer.Remove(name)
				return
			end

			local dupe = ply.AdvDupe2
			if(dupe.Downloading) then
				AdvDupe2.Notify(ply, "Skipping auto save, tool is busy.", NOTIFY_ERROR)
				return
			end

			local Tab = {Entities={}, Constraints={}, HeadEnt={}}

			if(dupe.AutoSaveContr) then
				if(not IsValid(dupe.AutoSaveEnt)) then
					timer.Remove(name)
					AdvDupe2.Notify(ply, "Head entity for auto save no longer valid; stopping auto save.", NOTIFY_ERROR)
					return
				end

				Tab.HeadEnt.Index = dupe.AutoSaveEnt:EntIndex()
				Tab.HeadEnt.Pos = dupe.AutoSaveEnt:GetPos()

				local WorldTrace = util.TraceLine({
					mask   = MASK_NPCWORLDSTATIC,
					start  = Tab.HeadEnt.Pos + Vector(0,0,1),
					endpos = Tab.HeadEnt.Pos - Vector(0,0,50000)
				})

				Tab.HeadEnt.Z = WorldTrace.Hit and math.abs(Tab.HeadEnt.Pos.Z - WorldTrace.HitPos.Z) or 0
				AdvDupe2.duplicator.Copy( ply, dupe.AutoSaveEnt, Tab.Entities, Tab.Constraints, Tab.HeadEnt.Pos )
			else
				local i = dupe.AutoSaveSize
				local Pos = dupe.AutoSavePos
				local T = Vector( i, i, i); T:Add(Pos)
				local B = Vector(-i,-i,-i); B:Add(Pos)

				local Entities = FindInBox(B,T, ply)
				local _, HeadEnt = next(Entities)
				if not HeadEnt then
					AdvDupe2.Notify(ply, "Area Auto Save copied 0 entities; be sure to turn it off.", NOTIFY_ERROR)
					return
				end

				if(dupe.AutoSaveEnt and Entities[dupe.AutoSaveEnt]) then
					Tab.HeadEnt.Index = dupe.AutoSaveEnt
				else
					Tab.HeadEnt.Index = HeadEnt:EntIndex()
				end
				Tab.HeadEnt.Pos = HeadEnt:GetPos()

				local WorldTrace = util.TraceLine({
					mask   = MASK_NPCWORLDSTATIC,
					start  = Tab.HeadEnt.Pos + Vector(0,0,1),
					endpos = Tab.HeadEnt.Pos - Vector(0,0,50000)
				})

				Tab.HeadEnt.Z = WorldTrace.Hit and math.abs(Tab.HeadEnt.Pos.Z - WorldTrace.HitPos.Z) or 0
				Tab.Entities, Tab.Constraints = AdvDupe2.duplicator.AreaCopy(ply, Entities, Tab.HeadEnt.Pos, dupe.AutoSaveOutSide)
			end
			Tab.Constraints = GetSortedConstraints(ply, Tab.Constraints)
			Tab.Description = dupe.AutoSaveDesc

			AdvDupe2.Encode( Tab, AdvDupe2.GenerateDupeStamp(ply), function(data)
				AdvDupe2.SendToClient(ply, data, 1)
			end)
			dupe.FileMod = CurTime()+tonumber(GetConVarString("AdvDupe2_FileModificationDelay"))
		end)
		timer.Start(name)
	end)

	concommand.Add("AdvDupe2_SetStage", function(ply, cmd, args)
		ply:GetTool("advdupe2"):SetStage(1)
	end)

	concommand.Add("AdvDupe2_RemoveAutoSave", function(ply, cmd, args)
		timer.Remove("AdvDupe2_AutoSave_"..ply:UniqueID())
	end)

	concommand.Add("AdvDupe2_SaveMap", function(ply, cmd, args)
		if(not ply:IsAdmin()) then
			AdvDupe2.Notify(ply, "You do not have permission to this function.", NOTIFY_ERROR)
			return
		end

		local Entities = {}
		for _, v in ents.Iterator() do
			if not v:CreatedByMap() and AdvDupe2.duplicator.IsCopyable(v) then
				Entities[v:EntIndex()] = v
			end
		end

		local _, HeadEnt = next(Entities)
		if not HeadEnt then return end

		local Tab = {Entities={}, Constraints={}, HeadEnt={}, Description=""}
		Tab.HeadEnt.Index = HeadEnt:EntIndex()
		Tab.HeadEnt.Pos = HeadEnt:GetPos()

		local WorldTrace = util.TraceLine({
			mask   = MASK_NPCWORLDSTATIC,
			start  = Tab.HeadEnt.Pos + Vector(0,0,1),
			endpos = Tab.HeadEnt.Pos - Vector(0,0,50000)
		})

		Tab.HeadEnt.Z = WorldTrace.Hit and math.abs(Tab.HeadEnt.Pos.Z - WorldTrace.HitPos.Z) or 0
		Tab.Entities, Tab.Constraints = AdvDupe2.duplicator.AreaCopy(ply, Entities, Tab.HeadEnt.Pos, true)
		Tab.Constraints = GetSortedConstraints(ply, Tab.Constraints)

		Tab.Map = true
		AdvDupe2.Encode( Tab, AdvDupe2.GenerateDupeStamp(ply), function(data)
			if #data > AdvDupe2.MaxDupeSize then
				AdvDupe2.Notify(ply, "Copied duplicator filesize is too big!",NOTIFY_ERROR)
				return 
			end
			if(not file.IsDir("advdupe2_maps", "DATA")) then
				file.CreateDir("advdupe2_maps")
			end
			file.Write("advdupe2_maps/"..args[1]..".txt", data)
			AdvDupe2.Notify(ply, "Map save, saved successfully.")
		end)
	end)
end

if(CLIENT) then

	function TOOL:LeftClick(trace)
		if(trace and AdvDupe2.HeadGhost) then
			return true
		end
		return false
	end

	function TOOL:RightClick(trace)
		if( self:GetOwner():KeyDown(IN_SPEED) and not self:GetOwner():KeyDown(IN_WALK) ) then
			return false
		end
		return true
	end

	--Removes progress bar and removes ghosts when tool is put away
	function TOOL:ReleaseGhostEntity()
		AdvDupe2.RemoveGhosts()
		AdvDupe2.RemoveSelectBox()
		if(AdvDupe2.Rotation) then
			hook.Remove("PlayerBindPress", "AdvDupe2_BindPress")
			hook.Remove("CreateMove", "AdvDupe2_MouseControl")
		end
		return
	end

	function TOOL:Reload( trace )
		if(trace and (AdvDupe2.HeadGhost or self:GetStage() == 1)) then
			return true
		end
		return false
	end

	--Take control of the mouse wheel bind so the player can modify the height of the dupe
	local function MouseWheelScrolled(ply, bind, pressed)

		if(bind == "invprev") then
			if(ply:GetTool("advdupe2"):GetStage() == 1) then
				local size = math.min(tonumber(ply:GetInfo("advdupe2_area_copy_size")) + 25, 30720)
				RunConsoleCommand("advdupe2_area_copy_size",size)
			else
				local Z = tonumber(ply:GetInfo("advdupe2_offset_z")) + 5
				RunConsoleCommand("advdupe2_offset_z",Z)
			end
			return true
		elseif(bind == "invnext") then
			if(ply:GetTool("advdupe2"):GetStage() == 1) then
				local size = math.max(tonumber(ply:GetInfo("advdupe2_area_copy_size")) - 25, 25)
				RunConsoleCommand("advdupe2_area_copy_size",size)
			else
				local Z = tonumber(ply:GetInfo("advdupe2_offset_z")) - 5
				RunConsoleCommand("advdupe2_offset_z",Z)
			end
			return true
		end

		GAMEMODE:PlayerBindPress(ply, bind, pressed)
	end

	local YawTo = 0
	local BsAng = Angle()

	local function GetRotationSign(ply)
		local VY = tonumber(ply:GetInfo("advdupe2_offset_yaw")) or 0
		BsAng:Zero(); BsAng:RotateAroundAxis(BsAng:Up(), VY)
		local PR = ply:GetRight()
		local DP = BsAng:Right():Dot(PR)
		local DR = BsAng:Forward():Dot(PR)
		if(math.abs(DR) > math.abs(DP)) then -- Roll priority
			if(DR >= 0) then return -1, 1 else return  1, -1 end
		else -- Pitch axis takes priority. Normal X-Y map
			if(DP >= 0) then return  1, 1 else return -1, -1 end
		end
	end

	local function MouseControl( cmd )
		local ply = LocalPlayer()
		local X =  cmd:GetMouseX() / 20
		local Y = -cmd:GetMouseY() / 20
		local ru = ply:KeyDown(IN_SPEED)
		local mm = input.IsMouseDown(MOUSE_MIDDLE)

		if(mm) then
			if(ru) then
				YawTo = 0 -- Reset total integrated yaw
				RunConsoleCommand("advdupe2_offset_pitch", 0)
				RunConsoleCommand("advdupe2_offset_yaw"  , 0)
				RunConsoleCommand("advdupe2_offset_roll" , 0)
			else
				if(Y ~= 0) then
					local VR = tonumber(ply:GetInfo("advdupe2_offset_roll"))  or 0
					local VP = tonumber(ply:GetInfo("advdupe2_offset_pitch")) or 0
					local SP, SR, P, R = GetRotationSign(ply)
					if(SP ~= SR) then
						P = math.NormalizeAngle(VP + X * SR)
						R = math.NormalizeAngle(VR + Y * SP)
					else
						P = math.NormalizeAngle(VP + Y * SP)
						R = math.NormalizeAngle(VR + X * SR)
					end
					RunConsoleCommand("advdupe2_offset_pitch", P)
					RunConsoleCommand("advdupe2_offset_roll" , R)
				end
			end
		else
			if(X ~= 0) then
				VY = tonumber(ply:GetInfo("advdupe2_offset_yaw")) or 0
				if(ru) then
					YawTo = YawTo + X -- Integrate the mouse on the X value from the mouse
					RunConsoleCommand("advdupe2_offset_yaw", math.SnapTo(math.NormalizeAngle(YawTo), 45))
				else
					YawTo = VY + X -- Update the last yaw with the current value from the mouse
					RunConsoleCommand("advdupe2_offset_yaw", math.NormalizeAngle(YawTo))
				end
			end
		end
	end

	--Checks binds to modify dupes position and angles
	function TOOL:Think()

		if AdvDupe2.HeadGhost then
			AdvDupe2.UpdateGhosts()
		end

		if(LocalPlayer():KeyDown(IN_USE)) then
			if(not AdvDupe2.Rotation) then
				hook.Add("PlayerBindPress", "AdvDupe2_BindPress", MouseWheelScrolled)
				hook.Add("CreateMove", "AdvDupe2_MouseControl", MouseControl)
				AdvDupe2.Rotation = true
			end
		else
			if(AdvDupe2.Rotation) then
				AdvDupe2.Rotation = false
				hook.Remove("PlayerBindPress", "AdvDupe2_BindPress")
				hook.Remove("CreateMove", "AdvDupe2_MouseControl")
			end
		end
	end

	--Hinder the player from looking to modify offsets with the mouse
	function TOOL:FreezeMovement()
		return AdvDupe2.Rotation
	end

	language.Add( "Tool.advdupe2.name",	"Advanced Duplicator 2" )
	language.Add( "Tool.advdupe2.desc",	"Duplicate things." )
	language.Add( "Tool.advdupe2.0",	"Primary: Paste, Secondary: Copy, Secondary+World: Select/Deselect All, Secondary+Shift: Area copy." )
	language.Add( "Tool.advdupe2.1",	"Primary: Paste, Secondary: Copy an area, Reload: Autosave an area, Secondary+Shift: Cancel." )
	language.Add( "Undone_AdvDupe2",	"Undone AdvDupe2 paste" )
	language.Add( "Cleanup_AdvDupe2",	"AdvDupe2 Duplications" )
	language.Add( "Cleaned_AdvDupe2",	"Cleaned up all AdvDupe2 Duplications" )
	language.Add( "SBoxLimit_AdvDupe2",	"You've reached the AdvDupe2 Duplicator limit!" )

	CreateClientConVar("advdupe2_offset_world", 0, false, true)
	CreateClientConVar("advdupe2_offset_z", 0, false, true)
	CreateClientConVar("advdupe2_offset_pitch", 0, false, true)
	CreateClientConVar("advdupe2_offset_yaw", 0, false, true)
	CreateClientConVar("advdupe2_offset_roll", 0, false, true)
	CreateClientConVar("advdupe2_original_origin", 0, false, true)
	CreateClientConVar("advdupe2_paste_constraints", 1, false, true)
	CreateClientConVar("advdupe2_sort_constraints", 1, true, true)
	CreateClientConVar("advdupe2_paste_parents", 1, false, true)
	CreateClientConVar("advdupe2_paste_unfreeze", 0, false, true)
	CreateClientConVar("advdupe2_preserve_freeze", 0, false, true)
	CreateClientConVar("advdupe2_copy_outside", 0, false, true)
	CreateClientConVar("advdupe2_copy_only_mine", 1, false, true)
	CreateClientConVar("advdupe2_limit_ghost", 100, false, true)
	CreateClientConVar("advdupe2_area_copy_size", 300, false, true)
	CreateClientConVar("advdupe2_auto_save_contraption", 0, false, true)
	CreateClientConVar("advdupe2_auto_save_overwrite", 1, false, true)
	CreateClientConVar("advdupe2_auto_save_time", 2, false, true)

	--Contraption Spawner
	CreateClientConVar("advdupe2_contr_spawner_key", -1, false, true)
	CreateClientConVar("advdupe2_contr_spawner_undo_key", -1, false, true)
	CreateClientConVar("advdupe2_contr_spawner_delay", 0, false, true)
	CreateClientConVar("advdupe2_contr_spawner_undo_delay", 10, false, true)
	CreateClientConVar("advdupe2_contr_spawner_disgrav", 0, false, true)
	CreateClientConVar("advdupe2_contr_spawner_disdrag", 0, false, true)
	CreateClientConVar("advdupe2_contr_spawner_addvel", 1, false, true)
	CreateClientConVar("advdupe2_contr_spawner_hideprops", 0, false, true)

	--Experimental
	CreateClientConVar("advdupe2_paste_disparents", 0, false, true)
	CreateClientConVar("advdupe2_paste_protectoveride", 1, false, true)
	CreateClientConVar("advdupe2_debug_openfile", 1, false, true)

	local function BuildCPanel(CPanel)
		CPanel:ClearControls()

		local FileBrowser = vgui.Create("advdupe2_browser")
		CPanel:AddItem(FileBrowser)
		FileBrowser:SetSize(CPanel:GetWide(), 405)
		AdvDupe2.FileBrowser = FileBrowser

		local Check = vgui.Create("DCheckBoxLabel")

		Check:SetText( "Paste at original position" )
		Check:SetDark(true)
		Check:SetConVar( "advdupe2_original_origin" )
		Check:SetValue( 0 )
		Check:SetToolTip("Paste at the position originally copied")
		CPanel:AddItem(Check)

		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Paste with constraints" )
		Check:SetDark(true)
		Check:SetConVar( "advdupe2_paste_constraints" )
		Check:SetValue( 1 )
		Check:SetToolTip("Paste with or without constraints")
		CPanel:AddItem(Check)

		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Paste with parenting" )
		Check:SetDark(true)
		Check:SetConVar( "advdupe2_paste_parents" )
		Check:SetValue( 1 )
		Check:SetToolTip("Paste with or without parenting")
		CPanel:AddItem(Check)

		local Check_1 = vgui.Create("DCheckBoxLabel")
		local Check_2 = vgui.Create("DCheckBoxLabel")

		Check_1:SetText( "Unfreeze all after paste" )
		Check_1:SetDark(true)
		Check_1:SetConVar( "advdupe2_paste_unfreeze" )
		Check_1:SetValue( 0 )
		Check_1.OnChange = function()
			if(Check_1:GetChecked() and Check_2:GetChecked()) then
				Check_2:SetValue(0)
			end
		end
		Check_1:SetToolTip("Unfreeze all props after pasting")
		CPanel:AddItem(Check_1)

		Check_2:SetText( "Preserve frozen state after paste" )
		Check_2:SetDark(true)
		Check_2:SetConVar( "advdupe2_preserve_freeze" )
		Check_2:SetValue( 0 )
		Check_2.OnChange = function()
			if(Check_2:GetChecked() and Check_1:GetChecked()) then
				Check_1:SetValue(0)
			end
		end
		Check_2:SetToolTip("Makes props have the same frozen state as when they were copied")
		CPanel:AddItem(Check_2)

		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Area copy constrained props outside of box" )
		Check:SetDark(true)
		Check:SetConVar( "advdupe2_copy_outside" )
		Check:SetValue( 0 )
		Check:SetToolTip("Copy entities outside of the area copy that are constrained to entities insde")
		CPanel:AddItem(Check)

		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "World/Area copy only your own props" )
		Check:SetDark(true)
		Check:SetConVar( "advdupe2_copy_only_mine" )
		Check:SetValue( 1 )
		Check:SetToolTip("Copy entities outside of the area copy that are constrained to entities insde")
		CPanel:AddItem(Check)

		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Sort constraints by their connections" )
		Check:SetDark(true)
		Check:SetConVar( "advdupe2_sort_constraints" )
		Check:SetValue( GetConVarNumber("advdupe2_sort_constraints") )
		Check:SetToolTip( "Orders constraints so that they build a rigid constraint system." )
		CPanel:AddItem(Check)

		local NumSlider = vgui.Create( "DNumSlider" )
		NumSlider:SetText( "Ghost Percentage:" )
		NumSlider.Label:SetDark(true)
		NumSlider:SetMin( 0 )
		NumSlider:SetMax( 100 )
		NumSlider:SetDecimals( 0 )
		NumSlider:SetConVar( "advdupe2_limit_ghost" )
		NumSlider:SetToolTip("Change the percent of ghosts to spawn")
		--If these funcs are not here, problems occur for each
		local func = NumSlider.Slider.OnMouseReleased
		NumSlider.Slider.OnMouseReleased = function(self, mcode) func(self, mcode) AdvDupe2.StartGhosting() end
		local func2 = NumSlider.Slider.Knob.OnMouseReleased
		NumSlider.Slider.Knob.OnMouseReleased = function(self, mcode) func2(self, mcode) AdvDupe2.StartGhosting() end
		local func3 = NumSlider.Wang.Panel.OnLoseFocus
		NumSlider.Wang.Panel.OnLoseFocus = function(txtBox) func3(txtBox) AdvDupe2.StartGhosting() end
		CPanel:AddItem(NumSlider)

		NumSlider = vgui.Create( "DNumSlider" )
		NumSlider:SetText( "Area Copy Size:" )
		NumSlider.Label:SetDark(true)
		NumSlider:SetMin( 0 )
		NumSlider:SetMax( 30720 )
		NumSlider:SetDecimals( 0 )
		NumSlider:SetConVar( "advdupe2_area_copy_size" )
		NumSlider:SetToolTip("Change the size of the area copy")
		CPanel:AddItem(NumSlider)

		local Category1 = vgui.Create("DCollapsibleCategory")
		CPanel:AddItem(Category1)
		Category1:SetLabel("Offsets")
		Category1:SetExpanded(0)

		local parent = FileBrowser:GetParent():GetParent():GetParent():GetParent()
		--[[Offsets]]--
		local CategoryContent1 = vgui.Create( "DPanelList" )
		CategoryContent1:SetAutoSize( true )
		CategoryContent1:SetDrawBackground( false )
		CategoryContent1:SetSpacing( 1 )
		CategoryContent1:SetPadding( 2 )
		CategoryContent1.OnMouseWheeled = function(self, dlta) parent:OnMouseWheeled(dlta) end		--Fix the damned mouse not scrolling when it's over the catagories

		Category1:SetContents( CategoryContent1 )

		NumSlider = vgui.Create( "DNumSlider" )
		NumSlider:SetText( "Height Offset" )
		NumSlider.Label:SetDark(true)
		NumSlider:SetMin( -2500 )
		NumSlider:SetMax( 2500 )
		NumSlider:SetDefaultValue( 0 )
		NumSlider:SetDecimals( 3 )
		NumSlider:SetConVar("advdupe2_offset_z")
		NumSlider:SetToolTip("Changes the dupe Z offset")
		CategoryContent1:AddItem(NumSlider)

		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Use World Angles" )
		Check:SetDark(true)
		Check:SetConVar( "advdupe2_offset_world" )
		Check:SetValue( 0 )
		Check:SetToolTip("Use world angles for the offset instead of the main entity")
		CategoryContent1:AddItem(Check)

		NumSlider = vgui.Create( "DNumSlider" )
		NumSlider:SetText( "Pitch Offset" )
		NumSlider.Label:SetDark(true)
		NumSlider:SetMin( -180 )
		NumSlider:SetMax( 180 )
		NumSlider:SetDefaultValue( 0 )
		NumSlider:SetDecimals( 3 )
		NumSlider:SetToolTip("Changes the dupe pitch offset")
		NumSlider:SetConVar("advdupe2_offset_pitch")
		CategoryContent1:AddItem(NumSlider)

		NumSlider = vgui.Create( "DNumSlider" )
		NumSlider:SetText( "Yaw Offset" )
		NumSlider.Label:SetDark(true)
		NumSlider:SetMin( -180 )
		NumSlider:SetMax( 180 )
		NumSlider:SetDefaultValue( 0 )
		NumSlider:SetDecimals( 3 )
		NumSlider:SetToolTip("Changes the dupe yaw offset")
		NumSlider:SetConVar("advdupe2_offset_yaw")
		CategoryContent1:AddItem(NumSlider)

		NumSlider = vgui.Create( "DNumSlider" )
		NumSlider:SetText( "Roll Offset" )
		NumSlider.Label:SetDark(true)
		NumSlider:SetMin( -180 )
		NumSlider:SetMax( 180 )
		NumSlider:SetDefaultValue( 0 )
		NumSlider:SetDecimals( 3 )
		NumSlider:SetToolTip("Changes the dupe roll offset")
		NumSlider:SetConVar("advdupe2_offset_roll")
		CategoryContent1:AddItem(NumSlider)

		local Btn = vgui.Create("DButton")
		Btn:SetText("Reset")
		Btn.DoClick = function()
			RunConsoleCommand("advdupe2_offset_z", 0)
			RunConsoleCommand("advdupe2_offset_pitch", 0)
			RunConsoleCommand("advdupe2_offset_yaw", 0)
			RunConsoleCommand("advdupe2_offset_roll", 0)
		end
		CategoryContent1:AddItem(Btn)


		--[[Dupe Information]]--
		local Category2 = vgui.Create("DCollapsibleCategory")
		CPanel:AddItem(Category2)
		Category2:SetLabel("Dupe Information")
		Category2:SetExpanded(0)

		local CategoryContent2 = vgui.Create( "DPanelList" )
		CategoryContent2:SetAutoSize( true )
		CategoryContent2:SetDrawBackground( false )
		CategoryContent2:SetSpacing( 3 )
		CategoryContent2:SetPadding( 2 )
		Category2:SetContents( CategoryContent2 )
		CategoryContent2.OnMouseWheeled = function(self, dlta) parent:OnMouseWheeled(dlta) end

		AdvDupe2.Info = {}

		local lbl = vgui.Create( "DLabel" )
		lbl:SetText(AdvDupe2.InfoText.File or "File: ")
		lbl:SetDark(true)
		CategoryContent2:AddItem(lbl)
		AdvDupe2.Info.File = lbl

		lbl = vgui.Create( "DLabel" )
		lbl:SetText(AdvDupe2.InfoText.Creator or "Creator:")
		lbl:SetDark(true)
		CategoryContent2:AddItem(lbl)
		AdvDupe2.Info.Creator = lbl

		lbl = vgui.Create( "DLabel" )
		lbl:SetText(AdvDupe2.InfoText.Date or "Date:")
		lbl:SetDark(true)
		CategoryContent2:AddItem(lbl)
		AdvDupe2.Info.Date = lbl

		lbl = vgui.Create( "DLabel" )
		lbl:SetText(AdvDupe2.InfoText.Time or "Time:")
		lbl:SetDark(true)
		CategoryContent2:AddItem(lbl)
		AdvDupe2.Info.Time = lbl

		lbl = vgui.Create( "DLabel" )
		lbl:SetText(AdvDupe2.InfoText.Size or "Size:")
		lbl:SetDark(true)
		CategoryContent2:AddItem(lbl)
		AdvDupe2.Info.Size = lbl

		lbl = vgui.Create( "DLabel" )
		lbl:SetText(AdvDupe2.InfoText.Desc or "Desc:")
		lbl:SetDark(true)
		CategoryContent2:AddItem(lbl)
		AdvDupe2.Info.Desc = lbl

		lbl = vgui.Create( "DLabel" )
		lbl:SetText(AdvDupe2.InfoText.Entities or "Entities:")
		lbl:SetDark(true)
		CategoryContent2:AddItem(lbl)
		AdvDupe2.Info.Entities = lbl

		lbl = vgui.Create( "DLabel" )
		lbl:SetText(AdvDupe2.InfoText.Constraints or "Constraints:")
		lbl:SetDark(true)
		CategoryContent2:AddItem(lbl)
		AdvDupe2.Info.Constraints = lbl

	--[[Contraption Spawner]]--
		local Category3 = vgui.Create("DCollapsibleCategory")
		CPanel:AddItem(Category3)
		Category3:SetLabel("Contraption Spawner")
		Category3:SetExpanded(0)

		local CategoryContent3 = vgui.Create( "DPanelList" )
		CategoryContent3:SetAutoSize( true )
		CategoryContent3:SetDrawBackground( false )
		CategoryContent3:SetSpacing( 3 )
		CategoryContent3:SetPadding( 2 )
		Category3:SetContents( CategoryContent3 )
		CategoryContent3.OnMouseWheeled = function(self, dlta) parent:OnMouseWheeled(dlta) end

		local ctrl = vgui.Create( "CtrlNumPad" )
		ctrl:SetConVar1( "advdupe2_contr_spawner_key" )
		ctrl:SetConVar2( "advdupe2_contr_spawner_undo_key" )
		ctrl:SetLabel1( "Spawn Key")
		ctrl:SetLabel2( "Undo Key" )
		CategoryContent3:AddItem(ctrl)

		NumSlider = vgui.Create( "DNumSlider" )
		NumSlider:SetText( "Spawn Delay" )
		NumSlider.Label:SetDark(true)
		if(game.SinglePlayer()) then
			NumSlider:SetMin( 0 )
		else
			local min = tonumber(GetConVarString("AdvDupe2_MinContraptionSpawnDelay")) or 0.2
			if(tonumber(LocalPlayer():GetInfo("advdupe2_contr_spawner_delay"))<min) then
				RunConsoleCommand("advdupe2_contr_spawner_delay", tostring(min))
			end
			NumSlider:SetMin( min )
		end
		NumSlider:SetMax(60)
		NumSlider:SetDecimals( 1 )
		NumSlider:SetConVar("advdupe2_contr_spawner_delay")
		CategoryContent3:AddItem(NumSlider)

		NumSlider = vgui.Create( "DNumSlider" )
		NumSlider:SetText( "Undo Delay" )
		NumSlider.Label:SetDark(true)
		if(game.SinglePlayer()) then
			NumSlider:SetMin( 0 )
			NumSlider:SetMax( 60 )
		else
			local min = tonumber(GetConVarString("AdvDupe2_MinContraptionUndoDelay")) or 10
			local max = tonumber(GetConVarString("AdvDupe2_MaxContraptionUndoDelay")) or 60
			if(tonumber(LocalPlayer():GetInfo("advdupe2_contr_spawner_undo_delay")) < min) then
				RunConsoleCommand("advdupe2_contr_spawner_undo_delay", tostring(min))
			elseif(tonumber(LocalPlayer():GetInfo("advdupe2_contr_spawner_undo_delay")) > max) then
				RunConsoleCommand("advdupe2_contr_spawner_undo_delay", tostring(max))
			end
			NumSlider:SetMin( min )
			NumSlider:SetMax( max )
		end
		NumSlider:SetDecimals( 1 )
		NumSlider:SetConVar("advdupe2_contr_spawner_undo_delay")
		CategoryContent3:AddItem(NumSlider)

		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Disable gravity for all spawned props" )
		Check:SetDark(true)
		Check:SetConVar( "advdupe2_contr_spawner_disgrav" )
		Check:SetValue( 0 )
		CategoryContent3:AddItem(Check)

		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Disable drag for all spawned props" )
		Check:SetDark(true)
		Check:SetConVar( "advdupe2_contr_spawner_disdrag" )
		Check:SetValue( 0 )
		CategoryContent3:AddItem(Check)

		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Add spawner's velocity to contraption" )
		Check:SetDark(true)
		Check:SetConVar( "advdupe2_contr_spawner_addvel" )
		Check:SetValue( 1 )
		CategoryContent3:AddItem(Check)

		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Disable drawing spawner props" )
		Check:SetDark(true)
		Check:SetConVar( "advdupe2_contr_spawner_hideprops" )
		Check:SetValue( 0 )
		CategoryContent3:AddItem(Check)

		--[[Area Auto Save]]--
		local Category4 = vgui.Create("DCollapsibleCategory")
		CPanel:AddItem(Category4)
		Category4:SetLabel("Area Auto Save")
		Category4:SetExpanded(0)

		local CategoryContent4 = vgui.Create( "DPanelList" )
		CategoryContent4:SetAutoSize( true )
		CategoryContent4:SetDrawBackground( false )
		CategoryContent4:SetSpacing( 3 )
		CategoryContent4:SetPadding( 2 )
		Category4:SetContents( CategoryContent4 )
		CategoryContent4.OnMouseWheeled = function(self, dlta) parent:OnMouseWheeled(dlta) end

		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Only copy contraption" )
		Check:SetDark(true)
		Check:SetConVar( "advdupe2_auto_save_contraption" )
		Check:SetValue( 0 )
		Check:SetToolTip("Only copy a contraption instead of an area")
		CategoryContent4:AddItem(Check)

		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Overwrite File" )
		Check:SetDark(true)
		Check:SetConVar( "advdupe2_auto_save_overwrite" )
		Check:SetValue( 1 )
		Check:SetToolTip("Overwrite the file instead of creating a new one everytime")
		CategoryContent4:AddItem(Check)

		NumSlider = vgui.Create( "DNumSlider" )
		NumSlider:SetText( "Minutes to Save:" )
		NumSlider.Label:SetDark(true)
		NumSlider:SetMin( 2 )
		NumSlider:SetMax( 30 )
		NumSlider:SetDecimals( 0 )
		NumSlider:SetConVar( "advdupe2_auto_save_time" )
		NumSlider:SetToolTip("Interval time to save in minutes")
		CategoryContent4:AddItem(NumSlider)

		local pnl = vgui.Create("Panel")
		pnl:SetWide(CPanel:GetWide()-40)
		pnl:SetTall(75)
		pnl:SetPos(0, 50)
		CategoryContent4:AddItem(pnl)

		local label = vgui.Create("DLabel", pnl)
		label:SetText("Directory: ")
		label:SizeToContents()
		label:SetDark(true)
		label:SetPos(5,7)

		AdvDupe2.AutoSavePath = ""
		local txtbox = vgui.Create("DTextEntry", pnl)
		txtbox:SetWide(pnl:GetWide()-100)
		txtbox:SetPos(60, 5)
		txtbox:SetUpdateOnType(true)
		txtbox.OnTextChanged = function(self)
			self:SetValue(AdvDupe2.AutoSavePath)
		end

		local btn = vgui.Create("DImageButton", pnl)
		local x, y = txtbox:GetPos()
		btn:SetPos(x + txtbox:GetWide() + 5, 7)
		btn:SetMaterial("icon16/folder_explore.png")
		btn:SizeToContents()
		btn:SetToolTip("Browse")
		btn.DoClick = function()
			local ScrollBar = parent.VBar
			ScrollBar:AnimateTo(0, 1, 0, 0.2)

			FileBrowser.Submit:SetMaterial("icon16/disk.png")
			FileBrowser.Submit:SetTooltip("Directory for Area Auto Save")
			if(FileBrowser.FileName:GetValue()=="Folder_Name...") then
				FileBrowser.FileName:SetValue("File_Name...")
			end
			FileBrowser.Desc:SetVisible(true)
			FileBrowser.Info:SetVisible(false)
			FileBrowser.FileName:SetVisible(true)
			FileBrowser.FileName:SelectAllOnFocus(true)
			FileBrowser.FileName:OnMousePressed()
			FileBrowser.FileName:RequestFocus()
			FileBrowser.Expanding=true
			FileBrowser:Slide(true)
			FileBrowser.Submit.DoClick = function()
				local name = FileBrowser.FileName:GetValue()
				if(name=="" or name=="File_Name...") then
					AdvDupe2.Notify("Name field is blank.", NOTIFY_ERROR)
					FileBrowser.FileName:SelectAllOnFocus(true)
					FileBrowser.FileName:OnGetFocus()
					FileBrowser.FileName:RequestFocus()
					return
				end
				local desc = FileBrowser.Desc:GetValue()
				if(desc=="Description...") then desc="" end

				if(not IsValid(FileBrowser.Browser.pnlCanvas.m_pSelectedItem) or FileBrowser.Browser.pnlCanvas.m_pSelectedItem.Derma.ClassName~="advdupe2_browser_folder") then
					AdvDupe2.Notify("Folder to save Area Auto Save not selected.", NOTIFY_ERROR)
					return
				end

				FileBrowser.AutoSaveNode = FileBrowser.Browser.pnlCanvas.m_pSelectedItem
				txtbox:SetValue(FileBrowser:GetFullPath(FileBrowser.Browser.pnlCanvas.m_pSelectedItem)..name)
				AdvDupe2.AutoSavePath = txtbox:GetValue()
				txtbox:SetToolTip(txtbox:GetValue())
				AdvDupe2.AutoSaveDesc = desc

				FileBrowser:Slide(false)
				ScrollBar:AnimateTo(ScrollBar.CanvasSize, 1, 0, 0.2)

				RunConsoleCommand("AdvDupe2_SetStage")
				hook.Add("HUDPaint", "AdvDupe2_DrawSelectionBox", AdvDupe2.DrawSelectionBox)
			end
			FileBrowser.FileName.OnEnter = function()
				FileBrowser.FileName:KillFocus()
				FileBrowser.Desc:SelectAllOnFocus(true)
				FileBrowser.Desc.OnMousePressed()
				FileBrowser.Desc:RequestFocus()
			end
			FileBrowser.Desc.OnEnter = FileBrowser.Submit.DoClick
		end

		btn = vgui.Create("DButton", pnl)
		btn:SetSize(50, 35)
		btn:SetPos(pnl:GetWide()/4-10, 30)
		btn:SetText("Show")
		btn.DoClick = function()
			if(AdvDupe2.AutoSavePos) then
				RunConsoleCommand("advdupe2_area_copy_size", AdvDupe2.AutoSaveSize)
				LocalPlayer():SetEyeAngles( (AdvDupe2.AutoSavePos - LocalPlayer():GetShootPos()):Angle() )
				RunConsoleCommand("AdvDupe2_SetStage")
				hook.Add("HUDPaint", "AdvDupe2_DrawSelectionBox", AdvDupe2.DrawSelectionBox)
			end
		end

		btn = vgui.Create("DButton", pnl)
		btn:SetSize(50, 35)
		btn:SetPos((pnl:GetWide()/4)*3-40, 30)
		btn:SetText("Turn Off")
		btn:SetDisabled(true)
		btn.DoClick = function(self)
			RunConsoleCommand("AdvDupe2_RemoveAutoSave")
			self:SetDisabled(true)
			AdvDupe2.AutoSavePos = nil
		end
		AdvDupe2.OffButton = btn


		--[[Experimental Section]]--
		local Category5 = vgui.Create("DCollapsibleCategory")
		CPanel:AddItem(Category5)
		Category5:SetLabel("Experimental Section")
		Category5:SetExpanded(0)

		local CategoryContent5 = vgui.Create( "DPanelList" )
		CategoryContent5:SetAutoSize( true )
		CategoryContent5:SetDrawBackground( false )
		CategoryContent5:SetSpacing( 3 )
		CategoryContent5:SetPadding( 2 )
		Category5:SetContents( CategoryContent5 )
		CategoryContent5.OnMouseWheeled = function(self, dlta) parent:OnMouseWheeled(dlta) end

		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Disable parented props physics interaction" )
		Check:SetDark(true)
		Check:SetConVar( "advdupe2_paste_disparents" )
		Check:SetValue( 0 )
		CategoryContent5:AddItem(Check)

		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Disable Dupe Spawn Protection" )
		Check:SetDark(true)
		Check:SetConVar( "advdupe2_paste_protectoveride" )
		Check:SetValue( 1 )
		Check:SetToolTip("Check this if you things don't look right after pasting.")
		CategoryContent5:AddItem(Check)

		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Open file after Saving" )
		Check:SetDark(true)
		Check:SetConVar( "advdupe2_debug_openfile" )
		Check:SetValue( 1 )
		Check:SetToolTip("Check this if you want your files to be opened after saving them.")
		CategoryContent5:AddItem(Check)

		--[[Save Map]]--
		if(LocalPlayer():IsAdmin()) then
			local Category6 = vgui.Create("DCollapsibleCategory")
			CPanel:AddItem(Category6)
			Category6:SetLabel("Save Map")
			Category6:SetExpanded(0)

			local CategoryContent6 = vgui.Create( "DPanelList" )
			CategoryContent6:SetAutoSize( true )
			CategoryContent6:SetDrawBackground( false )
			CategoryContent6:SetSpacing( 3 )
			CategoryContent6:SetPadding( 2 )
			Category6:SetContents( CategoryContent6 )
			CategoryContent6.OnMouseWheeled = function(self, dlta) parent:OnMouseWheeled(dlta) end

			pnl = vgui.Create("Panel")
			pnl:SetWide(CPanel:GetWide()-40)
			pnl:SetTall(75)
			pnl:SetPos(0, 50)
			CategoryContent6:AddItem(pnl)

			label = vgui.Create("DLabel", pnl)
			label:SetText("File Name: ")
			label:SizeToContents()
			label:SetDark(true)
			label:SetPos(5,7)

			AdvDupe2.AutoSavePath = ""

			local txtbox2 = vgui.Create("DTextEntry", pnl)
			txtbox2:SetWide(pnl:GetWide()-100)
			txtbox2:SetPos(60, 5)

			local btn2 = vgui.Create("DImageButton", pnl)
			x, y = txtbox2:GetPos()
			btn2:SetPos(x + txtbox2:GetWide() + 5, 7)
			btn2:SetMaterial("icon16/disk.png")
			btn2:SizeToContents()
			btn2:SetToolTip("Save Map")
			btn2.DoClick = 	function()
				if(txtbox2:GetValue()=="") then return end
				RunConsoleCommand("AdvDupe2_SaveMap", txtbox2:GetValue())
			end
			txtbox2.OnEnter = function()
				btn2:DoClick()
			end
		end
	end

	function TOOL.BuildCPanel(panel)
		panel:ClearControls()
		panel:AddControl("Header", {
			Text = "Advanced Duplicator 2",
			Description = "Duplicate stuff."
		})
		local function tryToBuild()
			local CPanel = controlpanel.Get("advdupe2")
			if CPanel and CPanel:GetWide()>16 then
				BuildCPanel(CPanel)
			else
				timer.Simple(0.1,tryToBuild)
			end
		end
		tryToBuild()
	end

	local StColor  = {r=130, g=25, b=40, a=255}
	local NoColor  = {r=25, g=100, b=40, a=255}
	local CurColor = {r=25, g=100, b=40, a=255}
	local CWhite   = Color(255,255,255,255)
	surface.CreateFont ("AD2Font", {font="Arial", size=40, weight=1000}) ---Remember to use gm_clearfonts
	surface.CreateFont ("AD2TitleFont", {font="Arial", size=24, weight=1000})

	function TOOL:DrawToolScreen()
		if(not AdvDupe2) then return true end

		local text = "Ready"
		local state, co = false
		local ply = LocalPlayer()

		if(AdvDupe2.Preview) then
			text = "Preview"
		end
		if(AdvDupe2.ProgressBar.Text) then
			state = true
			text = AdvDupe2.ProgressBar.Text
		end

		cam.Start2D()

			surface.SetDrawColor(32, 32, 32, 255)
			surface.DrawRect(0, 0, 256, 256)

			if(state) then
				co = StColor
			else
				co = NoColor
			end

			local rate = FrameTime() * 160
			CurColor.r = math.Approach( CurColor.r, co.r, rate )
			CurColor.g = math.Approach( CurColor.g, co.g, rate )

			surface.SetDrawColor(CurColor)
			surface.DrawRect(13, 13, 230, 230)

			surface.SetTextColor( 255, 255, 255, 255 )

			draw.SimpleText("Advanced Duplicator 2", "AD2TitleFont", 128, 50, CWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText(text, "AD2Font", 128, 128, CWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			if(state) then
				draw.RoundedBox( 6, 32, 178, 192, 28, Color( 255, 255, 255, 150 ) )
				draw.RoundedBox( 6, 34, 180, 188*(AdvDupe2.ProgressBar.Percent / 100), 24, Color( 0, 255, 0, 255 ) )
			elseif(ply:KeyDown(IN_USE)) then
				local font, align = "AD2TitleFont", TEXT_ALIGN_BOTTOM
				draw.SimpleText("H: "..ply:GetInfo("advdupe2_offset_z")    , font, 20,  210, CWhite, TEXT_ALIGN_LEFT , align)
				draw.SimpleText("P: "..ply:GetInfo("advdupe2_offset_pitch"), font, 236, 210, CWhite, TEXT_ALIGN_RIGHT, align)
				draw.SimpleText("Y: "..ply:GetInfo("advdupe2_offset_yaw")  , font, 20 , 240, CWhite, TEXT_ALIGN_LEFT , align)
				draw.SimpleText("R: "..ply:GetInfo("advdupe2_offset_roll") , font, 236, 240, CWhite, TEXT_ALIGN_RIGHT, align)
			end

		cam.End2D()
	end


	local function FindInBox(min, max, ply)
		local EntTable = {}
		for _,ent in ents.Iterator() do
			local pos = ent:GetPos()
			if (pos.X>=min.X) and (pos.X<=max.X) and (pos.Y>=min.Y) and (pos.Y<=max.Y) and (pos.Z>=min.Z) and (pos.Z<=max.Z) then
				--if(ent:GetClass()~="C_BaseFlexclass") then
					EntTable[ent:EntIndex()] = ent
				--end
			end
		end

		return EntTable
	end


	local GreenSelected = Color(0, 255, 0, 255)
	function AdvDupe2.DrawSelectionBox()

		local TraceRes = util.TraceLine(util.GetPlayerTrace(LocalPlayer()))
		local i = math.Clamp(tonumber(LocalPlayer():GetInfo("advdupe2_area_copy_size")) or 50, 0, 30720)

		--Bottom Points
		local B1 = (Vector(-i,-i,-i) + TraceRes.HitPos)
		local B2 = (Vector(-i, i,-i) + TraceRes.HitPos)
		local B3 = (Vector( i, i,-i) + TraceRes.HitPos)
		local B4 = (Vector( i,-i,-i) + TraceRes.HitPos)

		--Top Points
		local T1 = (Vector(-i,-i, i) + TraceRes.HitPos):ToScreen()
		local T2 = (Vector(-i, i, i) + TraceRes.HitPos):ToScreen()
		local T3 = (Vector( i, i, i) + TraceRes.HitPos):ToScreen()
		local T4 = (Vector( i,-i, i) + TraceRes.HitPos):ToScreen()

		if(not AdvDupe2.LastUpdate or CurTime()>=AdvDupe2.LastUpdate) then

			if AdvDupe2.ColorEntities then
				for k,v in pairs(AdvDupe2.EntityColors)do
					local ent = AdvDupe2.ColorEntities[k]
					if(IsValid(ent)) then
						AdvDupe2.ColorEntities[k]:SetColor(v)
					end
				end
			end

			local Entities = FindInBox(B1, (Vector(i,i,i)+TraceRes.HitPos), LocalPlayer())
			AdvDupe2.ColorEntities = Entities
			AdvDupe2.EntityColors = {}
			for k,v in pairs(Entities)do
				AdvDupe2.EntityColors[k] = v:GetColor()
				v:SetColor(GreenSelected)
			end
			AdvDupe2.LastUpdate = CurTime()+0.25

		end

		local tracedata = {}
		tracedata.mask = MASK_NPCWORLDSTATIC
		local WorldTrace

		tracedata.start = B1+Vector(0,0,i*2)
		tracedata.endpos = B1
		WorldTrace = util.TraceLine( tracedata )
		B1 = WorldTrace.HitPos:ToScreen()
		tracedata.start = B2+Vector(0,0,i*2)
		tracedata.endpos = B2
		WorldTrace = util.TraceLine( tracedata )
		B2 = WorldTrace.HitPos:ToScreen()
		tracedata.start = B3+Vector(0,0,i*2)
		tracedata.endpos = B3
		WorldTrace = util.TraceLine( tracedata )
		B3 = WorldTrace.HitPos:ToScreen()
		tracedata.start = B4+Vector(0,0,i*2)
		tracedata.endpos = B4
		WorldTrace = util.TraceLine( tracedata )
		B4 = WorldTrace.HitPos:ToScreen()

		surface.SetDrawColor( 0, 255, 0, 255 )

		--Draw Sides
		surface.DrawLine(B1.x, B1.y, T1.x, T1.y)
		surface.DrawLine(B2.x, B2.y, T2.x, T2.y)
		surface.DrawLine(B3.x, B3.y, T3.x, T3.y)
		surface.DrawLine(B4.x, B4.y, T4.x, T4.y)

		--Draw Bottom
		surface.DrawLine(B1.x, B1.y, B2.x, B2.y)
		surface.DrawLine(B2.x, B2.y, B3.x, B3.y)
		surface.DrawLine(B3.x, B3.y, B4.x, B4.y)
		surface.DrawLine(B4.x, B4.y, B1.x, B1.y)

		--Draw Top
		surface.DrawLine(T1.x, T1.y, T2.x, T2.y)
		surface.DrawLine(T2.x, T2.y, T3.x, T3.y)
		surface.DrawLine(T3.x, T3.y, T4.x, T4.y)
		surface.DrawLine(T4.x, T4.y, T1.x, T1.y)

	end

	net.Receive("AdvDupe2_DrawSelectBox", function()
		hook.Add("HUDPaint", "AdvDupe2_DrawSelectionBox", AdvDupe2.DrawSelectionBox)
	end)

	function AdvDupe2.RemoveSelectBox()
		hook.Remove("HUDPaint", "AdvDupe2_DrawSelectionBox")
		if AdvDupe2.ColorEntities then
			for k,v in pairs(AdvDupe2.EntityColors)do
				if(not IsValid(AdvDupe2.ColorEntities[k])) then
					AdvDupe2.ColorEntities[k]=nil
				else
					AdvDupe2.ColorEntities[k]:SetColor(v)
				end
			end
			AdvDupe2.ColorEntities={}
			AdvDupe2.EntityColors={}
		end
	end
	net.Receive("AdvDupe2_RemoveSelectBox",function()
		AdvDupe2.RemoveSelectBox()
	end)

	function AdvDupe2.InitProgressBar(label)
		AdvDupe2.ProgressBar = {}
		AdvDupe2.ProgressBar.Text = label
		AdvDupe2.ProgressBar.Percent = 0
		AdvDupe2.BusyBar = true
	end
	net.Receive("AdvDupe2_InitProgressBar", function()
		AdvDupe2.InitProgressBar(net.ReadString())
	end)

	net.Receive("AdvDupe2_UpdateProgressBar", function()
		AdvDupe2.ProgressBar.Percent = net.ReadFloat()
	end)

	function AdvDupe2.RemoveProgressBar()
		AdvDupe2.ProgressBar = {}
		AdvDupe2.BusyBar = false
		if(AdvDupe2.Ghosting) then
			AdvDupe2.InitProgressBar("Ghosting: ")
			AdvDupe2.BusyBar = false
			AdvDupe2.ProgressBar.Percent = AdvDupe2.CurrentGhost/AdvDupe2.TotalGhosts*100
		end
	end
	net.Receive("AdvDupe2_RemoveProgressBar", function()
		AdvDupe2.RemoveProgressBar()
	end)

	net.Receive("AdvDupe2_ResetOffsets", function()
		RunConsoleCommand("advdupe2_original_origin", "0")
		RunConsoleCommand("advdupe2_paste_constraints","1")
		RunConsoleCommand("advdupe2_offset_z","0")
		RunConsoleCommand("advdupe2_offset_pitch","0")
		RunConsoleCommand("advdupe2_offset_yaw","0")
		RunConsoleCommand("advdupe2_offset_roll","0")
		RunConsoleCommand("advdupe2_paste_parents","1")
		RunConsoleCommand("advdupe2_paste_disparents","0")
	end)

	net.Receive("AdvDupe2_ReportModel", function()
		print("Advanced Duplicator 2: Invalid Model: "..net.ReadString())
	end)

	net.Receive("AdvDupe2_ReportClass", function()
		print("Advanced Duplicator 2: Invalid Class: "..net.ReadString())
	end)

	net.Receive("AdvDupe2_ResetDupeInfo", function()
		if not AdvDupe2.Info then return end
		AdvDupe2.Info.File:SetText("File:")
		AdvDupe2.Info.Creator:SetText("Creator:")
		AdvDupe2.Info.Date:SetText("Date:")
		AdvDupe2.Info.Time:SetText("Time:")
		AdvDupe2.Info.Size:SetText("Size:")
		AdvDupe2.Info.Desc:SetText("Desc:")
		AdvDupe2.Info.Entities:SetText("Entities:")
		AdvDupe2.Info.Constraints:SetText("Constraints:")
	end)

	net.Receive("AdvDupe2_CanAutoSave", function()
		if(AdvDupe2.AutoSavePath~="") then
			AdvDupe2.AutoSavePos = net.ReadVector()
			AdvDupe2.AutoSaveSize = net.ReadFloat()
			local ent = net.ReadUInt(16)
			AdvDupe2.OffButton:SetDisabled(false)
			net.Start("AdvDupe2_CanAutoSave")
				net.WriteString(AdvDupe2.AutoSaveDesc)
				net.WriteInt(ent, 16)
				if(game.SinglePlayer()) then
					net.WriteString(string.sub(AdvDupe2.AutoSavePath, 10, #AdvDupe2.AutoSavePath))
				end
			net.SendToServer()
		else
			AdvDupe2.Notify("Select a directory for the Area Auto Save.", NOTIFY_ERROR)
		end
	end)

	net.Receive("AdvDupe2_SetDupeInfo", function(len, ply, len2)
		if AdvDupe2.Info then
			AdvDupe2.Info.File:SetText("File: "..net.ReadString())
			AdvDupe2.Info.Creator:SetText("Creator: "..net.ReadString())
			AdvDupe2.Info.Date:SetText("Date: "..net.ReadString())
			AdvDupe2.Info.Time:SetText("Time: "..net.ReadString())
			AdvDupe2.Info.Size:SetText("Size: "..net.ReadString())
			AdvDupe2.Info.Desc:SetText("Desc: "..net.ReadString())
			AdvDupe2.Info.Entities:SetText("Entities: "..net.ReadString())
			AdvDupe2.Info.Constraints:SetText("Constraints: "..net.ReadString())
		else
			AdvDupe2.InfoText.File = "File: "..net.ReadString()
			AdvDupe2.InfoText.Creator = "Creator: "..net.ReadString()
			AdvDupe2.InfoText.Date = "Date: "..net.ReadString()
			AdvDupe2.InfoText.Time = "Time: "..net.ReadString()
			AdvDupe2.InfoText.Size = "Size: "..net.ReadString()
			AdvDupe2.InfoText.Desc = "Desc: "..net.ReadString()
			AdvDupe2.InfoText.Entities = "Entities: "..net.ReadString()
			AdvDupe2.InfoText.Constraints = "Constraints: "..net.ReadString()
		end
	end)
end

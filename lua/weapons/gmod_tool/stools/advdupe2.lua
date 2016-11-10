--[[
	Title: Adv. Dupe 2 Tool
	
	Desc: Defines the AD2 tool and assorted functionalities.
	
	Author: TB
	
	Version: 1.0
]]
TOOL.Category = "Construction"
TOOL.Name = "#Tool.advdupe2.name"
cleanup.Register( "AdvDupe2" )
require "controlpanel"

if(SERVER)then
	CreateConVar("sbox_maxgmod_contr_spawners",5)

	//Thanks to Donovan for fixing the table
	//Turns a table into a numerically indexed table
	local function CollapseTableToArray( t )
		
		local array = {}
		local q = {}
		local min, max = 0, 0
		--get the bounds
		for k in pairs(t) do
			if not min and not max then min,max = k,k end
			min = (k < min) and k or min
			max = (k > max) and k or max	
		end
		for i=min, max do
			if t[i] then
				array[#array+1] = t[i]
			end
		end

		return array
	end

	local function PlayerCanDupeCPPI(ply, ent)
		if ent.DoNotDuplicate or not IsValid(ent:GetPhysicsObject()) or not duplicator.IsAllowed(ent:GetClass()) then return false end
		return ent:CPPIGetOwner()==ply
	end
	
	local function PlayerCanDupeTool(ply, ent)
		if ent.DoNotDuplicate or not IsValid(ent:GetPhysicsObject()) or not duplicator.IsAllowed(ent:GetClass()) then return false end
		local trace = WireLib and WireLib.dummytrace(ent) or { Entity = ent }
		return hook.Run( "CanTool", ply,  trace, "advdupe2" ) ~= false
	end
	
	//Find all the entities in a box, given the adjacent corners and the player
	local function FindInBox(min, max, ply)
		local PPCheck = (tobool(ply:GetInfo("advdupe2_copy_only_mine")) and CPPI~=nil) and PlayerCanDupeCPPI or PlayerCanDupeTool
		local Entities = ents.GetAll() //Don't use FindInBox. It has a 512 entity limit.
		local EntTable = {}
		local pos, ent
		for i=1, #Entities do
			ent = Entities[i]
			pos = ent:GetPos()
			if (pos.X>=min.X) and (pos.X<=max.X) and (pos.Y>=min.Y) and (pos.Y<=max.Y) and (pos.Z>=min.Z) and (pos.Z<=max.Z) and PPCheck( ply, ent ) then	
				EntTable[ent:EntIndex()] = ent
			end
		end

		return EntTable
	end
	
	--[[
		Name: LeftClick
		Desc: Defines the tool's behavior when the player left-clicks.
		Params: <trace> trace
		Returns: <boolean> success
	]]
	function TOOL:LeftClick( trace )
		if(not trace)then return false end

		local ply = self:GetOwner()
		if(not ply.AdvDupe2 or not ply.AdvDupe2.Entities)then return false end
		
		if(ply.AdvDupe2.Pasting or ply.AdvDupe2.Downloading)then
			AdvDupe2.Notify(ply,"Advanced Duplicator 2 is busy.",NOTIFY_ERROR)
			return false 
		end
		
		local z = math.Clamp((tonumber(ply:GetInfo("advdupe2_offset_z")) + ply.AdvDupe2.HeadEnt.Z), -16000, 16000)
		ply.AdvDupe2.Position = trace.HitPos + Vector(0, 0, z)
		ply.AdvDupe2.Angle = Angle(ply:GetInfoNum("advdupe2_offset_pitch", 0), ply:GetInfoNum("advdupe2_offset_yaw", 0), ply:GetInfoNum("advdupe2_offset_roll", 0))
		if(tobool(ply:GetInfo("advdupe2_offset_world")))then ply.AdvDupe2.Angle = ply.AdvDupe2.Angle - ply.AdvDupe2.Entities[ply.AdvDupe2.HeadEnt.Index].PhysicsObjects[0].Angle end
		
		ply.AdvDupe2.Pasting = true
		AdvDupe2.Notify(ply,"Pasting...")
		local origin
		if(tobool(ply:GetInfo("advdupe2_original_origin")))then
			origin = ply.AdvDupe2.HeadEnt.Pos
		end
		AdvDupe2.InitPastingQueue(ply, ply.AdvDupe2.Position, ply.AdvDupe2.Angle, origin, tobool(ply:GetInfo("advdupe2_paste_constraints")), tobool(ply:GetInfo("advdupe2_paste_parents")), tobool(ply:GetInfo("advdupe2_paste_disparents")),tobool(ply:GetInfo("advdupe2_paste_protectoveride")))
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
		
		if(not ply.AdvDupe2)then ply.AdvDupe2 = {} end
		if(ply.AdvDupe2.Pasting or ply.AdvDupe2.Downloading)then
			AdvDupe2.Notify(ply,"Advanced Duplicator 2 is busy.", NOTIFY_ERROR)
			return false 
		end

		//Set Area Copy on or off
		if( ply:KeyDown(IN_SPEED) and not ply:KeyDown(IN_WALK) )then
			if(self:GetStage()==0)then
				AdvDupe2.DrawSelectBox(ply)
				self:SetStage(1)
				return false
			elseif(self:GetStage()==1)then
				AdvDupe2.RemoveSelectBox(ply)
				self:SetStage(0)
				return false
			end	
		end
		
		if(not trace or not trace.Hit)then return false end
		
		local Entities, Constraints, AddOne
		local HeadEnt = {}
		//If area copy is on
		if(self:GetStage()==1)then
			local area_size = tonumber(ply:GetInfo("advdupe2_area_copy_size")) or 50
			if( not game.SinglePlayer() and area_size > tonumber(GetConVarString("AdvDupe2_MaxAreaCopySize")))then
				AdvDupe2.Notify(ply,"Area copy size exceeds limit of "..GetConVarString("AdvDupe2_MaxAreaCopySize")..".",NOTIFY_ERROR)
				return false 
			end
			local Pos = trace.HitNonWorld and trace.Entity:GetPos() or trace.HitPos
			local T = (Vector(area_size,area_size,area_size)+Pos)
			local B = (Vector(-area_size,-area_size,-area_size)+Pos)
			
			local Ents = FindInBox(B,T, ply)
			if next(Ents)==nil then
				self:SetStage(0)
				AdvDupe2.RemoveSelectBox(ply)
				return true
			end
			
			local Ent = trace.HitNonWorld and trace.Entity or Ents[next(Ents)]
			HeadEnt.Index = Ent:EntIndex()
			HeadEnt.Pos = Ent:GetPos()
			
			Entities, Constraints = AdvDupe2.duplicator.AreaCopy(Ents, HeadEnt.Pos, tobool(ply:GetInfo("advdupe2_copy_outside")))

			self:SetStage(0)
			AdvDupe2.RemoveSelectBox(ply)
		elseif trace.HitNonWorld then	//Area Copy is off
			-- Filter duplicator blocked entities out.
			if not duplicator.IsAllowed( trace.Entity:GetClass() ) then
				return false
			end

			//If Alt is being held, add a prop to the dupe
			if(ply:KeyDown(IN_WALK) and ply.AdvDupe2.Entities~=nil and next(ply.AdvDupe2.Entities)~=nil)then
				Entities = ply.AdvDupe2.Entities
				Constraints = ply.AdvDupe2.Constraints
				HeadEnt = ply.AdvDupe2.HeadEnt
				
				AdvDupe2.duplicator.Copy( trace.Entity, Entities, Constraints, HeadEnt.Pos)
				
				//Only add the one ghost
				AddOne = Entities[trace.Entity:EntIndex()]
			else
				Entities = {}
				Constraints = {}
				HeadEnt.Index = trace.Entity:EntIndex()
				HeadEnt.Pos = trace.HitPos
				
				AdvDupe2.duplicator.Copy( trace.Entity, Entities, Constraints, trace.HitPos )
			end
		else //Non valid entity or clicked the world
			if ply.AdvDupe2.Entities then
				//clear the dupe
				umsg.Start("AdvDupe2_RemoveGhosts", ply)
				umsg.End()
				ply.AdvDupe2.Entities = nil
				ply.AdvDupe2.Constraints = nil
				umsg.Start("AdvDupe2_ResetDupeInfo", ply)
				umsg.End()
				AdvDupe2.ResetOffsets(ply)
				return true
			else
				//select all owned props
				Entities = {}
				local PPCheck = (tobool(ply:GetInfo("advdupe2_copy_only_mine")) and CPPI~=nil) and PlayerCanDupeCPPI or PlayerCanDupeTool
				for _, ent in pairs(ents.GetAll()) do
					if PPCheck( ply, ent ) then
						Entities[ent:EntIndex()] = ent
					end
				end
				if next(Entities)==nil then
					return true
				end
				
				local Ent = Entities[next(Entities)]
				HeadEnt.Index = Ent:EntIndex()
				HeadEnt.Pos = Ent:GetPos()
				
				Entities, Constraints = AdvDupe2.duplicator.AreaCopy(Entities, HeadEnt.Pos, tobool(ply:GetInfo("advdupe2_copy_outside")))
			end
		end
		
		if not HeadEnt.Z then
			local WorldTrace = util.TraceLine( {mask=MASK_NPCWORLDSTATIC, start=HeadEnt.Pos+Vector(0,0,1), endpos=HeadEnt.Pos-Vector(0,0,50000)} )
			HeadEnt.Z = WorldTrace.Hit and math.abs(HeadEnt.Pos.Z-WorldTrace.HitPos.Z) or 0
		end
		
		ply.AdvDupe2.HeadEnt = HeadEnt
		ply.AdvDupe2.Entities = Entities
		ply.AdvDupe2.Constraints = CollapseTableToArray(Constraints)
		
		net.Start("AdvDupe2_SetDupeInfo")
			net.WriteString("")
			net.WriteString(ply:Nick())
			net.WriteString(os.date("%d %B %Y"))
			net.WriteString(os.date("%I:%M %p"))
			net.WriteString("")
			net.WriteString("")
			net.WriteString(table.Count(ply.AdvDupe2.Entities))
			net.WriteString(#ply.AdvDupe2.Constraints)
		net.Send(ply)

		if AddOne then
			net.Start("AdvDupe2_AddGhost")
				net.WriteBit(AddOne.Class=="prop_ragdoll")
				net.WriteString(AddOne.Model)
				net.WriteInt(#AddOne.PhysicsObjects, 8)
				for i=0, #AddOne.PhysicsObjects do
					net.WriteAngle(AddOne.PhysicsObjects[i].Angle)
					net.WriteVector(AddOne.PhysicsObjects[i].Pos)
				end
			net.Send(ply)
		else
			AdvDupe2.SendGhosts(ply) 
		end

		AdvDupe2.ResetOffsets(ply)

		return true
	end
	
	//Checks table, re-draws loading bar, and recreates ghosts when tool is pulled out
	function TOOL:Deploy()
		local ply = self:GetOwner()
		
		if ( not ply.AdvDupe2 ) then ply.AdvDupe2={} end
		
		if(not ply.AdvDupe2.Entities)then return end
		
		umsg.Start("AdvDupe2_StartGhosting", ply)
		umsg.End()
		
		if(ply.AdvDupe2.Queued)then
			AdvDupe2.InitProgressBar(ply, "Queued: ")
			return
		end
		
		if(ply.AdvDupe2.Pasting)then
			AdvDupe2.InitProgressBar(ply, "Pasting: ")
			return
		else
			if(ply.AdvDupe2.Uploading)then
				AdvDupe2.InitProgressBar(ply, "Opening: ")
				return
			elseif(ply.AdvDupe2.Downloading)then
				AdvDupe2.InitProgressBar(ply, "Saving: ")
				return
			end
		end

	end

	//Removes progress bar
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
		if(!trace.Hit)then return false end
		
		local ply = self:GetOwner()
		
		if(self:GetStage()==1)then
			if( not game.SinglePlayer() and (tonumber(ply:GetInfo("advdupe2_area_copy_size"))or 50) > tonumber(GetConVarString("AdvDupe2_MaxAreaCopySize")))then
				AdvDupe2.Notify(ply,"Area copy size exceeds limit of "..GetConVarString("AdvDupe2_MaxAreaCopySize")..".",NOTIFY_ERROR)
				return false 
			end
			umsg.Start("AdvDupe2_CanAutoSave", ply)
				umsg.Vector(trace.HitPos)
				umsg.Short(tonumber(ply:GetInfo("advdupe2_area_copy_size")) or 50)
				if(trace.Entity)then
					umsg.Short(trace.Entity:EntIndex())
				else
					umsg.Short(0)
				end
			umsg.End()
			self:SetStage(0)
			AdvDupe2.RemoveSelectBox(ply)
			ply.AdvDupe2.TempAutoSavePos = trace.HitPos
			ply.AdvDupe2.TempAutoSaveSize = tonumber(ply:GetInfo("advdupe2_area_copy_size")) or 50
			ply.AdvDupe2.TempAutoSaveOutSide = tobool(ply:GetInfo("advdupe2_copy_outside"))
			return true
		end
		
		//If a contraption spawner was clicked then update it with the current settings
		if(trace.Entity:GetClass()=="gmod_contr_spawner")then
			local delay = tonumber(ply:GetInfo("advdupe2_contr_spawner_delay"))
			local undo_delay = tonumber(ply:GetInfo("advdupe2_contr_spawner_undo_delay"))
			local min
			local max
			if(not delay)then
				delay = tonumber(GetConVarString("AdvDupe2_MinContraptionSpawnDelay")) or 0.2
			else
				if(not game.SinglePlayer())then
					min = tonumber(GetConVarString("AdvDupe2_MinContraptionSpawnDelay")) or 0.2
					if (delay < min) then
						delay = min
					end
				elseif(delay<0)then
					delay = 0
				end
			end
			
			if(not undo_delay)then
				undo_delay = tonumber(GetConVarString("AdvDupe2_MinContraptionUndoDelay"))
			else
				if(not game.SinglePlayer())then
					min = tonumber(GetConVarString("AdvDupe2_MinContraptionUndoDelay")) or 0.1
					max = tonumber(GetConVarString("AdvDupe2_MaxContraptionUndoDelay")) or 60
					if(undo_delay < min) then
						undo_delay = min
					elseif(undo_delay > max)then
						undo_delay = max
					end
				elseif(undo_delay < 0)then
					undo_delay = 0
				end
			end
			trace.Entity:GetTable():SetOptions(ply, delay, undo_delay, tonumber(ply:GetInfo("advdupe2_contr_spawner_key")), tonumber(ply:GetInfo("advdupe2_contr_spawner_undo_key")), tonumber(ply:GetInfo("advdupe2_contr_spawner_disgrav")) or 0, tonumber(ply:GetInfo("advdupe2_contr_spawner_disdrag")) or 0, tonumber(ply:GetInfo("advdupe2_contr_spawner_addvel")) or 1 )
			return true
		end

		//Create a contraption spawner
		if ply.AdvDupe2 and ply.AdvDupe2.Entities then
			local headent = ply.AdvDupe2.Entities[ply.AdvDupe2.HeadEnt.Index]
			local Pos, Ang
			
			if(headent)then
				if(tobool(ply:GetInfo("advdupe2_original_origin")))then
					Pos = ply.AdvDupe2.HeadEnt.Pos + headent.PhysicsObjects[0].Pos
					Ang = headent.PhysicsObjects[0].Angle
				else
					local EntAngle = headent.PhysicsObjects[0].Angle
					if(tobool(ply:GetInfo("advdupe2_offset_world")))then EntAngle = Angle(0,0,0) end
					trace.HitPos.Z = trace.HitPos.Z + math.Clamp(ply.AdvDupe2.HeadEnt.Z + tonumber(ply:GetInfo("advdupe2_offset_z")) or 0, -16000, 16000)
					Pos, Ang = LocalToWorld(headent.PhysicsObjects[0].Pos, EntAngle, trace.HitPos, Angle(math.Clamp(tonumber(ply:GetInfo("advdupe2_offset_pitch")) or 0,-180,180), math.Clamp(tonumber(ply:GetInfo("advdupe2_offset_yaw")) or 0,-180,180), math.Clamp(tonumber(ply:GetInfo("advdupe2_offset_roll")) or 0,-180,180))) 
				end
			else
				AdvDupe2.Notify(ply, "Invalid head entity to spawn contraption spawner.")
				return false
			end
			
			if(headent.Class=="gmod_contr_spawner") then 
				AdvDupe2.Notify(ply, "Cannot make a contraption spawner from a contraption spawner.")
				return false 
			end
		
			
			local spawner = MakeContraptionSpawner( ply, Pos, Ang, ply.AdvDupe2.HeadEnt.Index, table.Copy(ply.AdvDupe2.Entities), table.Copy(ply.AdvDupe2.Constraints), tonumber(ply:GetInfo("advdupe2_contr_spawner_delay")), tonumber(ply:GetInfo("advdupe2_contr_spawner_undo_delay")), headent.Model, tonumber(ply:GetInfo("advdupe2_contr_spawner_key")), tonumber(ply:GetInfo("advdupe2_contr_spawner_undo_key")),  tonumber(ply:GetInfo("advdupe2_contr_spawner_disgrav")) or 0, tonumber(ply:GetInfo("advdupe2_contr_spawner_disdrag")) or 0, tonumber(ply:GetInfo("advdupe2_contr_spawner_addvel")) or 1 )
			ply:AddCleanup( "AdvDupe2", spawner )
			undo.Create("gmod_contr_spawner")
				undo.AddEntity( spawner )
				undo.SetPlayer( ply )
			undo.Finish()

			return true
		end
	end	

	//Called to clean up the tool when pasting is finished or undo during pasting
	function AdvDupe2.FinishPasting(Player, Paste)
		Player.AdvDupe2.Pasting=false
		AdvDupe2.RemoveProgressBar(Player)
		if(Paste)then AdvDupe2.Notify(Player,"Finished Pasting!") end
	end
	
	function AdvDupe2.SendGhosts(ply)
		if(not ply.AdvDupe2.Entities)then return end
		
		local cache = {}
		local temp = {}
		local mdls = {}
		local cnt = 1
		local add = true
		local head

		for k,v in pairs(ply.AdvDupe2.Entities)do
			temp[cnt] = v
			for i=1,#cache do
				if(cache[i]==v.Model)then
					mdls[cnt] = i
					add=false
					break
				end
			end
			if(add)then
				mdls[cnt] = table.insert(cache, v.Model)
			else
				add = true
			end
			if(k==ply.AdvDupe2.HeadEnt.Index)then
				head = cnt
			end
			cnt = cnt+1
		end
		
		if(!head)then
			AdvDupe2.Notify(ply, "Invalid head entity for ghosts.", NOTIFY_ERROR);
			return
		end
		
		net.Start("AdvDupe2_SendGhosts")
			net.WriteInt(head, 16)
			net.WriteFloat(ply.AdvDupe2.HeadEnt.Z)
			net.WriteVector(ply.AdvDupe2.HeadEnt.Pos)
			net.WriteInt(#cache, 16)
			for i=1,#cache do
				net.WriteString(cache[i])
			end
			net.WriteInt(cnt-1, 16)
			for i=1, #temp do
				net.WriteBit(temp[i].Class=="prop_ragdoll")
				net.WriteInt(mdls[i], 16)
				net.WriteInt(#temp[i].PhysicsObjects, 8)
				for k=0, #temp[i].PhysicsObjects do
					net.WriteAngle(temp[i].PhysicsObjects[k].Angle)
					net.WriteVector(temp[i].PhysicsObjects[k].Pos)
				end
			end
		net.Send(ply)
		
	end

	//function for creating a contraption spawner
	function MakeContraptionSpawner( ply, Pos, Ang, HeadEnt, EntityTable, ConstraintTable, delay, undo_delay, model, key, undo_key, disgrav, disdrag, addvel)

		if not ply:CheckLimit("gmod_contr_spawners") then return nil end
		
		if(not game.SinglePlayer())then
			if(table.Count(EntityTable)>tonumber(GetConVarString("AdvDupe2_MaxContraptionEntities")))then
				AdvDupe2.Notify(ply,"Contraption Spawner exceeds the maximum amount of "..GetConVarString("AdvDupe2_MaxContraptionEntities").." entities for a spawner!",NOTIFY_ERROR)
				return false 
			end
			if(#ConstraintTable>tonumber(GetConVarString("AdvDupe2_MaxContraptionConstraints")))then
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
		spawner:Spawn()

		duplicator.ApplyEntityModifiers(ply, spawner)
		
		if IsValid(spawner:GetPhysicsObject()) then
			spawner:GetPhysicsObject():EnableMotion(false)
		end

		local min
		local max
		if(not delay)then
			delay = tonumber(GetConVarString("AdvDupe2_MinContraptionSpawnDelay")) or 0.2
		else
			if(not game.SinglePlayer())then
				min = tonumber(GetConVarString("AdvDupe2_MinContraptionSpawnDelay")) or 0.2
				if (delay < min) then
					delay = min
				end
			elseif(delay<0)then
				delay = 0
			end
		end
		
		if(not undo_delay)then
			undo_delay = tonumber(GetConVarString("AdvDupe2_MinContraptionUndoDelay"))
		else
			if(not game.SinglePlayer())then
				min = tonumber(GetConVarString("AdvDupe2_MinContraptionUndoDelay")) or 0.1
				max = tonumber(GetConVarString("AdvDupe2_MaxContraptionUndoDelay")) or 60
				if(undo_delay < min) then
					undo_delay = min
				elseif(undo_delay > max)then
					undo_delay = max
				end
			elseif(undo_delay < 0)then
				undo_delay = 0
			end
		end
			
		// Set options
		spawner:SetPlayer(ply)
		spawner:GetTable():SetOptions(ply, delay, undo_delay, key, undo_key, disgrav, disdrag, addvel)

		local tbl = {
			ply 		= ply,
			delay		= delay,
			undo_delay	= undo_delay,
			disgrav		= disgrav,
			disdrag 	= disdrag,
			addvel		= addvel;
		}
		table.Merge(spawner:GetTable(), tbl)
		spawner:SetDupeInfo(HeadEnt, EntityTable, ConstraintTable)
		spawner:AddGhosts(ply)

		ply:AddCount("gmod_contr_spawners", spawner)
		ply:AddCleanup("gmod_contr_spawner", spawner)
		return spawner
	end
	duplicator.RegisterEntityClass("gmod_contr_spawner", MakeContraptionSpawner, "Pos", "Ang", "HeadEnt", "EntityTable", "ConstraintTable", "delay", "undo_delay", "model", "key", "undo_key", "disgrav", "disdrag", "addvel")
	
	
	
	--[[==============]]--
	--[[FILE FUNCTIONS]]--
	--[[==============]]--
	
	if(game.SinglePlayer())then
		//Open file in SinglePlayer
		local function OpenFile(ply, cmd, args)

			if(ply.AdvDupe2.Pasting || ply.AdvDupe2.Downloading)then
				AdvDupe2.Notify(ply,"Advanced Duplicator 2 is busy.",NOTIFY_ERROR)
				return false 
			end
			
			local path, area = args[1], tonumber(args[2])
			
			if(area==0)then
				data = ply:ReadAdvDupe2File(path)
			elseif(area==1)then
				data = AdvDupe2.ReadFile(nil, "-Public-/"..path)
			else
				data = AdvDupe2.ReadFile(ply, path, "adv_duplicator")
			end
			if(data==false or data==nil)then
				AdvDupe2.Notify(ply, "File contains incorrect data!", NOTIFY_ERROR)
				return
			end
			
			local name = string.Explode("/", path)
			ply.AdvDupe2.Name = name[#name]

			AdvDupe2.Decode(data, function(success,dupe,info,moreinfo) AdvDupe2.LoadDupe(ply, success, dupe, info, moreinfo) end)
		end
		concommand.Add("AdvDupe2_OpenFile", OpenFile)
	end
	
	//Save a file to the client
	local function SaveFile(ply, cmd, args)
		if(not ply.AdvDupe2 or not ply.AdvDupe2.Entities or table.Count(ply.AdvDupe2.Entities)==0)then AdvDupe2.Notify(ply,"Duplicator is empty, nothing to save.", NOTIFY_ERROR) return end
		if(not game.SinglePlayer() and CurTime()-(ply.AdvDupe2.FileMod or 0) < 0)then 
			AdvDupe2.Notify(ply,"Cannot save at the moment. Please Wait...", NOTIFY_ERROR)
			return
		end
		
		if(ply.AdvDupe2.Pasting || ply.AdvDupe2.Downloading)then
			AdvDupe2.Notify(ply,"Advanced Duplicator 2 is busy.",NOTIFY_ERROR)
			return false 
		end

		ply.AdvDupe2.FileMod = CurTime()+tonumber(GetConVarString("AdvDupe2_FileModificationDelay")+2)
		
		local name = string.Explode("/", args[1])
		ply.AdvDupe2.Name = name[#name]
		
		net.Start("AdvDupe2_SetDupeInfo")
			net.WriteString(ply.AdvDupe2.Name)
			net.WriteString(ply:Nick())
			net.WriteString(os.date("%d %B %Y"))
			net.WriteString(os.date("%I:%M %p"))
			net.WriteString("")
			net.WriteString(args[2] or "")
			net.WriteString(table.Count(ply.AdvDupe2.Entities))
			net.WriteString(#ply.AdvDupe2.Constraints)
		net.Send(ply)
		
		local Tab = {Entities = ply.AdvDupe2.Entities, Constraints = ply.AdvDupe2.Constraints, HeadEnt = ply.AdvDupe2.HeadEnt, Description=args[2]}
		if(not game.SinglePlayer())then ply.AdvDupe2.Downloading = true end
		AdvDupe2.Encode( Tab, AdvDupe2.GenerateDupeStamp(ply), function(data)
																	if(game.SinglePlayer())then
																		local path = args[1]
																		if(args[3]~="" and args[3]~=nil)then path = args[3].."/"..path end
																		local dir, name = ply:WriteAdvDupe2File(path, data)
																		umsg.Start("AdvDupe2_AddFile", ply)
																			umsg.Bool(false)
																			umsg.String(name)
																		umsg.End()
																		if(ply:GetInfo("advdupe2_debug_openfile")=="1")then
																			if(not file.Exists(dir, "DATA"))then AdvDupe2.Notify(ply, "File does not exist", NOTIFY_ERROR) return end
																			
																			local read = file.Read(dir)
																			AdvDupe2.Decode(read, 	function(success,dupe,info,moreinfo) 
																										if(success)then
																											AdvDupe2.Notify(ply, "DEBUG CHECK: File successfully opens. No EOF errors.") 
																										else
																											AdvDupe2.Notify(ply, "DEBUG CHECK: File contains EOF errors.", NOTIFY_ERROR)
																										end
																									end)
																		end
																	else
																		if(not IsValid(ply))then return end
																		ply:ConCommand("AdvDupe2_SaveType 0")
																		timer.Simple(1, function() AdvDupe2.EstablishNetwork(ply, data) end)
																	end
																end)
	end
	concommand.Add("AdvDupe2_SaveFile", SaveFile)

		
	--[[=====================]]--
	--[[END OF FILE FUNCTIONS]]--
	--[[=====================]]--
	
	
	
	
	--[[=====================]]--
	--[[	USERMESSAGES	 ]]--
	--[[=====================]]--
	
	//Start the progress bar
	function AdvDupe2.InitProgressBar(ply,label)
		umsg.Start("AdvDupe2_InitProgressBar",ply)
			umsg.String(label)
		umsg.End()
	end
	
	//Start drawing the area copy box
	function AdvDupe2.DrawSelectBox(ply)
		umsg.Start("AdvDupe2_DrawSelectBox", ply)
		umsg.End()
	end

	//Removes the area copy box
	function AdvDupe2.RemoveSelectBox(ply)
		umsg.Start("AdvDupe2_RemoveSelectBox", ply)
		umsg.End()
	end

	//Reset the offsets of height, pitch, yaw, and roll back to default
	function AdvDupe2.ResetOffsets(ply, keep)
		
		if(not keep)then
			ply.AdvDupe2.Name = nil
		end
		umsg.Start("AdvDupe2_ResetOffsets", ply)
		umsg.End()
	end

	function AdvDupe2.UpdateProgressBar(ply, perc)
		umsg.Start("AdvDupe2_UpdateProgressBar", ply)
			umsg.Short(perc)
		umsg.End()
	end
	
	net.Receive("AdvDupe2_CanAutoSave", function(len, ply, len2)
	
		local desc = net.ReadString()
		local ent = net.ReadInt(16)
		if(ent~=0)then
			ply.AdvDupe2.AutoSaveEnt = ent
			if(ply:GetInfo("advdupe2_auto_save_contraption")=="1")then
				ply.AdvDupe2.AutoSaveEnt = ents.GetByIndex( ply.AdvDupe2.AutoSaveEnt )
			end
		else
			if(ply:GetInfo("advdupe2_auto_save_contraption")=="1")then
				AdvDupe2.Notify(ply, "No entity selected to auto save contraption.", NOTIFY_ERROR)
				return
			end
			ply.AdvDupe2.AutoSaveEnt = nil
		end
		
		ply.AdvDupe2.AutoSavePos = ply.AdvDupe2.TempAutoSavePos
		ply.AdvDupe2.AutoSaveSize = ply.AdvDupe2.TempAutoSaveSize
		ply.AdvDupe2.AutoSaveOutSide = ply.AdvDupe2.TempAutoSaveOutSide
		ply.AdvDupe2.AutoSaveContr = ply:GetInfo("advdupe2_auto_save_contraption")=="1"
		ply.AdvDupe2.AutoSaveDesc = desc
		
		local time = tonumber(ply:GetInfo("advdupe2_auto_save_time")) or 5
		if(game.SinglePlayer())then
			ply.AdvDupe2.AutoSavePath = net.ReadString()
		else
			if(time>30)then time = 30 end
			if(time<GetConVarNumber("AdvDupe2_AreaAutoSaveTime"))then time = GetConVarNumber("AdvDupe2_AreaAutoSaveTime") end
		end
		
		AdvDupe2.Notify(ply, "Your area will be auto saved every "..(time*60).." seconds.")
		local name = "AdvDupe2_AutoSave_"..ply:UniqueID()
		if(timer.Exists(name))then
			timer.Adjust(name, time*60, 0)
			return 
		end
		timer.Create(name, time*60, 0, function()
			if(not IsValid(ply))then
				timer.Remove(name)
				return
			end
			
			if(ply.AdvDupe2.Downloading)then
				AdvDupe2.Notify(ply, "Skipping auto save, tool is busy.", NOTIFY_ERROR)
				return
			end
			
			local Tab = {Entities={}, Constraints={}, HeadEnt={}}
			
			if(ply.AdvDupe2.AutoSaveContr)then
				if(not IsValid(ply.AdvDupe2.AutoSaveEnt))then
					timer.Remove(name)
					AdvDupe2.Notify(ply, "Head entity for auto save no longer valid; stopping auto save.", NOTIFY_ERROR)
					return
				end
				
				Tab.HeadEnt.Index = ply.AdvDupe2.AutoSaveEnt:EntIndex()
				Tab.HeadEnt.Pos = ply.AdvDupe2.AutoSaveEnt:GetPos()
				
				local WorldTrace = util.TraceLine( {mask=MASK_NPCWORLDSTATIC, start=Tab.HeadEnt.Pos+Vector(0,0,1), endpos=Tab.HeadEnt.Pos-Vector(0,0,50000)} )
				if(WorldTrace.Hit)then Tab.HeadEnt.Z = math.abs(Tab.HeadEnt.Pos.Z-WorldTrace.HitPos.Z) else Tab.HeadEnt.Z = 0 end
				
				AdvDupe2.duplicator.Copy( ply.AdvDupe2.AutoSaveEnt, Tab.Entities, Tab.Constraints, Tab.HeadEnt.Pos )
			else
				local i = ply.AdvDupe2.AutoSaveSize
				local Pos = ply.AdvDupe2.AutoSavePos
				local T = (Vector(i,i,i)+Pos)
				local B = (Vector(-i,-i,-i)+Pos)
				
				local Entities = FindInBox(B,T, ply)
				if(table.Count(Entities)==0)then
					AdvDupe2.Notify(ply, "Area Auto Save copied 0 entities; be sure to turn it off.", NOTIFY_ERROR)
					return
				end
				
				if(ply.AdvDupe2.AutoSaveEnt && Entities[ply.AdvDupe2.AutoSaveEnt])then
					Tab.HeadEnt.Index = ply.AdvDupe2.AutoSaveEnt
				else
					Tab.HeadEnt.Index = table.GetFirstKey(Entities)
				end
				Tab.HeadEnt.Pos = Entities[Tab.HeadEnt.Index]:GetPos()

				local WorldTrace = util.TraceLine( {mask=MASK_NPCWORLDSTATIC, start=Tab.HeadEnt.Pos+Vector(0,0,1), endpos=Tab.HeadEnt.Pos-Vector(0,0,50000)} )
				if(WorldTrace.Hit)then Tab.HeadEnt.Z = math.abs(Tab.HeadEnt.Pos.Z-WorldTrace.HitPos.Z) else Tab.HeadEnt.Z = 0 end

				Tab.Entities, Tab.Constraints = AdvDupe2.duplicator.AreaCopy(Entities, Tab.HeadEnt.Pos, ply.AdvDupe2.AutoSaveOutSide)
			end
			Tab.Constraints = CollapseTableToArray(Tab.Constraints)
			Tab.Description = ply.AdvDupe2.AutoSaveDesc

			if(not game.SinglePlayer())then ply.AdvDupe2.Downloading = true end
			AdvDupe2.Encode( Tab, AdvDupe2.GenerateDupeStamp(ply), function(data)
																		if(game.SinglePlayer())then
																			
																			local dir, name = ""
																			if(ply:GetInfo("advdupe2_auto_save_overwrite")=="1")then
																				file.Write("advdupe2/"..ply.AdvDupe2.AutoSavePath..".txt", data)
																				name = string.Explode("/", ply.AdvDupe2.AutoSavePath)
																				name = name[#name]
																			else
																				dir, name = ply:WriteAdvDupe2File(ply.AdvDupe2.AutoSavePath, data)
																			end
																			umsg.Start("AdvDupe2_AddFile", ply)
																				umsg.Bool(true)
																				umsg.String(name)
																			umsg.End()
																			AdvDupe2.Notify(ply, "Area auto saved.")
																		else
																			if(not IsValid(ply))then return end
																			ply:ConCommand("AdvDupe2_SaveType 1")
																			timer.Simple(1, function() AdvDupe2.EstablishNetwork(ply, data) end)
																		end
																	end)
			ply.AdvDupe2.FileMod = CurTime()+tonumber(GetConVarString("AdvDupe2_FileModificationDelay"))
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
		if(not ply:IsAdmin())then
			AdvDupe2.Notify(ply, "You do not have permission to this function.", NOTIFY_ERROR)
			return
		end
		
		local Entities = ents.GetAll()
		for k,v in pairs(Entities) do
			if v:CreatedByMap() or not duplicator.IsAllowed(v:GetClass()) then
				Entities[k]=nil
			end
		end
		
		if(table.Count(Entities)==0)then return end
		
		local Tab = {Entities={}, Constraints={}, HeadEnt={}, Description=""}
		Tab.HeadEnt.Index = table.GetFirstKey(Entities)
		Tab.HeadEnt.Pos = Entities[Tab.HeadEnt.Index]:GetPos()

		local WorldTrace = util.TraceLine( {mask=MASK_NPCWORLDSTATIC, start=Tab.HeadEnt.Pos+Vector(0,0,1), endpos=Tab.HeadEnt.Pos-Vector(0,0,50000)} )
		if(WorldTrace.Hit)then Tab.HeadEnt.Z = math.abs(Tab.HeadEnt.Pos.Z-WorldTrace.HitPos.Z) else Tab.HeadEnt.Z = 0 end
		Tab.Entities, Tab.Constraints = AdvDupe2.duplicator.AreaCopy(Entities, Tab.HeadEnt.Pos, true)
		Tab.Constraints = CollapseTableToArray(Tab.Constraints)
		
		Tab.Map = true
		AdvDupe2.Encode( Tab, AdvDupe2.GenerateDupeStamp(ply), 	function(data)
																	if(not file.IsDir("advdupe2_maps", "DATA"))then
																		file.CreateDir("advdupe2_maps")
																	end
																	file.Write("advdupe2_maps/"..args[1]..".txt", data)	
																	AdvDupe2.Notify(ply, "Map save, saved successfully.")
																end)
		
	end)
end

if(CLIENT)then

	function TOOL:LeftClick(trace)
		if(trace and AdvDupe2.HeadGhost)then
			return true
		end
		return false
	end
	
	function TOOL:RightClick(trace)
		if( self:GetOwner():KeyDown(IN_SPEED) and not self:GetOwner():KeyDown(IN_WALK) )then
			return false
		end
		return true
	end
	
	//Removes progress bar and removes ghosts when tool is put away
	function TOOL:Holster()
		AdvDupe2.RemoveGhosts()
		AdvDupe2.RemoveSelectBox()
		if(AdvDupe2.Rotation)then
			hook.Remove("PlayerBindPress", "AdvDupe2_BindPress")
		end
		return 
	end
	
	function TOOL:Reload( trace )
		if(trace and (AdvDupe2.HeadGhost || self:GetStage()==1))then
			return true
		end
		return false
	end

	//Take control of the mouse wheel bind so the player can modify the height of the dupe
	local function MouseWheelScrolled(ply, bind, pressed)

		if(bind=="invprev")then
			if(ply:GetTool("advdupe2"):GetStage()==1)then
				local size = tonumber(ply:GetInfo("advdupe2_area_copy_size")) + 25
				if(size>GetConVarNumber("AdvDupe2_MaxAreaCopySize"))then return end
				RunConsoleCommand("advdupe2_area_copy_size",size)
			else
				local Z = tonumber(ply:GetInfo("advdupe2_offset_z")) + 5
				RunConsoleCommand("advdupe2_offset_z",Z)
			end
			return true
		elseif(bind=="invnext")then
			if(ply:GetTool("advdupe2"):GetStage()==1)then
				local size = tonumber(ply:GetInfo("advdupe2_area_copy_size")) - 25
				if(size<50)then size = 50 end
				RunConsoleCommand("advdupe2_area_copy_size",size)
			else
				local Z = tonumber(ply:GetInfo("advdupe2_offset_z")) - 5
				RunConsoleCommand("advdupe2_offset_z",Z)
			end
			return true
		end
		
		GAMEMODE:PlayerBindPress(ply, bind, pressed)
	end
	
	local XTotal = 0
	local YTotal = 0
	local LastXDegree = 0
	local function MouseControl( cmd )
		local X = -cmd:GetMouseX()/-20
		local Y = cmd:GetMouseY()/-20

		local X2 = 0
		local Y2 = 0
		
		if(X~=0)then	
			X2 = tonumber(LocalPlayer():GetInfo("advdupe2_offset_yaw"))
			
			if(LocalPlayer():KeyDown(IN_SPEED))then
				XTotal = XTotal + X
				local temp = XTotal + X2
				
				local degree = math.Round(temp/45)*45
				if(degree>=225)then
					degree = -135
				elseif(degree<=-225)then
					degree = 135
				end
				if(degree~=LastXDegree)then
					XTotal = 0
					LastXDegree = degree
				end
				
				X2 = degree
			else
				X2 = X2 + X
				if(X2<-180)then
					X2 = X2+360
				elseif(X2>180)then
					X2 = X2-360
				end
			end
			RunConsoleCommand("advdupe2_offset_yaw", X2)
		end
		
		/*if(Y~=0)then
			local modyaw = LocalPlayer():GetAngles().y
			local modyaw2 = tonumber(LocalPlayer():GetInfo("advdupe2_offset_yaw"))
			
			if(modyaw<0)then modyaw = modyaw + 360 else modyaw = modyaw + 180 end
			if(modyaw2<0)then modyaw2 = modyaw2 + 360 else modyaw2 = modyaw2 + 180 end
			
			modyaw = modyaw - modyaw2
			local modyaw3 = modyaw
			if(modyaw3<0)then
				modyaw3 = modyaw3 * -1
			end
			
			local pitch = tonumber(LocalPlayer():GetInfo("advdupe2_offset_pitch"))
			local roll = tonumber(LocalPlayer():GetInfo("advdupe2_offset_roll"))
			
				//print(modyaw3)
			if(modyaw3 <= 90)then
				pitch = pitch + (Y - Y * (modyaw3/90))
				roll = roll - (Y*(modyaw3/90))
			end
			
			//if(pitch>180)then pitch = -180
			
			RunConsoleCommand("advdupe2_offset_pitch",pitch)
			RunConsoleCommand("advdupe2_offset_roll",roll)
		end*/
		
	end

	//Update the ghost's postion and angles based on where the player is looking and the offsets
	local Utrace, UGhostEnt, UEntAngle, UPos, UAngle
	local function UpdateGhost()
		Utrace = util.TraceLine(util.GetPlayerTrace(LocalPlayer(), LocalPlayer():GetAimVector()))
		if (not Utrace.Hit) then return end

		UGhostEnt = AdvDupe2.HeadGhost
		
		if(not IsValid(UGhostEnt))then
			AdvDupe2.RemoveGhosts()
			AdvDupe2.Notify("Invalid ghost parent.", NOTIFY_ERROR)
			return 
		end
		
		if(tobool(GetConVarNumber("advdupe2_original_origin")))then
			UGhostEnt:SetPos(AdvDupe2.HeadPos + AdvDupe2.HeadOffset)
			UGhostEnt:SetAngles(AdvDupe2.HeadAngle)
		else
			UEntAngle = AdvDupe2.HeadAngle
			if(tobool(GetConVarNumber("advdupe2_offset_world")))then UEntAngle = Angle(0,0,0) end
			Utrace.HitPos.Z = Utrace.HitPos.Z + math.Clamp(AdvDupe2.HeadZPos + GetConVarNumber("advdupe2_offset_z") or 0, -16000, 16000)
			UPos, UAngle = LocalToWorld(AdvDupe2.HeadOffset, UEntAngle, Utrace.HitPos, Angle(math.Clamp(GetConVarNumber("advdupe2_offset_pitch") or 0,-180,180), math.Clamp(GetConVarNumber("advdupe2_offset_yaw") or 0,-180,180), math.Clamp(GetConVarNumber("advdupe2_offset_roll") or 0,-180,180))) 
			UGhostEnt:SetPos(UPos)
			UGhostEnt:SetAngles(UAngle)
		end
	end

	//Checks binds to modify dupes position and angles
	function TOOL:Think()

		if(AdvDupe2.HeadGhost)then UpdateGhost() end
		
		if(LocalPlayer():KeyDown(IN_USE))then
			if(not AdvDupe2.Rotation)then
				hook.Add("PlayerBindPress", "AdvDupe2_BindPress", MouseWheelScrolled)
				hook.Add("CreateMove", "AdvDupe2_MouseControl", MouseControl)
				AdvDupe2.Rotation = true
			end
		else
			if(AdvDupe2.Rotation)then
				AdvDupe2.Rotation = false
				hook.Remove("PlayerBindPress", "AdvDupe2_BindPress")
				hook.Remove("CreateMove", "AdvDupe2_MouseControl")
			end
			
			XTotal = 0
			YTotal = 0
			LastXDegree = 0
			
			return
		end
	end
	
	//Hinder the player from looking to modify offsets with the mouse
	function TOOL:FreezeMovement()
		return AdvDupe2.Rotation
	end

	language.Add( "Tool.advdupe2.name",	"Advanced Duplicator 2" )
	language.Add( "Tool.advdupe2.desc",	"Duplicate things." )
	language.Add( "Tool.advdupe2.0",		"Primary: Paste, Secondary: Copy, Secondary+World: Select/Deselect All, Secondary+Shift: Area copy." )
	language.Add( "Tool.advdupe2.1",		"Primary: Paste, Secondary: Copy an area, Secondary+Shift: Cancel." )
	language.Add( "Undone.AdvDupe2",	"Undone AdvDupe2 paste" )
	language.Add( "Cleanup.AdvDupe2",	"Adv. Duplications" )
	language.Add( "Cleaned.AdvDupe2",	"Cleaned up all Adv. Duplications" )
	language.Add( "SBoxLimit.AdvDupe2",	"You've reached the Adv. Duplicator limit!" )
	
	CreateClientConVar("advdupe2_offset_world", 0, false, true)
	CreateClientConVar("advdupe2_offset_z", 0, false, true)
	CreateClientConVar("advdupe2_offset_pitch", 0, false, true)
	CreateClientConVar("advdupe2_offset_yaw", 0, false, true)
	CreateClientConVar("advdupe2_offset_roll", 0, false, true)
	CreateClientConVar("advdupe2_original_origin", 0, false, true)
	CreateClientConVar("advdupe2_paste_constraints", 1, false, true)
	CreateClientConVar("advdupe2_paste_parents", 1, false, true)
	CreateClientConVar("advdupe2_paste_unfreeze", 0, false, true)
	CreateClientConVar("advdupe2_preserve_freeze", 0, false, true)
	CreateClientConVar("advdupe2_copy_outside", 0, false, true)
	CreateClientConVar("advdupe2_copy_only_mine", 1, false, true)
	CreateClientConVar("advdupe2_limit_ghost", 100, false, true)
	CreateClientConVar("advdupe2_area_copy_size", 300, false, true)
	CreateClientConVar("advdupe2_auto_save_contraption", 0, false, true)
	CreateClientConVar("advdupe2_auto_save_overwrite", 1, false, true)
	CreateClientConVar("advdupe2_auto_save_time", 10, false, true)
	
	//Contraption Spawner
	CreateClientConVar("advdupe2_contr_spawner_key", -1, false, true)
	CreateClientConVar("advdupe2_contr_spawner_undo_key", -1, false, true)
	CreateClientConVar("advdupe2_contr_spawner_delay", 0, false, true)
	CreateClientConVar("advdupe2_contr_spawner_undo_delay", 10, false, true)
	CreateClientConVar("advdupe2_contr_spawner_disgrav", 0, false, true)
	CreateClientConVar("advdupe2_contr_spawner_disdrag", 0, false, true)
	CreateClientConVar("advdupe2_contr_spawner_addvel", 1, false, true)
	
	//Experimental
	CreateClientConVar("advdupe2_paste_disparents", 0, false, true)
	CreateClientConVar("advdupe2_paste_protectoveride", 1, false, true)
	CreateClientConVar("advdupe2_debug_openfile", 1, false, true)
	
	local function BuildCPanel()
		local CPanel = controlpanel.Get("advdupe2")
		
		if not CPanel then return end
		CPanel:ClearControls()
		
		if(!file.Exists("advdupe2", "DATA"))then
			file.CreateDir("advdupe2")
		end
		
		local FileBrowser = vgui.Create("advdupe2_browser")
		CPanel:AddItem(FileBrowser)
		FileBrowser:SetSize(CPanel:GetWide(),405)
		AdvDupe2.FileBrowser = FileBrowser
		
		local Check = vgui.Create("DCheckBoxLabel")
		
		Check:SetText( "Paste at original position" )
		Check:SetTextColor(Color(0,0,0,255))
		Check:SetConVar( "advdupe2_original_origin" ) 
		Check:SetValue( 0 )
		Check:SetToolTip("Paste at the position originally copied")
		CPanel:AddItem(Check)
		
		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Paste with constraints" )
		Check:SetTextColor(Color(0,0,0,255))
		Check:SetConVar( "advdupe2_paste_constraints" ) 
		Check:SetValue( 1 )
		Check:SetToolTip("Paste with or without constraints")
		CPanel:AddItem(Check)
		
		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Paste with parenting" )
		Check:SetTextColor(Color(0,0,0,255))
		Check:SetConVar( "advdupe2_paste_parents" ) 
		Check:SetValue( 1 )
		Check:SetToolTip("Paste with or without parenting")
		CPanel:AddItem(Check)
		
		local Check_1 = vgui.Create("DCheckBoxLabel")
		local Check_2 = vgui.Create("DCheckBoxLabel")
		
		Check_1:SetText( "Unfreeze all after paste" )
		Check_1:SetTextColor(Color(0,0,0,255))
		Check_1:SetConVar( "advdupe2_paste_unfreeze" ) 
		Check_1:SetValue( 0 )
		Check_1.OnChange = 	function() 
								if(Check_1:GetChecked() and Check_2:GetChecked())then
									Check_2:SetValue(0)
								end
							end
		Check_1:SetToolTip("Unfreeze all props after pasting")
		CPanel:AddItem(Check_1)
		
		Check_2:SetText( "Preserve frozen state after paste" )
		Check_2:SetTextColor(Color(0,0,0,255))
		Check_2:SetConVar( "advdupe2_preserve_freeze" ) 
		Check_2:SetValue( 0 )
		Check_2.OnChange = 	function() 
								if(Check_2:GetChecked() and Check_1:GetChecked())then
									Check_1:SetValue(0)
								end
							end
		Check_2:SetToolTip("Makes props have the same frozen state as when they were copied")
		CPanel:AddItem(Check_2)
		
		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Area copy constrained props outside of box" )
		Check:SetTextColor(Color(0,0,0,255))
		Check:SetConVar( "advdupe2_copy_outside" ) 
		Check:SetValue( 0 )
		Check:SetToolTip("Copy entities outside of the area copy that are constrained to entities insde")
		CPanel:AddItem(Check)
		
		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "World/Area copy only your own props" )
		Check:SetTextColor(Color(0,0,0,255))
		Check:SetConVar( "advdupe2_copy_only_mine" ) 
		Check:SetValue( 1 )
		Check:SetToolTip("Copy entities outside of the area copy that are constrained to entities insde")
		CPanel:AddItem(Check)

		local NumSlider = vgui.Create( "DNumSlider" )
		NumSlider:SetText( "Ghost Percentage:" )
		NumSlider.Label:SetTextColor(Color(0,0,0,255))
		NumSlider:SetMin( 0 )
		NumSlider:SetMax( 100 )
		NumSlider:SetDecimals( 0 )
		NumSlider:SetConVar( "advdupe2_limit_ghost" )
		NumSlider:SetToolTip("Change the percent of ghosts to spawn")
		//If these funcs are not here, problems occur for each
		local func = NumSlider.Slider.OnMouseReleased
		NumSlider.Slider.OnMouseReleased = function(self, mcode) func(self, mcode) AdvDupe2.StartGhosting() end
		local func2 = NumSlider.Slider.Knob.OnMouseReleased
		NumSlider.Slider.Knob.OnMouseReleased = function(self, mcode) func2(self, mcode) AdvDupe2.StartGhosting() end
		local func3 = NumSlider.Wang.Panel.OnLoseFocus
		NumSlider.Wang.Panel.OnLoseFocus = function(txtBox) func3(txtBox) AdvDupe2.StartGhosting() end
		CPanel:AddItem(NumSlider)
		
		NumSlider = vgui.Create( "DNumSlider" )
		NumSlider:SetText( "Area Copy Size:" )
		NumSlider.Label:SetTextColor(Color(0,0,0,255))
		NumSlider:SetMin( 0 )
		local size = GetConVarNumber("AdvDupe2_MaxAreaCopySize") or 2500
		if(size == 0)then size = 2500 end
		NumSlider:SetMax( size )
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
			CategoryContent1.OnMouseWheeled = function(self, dlta) parent:OnMouseWheeled(dlta) end		//Fix the damned mouse not scrolling when it's over the catagories
			
			Category1:SetContents( CategoryContent1 )

					
			NumSlider = vgui.Create( "DNumSlider" )
			NumSlider:SetText( "Height Offset" )
			NumSlider.Label:SetTextColor(Color(0,0,0,255))
			NumSlider:SetMin( 0 )
			NumSlider:SetMax( 2500 ) 
			NumSlider:SetDecimals( 0 ) 
			NumSlider:SetConVar("advdupe2_offset_z")
			NumSlider:SetToolTip("Change the Z offset of the dupe")
			CategoryContent1:AddItem(NumSlider)
			
			Check = vgui.Create("DCheckBoxLabel")
			Check:SetText( "Use World Angles" )
			Check:SetTextColor(Color(0,0,0,255))
			Check:SetConVar( "advdupe2_offset_world" ) 
			Check:SetValue( 0 )
			Check:SetToolTip("Use world angles for the offset instead of the main entity")
			CategoryContent1:AddItem(Check)
			
			NumSlider = vgui.Create( "DNumSlider" )
			NumSlider:SetText( "Pitch Offset" )
			NumSlider.Label:SetTextColor(Color(0,0,0,255))
			NumSlider:SetMin( -180 ) 
			NumSlider:SetMax( 180 ) 
			NumSlider:SetDecimals( 0 ) 
			NumSlider:SetConVar("advdupe2_offset_pitch")
			CategoryContent1:AddItem(NumSlider)
					
			NumSlider = vgui.Create( "DNumSlider" )
			NumSlider:SetText( "Yaw Offset" )
			NumSlider.Label:SetTextColor(Color(0,0,0,255))
			NumSlider:SetMin( -180 )
			NumSlider:SetMax( 180 )
			NumSlider:SetDecimals( 0 )
			NumSlider:SetConVar("advdupe2_offset_yaw")
			CategoryContent1:AddItem(NumSlider)
					
			NumSlider = vgui.Create( "DNumSlider" )
			NumSlider:SetText( "Roll Offset" )
			NumSlider.Label:SetTextColor(Color(0,0,0,255))
			NumSlider:SetMin( -180 )
			NumSlider:SetMax( 180 )
			NumSlider:SetDecimals( 0 )
			NumSlider:SetConVar("advdupe2_offset_roll")
			CategoryContent1:AddItem(NumSlider)
			
			local Btn = vgui.Create("DButton")
			Btn:SetText("Reset")
			Btn.DoClick =	function()
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
			lbl:SetText("File: ")
			lbl:SetTextColor(Color(0,0,0,255))
			CategoryContent2:AddItem(lbl)
			AdvDupe2.Info.File = lbl
			
			lbl = vgui.Create( "DLabel" )
			lbl:SetText("Creator:")
			lbl:SetTextColor(Color(0,0,0,255))
			CategoryContent2:AddItem(lbl)
			AdvDupe2.Info.Creator = lbl
			
			lbl = vgui.Create( "DLabel" )
			lbl:SetText("Date:")
			lbl:SetTextColor(Color(0,0,0,255))
			CategoryContent2:AddItem(lbl)
			AdvDupe2.Info.Date = lbl
			
			lbl = vgui.Create( "DLabel" )
			lbl:SetText("Time:")
			lbl:SetTextColor(Color(0,0,0,255))
			CategoryContent2:AddItem(lbl)
			AdvDupe2.Info.Time = lbl
			
			lbl = vgui.Create( "DLabel" )
			lbl:SetText("Size:")
			lbl:SetTextColor(Color(0,0,0,255))
			CategoryContent2:AddItem(lbl)
			AdvDupe2.Info.Size = lbl
			
			lbl = vgui.Create( "DLabel" )
			lbl:SetText("Desc:")
			lbl:SetTextColor(Color(0,0,0,255))
			CategoryContent2:AddItem(lbl)
			AdvDupe2.Info.Desc = lbl
			
			lbl = vgui.Create( "DLabel" )
			lbl:SetText("Entities:")
			lbl:SetTextColor(Color(0,0,0,255))
			CategoryContent2:AddItem(lbl)
			AdvDupe2.Info.Entities = lbl
			
			lbl = vgui.Create( "DLabel" )
			lbl:SetText("Constraints:")
			lbl:SetTextColor(Color(0,0,0,255))
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
			NumSlider.Label:SetTextColor(Color(0,0,0,255))
			if(game.SinglePlayer())then
				NumSlider:SetMin( 0 )
			else
				local min = tonumber(GetConVarString("AdvDupe2_MinContraptionSpawnDelay")) or 0.2
				if(tonumber(LocalPlayer():GetInfo("advdupe2_contr_spawner_delay"))<min)then
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
			NumSlider.Label:SetTextColor(Color(0,0,0,255))
			if(game.SinglePlayer())then 
				NumSlider:SetMin( 0 )
				NumSlider:SetMax( 60 )
			else
				local min = tonumber(GetConVarString("AdvDupe2_MinContraptionUndoDelay")) or 10
				local max = tonumber(GetConVarString("AdvDupe2_MaxContraptionUndoDelay")) or 60
				if(tonumber(LocalPlayer():GetInfo("advdupe2_contr_spawner_undo_delay")) < min)then
					RunConsoleCommand("advdupe2_contr_spawner_undo_delay", tostring(min))
				elseif(tonumber(LocalPlayer():GetInfo("advdupe2_contr_spawner_undo_delay")) > max)then
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
			Check:SetTextColor(Color(0,0,0,255))
			Check:SetConVar( "advdupe2_contr_spawner_disgrav" ) 
			Check:SetValue( 0 )
			CategoryContent3:AddItem(Check)
					
			Check = vgui.Create("DCheckBoxLabel")
			Check:SetText( "Disable drag for all spawned props" )
			Check:SetTextColor(Color(0,0,0,255))
			Check:SetConVar( "advdupe2_contr_spawner_disdrag" ) 
			Check:SetValue( 0 )
			CategoryContent3:AddItem(Check)
					
			Check = vgui.Create("DCheckBoxLabel")
			Check:SetText( "Add spawner's velocity to contraption" )
			Check:SetTextColor(Color(0,0,0,255))
			Check:SetConVar( "advdupe2_contr_spawner_addvel" ) 
			Check:SetValue( 1 )
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
			Check:SetTextColor(Color(0,0,0,255))
			Check:SetConVar( "advdupe2_auto_save_contraption" ) 
			Check:SetValue( 0 )
			Check:SetToolTip("Only copy a contraption instead of an area")
			CategoryContent4:AddItem(Check)
			
			Check = vgui.Create("DCheckBoxLabel")
			Check:SetText( "Overwrite File" )
			Check:SetTextColor(Color(0,0,0,255))
			Check:SetConVar( "advdupe2_auto_save_overwrite" )
			Check:SetValue( 1 )
			Check:SetToolTip("Overwrite the file instead of creating a new one everytime")
			CategoryContent4:AddItem(Check)
			
			NumSlider = vgui.Create( "DNumSlider" )
			NumSlider:SetText( "Minutes to Save:" )
			NumSlider.Label:SetTextColor(Color(0,0,0,255))
			NumSlider:SetMin( GetConVarNumber("AdvDupe2_AreaAutoSaveTime") )
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
			label:SetTextColor(Color(0,0,0,255))
			label:SetPos(5,7)
			
			AdvDupe2.AutoSavePath = ""
			local txtbox = vgui.Create("DTextEntry", pnl)
			txtbox:SetWide(pnl:GetWide()-100)
			txtbox:SetPos(60, 5)
			txtbox:SetUpdateOnType(true)
			txtbox.OnTextChanged = 	function(self)
										self:SetValue(AdvDupe2.AutoSavePath)
									end
			
			local btn = vgui.Create("DImageButton", pnl)
			local x, y = txtbox:GetPos()
			btn:SetPos(x + txtbox:GetWide() + 5, 7)
			btn:SetMaterial("icon16/folder_explore.png")
			btn:SizeToContents()
			btn:SetToolTip("Browse")
			btn.DoClick = 	function()
								local ScrollBar = parent.VBar
								ScrollBar:AnimateTo(0, 1, 0, 0.2)
								
								FileBrowser.Submit:SetMaterial("icon16/disk.png")
								FileBrowser.Submit:SetTooltip("Directory for Area Auto Save")
								if(FileBrowser.FileName:GetValue()=="Folder_Name...")then
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
																	if(name=="" or name=="File_Name...")then
																		AdvDupe2.Notify("Name field is blank.", NOTIFY_ERROR)
																		FileBrowser.FileName:SelectAllOnFocus(true)
																		FileBrowser.FileName:OnGetFocus()
																		FileBrowser.FileName:RequestFocus()
																		return 
																	end 
																	local desc = FileBrowser.Desc:GetValue()
																	if(desc=="Description...")then desc="" end
																	
																	if(not IsValid(FileBrowser.Browser.pnlCanvas.m_pSelectedItem) or FileBrowser.Browser.pnlCanvas.m_pSelectedItem.Derma.ClassName~="advdupe2_browser_folder")then
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
			btn.DoClick = 	function()
								if(AdvDupe2.AutoSavePos)then
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
			btn.DoClick = 	function(self)
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
			Check:SetTextColor(Color(0,0,0,255))
			Check:SetConVar( "advdupe2_paste_disparents" ) 
			Check:SetValue( 0 )
			CategoryContent5:AddItem(Check)
			
			Check = vgui.Create("DCheckBoxLabel")
			Check:SetText( "Disable Dupe Spawn Protection" )
			Check:SetTextColor(Color(0,0,0,255))
			Check:SetConVar( "advdupe2_paste_protectoveride" ) 
			Check:SetValue( 1 )
			Check:SetToolTip("Check this if you things don't look right after pasting.")
			CategoryContent5:AddItem(Check)
			
			Check = vgui.Create("DCheckBoxLabel")
			Check:SetText( "Open file after Saving" )
			Check:SetTextColor(Color(0,0,0,255))
			Check:SetConVar( "advdupe2_debug_openfile" ) 
			Check:SetValue( 1 )
			Check:SetToolTip("Check this if you want your files to be opened after saving them.")
			CategoryContent5:AddItem(Check)
			
		--[[Save Map]]--
			if(LocalPlayer():IsAdmin())then
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
				label:SetTextColor(Color(0,0,0,255))
				label:SetPos(5,7)
				
				AdvDupe2.AutoSavePath = ""
				
				local txtbox2 = vgui.Create("DTextEntry", pnl)
				txtbox2:SetWide(pnl:GetWide()-100)
				txtbox2:SetPos(60, 5)
				txtbox2.OnEnter =	function()
										btn2:DoClick()	
									end
									
				local btn2 = vgui.Create("DImageButton", pnl)
				x, y = txtbox2:GetPos()
				btn2:SetPos(x + txtbox2:GetWide() + 5, 7)
				btn2:SetMaterial("icon16/disk.png")
				btn2:SizeToContents()
				btn2:SetToolTip("Save Map")
				btn2.DoClick = 	function()
									if(txtbox2:GetValue()=="")then return end
									RunConsoleCommand("AdvDupe2_SaveMap", txtbox2:GetValue())
								end
			end
			
	end
	
	function TOOL.BuildCPanel(panel)
		panel:ClearControls()
		panel:AddControl("Header", {
			Text = "Advanced Duplicator 2",
			Description = "Duplicate stuff."
		})
		timer.Simple(0, BuildCPanel)	
	end
	
	function AdvDupe2.RemoveGhosts()
		
		if(AdvDupe2.Ghosting)then
			hook.Remove("Tick", "AdvDupe2_SpawnGhosts")
			if(AdvDupe2.Preview)then
				if(AdvDupe2.PHeadEnt)then
					AdvDupe2.HeadEnt = AdvDupe2.PHeadEnt
					AdvDupe2.HeadZPos = AdvDupe2.PHeadZPos
					AdvDupe2.HeadPos = AdvDupe2.PHeadPos*1
					AdvDupe2.HeadOffset = AdvDupe2.PHeadOffset*1
					AdvDupe2.HeadAngle = AdvDupe2.PHeadAngle*1
					AdvDupe2.GhostToSpawn = table.Copy(AdvDupe2.GhostToPreview)
				end
				AdvDupe2.PHeadEnt = nil
				AdvDupe2.PHeadZPos = nil
				AdvDupe2.PHeadPos = nil
				AdvDupe2.PHeadOffset = nil
				AdvDupe2.PHeadAngle = nil
				AdvDupe2.GhostToPreview = nil
				AdvDupe2.Preview=false
			end
			AdvDupe2.Ghosting = false 
			if(not AdvDupe2.BusyBar)then
				AdvDupe2.RemoveProgressBar()
			end
		end

		if(AdvDupe2.GhostEntities)then
			for k,v in pairs(AdvDupe2.GhostEntities)do
				if(IsValid(v))then
					v:Remove()
				end
			end
		end

		if(IsValid(AdvDupe2.HeadGhost))then
			AdvDupe2.HeadGhost:Remove()
		end
		AdvDupe2.HeadGhost = nil
		AdvDupe2.CurrentGhost = 1
		AdvDupe2.GhostEntities = nil
	end
	
	//Creates a ghost from the given entity's table
	local function MakeGhostsFromTable(EntTable, gParent)

		if(not EntTable)then return end
		if(not EntTable.Model or EntTable.Model=="" or EntTable.Model[#EntTable.Model-3]~=".")then EntTable.Model="models/error.mdl" end

		local GhostEntity = ClientsideModel(EntTable.Model, RENDERGROUP_TRANSLUCENT)
		
		// If there are too many entities we might not spawn..
		if not IsValid(GhostEntity) then 
			AdvDupe2.RemoveGhosts()
			AdvDupe2.Notify("Too many entities to spawn ghosts", NOTIFY_ERROR)
			return 
		end
		
		local Phys = EntTable.PhysicsObjects[0]
		
		GhostEntity:SetRenderMode( RENDERMODE_TRANSALPHA )	//Was broken, making ghosts invisible
		GhostEntity:SetColor( Color(255, 255, 255, 150) )

		// If we're a ragdoll send our bone positions
		/*if (EntTable.R) then
			for k, v in pairs( EntTable.PhysicsObjects ) do
				if(k==0)then
					GhostEntity:SetNetworkedBonePosition( k, Vector(0,0,0), v.Angle )
				else
					GhostEntity:SetNetworkedBonePosition( k, v.Pos, v.Angle )
				end
			end	
			Phys.Angle = Angle(0,0,0)
		end*/
		
		if ( gParent ) then
			local Parent = AdvDupe2.HeadGhost
			local temp = Parent:GetAngles()
			GhostEntity:SetPos(Parent:GetPos() + Phys.Pos - AdvDupe2.HeadOffset)
			GhostEntity:SetAngles(Phys.Angle)
			Parent:SetAngles(AdvDupe2.HeadAngle)
			GhostEntity:SetParent(Parent)
			Parent:SetAngles(temp)
		else
			GhostEntity:SetAngles(Phys.Angle)
		end
		
		return GhostEntity
	end
	
	local gTemp = 0
	local gPerc = 0
	local function SpawnGhosts()
		AdvDupe2.CurrentGhost = AdvDupe2.CurrentGhost + math.floor(gPerc)
		gTemp = gTemp + gPerc - math.floor(gPerc)
		if(gTemp>1)then
			AdvDupe2.CurrentGhost = AdvDupe2.CurrentGhost + 1
			gTemp = gTemp - math.floor(gTemp)
		end
		if(AdvDupe2.CurrentGhost==AdvDupe2.HeadEnt)then AdvDupe2.CurrentGhost = AdvDupe2.CurrentGhost + 1 end
		
		local g = AdvDupe2.GhostToSpawn[AdvDupe2.CurrentGhost]
		if(not g)then
			AdvDupe2.Ghosting = false
			hook.Remove("Tick", "AdvDupe2_SpawnGhosts")
			if(not AdvDupe2.BusyBar)then
				AdvDupe2.RemoveProgressBar()
			end
			return
		end
		AdvDupe2.GhostEntities[AdvDupe2.CurrentGhost] = MakeGhostsFromTable(g, true)
		if(not AdvDupe2.BusyBar)then
			AdvDupe2.ProgressBar.Percent = AdvDupe2.CurrentGhost/AdvDupe2.TotalGhosts*100
		end
	end
	
	net.Receive("AdvDupe2_SendGhosts", 	function(len, ply, len2)
											AdvDupe2.RemoveGhosts()
											if(AdvDupe2.Preview)then
												AdvDupe2.PHeadEnt = nil
												AdvDupe2.PHeadZPos = nil
												AdvDupe2.PHeadPos = nil
												AdvDupe2.PHeadOffset = nil
												AdvDupe2.PHeadAngle = nil
												AdvDupe2.GhostToPreview = nil
												AdvDupe2.Preview=false
											end
											AdvDupe2.Ghosting = true
											AdvDupe2.GhostToSpawn = {}
											AdvDupe2.HeadEnt = net.ReadInt(16)
											AdvDupe2.HeadZPos = net.ReadFloat()
											AdvDupe2.HeadPos = net.ReadVector()
											local cache = {}
											for i=1, net.ReadInt(16) do
												cache[i] = net.ReadString()
											end
											
											for i=1, net.ReadInt(16) do
												AdvDupe2.GhostToSpawn[i] = {R = net.ReadBit()==1, Model = cache[net.ReadInt(16)], PhysicsObjects = {}}
												for k=0, net.ReadInt(8) do
													AdvDupe2.GhostToSpawn[i].PhysicsObjects[k] = {Angle = net.ReadAngle(), Pos = net.ReadVector()}
												end
											end
											AdvDupe2.GhostEntities = {}
											AdvDupe2.HeadGhost = MakeGhostsFromTable(AdvDupe2.GhostToSpawn[AdvDupe2.HeadEnt])
											AdvDupe2.HeadOffset = AdvDupe2.GhostToSpawn[AdvDupe2.HeadEnt].PhysicsObjects[0].Pos
											AdvDupe2.HeadAngle = AdvDupe2.GhostToSpawn[AdvDupe2.HeadEnt].PhysicsObjects[0].Angle
											AdvDupe2.GhostEntities[AdvDupe2.HeadEnt] = AdvDupe2.HeadGhost	
											AdvDupe2.CurrentGhost = 0
											AdvDupe2.TotalGhosts = table.Count(AdvDupe2.GhostToSpawn)
											
											if(AdvDupe2.TotalGhosts>1)then
												gTemp = 0
												gPerc = AdvDupe2.TotalGhosts*(GetConVarNumber("advdupe2_limit_ghost")*0.01)
												if(gPerc>0)then
													gPerc = AdvDupe2.TotalGhosts / gPerc
													if(not AdvDupe2.BusyBar)then
														AdvDupe2.InitProgressBar("Ghosting: ")
														AdvDupe2.BusyBar = false
													end
													hook.Add("Tick", "AdvDupe2_SpawnGhosts", SpawnGhosts)
												else
													AdvDupe2.Ghosting = false
												end
											else
												AdvDupe2.Ghosting = false
											end
										end)
										
	net.Receive("AdvDupe2_AddGhost", 	function(len, ply, len2)
											local preview = false
											if(AdvDupe2.Preview)then
												if(AdvDupe2.PHeadEnt)then
													AdvDupe2.HeadEnt = AdvDupe2.PHeadEnt
													AdvDupe2.HeadZPos = AdvDupe2.PHeadZPos
													AdvDupe2.HeadPos = AdvDupe2.PHeadPos*1
													AdvDupe2.HeadOffset = AdvDupe2.PHeadOffset*1
													AdvDupe2.HeadAngle = AdvDupe2.PHeadAngle*1
													AdvDupe2.GhostToSpawn = table.Copy(AdvDupe2.GhostToPreview)
												end
												AdvDupe2.PHeadEnt = nil
												AdvDupe2.PHeadZPos = nil
												AdvDupe2.PHeadPos = nil
												AdvDupe2.PHeadOffset = nil
												AdvDupe2.PHeadAngle = nil
												AdvDupe2.GhostToPreview = nil
												AdvDupe2.Preview=false
												preview = true
											end
											local gNew = table.insert(AdvDupe2.GhostToSpawn, {R = net.ReadBit()==1, Model = net.ReadString(), PhysicsObjects = {}})
											for k=0, net.ReadInt(8) do
												AdvDupe2.GhostToSpawn[gNew].PhysicsObjects[k] = {Angle = net.ReadAngle(), Pos = net.ReadVector()}
											end
											
											if(preview)then
												AdvDupe2.StartGhosting()
											elseif(AdvDupe2.CurrentGhost==gNew)then
												AdvDupe2.GhostEntities[gNew] = MakeGhostsFromTable(AdvDupe2.GhostToSpawn[gNew], true)
												AdvDupe2.CurrentGhost = AdvDupe2.CurrentGhost + math.floor(gPerc)
												gTemp = gTemp + gPerc - math.floor(gPerc)
												if(gTemp>1)then
													AdvDupe2.CurrentGhost = AdvDupe2.CurrentGhost + 1
													gTemp = gTemp - math.floor(gTemp)
												end
											end
										end)
	
	function AdvDupe2.StartGhosting()
	
		AdvDupe2.RemoveGhosts()
		if(not AdvDupe2.GhostToSpawn)then return end
		AdvDupe2.Ghosting = true
		AdvDupe2.GhostEntities = {}
		AdvDupe2.HeadGhost = MakeGhostsFromTable(AdvDupe2.GhostToSpawn[AdvDupe2.HeadEnt])
		AdvDupe2.GhostEntities[AdvDupe2.HeadEnt] = AdvDupe2.HeadGhost
		AdvDupe2.CurrentGhost = 0
		AdvDupe2.TotalGhosts = #AdvDupe2.GhostToSpawn
		
		if(AdvDupe2.TotalGhosts  > 1)then
			gTemp = 0
			gPerc = AdvDupe2.TotalGhosts*(GetConVarNumber("advdupe2_limit_ghost")*0.01) - 1
			if(gPerc>0)then
				gPerc = AdvDupe2.TotalGhosts / gPerc
				if(not AdvDupe2.BusyBar)then
					AdvDupe2.InitProgressBar("Ghosting: ")
					AdvDupe2.BusyBar = false
				end
				hook.Add("Tick", "AdvDupe2_SpawnGhosts", SpawnGhosts)
			else
				AdvDupe2.Ghosting = false
			end
		else
			AdvDupe2.Ghosting = false
		end
	end
	usermessage.Hook("AdvDupe2_StartGhosting", function()
													if(AdvDupe2.Preview)then
														if(AdvDupe2.PHeadEnt)then
															AdvDupe2.HeadEnt = AdvDupe2.PHeadEnt
															AdvDupe2.HeadZPos = AdvDupe2.PHeadZPos
															AdvDupe2.HeadPos = AdvDupe2.PHeadPos*1
															AdvDupe2.HeadOffset = AdvDupe2.PHeadOffset*1
															AdvDupe2.HeadAngle = AdvDupe2.PHeadAngle*1
															AdvDupe2.GhostToSpawn = table.Copy(AdvDupe2.GhostToPreview)
														end
														AdvDupe2.PHeadEnt = nil
														AdvDupe2.PHeadZPos = nil
														AdvDupe2.PHeadPos = nil
														AdvDupe2.PHeadOffset = nil
														AdvDupe2.PHeadAngle = nil
														AdvDupe2.GhostToPreview = nil
														AdvDupe2.Preview=false
													end
													AdvDupe2.StartGhosting()
												end)
												
	usermessage.Hook("AdvDupe2_RemoveGhosts", AdvDupe2.RemoveGhosts)
												
	

	local state = 0
	local ToColor = {r=25, g=100, b=40, a=255}
	local CurColor = {r=25, g=100, b=40, a=255}
	local rate
	surface.CreateFont ("AD2Font", {font="Arial", size=40, weight=1000}) ---Remember to use gm_clearfonts
	surface.CreateFont ("AD2TitleFont", {font="Arial", size=24, weight=1000})
	//local spacing = {"   ","     ","       ","         ","           ","             "}
	function TOOL:DrawToolScreen()
		if(not AdvDupe2)then return true end
		
		local text = "Ready"
		if(AdvDupe2.Preview)then
			text = "Preview"
		end
		state=0
		if(AdvDupe2.ProgressBar.Text)then
			state=1
			text = AdvDupe2.ProgressBar.Text
		end
		
		cam.Start2D()

			surface.SetDrawColor(32, 32, 32, 255)
			surface.DrawRect(0, 0, 256, 256)
			
			if(state==0)then
				ToColor = {r=25, g=100, b=40, a=255}
			else
				ToColor = {r=130, g=25, b=40, a=255}
			end
			
			rate = FrameTime()*160
			CurColor.r = math.Approach( CurColor.r, ToColor.r, rate )
			CurColor.g = math.Approach( CurColor.g, ToColor.g, rate )
			
			surface.SetDrawColor(CurColor)
			surface.DrawRect(13, 13, 230, 230)
			
			surface.SetTextColor( 255, 255, 255, 255 )

			draw.SimpleText("Advanced Duplicator 2", "AD2TitleFont", 128, 50, Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText(text, "AD2Font", 128, 128, Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			if(state~=0)then
				draw.RoundedBox( 6, 32, 178, 192, 28, Color( 255, 255, 255, 150 ) )
				draw.RoundedBox( 6, 36, 182, 188*(AdvDupe2.ProgressBar.Percent/100), 24, Color( 0, 255, 0, 255 ) )
			elseif(LocalPlayer():KeyDown(IN_USE))then
				//draw.SimpleText("Height:   Pitch:   Roll:", "AD2TitleFont", 128, 206, Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				//local str_space1 = spacing[7-string.len(height)] or ""
				//local str_space2 = spacing[7-string.len(pitch)] or ""
				//draw.SimpleText(height..str_space1..pitch..str_space2..LocalPlayer():GetInfo("advdupe2_offset_roll"), "AD2TitleFont", 25, 226, Color(255,255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				draw.SimpleText("Height: "..LocalPlayer():GetInfo("advdupe2_offset_z"), "AD2TitleFont", 25, 160, Color(255,255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				draw.SimpleText("Pitch: "..LocalPlayer():GetInfo("advdupe2_offset_pitch"), "AD2TitleFont", 25, 190, Color(255,255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				draw.SimpleText("Yaw: "..LocalPlayer():GetInfo("advdupe2_offset_yaw"), "AD2TitleFont", 25, 220, Color(255,255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			end
			
		cam.End2D()
	end

	
	local function FindInBox(min, max, ply)

		local Entities = ents.GetAll()
		local EntTable = {}
		for _,ent in pairs(Entities) do
			local pos = ent:GetPos()
			if (pos.X>=min.X) and (pos.X<=max.X) and (pos.Y>=min.Y) and (pos.Y<=max.Y) and (pos.Z>=min.Z) and (pos.Z<=max.Z) then
				//if(ent:GetClass()~="C_BaseFlexclass")then
					EntTable[ent:EntIndex()] = ent
				//end
			end
		end

		return EntTable
	end
	
	
	local GreenSelected = Color(0, 255, 0, 255)
	function AdvDupe2.DrawSelectionBox()
			
		local TraceRes = util.TraceLine(util.GetPlayerTrace(LocalPlayer()))
		local i = tonumber(LocalPlayer():GetInfo("advdupe2_area_copy_size")) or 50
				
		//Bottom Points
		local B1 = (Vector(-i,-i,-i)+TraceRes.HitPos)
		local B2 = (Vector(-i,i,-i)+TraceRes.HitPos)
		local B3 = (Vector(i,i,-i)+TraceRes.HitPos)
		local B4 = (Vector(i,-i,-i)+TraceRes.HitPos)
				
		//Top Points
		local T1 = (Vector(-i,-i,i)+TraceRes.HitPos):ToScreen()
		local T2 = (Vector(-i,i,i)+TraceRes.HitPos):ToScreen()
		local T3 = (Vector(i,i,i)+TraceRes.HitPos):ToScreen()
		local T4 = (Vector(i,-i,i)+TraceRes.HitPos):ToScreen()
				
		if(not AdvDupe2.LastUpdate or CurTime()>=AdvDupe2.LastUpdate)then
			
			if AdvDupe2.ColorEntities then
				for k,v in pairs(AdvDupe2.EntityColors)do
					local ent = AdvDupe2.ColorEntities[k]
					if(IsValid(ent))then
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
				
		//Draw Sides
		surface.DrawLine(B1.x, B1.y, T1.x, T1.y)
		surface.DrawLine(B2.x, B2.y, T2.x, T2.y)
		surface.DrawLine(B3.x, B3.y, T3.x, T3.y)
		surface.DrawLine(B4.x, B4.y, T4.x, T4.y)
				
		//Draw Bottom
		surface.DrawLine(B1.x, B1.y, B2.x, B2.y)
		surface.DrawLine(B2.x, B2.y, B3.x, B3.y)
		surface.DrawLine(B3.x, B3.y, B4.x, B4.y)
		surface.DrawLine(B4.x, B4.y, B1.x, B1.y)
			
		//Draw Top
		surface.DrawLine(T1.x, T1.y, T2.x, T2.y)
		surface.DrawLine(T2.x, T2.y, T3.x, T3.y)
		surface.DrawLine(T3.x, T3.y, T4.x, T4.y)
		surface.DrawLine(T4.x, T4.y, T1.x, T1.y)

	end
			
	usermessage.Hook("AdvDupe2_DrawSelectBox",function() 
		hook.Add("HUDPaint", "AdvDupe2_DrawSelectionBox", AdvDupe2.DrawSelectionBox) 
	end)
	
	function AdvDupe2.RemoveSelectBox()
		hook.Remove("HUDPaint", "AdvDupe2_DrawSelectionBox") 
		if AdvDupe2.ColorEntities then
			for k,v in pairs(AdvDupe2.EntityColors)do
				if(not IsValid(AdvDupe2.ColorEntities[k]))then 
					AdvDupe2.ColorEntities[k]=nil
				else
					AdvDupe2.ColorEntities[k]:SetColor(v)
				end
			end
			AdvDupe2.ColorEntities={}
			AdvDupe2.EntityColors={}
		end
	end
	usermessage.Hook("AdvDupe2_RemoveSelectBox",function() 
		AdvDupe2.RemoveSelectBox()
	end)
	
	function AdvDupe2.InitProgressBar(label)
		AdvDupe2.ProgressBar = {}
		AdvDupe2.ProgressBar.Text = label
		AdvDupe2.ProgressBar.Percent = 0
		AdvDupe2.BusyBar = true
	end
	usermessage.Hook("AdvDupe2_InitProgressBar",function(um)
		AdvDupe2.InitProgressBar(um:ReadString())
	end)

	usermessage.Hook("AdvDupe2_UpdateProgressBar",function(um)
		AdvDupe2.ProgressBar.Percent = um:ReadChar()
	end)
	
	function AdvDupe2.RemoveProgressBar()
		AdvDupe2.ProgressBar = {}
		AdvDupe2.BusyBar = false
		if(AdvDupe2.Ghosting)then
			AdvDupe2.InitProgressBar("Ghosting: ")
			AdvDupe2.BusyBar = false
			AdvDupe2.ProgressBar.Percent = AdvDupe2.CurrentGhost/AdvDupe2.TotalGhosts*100
		end
	end
	usermessage.Hook("AdvDupe2_RemoveProgressBar",function(um)
		AdvDupe2.RemoveProgressBar()
	end)
	
	usermessage.Hook("AdvDupe2_ResetOffsets",function(um)
		RunConsoleCommand("advdupe2_original_origin", "0")
		RunConsoleCommand("advdupe2_paste_constraints","1")
		RunConsoleCommand("advdupe2_offset_z","0")
		RunConsoleCommand("advdupe2_offset_pitch","0")
		RunConsoleCommand("advdupe2_offset_yaw","0")
		RunConsoleCommand("advdupe2_offset_roll","0")
		RunConsoleCommand("advdupe2_paste_parents","1")
		RunConsoleCommand("advdupe2_paste_disparents","0")
	end)
	
	usermessage.Hook("AdvDupe2_ReportModel",function(um)
		print("Advanced Duplicator 2: Invalid Model: "..um:ReadString())
	end)
	
	usermessage.Hook("AdvDupe2_ReportClass",function(um)
		print("Advanced Duplicator 2: Invalid Class: "..um:ReadString())
	end)
	
	usermessage.Hook("AdvDupe2_ResetDupeInfo", function(um)
		AdvDupe2.Info.File:SetText("File:")
		AdvDupe2.Info.Creator:SetText("Creator:")
		AdvDupe2.Info.Date:SetText("Date:")
		AdvDupe2.Info.Time:SetText("Time:")
		AdvDupe2.Info.Size:SetText("Size:")
		AdvDupe2.Info.Desc:SetText("Desc:")
		AdvDupe2.Info.Entities:SetText("Entities:")
		AdvDupe2.Info.Constraints:SetText("Constraints:")
	end)
	
	usermessage.Hook("AdvDupe2_CanAutoSave", function(um)
		if(AdvDupe2.AutoSavePath~="")then
			AdvDupe2.AutoSavePos = um:ReadVector()
			AdvDupe2.AutoSaveSize = um:ReadShort()
			local ent = um:ReadShort()
			AdvDupe2.OffButton:SetDisabled(false)
			net.Start("AdvDupe2_CanAutoSave")
				net.WriteString(AdvDupe2.AutoSaveDesc)
				net.WriteInt(ent, 16)
				if(game.SinglePlayer())then
					net.WriteString(string.sub(AdvDupe2.AutoSavePath, 10, #AdvDupe2.AutoSavePath))
				end
			net.SendToServer()
		else
			AdvDupe2.Notify("Select a directory for the Area Auto Save.", NOTIFY_ERROR)
		end
	end)
	
	net.Receive("AdvDupe2_SetDupeInfo", function(len, ply, len2)
		AdvDupe2.Info.File:SetText("File: "..net.ReadString())
		AdvDupe2.Info.Creator:SetText("Creator: "..net.ReadString())
		AdvDupe2.Info.Date:SetText("Date: "..net.ReadString())
		AdvDupe2.Info.Time:SetText("Time: "..net.ReadString())
		AdvDupe2.Info.Size:SetText("Size: "..net.ReadString())
		AdvDupe2.Info.Desc:SetText("Desc: "..net.ReadString())
		AdvDupe2.Info.Entities:SetText("Entities: "..net.ReadString())
		AdvDupe2.Info.Constraints:SetText("Constraints: "..net.ReadString())
	end)
end

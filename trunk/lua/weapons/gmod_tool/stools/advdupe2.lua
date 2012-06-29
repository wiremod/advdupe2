--[[
	Title: Adv. Dupe 2 Tool
	
	Desc: Defines the AD2 tool and assorted functionalities.
	
	Author: TB
	
	Version: 1.0
]]


TOOL.Category = "Construction"
TOOL.Name = "#Advanced Duplicator 2"
cleanup.Register( "AdvDupe2" )



--[[
	Name: LeftClick
	Desc: Defines the tool's behavior when the player left-clicks.
	Params: <trace> trace
	Returns: <boolean> success
]]
function TOOL:LeftClick( trace )

	if(!trace)then return false end
	if(CLIENT)then return true end

	local ply = self:GetOwner()

	if(!ply.AdvDupe2 || !ply.AdvDupe2.Entities)then return false end
	
	if(ply.AdvDupe2.Pasting || ply.AdvDupe2.Downloading)then
		AdvDupe2.Notify(ply,"Advanced Duplicator 2 is busy.",NOTIFY_ERROR)
		return false 
	end
	
	local z = math.Clamp((tonumber(ply:GetInfo("advdupe2_offset_z")) + ply.AdvDupe2.HeadEnt.Z), -16000, 16000)
	ply.AdvDupe2.Position = trace.HitPos + Vector(0, 0, z)
	ply.AdvDupe2.Angle = Angle(tonumber(ply:GetInfo("advdupe2_offset_pitch")), tonumber(ply:GetInfo("advdupe2_offset_yaw")), tonumber(ply:GetInfo("advdupe2_offset_roll")))

	if(tobool(ply:GetInfo("advdupe2_offset_world")))then ply.AdvDupe2.Angle = ply.AdvDupe2.Angle - ply.AdvDupe2.Entities[ply.AdvDupe2.HeadEnt.Index].PhysicsObjects[0].Angle end
	ply.AdvDupe2.Pasting = true
	umsg.Start("AdvDupe2_NotGhosting", ply)
	umsg.End()
	AdvDupe2.Notify(ply,"Pasting...")
	local origin
	if(tobool(ply:GetInfo("advdupe2_original_origin")))then
		origin = ply.AdvDupe2.HeadEnt.Pos
	end
	AdvDupe2.InitPastingQueue(ply, ply.AdvDupe2.Position, ply.AdvDupe2.Angle, origin, tobool(ply:GetInfo("advdupe2_paste_constraints")), tobool(ply:GetInfo("advdupe2_paste_parents")), tobool(ply:GetInfo("advdupe2_paste_disparents")),tobool(ply:GetInfo("advdupe2_paste_protectoveride")))
	//AdvDupe2.duplicator.Paste(ply, table.Copy(ply.AdvDupe2.Entities), table.Copy(ply.AdvDupe2.Constraints), ply.AdvDupe2.Position, ply.AdvDupe2.Angle, nil, true)
	return true
end


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

//Find all the entities in a box, given the adjacent corners and the player
local function FindInBox(min, max, ply)

	local Entities = ents.GetAll()
	local EntTable = {}
	local pos
	for _,ent in pairs(Entities) do
		pos = ent:GetPos()
		if (pos.X>=min.X) and (pos.X<=max.X) and (pos.Y>=min.Y) and (pos.Y<=max.Y) and (pos.Z>=min.Z) and (pos.Z<=max.Z) and (AdvDupe2.duplicator.EntityList[ent:GetClass()] ~= nil) then
			if CPPI then
				if ent:CPPICanTool(ply, "advdupe2") then
					EntTable[ent:EntIndex()] = ent
				end
			else
				EntTable[ent:EntIndex()] = ent
			end
		end
	end

	return EntTable
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
function AdvDupe2.ResetOffsets(ply)
	ply.AdvDupe2.Name = nil
	umsg.Start("AdvDupe2_ResetOffsets", ply)
	umsg.End()
end

//Remove player's ghosts and tell the client to stop updating ghosts
function TOOL:RemoveGhosts(ply)

	
	if(IsValid(ply) && ply.AdvDupe2)then 
		if(ply.AdvDupe2.Ghosting && !ply.AdvDupe2.Downloading)then
			AdvDupe2.RemoveProgressBar(ply)
		end
		ply.AdvDupe2.Ghosting = false 
	end
	
	if(self.GhostEntities)then
		for k,v in pairs(self.GhostEntities)do
			if(IsValid(v))then
				v:Remove()
			end
		end
	end
	
	self.GhostEntities = nil
	if(!IsValid(ply) || !ply.AdvDupe2)then return end
	ply.AdvDupe2.GhostToSpawn = nil
	ply.AdvDupe2.CurrentGhost = 1
	umsg.Start("AdvDupe2_NotGhosting", ply)
	umsg.End()
end

--[[
	Name: RightClick
	Desc: Defines the tool's behavior when the player right-clicks.
	Params: <trace> trace
	Returns: <boolean> success
]]
function TOOL:RightClick( trace )

	if CLIENT then return true end

	local ply = self:GetOwner()
	
	if(!ply.AdvDupe2)then ply.AdvDupe2 = {} end
	if(ply.AdvDupe2.Pasting || ply.AdvDupe2.Downloading)then
		AdvDupe2.Notify(ply,"Advanced Duplicator 2 is busy.",NOTIFY_ERROR)
		return false 
	end

	//Set Area Copy on or off
	if( ply:KeyDown(IN_SPEED) && !ply:KeyDown(IN_WALK) )then
		if( self:GetStage()==0)then
			AdvDupe2.DrawSelectBox(ply)
			self:SetStage(1)
			return false
		elseif(self:GetStage()==1)then
			AdvDupe2.RemoveSelectBox(ply)
			self:SetStage(0)
			return false
		end	
	end
	
	if(!trace or !trace.Hit)then return false end 
	//If area copy is on and an ent was not right clicked, do an area copy and pick an ent
	if( self:GetStage()==1 and !IsValid(trace.Entity) )then	
		if( !SinglePlayer() && (tonumber(ply:GetInfo("advdupe2_area_copy_size"))or 50) > tonumber(GetConVarString("AdvDupe2_MaxAreaCopySize")))then
			AdvDupe2.Notify(ply,"Area copy size exceeds limit of "..GetConVarString("AdvDupe2_MaxAreaCopySize")..".",NOTIFY_ERROR)
			return false 
		end
		local i = tonumber(ply:GetInfo("advdupe2_area_copy_size")) or 50
		local Pos = trace.HitPos
		local T = (Vector(i,i,i)+Pos)
		local B = (Vector(-i,-i,-i)+Pos)
		local timecheck = SysTime()
		local Entities = FindInBox(B,T, ply)

		if(table.Count(Entities)==0)then
			self:SetStage(0)
			AdvDupe2.RemoveSelectBox(ply)
			return true
		end
		
		self:RemoveGhosts(ply)
		ply.AdvDupe2.HeadEnt = {}
		ply.AdvDupe2.Entities = {}
		ply.AdvDupe2.Constraints = {}
		
		ply.AdvDupe2.HeadEnt.Index = table.GetFirstKey(Entities)
		ply.AdvDupe2.HeadEnt.Pos = Entities[ply.AdvDupe2.HeadEnt.Index]:GetPos()
		
		local Outside = false
		if((tonumber(ply:GetInfo("advdupe2_copy_outside")) or 0)==1)then
			Outside = true
		end

		ply.AdvDupe2.Entities, ply.AdvDupe2.Constraints = AdvDupe2.duplicator.AreaCopy(Entities, ply.AdvDupe2.HeadEnt.Pos, Outside)
	
		local tracedata = {}
		tracedata.mask = MASK_NPCWORLDSTATIC
		tracedata.start = ply.AdvDupe2.HeadEnt.Pos+Vector(0,0,1)
		tracedata.endpos = ply.AdvDupe2.HeadEnt.Pos-Vector(0,0,50000)
		local WorldTrace = util.TraceLine( tracedata )
		if(WorldTrace.Hit)then ply.AdvDupe2.HeadEnt.Z = math.abs(ply.AdvDupe2.HeadEnt.Pos.Z-WorldTrace.HitPos.Z) else ply.AdvDupe2.HeadEnt.Z = 0 end

		AdvDupe2.RemoveSelectBox(ply)
	else	//Area Copy is off or the ent is valid
	
		//Non valid entity or clicked the world
		if(!IsValid(trace.Entity))then 

			//If shift and alt are being held, clear the dupe
			if(ply:KeyDown(IN_WALK) && ply:KeyDown(IN_SPEED))then

				self:RemoveGhosts(ply)
				ply.AdvDupe2.Entities = nil
				ply.AdvDupe2.Constraints = nil
				umsg.Start("AdvDupe2_ResetDupeInfo", ply)
				umsg.End()
				AdvDupe2.ResetOffsets(ply)
			end
			return false 
		end

		//If Alt is being held, add a prop to the dupe
		if(self:GetStage()==0 and ply:KeyDown(IN_WALK) and ply.AdvDupe2.Entities!=nil and table.Count(ply.AdvDupe2.Entities)>0)then 
			AdvDupe2.duplicator.Copy( trace.Entity, ply.AdvDupe2.Entities, ply.AdvDupe2.Constraints, ply.AdvDupe2.HeadEnt.Pos)  

			ply.AdvDupe2.Constraints = CollapseTableToArray(ply.AdvDupe2.Constraints)
			
			umsg.Start("AdvDupe2_SetDupeInfo", ply)
				umsg.String("")
				umsg.String("")
				umsg.String("")
				umsg.String(os.date("%I:%M %p"))
				umsg.String("")
				umsg.String("")
				umsg.String(table.Count(ply.AdvDupe2.Entities))
				umsg.String(#ply.AdvDupe2.Constraints)
			umsg.End()
			
			//Only add the one ghost
			local index = trace.Entity:EntIndex()
			if(ply.AdvDupe2.Entities[index] && !self.GhostEntities[index])then
				if(!ply.AdvDupe2.GhostToSpawn)then ply.AdvDupe2.GhostToSpawn={} end
				ply.AdvDupe2.GhostToSpawn[#ply.AdvDupe2.GhostToSpawn] = index
				ply.AdvDupe2.LastGhost = CurTime()+0.02
				ply.AdvDupe2.Ghosting = true
			end

		else
			self:RemoveGhosts(ply)
		
			ply.AdvDupe2.HeadEnt = {}
			ply.AdvDupe2.HeadEnt.Index = trace.Entity:EntIndex()
			ply.AdvDupe2.Entities = {}
			ply.AdvDupe2.Constraints = {}
			ply.AdvDupe2.HeadEnt.Pos = trace.HitPos //trace.Entity:GetPos()

			local tracedata = {}
			tracedata.mask = MASK_NPCWORLDSTATIC
			tracedata.start = ply.AdvDupe2.HeadEnt.Pos
			tracedata.endpos = ply.AdvDupe2.HeadEnt.Pos-Vector(0,0,50000)
			local WorldTrace = util.TraceLine( tracedata )
			if WorldTrace.Hit then ply.AdvDupe2.HeadEnt.Z = math.abs(ply.AdvDupe2.HeadEnt.Pos.Z-WorldTrace.HitPos.Z) else ply.AdvDupe2.HeadEnt.Z=0 end
			
			//Area Copy is off, do a regular copy
			if(self:GetStage()==0)then
				AdvDupe2.duplicator.Copy( trace.Entity, ply.AdvDupe2.Entities, ply.AdvDupe2.Constraints, trace.HitPos ) //ply.AdvDupe2.HeadEnt.Pos  )		
			else	//Area copy is on and an ent was clicked, do an area copy
				if( !SinglePlayer() && (tonumber(ply:GetInfo("advdupe2_area_copy_size"))or 50) > tonumber(GetConVarString("AdvDupe2_MaxAreaCopySize")))then
					AdvDupe2.Notify(ply,"Area copy size exceeds limit of "..GetConVarString("AdvDupe2_MaxAreaCopySize")..".",NOTIFY_ERROR)
					return false 
				end
				local i = tonumber(ply:GetInfo("advdupe2_area_copy_size")) or 50
				local Pos = ply.AdvDupe2.HeadEnt.Pos
				local T = (Vector(i,i,i)+Pos)
				local B = (Vector(-i,-i,-i)+Pos)
				
				local Outside = false
				if((tonumber(ply:GetInfo("advdupe2_copy_outside")) or 0)==1)then
					Outside = true
				end

				local Entities = FindInBox(B,T, ply)
				
				ply.AdvDupe2.Entities, ply.AdvDupe2.Constraints = AdvDupe2.duplicator.AreaCopy(Entities, Pos, Outside)
				
				self:SetStage(0)
				AdvDupe2.RemoveSelectBox(ply)
			end
		end
	end
	
	ply.AdvDupe2.Constraints = CollapseTableToArray(ply.AdvDupe2.Constraints)
	
	umsg.Start("AdvDupe2_SetDupeInfo", ply)
		umsg.String("")
		umsg.String(ply:Nick())
		umsg.String(os.date("%d %B %Y"))
		umsg.String(os.date("%I:%M %p"))
		umsg.String("")
		umsg.String("")
		umsg.String(table.Count(ply.AdvDupe2.Entities))
		umsg.String(#ply.AdvDupe2.Constraints)
	umsg.End()
		
	AdvDupe2.StartGhosting(ply)

	if(self:GetStage()==1)then
		self:SetStage(0)
		AdvDupe2.RemoveSelectBox(ply)
	end

	AdvDupe2.ResetOffsets(ply)

	return true
end

//Called to clean up the tool when pasting is finished or undo during pasting
function AdvDupe2.FinishPasting(Player, Paste)
	Player.AdvDupe2.Pasting=false
	AdvDupe2.RemoveProgressBar(Player)
	
	if(Paste)then AdvDupe2.Notify(Player,"Finished Pasting!") end

	local tool = Player:GetTool()
	if(tool)then
		if(Player:GetActiveWeapon():GetClass()=="gmod_tool" && tool.Mode=="advdupe2")then
			if(Player.AdvDupe2.Ghosting)then AdvDupe2.InitProgressBar(Player, "Ghosting: ") end
			umsg.Start("AdvDupe2_Ghosting", Player)
			umsg.End()
			return
		else
			Player:GetTool("advdupe2"):RemoveGhosts(Player)
		end
	end

end

//Update the ghost's postion and angles based on where the player is looking and the offsets
local function UpdateGhost(ply, toolWep)

	local trace = util.TraceLine(util.GetPlayerTrace(ply, ply:GetCursorAimVector()))
	if (!trace.Hit) then return end

	local GhostEnt = toolWep:GetNetworkedEntity("GhostEntity", nil)
	
	if(!IsValid(GhostEnt) || !IsValid(ply))then
		if SERVER then toolWep.Tool.advdupe2:RemoveGhosts(ply) end
		return 
	end

	GhostEnt:SetMoveType(MOVETYPE_VPHYSICS)
	GhostEnt:SetNotSolid(true)

	local PhysObj = GhostEnt:GetPhysicsObject()
	if ( IsValid(PhysObj) ) then
		PhysObj:EnableMotion( false )
		if(tobool(ply:GetInfo("advdupe2_original_origin")))then
			PhysObj:SetPos(toolWep:GetNetworkedVector("HeadPos", Vector(0,0,0)) + toolWep:GetNetworkedVector( "HeadOffset", Vector(0,0,0) ))
			PhysObj:SetAngle(toolWep:GetNetworkedAngle("HeadAngle", Angle(0,0,0)))
		else
			local EntAngle = toolWep:GetNetworkedAngle("HeadAngle", Angle(0,0,0))
			if(tobool(ply:GetInfo("advdupe2_offset_world")))then EntAngle = Angle(0,0,0) end
			trace.HitPos.Z = trace.HitPos.Z + math.Clamp((toolWep:GetNetworkedFloat("HeadZPos", 0) or 0 + tonumber(ply:GetInfo("advdupe2_offset_z")) or 0), -16000, 16000)
			local Pos, Angle = LocalToWorld(toolWep:GetNetworkedVector("HeadOffset", Vector(0,0,0)), EntAngle, trace.HitPos, Angle(math.Clamp(tonumber(ply:GetInfo("advdupe2_offset_pitch")) or 0,-180,180), math.Clamp(tonumber(ply:GetInfo("advdupe2_offset_yaw")) or 0,-180,180), math.Clamp(tonumber(ply:GetInfo("advdupe2_offset_roll")) or 0,-180,180))) 
			PhysObj:SetPos(Pos)
			PhysObj:SetAngle(Angle)
		end
		PhysObj:Wake()
	else
		// Give the head ghost entity a physics object
		// This way the movement will be predicted on the client
		if(CLIENT)then
			GhostEnt:PhysicsInit(SOLID_VPHYSICS)
		end
	end
end

//Add a folder to the clients file browser
local function AddFolder(ply,name,id,parent,new)
	umsg.Start("AdvDupe2_AddFolder",ply)
		umsg.String(name)
		umsg.Short(id)
		umsg.Short(parent)
		umsg.Bool(new)
	umsg.End()
end

//Add a file to the clients file browser
local function AddFile(ply,name,parent,new)
	umsg.Start("AdvDupe2_AddFile",ply)
		umsg.String(name)
		umsg.Short(parent)
		umsg.Bool(new)
	umsg.End()
end

//Take control of the mouse wheel bind so the player can modify the height of the dupe
local function MouseWheelScrolled(ply, bind, pressed)

	if(bind=="invprev")then
		local Z = tonumber(ply:GetInfo("advdupe2_offset_z")) + 5
		RunConsoleCommand("advdupe2_offset_z",Z)
		return true
	elseif(bind=="invnext")then
		local Z = tonumber(ply:GetInfo("advdupe2_offset_z")) - 5
		RunConsoleCommand("advdupe2_offset_z",Z)
		return true
	end
	
	GAMEMODE:PlayerBindPress(ply, bind, pressed)
end


//Creates a ghost from the given entity's table
local function MakeGhostsFromTable( toolWep, gParent, EntTable, Player)

	if(!EntTable)then return end
	
	if(!EntTable.Model || !util.IsValidModel(EntTable.Model)) then EntTable.Model="models/error.mdl" end
	
	local GhostEntity
	if ( EntTable.Model:sub( 1, 1 ) == "*" ) then
		GhostEntity = ents.Create( "func_physbox" )
	else
		GhostEntity = ents.Create( "gmod_ghost" )
	end
	
	// If there are too many entities we might not spawn..
	if !IsValid(GhostEntity) then 
		toolWep.Tool.advdupe2:RemoveGhosts(Player)
		AdvDupe2.RemoveProgressBar(Player)
		AdvDupe2.Notify(Player, "To many entities to spawn ghosts", NOTIFY_ERROR)
		return 
	end
	
	local Phys = EntTable.PhysicsObjects[0]
	EntTable.Pos = Phys.Pos
	EntTable.Angle = Phys.Angle
	duplicator.DoGeneric( GhostEntity, EntTable )
	
	GhostEntity:Spawn()
	GhostEntity:DrawShadow( false )
	GhostEntity:SetMoveType( MOVETYPE_NONE )
	GhostEntity:SetSolid( SOLID_VPHYSICS );
	GhostEntity:SetNotSolid( true )
	GhostEntity:SetRenderMode( RENDERMODE_TRANSALPHA )
	
	GhostEntity:SetColor( 255, 255, 255, 150 )
	
		// If we're a ragdoll send our bone positions
	if ( EntTable.Class == "prop_ragdoll" ) then
		for k, v in pairs( EntTable.PhysicsObjects ) do
			if(k==0)then
				GhostEntity:SetNetworkedBonePosition( k, Vector(0,0,0), v.Angle )
			else
				GhostEntity:SetNetworkedBonePosition( k, v.Pos, v.Angle )
			end
		end	
		Phys.Angle = Angle(0,0,0)
	end
	
	if ( gParent ) then
		local Parent = toolWep:GetNetworkedEntity("GhostEntity", nil)
		local temp = Parent:GetAngles()
		GhostEntity:SetPos(Parent:GetPos() + Phys.Pos - toolWep:GetNetworkedAngle("HeadOffset", Angle(0,0,0)))
		GhostEntity:SetAngles(Phys.Angle)
		Parent:SetAngles(toolWep:GetNetworkedAngle("HeadAngle", Angle(0,0,0)))
		GhostEntity:SetParent(Parent)
		Parent:SetAngles(temp)
	else
		GhostEntity:SetAngles(Phys.Angle)
		toolWep:SetNetworkedEntity("GhostEntity", GhostEntity)
		toolWep:SetNetworkedVector("HeadPos", Player.AdvDupe2.HeadEnt.Pos)
		toolWep:SetNetworkedVector("HeadOffset", EntTable.Pos)
		toolWep:SetNetworkedFloat("HeadZPos", Player.AdvDupe2.HeadEnt.Z)
		toolWep:SetNetworkedAngle("HeadAngle", Phys.Angle)

		umsg.Start("AdvDupe2_Ghosting", Player)
		umsg.End()
	end
	
	return GhostEntity
end


local XTotal = 0
local YTotal = 0
local LastXDegree = 0
//Retrieves the players files for the file browser, creates and updates ghosts, checks binds to modify dupes position and angles
function TOOL:Think()

	local ply = self:GetOwner()
	
	if(SERVER && ply.AdvDupe2)then
		if(self.GhostEntities && !ply.AdvDupe2.Pasting)then
			UpdateGhost(ply, self.Weapon)
		end
		
		if(ply.AdvDupe2.Ghosting && CurTime()>=ply.AdvDupe2.LastGhost && !ply.AdvDupe2.Pasting)then
			
			local i = ply.AdvDupe2.GhostToSpawn[ply.AdvDupe2.CurrentGhost]
			if(i!=nil)then
				
				local total = math.Round((math.Clamp( tonumber(ply:GetInfo("advdupe2_limit_ghost")) or 100, 1, 100 )/100)*#ply.AdvDupe2.GhostToSpawn)
				if(ply.AdvDupe2.CurrentGhost >= total)then 

					AdvDupe2.RemoveProgressBar(ply)
					ply.AdvDupe2.Ghosting = false
					ply.AdvDupe2.CurrentGhost=1
				end

				self.GhostEntities[i] = MakeGhostsFromTable( self.Weapon, ply.AdvDupe2.HeadEnt.Index, table.Copy(ply.AdvDupe2.Entities[i]), ply)
				ply.AdvDupe2.CurrentGhost = ply.AdvDupe2.CurrentGhost+1
				local barperc = math.floor((ply.AdvDupe2.CurrentGhost/total)*100)
				if(!ply.AdvDupe2.Downloading)then
					AdvDupe2.UpdateProgressBar(ply, barperc)
				end
				ply.AdvDupe2.LastGhost=CurTime()+0.02
			else
				AdvDupe2.RemoveProgressBar(ply)
				ply.AdvDupe2.Ghosting = false
				ply.AdvDupe2.CurrentGhost=1
			end
			
		end
		
		if(ply.AdvDupe2.SendFiles && CurTime()>= ply.AdvDupe2.LastFile)then
			if(ply.AdvDupe2.Folders[1])then
				local Folder = ply.AdvDupe2.Folders[1]
				AddFolder(ply, Folder.Name, Folder.ID, Folder.Parent, false)
				table.remove(ply.AdvDupe2.Folders, 1)
			elseif(ply.AdvDupe2.Files[1])then
				local File = ply.AdvDupe2.Files[1]
				AddFile(ply, File.Name, File.Parent, false)
				table.remove(ply.AdvDupe2.Files, 1)
			else
				ply.AdvDupe2.SendFiles = false
				ply.AdvDupe2.LastFile = 0
			end
			
			ply.AdvDupe2.LastFile = CurTime()+0.02
		end
		
	else
		if(!AdvDupe2.GhostEntity)then return end
			
		UpdateGhost(ply, self.Weapon)
		
		local cmd = ply:GetCurrentCommand()	
		
		if(ply:KeyDown(IN_USE))then
			if(!AdvDupe2.Rotation)then
				hook.Add("PlayerBindPress", "AdvDupe2_BindPress", MouseWheelScrolled)
				AdvDupe2.Rotation = true
			end
		else
			if(AdvDupe2.Rotation)then
				AdvDupe2.Rotation = false
				hook.Remove("PlayerBindPress", "AdvDupe2_BindPress")
			end
			
			XTotal = 0
			YTotal = 0
			LastXDegree = 0
			
			return
		end
		
			local X = -cmd:GetMouseX()/-20
			local Y = cmd:GetMouseY()/-20
			
			local X2 = 0
			local Y2 = 0
			
			if(X!=0)then
				
				X2 = tonumber(ply:GetInfo("advdupe2_offset_yaw"))
				
				if(ply:KeyDown(IN_SPEED))then
					XTotal = XTotal + X
					local temp = XTotal + X2
					
					local degree = math.Round(temp/45)*45
					if(degree>=225)then
						degree = -135
					elseif(degree<=-225)then
						degree = 135
					end
					if(degree!=LastXDegree)then
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
			
			/*if(Y!=0)then
				Y2 =  tonumber(ply:GetInfo("advdupe2_offset_pitch"))
				local Y3 = tonumber(ply:GetInfo("advdupe2_offset_roll"))
				if(ply:KeyDown(IN_SPEED))then
					YTotal = YTotal + Y
					local temp = YTotal + Y2
					
					local degree = math.Round(temp/45)*45
					if(degree>=225)then
						degree = -135
					elseif(degree<=-225)then
						degree = 135
					end
					if(degree!=LastYDegree)then
						YTotal = 0
						LastYDegree = degree
					end
					
					Y2 = degree
				else
					local dir = LocalPlayer():GetForward()
				
					Y2 = Y2 + Y*dir.X
					Y3 = Y3 + Y*dir.Y
				
					if(Y2<-180)then
						Y2 = Y2+360
					elseif(Y2>180)then
						Y2 = Y2-360
					end
				end
				
				
				
				RunConsoleCommand("advdupe2_offset_pitch",Y2)
				RunConsoleCommand("advdupe2_offset_roll",Y3)
			end*/
			
			cmd:SetMouseX(0)
			cmd:SetMouseY(0)
	end

end

//Hinder the player from looking to modify offsets with the mouse
function TOOL:FreezeMovement()
	return AdvDupe2.Rotation
end

//Checks table, re-draws loading bar, and recreates ghosts when tool is pulled out
function TOOL:Deploy()
	if ( CLIENT ) then return end
	local ply = self:GetOwner()
	
	if ( !ply.AdvDupe2 ) then ply.AdvDupe2={} end
	
	if(!ply.AdvDupe2.Entities)then return end
	if(ply.AdvDupe2.Queued)then
		AdvDupe2.InitProgressBar(ply, "Queued: ")
		return
	end
	
	if(ply.AdvDupe2.Pasting)then
		AdvDupe2.InitProgressBar(ply, "Pasting: ")
		return
	else
		self.GhostEntities = nil
		if(ply.AdvDupe2.Uploading)then
			AdvDupe2.InitProgressBar(ply, "Uploading: ")
			return
		elseif(ply.AdvDupe2.Downloading)then
			AdvDupe2.InitProgressBar(ply, "Downloading: ")
			return
		end
	end

	AdvDupe2.StartGhosting(ply)
end

//Removes progress bar and removes ghosts when tool is put away
function TOOL:Holster()
	if( CLIENT ) then 
		if(AdvDupe2.Rotation)then
			hook.Remove("PlayerBindPress", "AdvDupe2_BindPress")
		end
		return 
	end
	local ply = self:GetOwner()
	if(self:GetStage()==1)then 
		AdvDupe2.RemoveSelectBox(ply)
	end
	
	AdvDupe2.RemoveProgressBar(ply)
		
	if ( ply.AdvDupe2 && ply.AdvDupe2.Pasting ) then return end
	self:RemoveGhosts(ply)

end

//function for creating a contraption spawner
function MakeContraptionSpawner( ply, Pos, Ang, HeadEnt, EntityTable, ConstraintTable, delay, undo_delay, model, key, undo_key, disgrav, disdrag, addvel)

	if !ply:CheckLimit("gmod_contr_spawners") then return nil end
	
	if(!SinglePlayer())then
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
	if !IsValid(spawner) then return end

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
	if(!delay)then
		delay = tonumber(GetConVarString("AdvDupe2_MinContraptionSpawnDelay")) or 0.2
	else
		if(!SinglePlayer())then
			min = tonumber(GetConVarString("AdvDupe2_MinContraptionSpawnDelay")) or 0.2
			if (delay < min) then
				delay = min
			end
		elseif(delay<0)then
			delay = 0
		end
	end
	
	if(!undo_delay)then
		undo_delay = tonumber(GetConVarString("AdvDupe2_MinContraptionUndoDelay"))
	else
		if(!SinglePlayer())then
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
		ply 			= ply,
		delay		= delay,
		undo_delay	= undo_delay,
		disgrav		= disgrav,
		disdrag 	= disdrag,
		addvel		= addvel;
	}
	table.Merge(spawner:GetTable(), tbl)
	spawner:SetDupeInfo(HeadEnt, EntityTable, ConstraintTable)
	spawner:AddGhosts()

	ply:AddCount("gmod_contr_spawners", spawner)
	ply:AddCleanup("gmod_contr_spawner", spawner)
	return spawner
end
duplicator.RegisterEntityClass("gmod_contr_spawner", MakeContraptionSpawner, "Pos", "Ang", "HeadEnt", "EntityTable", "ConstraintTable", "delay", "undo_delay", "model", "key", "undo_key", "disgrav", "disdrag", "addvel")


--[[
	Name: Reload
	Desc: Creates an Advance Contraption Spawner.
	Params: <trace> trace
	Returns: <boolean> success
]]
function TOOL:Reload( trace )
	if CLIENT then return true end
	local ply = self:GetOwner()

	//If a contraption spawner was clicked then update it with the current settings
	if(trace.Entity:GetClass()=="gmod_contr_spawner")then
		local delay = tonumber(ply:GetInfo("advdupe2_contr_spawner_delay"))
		local undo_delay = tonumber(ply:GetInfo("advdupe2_contr_spawner_undo_delay"))
		local min
		local max
		if(!delay)then
			delay = tonumber(GetConVarString("AdvDupe2_MinContraptionSpawnDelay")) or 0.2
		else
			if(!SinglePlayer())then
				min = tonumber(GetConVarString("AdvDupe2_MinContraptionSpawnDelay")) or 0.2
				if (delay < min) then
					delay = min
				end
			elseif(delay<0)then
				delay = 0
			end
		end
		
		if(!undo_delay)then
			undo_delay = tonumber(GetConVarString("AdvDupe2_MinContraptionUndoDelay"))
		else
			if(!SinglePlayer())then
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
		local ghostent = self.GhostEntities[ply.AdvDupe2.HeadEnt.Index]
		local ang
		local pos
		if(self.GhostEntities && IsValid(self.GhostEntities[ply.AdvDupe2.HeadEnt.Index]))then
			pos = self.GhostEntities[ply.AdvDupe2.HeadEnt.Index]:GetPos()
			ang = self.GhostEntities[ply.AdvDupe2.HeadEnt.Index]:GetAngles()
		elseif(headent)then
			local trace = util.TraceLine(util.GetPlayerTrace(ply, ply:GetCursorAimVector()))
			if (!trace.Hit) then return end
			local EntAngle = self:GetNetworkedAngle("HeadAngle", Angle(0,0,0))
			if(tobool(ply:GetInfo("advdupe2_offset_world")))then EntAngle = Angle(0,0,0) end
			trace.HitPos.Z = trace.HitPos.Z + math.Clamp((self:GetNetworkedFloat("HeadZPos", 0) + tonumber(ply:GetInfo("advdupe2_offset_z")) or 0), -16000, 16000)
			pos, ang = LocalToWorld(self:GetNetworkedVector("HeadOffset", Vector(0,0,0)), EntAngle, trace.HitPos, Angle(math.Clamp(tonumber(ply:GetInfo("advdupe2_offset_pitch")) or 0,-180,180), math.Clamp(tonumber(ply:GetInfo("advdupe2_offset_yaw")) or 0,-180,180), math.Clamp(tonumber(ply:GetInfo("advdupe2_offset_roll")) or 0,-180,180))) 
		else
			AdvDupe2.Notify(ply, "Invalid head entity to spawn contraption spawner.")
			return
		end
		
		if(headent.Class=="gmod_contr_spawner") then 
			AdvDupe2.Notify(ply, "Cannot make a contraption spawner from a contraption spawner.")
			return false 
		end
	
		
		local spawner = MakeContraptionSpawner( ply, ghostent:GetPos(), ghostent:GetAngles(), ply.AdvDupe2.HeadEnt.Index, table.Copy(ply.AdvDupe2.Entities), table.Copy(ply.AdvDupe2.Constraints), tonumber(ply:GetInfo("advdupe2_contr_spawner_delay")), tonumber(ply:GetInfo("advdupe2_contr_spawner_undo_delay")), headent.Model, tonumber(ply:GetInfo("advdupe2_contr_spawner_key")), tonumber(ply:GetInfo("advdupe2_contr_spawner_undo_key")),  tonumber(ply:GetInfo("advdupe2_contr_spawner_disgrav")) or 0, tonumber(ply:GetInfo("advdupe2_contr_spawner_disdrag")) or 0, tonumber(ply:GetInfo("advdupe2_contr_spawner_addvel")) or 1 )
		ply:AddCleanup( "AdvDupe2", spawner )
		undo.Create("gmod_contr_spawner")
			undo.AddEntity( spawner )
			undo.SetPlayer( ply )
		undo.Finish()

		return true
	end
end	



if SERVER then

	CreateConVar("sbox_maxgmod_contr_spawners",5)

	function AdvDupe2.StartGhosting(ply)

		if(!ply.AdvDupe2.Entities)then return end
		local tool = ply:GetTool()
		if(!tool || ply:GetActiveWeapon():GetClass()!="gmod_tool" || tool.Mode!="advdupe2")then return end
		
		local index = ply.AdvDupe2.HeadEnt.Index
		
		tool:RemoveGhosts(ply)
		tool.GhostEntities	= {}
		tool.GhostEntities[index] = MakeGhostsFromTable( tool.Weapon, nil, table.Copy(ply.AdvDupe2.Entities[index]), ply)

		if !IsValid(tool.GhostEntities[index]) then
			tool.GhostEntities = nil
			AdvDupe2.Notify(ply, "Parent ghost is invalid, not creating ghosts", NOTIFY_ERROR)
			return
		end

		ply.AdvDupe2.GhostToSpawn = {}
		local total = 1
		for k,v in pairs(ply.AdvDupe2.Entities)do
			if(k!=index)then
				ply.AdvDupe2.GhostToSpawn[total] = k
				total = total + 1
			end
		end
		ply.AdvDupe2.LastGhost = CurTime()+0.02
		AdvDupe2.InitProgressBar(ply, "Ghosting: ")
		ply.AdvDupe2.Ghosting = true
	end
	
	local function RenameNode(ply, newname)
		umsg.Start("AdvDupe2_RenameNode", ply)
			umsg.String(newname)
		umsg.End()
	end
	
	--[[==============]]--
	--[[FILE FUNCTIONS]]--
	--[[==============]]--
	
	//Download a file from the server
	local function DownloadFile(ply, cmd, args)
		
		if(ply.AdvDupe2.Pasting || ply.AdvDupe2.Downloading)then
			AdvDupe2.Notify(ply,"Advanced Duplicator 2 is busy.",NOTIFY_ERROR)
			return false 
		end
		if(!tobool(GetConVarString("AdvDupe2_AllowDownloading")))then
			AdvDupe2.Notify(ply,"Downloading is not allowed.",NOTIFY_ERROR)
			return false 
		end
		
		local path = args[1]
		local area = tonumber(args[2])

		local newfile 
		if(area==0)then	//AD2 folder in client's folder
			newfile = ply:GetAdvDupe2Folder().."/"..path..".txt"
		elseif(area==1)then	//Public folder
			if(!tobool(GetConVarString("AdvDupe2_AllowPublicFolder")))then
				AdvDupe2.Notify(ply,"Public Folder is disabled.",NOTIFY_ERROR)
				return
			end
			newfile = AdvDupe2.DataFolder.."/=Public=/"..path..".txt"
		else	//AD1 folder in client's folder
			newfile = "adv_duplicator/"..ply:GetAdvDupe2Folder().."/"..path..".txt"
		end

		if(!file.Exists(newfile))then return end
		
		AdvDupe2.EstablishNetwork(ply, file.Read(newfile))
	end
	concommand.Add("AdvDupe2_DownloadFile", DownloadFile)
	
	//Open a file on the server
	local function OpenFile(ply, cmd, args)
		if(args[1]=="" || args[1]==nil || args[2]=="" || args[2]==nil)then return end
	
		if(ply.AdvDupe2.Pasting || ply.AdvDupe2.Downloading)then
			AdvDupe2.Notify(ply,"Advanced Duplicator 2 is busy.",NOTIFY_ERROR)
			return false 
		end
		
		if(!SinglePlayer() && CurTime()-(ply.AdvDupe2.FileMod or 0) < 0)then 
			AdvDupe2.Notify(ply,"Cannot open at the moment. Please Wait...", NOTIFY_ERROR)
			return
		end
		ply.AdvDupe2.FileMod = CurTime()+tonumber(GetConVarString("AdvDupe2_FileModificationDelay"))
		
		local path, area = args[1], tonumber(args[2])
		local name = args[1]:match("[^/]+$")
		
		if(area==0)then
			data = ply:ReadAdvDupe2File(path)
		elseif(area==1)then
			if(SinglePlayer())then path = "=Public=/"..path end
			data = AdvDupe2.ReadFile(nil, path)
			if(data==nil)then
				AdvDupe2.Notify(ply, "File does not exist!", NOTIFY_ERROR)
			elseif(data==false)then
				AdvDupe2.Notify(ply,"File size is greater than "..GetConVarString("AdvDupe2_MaxFileSize"), NOTIFY_ERROR)
			end
		else
			data = AdvDupe2.ReadFile(ply, path, "adv_duplicator")
		end
		if(data==false || data==nil)then
			return
		end
		
		AdvDupe2.Decode(data, function(success,dupe,info,moreinfo)

			if(!IsValid(ply))then return end
			
			if not success then 
				AdvDupe2.Notify(ply,"Could not open "..dupe,NOTIFY_ERROR)
				return
			end
			
			if(!SinglePlayer())then
				if(tonumber(GetConVarString("AdvDupe2_MaxConstraints"))!=0 && #dupe["Constraints"]>tonumber(GetConVarString("AdvDupe2_MaxConstraints")))then
					AdvDupe2.Notify(ply,"Amount of constraints is greater than "..GetConVarString("AdvDupe2_MaxConstraints"),NOTIFY_ERROR)
					return false
				end
				/*
				local entcount = table.Count(dupe["Entities"])
				
				if(tonumber(GetConVarString("AdvDupe2_MaxEntities"))>0)then
					if(entcount>tonumber(GetConVarString("AdvDupe2_MaxEntities")))then
						AdvDupe2.Notify(ply,"Amount of entities is greater than "..GetConVarString("AdvDupe2_MaxEntities"),NOTIFY_ERROR)
						return false
					end
				else
					if(entcount>tonumber(GetConVarString("sbox_maxprops")))then
						AdvDupe2.Notify(ply,"Amount of entities is greater than "..GetConVarString("sbox_maxprops"),NOTIFY_ERROR)
						return false
					end
				end*/
			end

			ply.AdvDupe2.Entities = {}
			ply.AdvDupe2.Constraints = {}
			ply.AdvDupe2.HeadEnt={}
			local time
			local desc
			local date
			local creator
			
			if(info.ad1)then
				time = moreinfo["Time"] or ""
				desc = info["Description"] or ""
				date = info["Date"] or ""
				creator = info["Creator"] or ""
				
				ply.AdvDupe2.HeadEnt.Index = tonumber(moreinfo.Head)
				local spx,spy,spz = moreinfo.StartPos:match("^(.-),(.-),(.+)$")
				ply.AdvDupe2.HeadEnt.Pos = Vector(tonumber(spx) or 0, tonumber(spy) or 0, tonumber(spz) or 0)
				local z = (tonumber(moreinfo.HoldPos:match("^.-,.-,(.+)$")) or 0)*-1
				ply.AdvDupe2.HeadEnt.Z = z
				ply.AdvDupe2.HeadEnt.Pos.Z = ply.AdvDupe2.HeadEnt.Pos.Z + z
				local Pos
				local Ang
				for k,v in pairs(dupe["Entities"])do
					Pos = nil
					Ang = nil
					if(v.SavedParentIdx)then 
						if(!v.BuildDupeInfo)then v.BuildDupeInfo = {} end
						v.BuildDupeInfo.DupeParentID = v.SavedParentIdx
						Pos = v.LocalPos*1
						Ang = v.LocalAngle*1
					end
					for i,p in pairs(v.PhysicsObjects)do
						p.Pos = Pos or (p.LocalPos*1)
						p.Pos.Z = p.Pos.Z - z
						p.Angle = Ang or (p.LocalAngle*1)
						p.LocalPos = nil
						p.LocalAngle = nil
					end
					v.LocalPos = nil
					v.LocalAngle = nil
				end

				ply.AdvDupe2.Entities = dupe["Entities"]
				ply.AdvDupe2.Constraints = dupe["Constraints"]
				
			else
				time = info["time"]
				desc = dupe["Description"]
				date = info["date"]
				creator = info["name"]
				
				ply.AdvDupe2.Entities = dupe["Entities"]
				ply.AdvDupe2.Constraints = dupe["Constraints"]
				ply.AdvDupe2.HeadEnt = dupe["HeadEnt"]
			end
			
			ply.AdvDupe2.Name = name
			
			umsg.Start("AdvDupe2_SetDupeInfo", ply)
				umsg.String(name)
				umsg.String(creator)
				umsg.String(date)
				umsg.String(time)
				umsg.String(string.NiceSize(tonumber(info.size) or 0))
				umsg.String(desc)
				umsg.String(table.Count(ply.AdvDupe2.Entities))
				umsg.String(#ply.AdvDupe2.Constraints)
			umsg.End()
			
			AdvDupe2.ResetOffsets(ply)
			AdvDupe2.StartGhosting(ply)
		end)
	end
	concommand.Add("AdvDupe2_OpenFile", OpenFile)
	
	//Save a file to the server
	local function SaveFile(ply, cmd, args)
		if(!ply.AdvDupe2 || !ply.AdvDupe2.Entities || ply.AdvDupe2.Entities == {})then return end
		if(args[1]=="" || args[1]==nil || args[3]=="" || args[3]==nil)then return end

		if(!SinglePlayer() && CurTime()-(ply.AdvDupe2.FileMod or 0) < 0)then 
			AdvDupe2.Notify(ply,"Cannot save at the moment. Please Wait...", NOTIFY_ERROR)
			return
		end
		ply.AdvDupe2.FileMod = CurTime()+tonumber(GetConVarString("AdvDupe2_FileModificationDelay"))
		
		local path, area = args[1], tonumber(args[3])
		local public = false
		
		if(args[2]!="")then
			path = args[2].."/"..path
		end
		
		if(area==1)then
			if(!tobool(GetConVarString("AdvDupe2_AllowPublicFolder")))then
				AdvDupe2.Notify(ply,"Public Folder is disabled.",NOTIFY_ERROR)
				return
			end
			if(SinglePlayer())then path = "=Public=/"..path end
			public = true
		elseif(area==2)then
			AdvDupe2.Notify(ply,"Cannot save into this directory.",NOTIFY_ERROR)
			return
		end
		
		umsg.Start("AdvDupe2_SetDupeInfo", ply)
			umsg.String(args[1])
			umsg.String(ply:Nick())
			umsg.String(os.date("%d %B %Y"))
			umsg.String(os.date("%I:%M %p"))
			umsg.String("")
			umsg.String(args[4])
			umsg.String(table.Count(ply.AdvDupe2.Entities))
			umsg.String(#ply.AdvDupe2.Constraints)
		umsg.End()
		
		local Tab = {Entities = ply.AdvDupe2.Entities, Constraints = ply.AdvDupe2.Constraints, HeadEnt = ply.AdvDupe2.HeadEnt, Description=args[4]}
		
		AdvDupe2.Encode(
			Tab,
			AdvDupe2.GenerateDupeStamp(ply),
			function(data)
				local dir, name = "", ""
				if(!public)then
					dir, name = ply:WriteAdvDupe2File(path, data)
				else
					dir, name = AdvDupe2.WriteFile(nil, path, data)
				end
				AddFile(ply,name,args[5],true)
			end)
			
		if(!SinglePlayer() && tobool(GetConVarString("AdvDupe2_RemoveFilesOnDisconnect")))then
			AdvDupe2.Notify(ply, "Your saved files will be deleted when you disconnect!", NOTIFY_CLEANUP, 10)
		end
	end
	concommand.Add("AdvDupe2_SaveFile", SaveFile)
	
	//Add a new folder to the server
	local function NewFolder(ply, cmd, args)
	
		if(!SinglePlayer() && CurTime()-(ply.AdvDupe2.FileMod or 0) < 0)then 
			AdvDupe2.Notify(ply,"Cannot create a new folder at the moment.  Please Wait...", NOTIFY_ERROR)
			return
		end
		ply.AdvDupe2.FileMod = CurTime()+tonumber(GetConVarString("AdvDupe2_FileModificationDelay"))
	
		local path, area = args[1], tonumber(args[3])
		local public = false
		if path:find("%W") then AdvDupe2.Notify(ply,"Invalid folder name.",NOTIFY_ERROR) return false end
		
		if(args[2]!="")then 
			path = args[2].."/"..path
		end
			
		if(area==0)then
			path = ply:GetAdvDupe2Folder().."/"..path
		elseif(area==1)then
			if(!tobool(GetConVarString("AdvDupe2_AllowPublicFolder")))then
				AdvDupe2.Notify(ply,"Public Folder is disabled.",NOTIFY_ERROR)
				return
			end
			path = AdvDupe2.DataFolder.."/=Public=/"..path
		else
			path = "adv_duplicator/"..ply:SteamIDSafe().."/"..path
		end


		if(file.IsDir(path))then 
			AdvDupe2.Notify(ply,"Folder name already exists.",NOTIFY_ERROR)
			return 
		end
		file.CreateDir(path)
		ply.AdvDupe2.FolderID = ply.AdvDupe2.FolderID+1
		AddFolder(ply, args[1], ply.AdvDupe2.FolderID, args[4], true)
	end
	concommand.Add("AdvDupe2_NewFolder", NewFolder)
	
	local function TFindDelete(Search, Folders, Files)
		Search = string.sub(Search, 6, -2)
		
		for k,v in pairs(Files)do
			file.Delete(Search..v)
		end
		
		for k,v in pairs(Folders)do
			file.TFind("data/"..Search..v.."/*", 
				function(Search2, Folders2, Files2)
					TFindDelete(Search2, Folders2, Files2)
				end)
		end
	end
	
	//Delete a file on the server
	local function DeleteFile(ply, cmd, args)
	
		if(!SinglePlayer() && CurTime()-(ply.AdvDupe2.FileMod or 0) < 0)then 
			AdvDupe2.Notify(ply,"Cannot delete at the moment.  Please Wait...", NOTIFY_ERROR)
			return
		end
		ply.AdvDupe2.FileMod = CurTime()+tonumber(GetConVarString("AdvDupe2_FileModificationDelay"))
	
		local path, area = args[1], tonumber(args[2])
		local folder = tobool(args[3])


		if(area==0)then
			if(folder)then
				path = ply:GetAdvDupe2Folder().."/"..path
			else
				path = ply:GetAdvDupe2Folder().."/"..path..".txt"
			end
		elseif(area==1)then
			if(!ply:IsAdmin())then
				AdvDupe2.Notify(ply,"You are not an admin.",NOTIFY_ERROR)
				return
			end
			if(folder)then
				path = AdvDupe2.DataFolder.."/=Public=/"..path
			else
				path = AdvDupe2.DataFolder.."/=Public=/"..path..".txt"
			end
		else
			if(folder)then
				path = "adv_duplicator/"..ply:SteamIDSafe().."/"..path
			else
				path = "adv_duplicator/"..ply:SteamIDSafe().."/"..path..".txt"
			end
		end
		if(!folder && file.Exists(path))then
			file.Delete(path)
		end
		
		if(folder && file.IsDir(path))then 
			file.TFind("data/"..path.."/*", 
				function(Search, Folders, Files)
					TFindDelete(Search, Folders, Files)
				end)
		end
		umsg.Start("AdvDupe2_DeleteNode", ply)
		umsg.End()
		
	end
	concommand.Add("AdvDupe2_DeleteFile", DeleteFile)
	
	local function RenameFile(ply, cmd, args)
	
		if(!SinglePlayer() && CurTime()-(ply.AdvDupe2.FileMod or 0) < 0)then 
			AdvDupe2.Notify(ply,"Cannot rename at the moment.  Please Wait...", NOTIFY_ERROR)
			return
		end
		ply.AdvDupe2.FileMod = CurTime()+tonumber(GetConVarString("AdvDupe2_FileModificationDelay"))

		local Alt = tonumber(args[1]) or nil
		if(Alt==nil)then return end
		local NewName = args[2]
		local Path = args[3]
		
		if(Alt==0)then
			Path = ply:GetAdvDupe2Folder().."/"..Path
		elseif(Alt==1)then
			AdvDupe2.Notify(ply, "Public folder modification not allowed", NOTIFY_ERROR)
			//Path = AdvDupe2.DataFolder.."/"..Path
		else
			Path = "adv_duplicator/"..ply:SteamIDSafe().."/"..Path
		end
		
		local NewPath = string.sub(Path, 1, -#Path:match("[^/]+$")-1)..NewName
		
		if file.Exists(NewPath..".txt") then
			local found = false
			for i = 1, AdvDupe2.FileRenameTryLimit do
				if not file.Exists(NewPath.."_"..i..".txt") then
					NewPath = NewPath.."_"..i
					found = true
					break
				end
			end
			if(!found)then AdvDupe2.Notify(ply, "File could not be renamed.", NOTIFY_ERROR) return end
		end
		local File = file.Read(Path..".txt")
		file.Write(NewPath..".txt", File)
		
		if(file.Exists(NewPath..".txt"))then
			file.Delete(Path..".txt")
			RenameNode(ply, NewPath:match("[^/]+$"))
		else
			AdvDupe2.Notify(ply, "File rename failed.", NOTIFY_ERROR)
		end
		
	end
	concommand.Add("AdvDupe2_RenameFile", RenameFile)
	
	local function MoveFile(ply, cmd, args)
		
		if(!SinglePlayer() && CurTime()-(ply.AdvDupe2.FileMod or 0) < 0)then 
			AdvDupe2.Notify(ply,"Cannot move file at the moment.  Please Wait...", NOTIFY_ERROR)
			return
		end
		ply.AdvDupe2.FileMod = CurTime()+tonumber(GetConVarString("AdvDupe2_FileModificationDelay"))
		
		local area1, area2 = tonumber(args[1]) or nil, tonumber(args[2]) or nil
		local path1, path2 = args[3], args[4]
		
		if(area1==nil || area2==nil)then return end
		if((area1==2 && area2!=2) || (area2==2 && area1!=2))then return end
		
		path1 = ply:SteamIDSafe().."/"..path1
		path2 = ply:SteamIDSafe().."/"..path2.."/"..path1:match("[^/]+$")

		if(area1==0)then
			path1 = AdvDupe2.DataFolder.."/"..path1
		elseif(area1==1)then
			AdvDupe2.Notify(ply, "Public folder modification not allowed", NOTIFY_ERROR)
			//path1 = AdvDupe2.DataFolder.."/".."=Public=/"..path1
			return
		else
			path1 = "adv_duplicator/"..path1
		end
		
		if(area2==0)then
			path2 = AdvDupe2.DataFolder.."/"..path2
		elseif(area2==1)then
			AdvDupe2.Notify(ply, "Public folder modification not allowed", NOTIFY_ERROR)
			//path2 = AdvDupe2.DataFolder.."/".."=Public=/"..path2
			return
		else
			path2 = "adv_duplicator/"..path2
		end
		
		local File = file.Read(path1..".txt")
		if(!File)then return end
		
		if file.Exists(path2..".txt") then
			local found = false
			for i = 1, AdvDupe2.FileRenameTryLimit do
				if not file.Exists(path2.."_"..i..".txt") then
					path2 = path2.."_"..i
					found = true
					break
				end
			end
			if(!found)then AdvDupe2.Notify(ply, "File could not be renamed.", NOTIFY_ERROR) return end
		end
		
		file.Write(path2..".txt", File)
		if(file.Exists(path2..".txt"))then
			file.Delete(path1..".txt")
			
			umsg.Start("AdvDupe2_MoveNode", ply)
				umsg.String(path2:match("[^/]+$"))
			umsg.End()
		else
			AdvDupe2.Notify(ply, "File could not be moved.", NOTIFY_ERROR)
		end
		
	end
	concommand.Add("AdvDupe2_MoveFile", MoveFile)
	
	//TFind files and folders on the server
	local function TFind(ply, Search, Folders, Files, parent)

		for k,v in pairs(Files)do
			local File = {}
			File.Name = string.Left(v, #v-4)
			File.IsFolder = 0
			File.Parent = parent
			table.insert(ply.AdvDupe2.Files, File)
		end
		for k,v in pairs(Folders)do
			ply.AdvDupe2.FolderID=ply.AdvDupe2.FolderID+1
			local Folder = {}
			Folder.Name = v
			Folder.Parent = parent
			Folder.ID = ply.AdvDupe2.FolderID
			table.insert(ply.AdvDupe2.Folders, Folder)
			file.TFind(string.Left(Search,#Search-1)..v.."/*", function(Search2, Folders2, Files2) TFind(ply, Search2, Folders2, Files2, Folder.ID) end)
		end
		ply.AdvDupe2.SendFiles = true
	end
	
	concommand.Add("AdvDupe2_SendFiles", function(ply, cmd, args) 

			if(ply.AdvDupe2 && !SinglePlayer() && CurTime()-(ply.AdvDupe2.NextSend or 0) < 0)then 
				AdvDupe2.Notify(ply,"Cannot update at the moment.  Please Wait...",NOTIFY_ERROR)
				return 	
			end
			
			if(!ply.AdvDupe2)then ply.AdvDupe2 = {} end
			ply.AdvDupe2.SendFiles = false
			ply.AdvDupe2.LastFile = 0
			ply.AdvDupe2.FolderID = 0
			ply.AdvDupe2.Folders = {}
			ply.AdvDupe2.Files = {}
			if(tonumber(args[1])==0)then
				umsg.Start("AdvDupe2_ClearBrowser", ply)
				umsg.End()
				return
			end 
			

			
			file.TFind("data/"..ply:GetAdvDupe2Folder().."/*", 
				function(Search, Folders, Files) 
					if(!ply.AdvDupe2)then ply.AdvDupe2 = {} end
					ply.AdvDupe2.NextSend = CurTime() + tonumber(GetConVarString("AdvDupe2_UpdateFilesDelay"))
					
					local AD1 = "adv_duplicator"
					if(!SinglePlayer())then
						AD1 = AD1.."/"..ply:SteamIDSafe()
					end
					ply.AdvDupe2.FolderID=ply.AdvDupe2.FolderID+1
					local AD1Folder = {}
					AD1Folder.Name = "=Adv Duplicator="
					AD1Folder.Parent = 0
					AD1Folder.ID = ply.AdvDupe2.FolderID
					table.insert(ply.AdvDupe2.Folders, AD1Folder)
					
					if(!SinglePlayer() && tobool(GetConVarString("AdvDupe2_AllowPublicFolder")))then
						ply.AdvDupe2.FolderID=ply.AdvDupe2.FolderID+1
						local Folder = {}
						Folder.Name = "=Public="
						Folder.Parent = 0
						Folder.ID = ply.AdvDupe2.FolderID
						Folder.Public = true
						table.insert(ply.AdvDupe2.Folders, Folder)
						file.TFind("data/advdupe2/=Public=/*", function(Search, Folders, Files) TFind(ply, Search, Folders, Files, Folder.ID) end)
					end
					
					file.TFind("data/"..AD1.."/*", 
						function(Search2, Folders2, Files2)
							TFind(ply, Search2, Folders2, Files2, AD1Folder.ID) 
						end)
					
					TFind(ply, Search, Folders, Files, 0) 
				end) 
				
				
		end)
		
	--[[=====================]]--
	--[[END OF FILE FUNCTIONS]]--
	--[[=====================]]--
		
	function AdvDupe2.InitProgressBar(ply,label)
		umsg.Start("AdvDupe2_InitProgressBar",ply)
			umsg.String(label)
		umsg.End()
	end
	
	concommand.Add("AdvDupe2_RemakeGhosts", function(ply, cmd, args)
		ply:GetTool("advdupe2"):RemoveGhosts(ply)
		AdvDupe2.StartGhosting(ply)
		AdvDupe2.ResetOffsets(ply)
	end)
end


concommand.Add( "SaveDupe", SaveDupe )
concommand.Add( "ReadDupe", ReadDupe )
if CLIENT then

	language.Add( "Tool_advdupe2_name",	"Advanced Duplicator 2" )
	language.Add( "Tool_advdupe2_desc",	"Duplicate things." )
	language.Add( "Tool_advdupe2_0",		"Primary: Paste, Secondary: Copy." )
	language.Add( "Tool_advdupe2_1",		"Primary: Paste, Secondary: Copy an area." )
	language.Add( "Undone_AdvDupe2",	"Undone AdvDupe2 paste" )
	language.Add( "Cleanup_AdvDupe2",	"Adv. Duplications" )
	language.Add( "Cleaned_AdvDupe2",	"Cleaned up all Adv. Duplications" )
	language.Add( "SBoxLimit_AdvDupe2",	"You've reached the Adv. Duplicator limit!" )
	
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
	CreateClientConVar("advdupe2_limit_ghost", 100, false, true)
	CreateClientConVar("advdupe2_area_copy_size", 300, false, true)
	
	//Contraption Spawner
	CreateClientConVar("advdupe2_contr_spawner_key", -1, false, true)
	CreateClientConVar("advdupe2_contr_spawner_undo_key", -1, false, true)
	CreateClientConVar("advdupe2_contr_spawner_delay", 0, false, true)
	CreateClientConVar("advdupe2_contr_spawner_undo_delay", 0, false, true)
	CreateClientConVar("advdupe2_contr_spawner_disgrav", 0, false, true)
	CreateClientConVar("advdupe2_contr_spawner_disdrag", 0, false, true)
	CreateClientConVar("advdupe2_contr_spawner_addvel", 1, false, true)
	
	//Experimental
	CreateClientConVar("advdupe2_paste_disparents", 0, false, true)
	CreateClientConVar("advdupe2_paste_protectoveride", 0, false, true)
	
	local function BuildCPanel()
		local CPanel = GetControlPanel("advdupe2")
		
		if not CPanel then return end
		CPanel:ClearControls()
		local Fill = vgui.Create( "DPanel" )
		CPanel:AddPanel(Fill)
		Fill:SetTall(CPanel:GetParent():GetParent():GetTall()-45)
		local List = vgui.Create( "DPanelList", CPanel )
		List:EnableVerticalScrollbar( true )
		List:Dock( FILL )
		List:SetSpacing( 2 )
		List:SetPadding( 2 )

		local FileBrowser = vgui.Create("advdupe2_browser")
		AdvDupe2.FileBrowser = FileBrowser
		List:AddItem(FileBrowser)
		FileBrowser:SetSize(235,450)
		FileBrowser.Filler = Fill
		FileBrowser.Initialized = true
		RunConsoleCommand("AdvDupe2_SendFiles")
		
		local Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Paste at original position" )
		Check:SetConVar( "advdupe2_original_origin" ) 
		Check:SetValue( 0 )
		Check:SetToolTip("Paste at the coords originally copied")
		List:AddItem(Check)
		
		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Paste with constraints" )
		Check:SetConVar( "advdupe2_paste_constraints" ) 
		Check:SetValue( 1 )
		Check:SetToolTip("Paste with or without constraints")
		List:AddItem(Check)
		
		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Paste with parenting" )
		Check:SetConVar( "advdupe2_paste_parents" ) 
		Check:SetValue( 1 )
		Check:SetToolTip("Paste with or without parenting")
		List:AddItem(Check)
		
		local Check_1 = vgui.Create("DCheckBoxLabel")
		local Check_2 = vgui.Create("DCheckBoxLabel")
		
		Check_1:SetText( "Unfreeze all after paste" )
		Check_1:SetConVar( "advdupe2_paste_unfreeze" ) 
		Check_1:SetValue( 0 )
		Check_1.OnChange = 	function() 
								if(Check_1:GetChecked() and Check_2:GetChecked())then
									Check_2:SetValue(0)
								end
							end
		Check_1:SetToolTip("Unfreeze all props after pasting")
		List:AddItem(Check_1)
		
		Check_2:SetText( "Preserve frozen state after paste" )
		Check_2:SetConVar( "advdupe2_preserve_freeze" ) 
		Check_2:SetValue( 0 )
		Check_2.OnChange = 	function() 
								if(Check_2:GetChecked() and Check_1:GetChecked())then
									Check_1:SetValue(0)
								end
							end
		Check_2:SetToolTip("Makes props have the same frozen state as when they were copied")
		List:AddItem(Check_2)
		
		Check = vgui.Create("DCheckBoxLabel")
		Check:SetText( "Area copy constrained props outside of box" )
		Check:SetConVar( "advdupe2_copy_outside" ) 
		Check:SetValue( 0 )
		Check:SetToolTip("Copy entities outside of the area copy that are constrained to entities insde")
		List:AddItem(Check)

		local NumSlider = vgui.Create( "DNumSlider" )
		NumSlider:SetText( "Percent of ghost to create" )
		NumSlider:SetMin( 0 )
		NumSlider:SetMax( 100 )
		NumSlider:SetDecimals( 0 )
		NumSlider:SetConVar( "advdupe2_limit_ghost" )
		NumSlider:SetToolTip("Change the percent of ghosts to spawn")
		//If these funcs are not here, problems occur for each
		local func = NumSlider.Slider.OnMouseReleased
		NumSlider.Slider.OnMouseReleased = function(mcode) func(mcode) RunConsoleCommand("AdvDupe2_RemakeGhosts") end
		local func2 = NumSlider.Wang.OnMouseReleased	//Hacky way to make it work
		NumSlider.Wang.OnMouseReleased = function(mousecode) func2(mousecode) RunConsoleCommand("AdvDupe2_RemakeGhosts") end
		local func3 = NumSlider.Wang.TextEntry.OnLoseFocus
		NumSlider.Wang.TextEntry.OnLoseFocus = function(txtBox) func3(txtBox) RunConsoleCommand("AdvDupe2_RemakeGhosts") end
		List:AddItem(NumSlider)
		
		NumSlider = vgui.Create( "DNumSlider" )
		NumSlider:SetText( "Area Copy Size" )
		NumSlider:SetMin( 0 )
		NumSlider:SetMax( 2500 )
		NumSlider:SetDecimals( 0 )
		NumSlider:SetConVar( "advdupe2_area_copy_size" )
		NumSlider:SetToolTip("Change the size of the area copy")
		List:AddItem(NumSlider)
		
		local Category1 = vgui.Create("DCollapsibleCategory")
		List:AddItem(Category1)
		Category1:SetLabel("Offsets")
		Category1:SetExpanded(0)
		
		--[[Offsets]]--
			local CategoryContent1 = vgui.Create( "DPanelList" )
			CategoryContent1:SetAutoSize( true )
			CategoryContent1:SetDrawBackground( false )
			CategoryContent1:SetSpacing( 1 )
			CategoryContent1:SetPadding( 2 )
			
			Category1:SetContents( CategoryContent1 )
					
			NumSlider = vgui.Create( "DNumSlider" )
			NumSlider:SetText( "Height Offset" )
			NumSlider:SetMin( 0 )
			NumSlider:SetMax( 2500 ) 
			NumSlider:SetDecimals( 0 ) 
			NumSlider:SetConVar("advdupe2_offset_z")
			NumSlider:SetToolTip("Change the Z offset of the dupe")
			CategoryContent1:AddItem(NumSlider)
			
			Check = vgui.Create("DCheckBoxLabel")
			Check:SetText( "Use World Angles" )
			Check:SetConVar( "advdupe2_offset_world" ) 
			Check:SetValue( 0 )
			Check:SetToolTip("Use world angles for the offset instead of the main entity")
			CategoryContent1:AddItem(Check)
			
			NumSlider = vgui.Create( "DNumSlider" )
			NumSlider:SetText( "Pitch Offset" )
			NumSlider:SetMin( -180 ) 
			NumSlider:SetMax( 180 ) 
			NumSlider:SetDecimals( 0 ) 
			NumSlider:SetConVar("advdupe2_offset_pitch")
			CategoryContent1:AddItem(NumSlider)
					
			NumSlider = vgui.Create( "DNumSlider" )
			NumSlider:SetText( "Yaw Offset" )
			NumSlider:SetMin( -180 )
			NumSlider:SetMax( 180 )
			NumSlider:SetDecimals( 0 )
			NumSlider:SetConVar("advdupe2_offset_yaw")
			CategoryContent1:AddItem(NumSlider)
					
			NumSlider = vgui.Create( "DNumSlider" )
			NumSlider:SetText( "Roll Offset" )
			NumSlider:SetMin( -180 )
			NumSlider:SetMax( 180 )
			NumSlider:SetDecimals( 0 )
			NumSlider:SetConVar("advdupe2_offset_roll")
			CategoryContent1:AddItem(NumSlider)
			
			
		--[[Dupe Information]]--
			local Category2 = vgui.Create("DCollapsibleCategory")
			List:AddItem(Category2)
			Category2:SetLabel("Dupe Information")
			Category2:SetExpanded(0)
					
			local CategoryContent2 = vgui.Create( "DPanelList" )
			CategoryContent2:SetAutoSize( true )
			CategoryContent2:SetDrawBackground( false )
			CategoryContent2:SetSpacing( 3 )
			CategoryContent2:SetPadding( 2 )
			Category2:SetContents( CategoryContent2 )
			
			AdvDupe2.Info = {}
			
			local lbl = vgui.Create( "DLabel" )
			lbl:SetText("File: ")
			CategoryContent2:AddItem(lbl)
			AdvDupe2.Info.File = lbl
			
			lbl = vgui.Create( "DLabel" )
			lbl:SetText("Creator:")
			CategoryContent2:AddItem(lbl)
			AdvDupe2.Info.Creator = lbl
			
			lbl = vgui.Create( "DLabel" )
			lbl:SetText("Date:")
			CategoryContent2:AddItem(lbl)
			AdvDupe2.Info.Date = lbl
			
			lbl = vgui.Create( "DLabel" )
			lbl:SetText("Time:")
			CategoryContent2:AddItem(lbl)
			AdvDupe2.Info.Time = lbl
			
			lbl = vgui.Create( "DLabel" )
			lbl:SetText("Size:")
			CategoryContent2:AddItem(lbl)
			AdvDupe2.Info.Size = lbl
			
			lbl = vgui.Create( "DLabel" )
			lbl:SetText("Desc:")
			CategoryContent2:AddItem(lbl)
			AdvDupe2.Info.Desc = lbl
			
			lbl = vgui.Create( "DLabel" )
			lbl:SetText("Entities:")
			CategoryContent2:AddItem(lbl)
			AdvDupe2.Info.Entities = lbl
			
			lbl = vgui.Create( "DLabel" )
			lbl:SetText("Constraints:")
			CategoryContent2:AddItem(lbl)
			AdvDupe2.Info.Constraints = lbl
		
		--[[Contraption Spawner]]--
			local Category3 = vgui.Create("DCollapsibleCategory")
			List:AddItem(Category3)
			Category3:SetLabel("Contraption Spawner")
			Category3:SetExpanded(0)
			
			local CategoryContent3 = vgui.Create( "DPanelList" )
			CategoryContent3:SetAutoSize( true )
			CategoryContent3:SetDrawBackground( false )
			CategoryContent3:SetSpacing( 3 )
			CategoryContent3:SetPadding( 2 )
			Category3:SetContents( CategoryContent3 )
					
			local ctrl = vgui.Create( "CtrlNumPad" )
			ctrl:SetConVar1( "advdupe2_contr_spawner_key" )
			ctrl:SetConVar2( "advdupe2_contr_spawner_undo_key" )
			ctrl:SetLabel1( "Spawn Key")
			ctrl:SetLabel2( "Undo Key" )
			CategoryContent3:AddItem(ctrl)
				
			NumSlider = vgui.Create( "DNumSlider" )
			NumSlider:SetText( "Spawn Delay" )
			if(SinglePlayer())then
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
			if(SinglePlayer())then 
				NumSlider:SetMin( 0 )
				NumSlider:SetMax( 60 )
			else
				local min = tonumber(GetConVarString("AdvDupe2_MinContraptionUndoDelay")) or 0.1
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
			Check:SetConVar( "advdupe2_contr_spawner_disgrav" ) 
			Check:SetValue( 0 )
			CategoryContent3:AddItem(Check)
					
			Check = vgui.Create("DCheckBoxLabel")
			Check:SetText( "Disable drag for all spawned props" )
			Check:SetConVar( "advdupe2_contr_spawner_disdrag" ) 
			Check:SetValue( 0 )
			CategoryContent3:AddItem(Check)
					
			Check = vgui.Create("DCheckBoxLabel")
			Check:SetText( "Add spawner's velocity to contraption" )
			Check:SetConVar( "advdupe2_contr_spawner_addvel" ) 
			Check:SetValue( 1 )
			CategoryContent3:AddItem(Check)
			
		--[[Experimental Section]]--
			local Category4 = vgui.Create("DCollapsibleCategory")
			List:AddItem(Category4)
			Category4:SetLabel("Experimental Section")
			Category4:SetExpanded(0)
			
			local CategoryContent4 = vgui.Create( "DPanelList" )
			CategoryContent4:SetAutoSize( true )
			CategoryContent4:SetDrawBackground( false )
			CategoryContent4:SetSpacing( 3 )
			CategoryContent4:SetPadding( 2 )
			Category4:SetContents( CategoryContent4 )
			
			Check = vgui.Create("DCheckBoxLabel")
			Check:SetText( "Disable parented props physics interaction" )
			Check:SetConVar( "advdupe2_paste_disparents" ) 
			Check:SetValue( 0 )
			CategoryContent4:AddItem(Check)
			
			Check = vgui.Create("DCheckBoxLabel")
			Check:SetText( "Disable Dupe Spawn Protection" )
			Check:SetConVar( "advdupe2_paste_protectoveride" ) 
			Check:SetValue( 0 )
			CategoryContent4:AddItem(Check)
	end
	
	function TOOL.BuildCPanel(panel)
		panel:AddControl("Header", {
			Text = "Advanced Duplicator 2",
			Description = "Duplicate stuff."
		})
		timer.Simple(0, BuildCPanel)	
	end

	local state = 0
	local ToColor = {r=25, g=100, b=40, a=255}
	local CurColor = {r=25, g=100, b=40, a=255}
	local rate
	surface.CreateFont ("Arial", 40, 1000, true, false, "AD2Font") ---Remember to use gm_clearfonts
	surface.CreateFont ("Arial", 24, 1000, true, false, "AD2TitleFont")
	//local spacing = {"   ","     ","       ","         ","           ","             "}
	function TOOL:RenderToolScreen()
		if(!AdvDupe2)then return true end
		
		local text = "Ready"
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
			if(state!=0)then
				draw.RoundedBox( 6, 32, 178, 192, 28, Color( 255, 255, 255, 150 ) )
				draw.RoundedBox( 6, 36, 182, 188*(AdvDupe2.ProgressBar.Percent/100), 24, Color( 0, 255, 0, 255 ) )
			elseif(LocalPlayer():KeyDown(IN_USE))then
				//draw.SimpleText("Height:   Pitch:   Roll:", "AD2TitleFont", 128, 206, Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				//local str_space1 = spacing[7-string.len(height)] or ""
				//local str_space2 = spacing[7-string.len(pitch)] or ""
				//draw.SimpleText(height..str_space1..pitch..str_space2..LocalPlayer():GetInfo("advdupe2_offset_roll"), "AD2TitleFont", 25, 226, Color(255,255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				draw.SimpleText("Height: "..LocalPlayer():GetInfo("advdupe2_offset_z"), "AD2TitleFont", 25, 180, Color(255,255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				draw.SimpleText("Pitch: "..LocalPlayer():GetInfo("advdupe2_offset_pitch"), "AD2TitleFont", 25, 210, Color(255,255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				draw.SimpleText("Yaw: "..LocalPlayer():GetInfo("advdupe2_offset_yaw"), "AD2TitleFont", 25, 240, Color(255,255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			end
			
		cam.End2D()
	end

	
	local function FindInBox(min, max, ply)

		local Entities = ents.GetAll()
		local EntTable = {}
		for _,ent in pairs(Entities) do
			local pos = ent:GetPos()
			if (pos.X>=min.X) and (pos.X<=max.X) and (pos.Y>=min.Y) and (pos.Y<=max.Y) and (pos.Z>=min.Z) and (pos.Z<=max.Z) then
				if(ent:GetClass()!="gmod_ghost")then
					EntTable[ent:EntIndex()] = ent
				end
			end
		end

		return EntTable
	end
	
	local function DrawSelectionBox()
			
		local trace = util.GetPlayerTrace(LocalPlayer())
		local TraceRes = util.TraceLine(trace)
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
				
		//Version 1 Constantly resets the color of all the props that have entered the box and changes all the props color in the it.
		//Version 2 Only Colors if the prop is new or has left the box, but if a prop is moved it will change back...gmod bug.
				
		//Version 1 of prop coloring
		if(!AdvDupe2.LastUpdate || CurTime()>=AdvDupe2.LastUpdate)then
			
			if AdvDupe2.ColorEntities then
				for k,v in pairs(AdvDupe2.EntityColors)do
					local ent = AdvDupe2.ColorEntities[k]
					if(IsValid(ent))then
						AdvDupe2.ColorEntities[k]:SetColor(v.r,v.g,v.b,v.a)
					end
				end
			end
					
			local Entities = FindInBox(B1, (Vector(i,i,i)+TraceRes.HitPos), LocalPlayer())
			AdvDupe2.ColorEntities = Entities
			AdvDupe2.EntityColors = {}
			for k,v in pairs(Entities)do
				local r,g,b,a = v:GetColor()
				AdvDupe2.EntityColors[k] = {r = r, g = g,b = b,a = a}
				v:SetColor(0,255,0,255)
			end
			AdvDupe2.LastUpdate = CurTime()+0.25
				
		end
				
				/* Version 2 of prop coloring(this version needs some stuff uncommented in the hook)
				if(!AdvDupe2.LastUpdate || CurTime()<=AdvDupe2.LastUpdate)then
				
					AdvDupe2.TempEntities = {}
					local Entities = ents.FindInBox(B1, (Vector(i,i,i)+TraceRes.HitPos))
					
					for k,v in pairs(Entities)do
						local i = v:EntIndex()
						if(!AdvDupe2.ColorEntities[i])then
							local r,g,b,a = v:GetColor()
							AdvDupe2.EntityColors[i] = {r = r, g = g,b = b,a = a}
							v:SetColor(0,255,0,255)
							AdvDupe2.ColorEntities[i] = v
						end
						AdvDupe2.TempEntities[i] = v
					end
					
					if AdvDupe2.ColorEntities then
						for k,v in pairs(AdvDupe2.EntityColors)do
							if(!AdvDupe2.TempEntities[k])then
								local ent = AdvDupe2.ColorEntities[k]
								if(ent:IsValid())then
									AdvDupe2.ColorEntities[k]:SetColor(v.r,v.g,v.b,v.a)
									AdvDupe2.ColorEntities[k] = nil
									AdvDupe2.EntityColors[k] = nil
									
								end
							end	
						end
					end
					
					AdvDupe2.LastUpdate = CurTime()+0.5
				end
				*/
				
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
				hook.Add("HUDPaint", "AdvDupe2_DrawSelectionBox", DrawSelectionBox) 
					if !AdvDupe2 then AdvDupe2={} AdvDupe2.ProgressBar={} end
					/*Version 2 Prop coloring 
					AdvDupe2.ColorEntities = {}
					AdvDupe2.EntityColors = {}
					*/
			end)
			
			usermessage.Hook("AdvDupe2_RemoveSelectBox",function() 
				hook.Remove("HUDPaint", "AdvDupe2_DrawSelectionBox") 
					if AdvDupe2.ColorEntities then
						for k,v in pairs(AdvDupe2.EntityColors)do
							if(!IsValid(AdvDupe2.ColorEntities[k]))then AdvDupe2.ColorEntities[k]=nil continue end
							local r,g,b,a = v.r, v.g, v.b, v.a
							AdvDupe2.ColorEntities[k]:SetColor(r,g,b,a)
						end
						AdvDupe2.ColorEntities={}
						AdvDupe2.EntityColors={}
					end
			end)
			
			function AdvDupe2.InitProgressBar(label)
				if !AdvDupe2 then AdvDupe2={} end
				AdvDupe2.ProgressBar = {}
				AdvDupe2.ProgressBar.Text = label
				AdvDupe2.ProgressBar.Percent = 0
			end
			
			usermessage.Hook("AdvDupe2_InitProgressBar",function(um)
				AdvDupe2.InitProgressBar(um:ReadString())
			end)

			usermessage.Hook("AdvDupe2_UpdateProgressBar",function(um)
				AdvDupe2.ProgressBar.Percent = um:ReadChar()
			end)
			
			usermessage.Hook("AdvDupe2_RemoveProgressBar",function(um)
				if !AdvDupe2 then AdvDupe2={} end
				AdvDupe2.ProgressBar = {}
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

			usermessage.Hook("AdvDupe2_AddFile",function(um)
				AdvDupe2.FileBrowser:AddFile(um:ReadString(), um:ReadShort(), um:ReadBool())
			end)
			
			usermessage.Hook("AdvDupe2_AddFolder",function(um)
				AdvDupe2.FileBrowser:AddFolder(um:ReadString(), um:ReadShort(), um:ReadShort(), um:ReadBool())
			end)
			
			usermessage.Hook("AdvDupe2_ClearBrowser",function(um)
				AdvDupe2.FileBrowser:ClearBrowser()
			end)
			
			usermessage.Hook("AdvDupe2_SetDupeInfo",function(um)
				if(!AdvDupe2.Info)then return end

				AdvDupe2.Info.File:SetText('File: "'..um:ReadString()..'"')
				AdvDupe2.Info.Creator:SetText("Creator: "..um:ReadString())
				AdvDupe2.Info.Date:SetText("Date: "..um:ReadString())
				AdvDupe2.Info.Time:SetText("Time: "..um:ReadString())
				AdvDupe2.Info.Size:SetText("Size : "..um:ReadString())
				AdvDupe2.Info.Desc:SetText("Desc: "..um:ReadString())
				AdvDupe2.Info.Entities:SetText("Entities: "..um:ReadString())
				AdvDupe2.Info.Constraints:SetText("Constraints: "..um:ReadString())
			end)
			
			usermessage.Hook("AdvDupe2_ResetDupeInfo",function(um)
				if(!AdvDupe2.Info)then return end
				AdvDupe2.Info.File:SetText("File:")
				AdvDupe2.Info.Creator:SetText("Creator:")
				AdvDupe2.Info.Date:SetText("Date:")
				AdvDupe2.Info.Time:SetText("Time:")
				AdvDupe2.Info.Size:SetText("Size:")
				AdvDupe2.Info.Desc:SetText("Desc:")
				AdvDupe2.Info.Entities:SetText("Entities:")
				AdvDupe2.Info.Constraints:SetText("Constraints:")
			end)
			
			usermessage.Hook("AdvDupe2_Ghosting", function(um)
				AdvDupe2.GhostEntity = true
			end)
			
			usermessage.Hook("AdvDupe2_NotGhosting", function(um)
				AdvDupe2.GhostEntity = nil
				AdvDupe2.Rotation = false
			end)
			
			usermessage.Hook("AdvDupe2_RenameNode", function(um)
				AdvDupe2.FileBrowser:RenameNode(um:ReadString())
			end)
			
			usermessage.Hook("AdvDupe2_MoveNode", function(um)
				AdvDupe2.FileBrowser:MoveNode(um:ReadString())
			end)
			
			usermessage.Hook("AdvDupe2_DeleteNode", function(um)
				AdvDupe2.FileBrowser:DeleteNode()
			end)

end
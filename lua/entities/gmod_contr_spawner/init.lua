--[[	
	Title: Adv. Dupe 2 Contraption Spawner
	
	Desc: A mobile duplicator
	
	Author: TB
	
	Version: 1.0
]]


AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
if(WireLib)then
	include('entities/base_wire_entity.lua')
end
include('shared.lua')


function ENT:Initialize()

	self.Entity:SetMoveType( MOVETYPE_NONE )
	self.Entity:PhysicsInit( SOLID_VPHYSICS )
	self.Entity:SetCollisionGroup( COLLISION_GROUP_WORLD )
	self.Entity:DrawShadow( false )
	
	local phys = self.Entity:GetPhysicsObject()
	if phys:IsValid() then
		phys:Wake()
	end
	
	self.UndoList = {}
	self.Ghosts = {}

	self.SpawnLastValue = 0
	self.UndoLastValue = 0
	
	self.LastSpawnTime = 0

	self.CurrentPropCount = 0

	if WireLib then
		self.Inputs = Wire_CreateInputs(self.Entity, {"Spawn", "Undo"})
		self.Outputs = WireLib.CreateSpecialOutputs(self.Entity, {"Out"}, { "NORMAL" })
	end
end



/*-----------------------------------------------------------------------*
 * Sets options for this spawner
 *-----------------------------------------------------------------------*/
function ENT:SetOptions(ply, delay, undo_delay, key, undo_key, disgrav, disdrag, addvel, hideprops )

	self.delay = delay
	self.undo_delay = undo_delay

	--Key bindings
	self.key = key
	self.undo_key = undo_key

	numpad.Remove( self.CreateKey )
	numpad.Remove( self.UndoKey )
	self.CreateKey 	= numpad.OnDown( ply, self.key, "ContrSpawnerCreate", self.Entity, true )
	self.UndoKey 	= numpad.OnDown( ply, self.undo_key, "ContrSpawnerUndo", self.Entity, true )
	self.DisableGravity = disgrav
	self.DisableDrag = disdrag
	self.AddVelocity = addvel
	self.HideProps = hideprops

	self:ShowOutput()
end

function ENT:UpdateOptions( options )
	self:SetOptions( options["delay"], options["undo_delay"], options["key"], options["undo_key"])
end


function ENT:AddGhosts()
	if self.HideProps then return end
	local moveable = self:GetPhysicsObject():IsMoveable()
	self:GetPhysicsObject():EnableMotion(false)
	local EntTable
	local GhostEntity
	local Offset = self.DupeAngle - self.EntAngle
	local Phys
	for EntIndex,v in pairs(self.EntityTable)do
		if(EntIndex!=self.HeadEnt)then
			if(self.EntityTable[EntIndex].Class=="gmod_contr_spawner")then self.EntityTable[EntIndex] = nil continue end
			EntTable = table.Copy(self.EntityTable[EntIndex])
			if(EntTable.BuildDupeInfo && EntTable.BuildDupeInfo.PhysicsObjects)then
				Phys = EntTable.BuildDupeInfo.PhysicsObjects[0]
			else
				if(!v.BuildDupeInfo)then v.BuildDupeInfo = {} end
				v.BuildDupeInfo.PhysicsObjects = table.Copy(v.PhysicsObjects)
				Phys = EntTable.PhysicsObjects[0]
			end
			
			GhostEntity = nil
			
			if(EntTable.Model==nil || !util.IsValidModel(EntTable.Model)) then EntTable.Model="models/error.mdl" end
			
			if ( EntTable.Model:sub( 1, 1 ) == "*" ) then
				GhostEntity = ents.Create( "func_physbox" )
			else
				GhostEntity = ents.Create( "gmod_ghost" )
			end
			
			// If there are too many entities we might not spawn..
			if ( !GhostEntity || GhostEntity == NULL ) then return end
			
			duplicator.DoGeneric( GhostEntity, EntTable )
			
			GhostEntity:Spawn()
			
			GhostEntity:DrawShadow( false )
			GhostEntity:SetMoveType( MOVETYPE_NONE )
			GhostEntity:SetSolid( SOLID_VPHYSICS );
			GhostEntity:SetNotSolid( true )
			GhostEntity:SetRenderMode( RENDERMODE_TRANSALPHA )
			GhostEntity:SetColor( Color(255, 255, 255, 150) )
	
			GhostEntity:SetAngles(Phys.Angle)
			GhostEntity:SetPos(self:GetPos() + Phys.Pos - self.Offset)
			self:SetAngles(self.EntAngle)
			GhostEntity:SetParent( self )
			self:SetAngles(self.DupeAngle)
			self.Ghosts[EntIndex] = GhostEntity
		end
	end
	self:SetAngles(self.DupeAngle)
	self:GetPhysicsObject():EnableMotion(moveable)
end

function ENT:GetCreationDelay()	return self.delay	end
function ENT:GetDeletionDelay()	return self.undo_delay	end

function ENT:OnTakeDamage( dmginfo ) self.Entity:TakePhysicsDamage( dmginfo ) end

function ENT:SetDupeInfo( HeadEnt, EntityTable, ConstraintTable )
	self.HeadEnt = HeadEnt
	self.EntityTable = EntityTable
	self.ConstraintTable = ConstraintTable
	if(!self.DupeAngle)then self.DupeAngle = self:GetAngles() end
	if(!self.EntAngle)then self.EntAngle = EntityTable[HeadEnt].PhysicsObjects[0].Angle end
	if(!self.Offset)then self.Offset = self.EntityTable[HeadEnt].PhysicsObjects[0].Pos end

	local headpos, headang = EntityTable[HeadEnt].PhysicsObjects[0].Pos, EntityTable[HeadEnt].PhysicsObjects[0].Angle
	for k, v in pairs(EntityTable) do
		for o, p in pairs(v.PhysicsObjects) do
			p.LPos, p.LAngle = WorldToLocal(p.Pos, p.Angle, headpos, headang)
		end
	end
end



 
function ENT:DoSpawn( ply )
	-- Explicitly allow spawning if no player is provided, but an invalid player gets denied. This can happen when a player leaves the server.
	if not (ply and ply:IsValid()) then return end

	for k, v in pairs(self.EntityTable) do
		for o, p in pairs(v.PhysicsObjects) do
			p.Pos, p.Angle = self:LocalToWorld(p.LPos), self:LocalToWorldAngles(p.LAngle)
		end
	end

	/*local AngleOffset = self.EntAngle
	AngleOffset = self:GetAngles() - AngleOffset
	local AngleOffset2 = Angle(0,0,0)
	//AngleOffset2.y = AngleOffset.y
	AngleOffset2:RotateAroundAxis(self:GetUp(), AngleOffset.y)
	AngleOffset2:RotateAroundAxis(self:GetRight(),AngleOffset.p)
	AngleOffset2:RotateAroundAxis(self:GetForward(),AngleOffset.r)*/

	local Ents, Constrs = AdvDupe2.duplicator.Paste(ply, self.EntityTable, self.ConstraintTable, nil, nil, Vector(0,0,0), true) 
	local i = #self.UndoList+1
	self.UndoList[i] = Ents
	
	undo.Create("contraption_spawns")
		local phys
		for k,ent in pairs(Ents)do
			phys = ent:GetPhysicsObject()
			if IsValid(phys) then 
				phys:Wake()
				if(self.DisableGravity==1)then phys:EnableGravity(false) end
				if(self.DisableDrag==1)then phys:EnableDrag(false) end
				phys:EnableMotion(true)
				if(ent.SetForce)then ent.SetForce(ent, ent.force, ent.mul) end
				if(self.AddVelocity==1)then 
					phys:SetVelocity( self:GetVelocity() ) 
					phys:AddAngleVelocity( self:GetPhysicsObject():GetAngleVelocity() ) 
				end
			end

			undo.AddEntity(ent)	
		end

		undo.SetPlayer(ply)
	undo.Finish()
	
	if(self.undo_delay>0)then
		timer.Simple(self.undo_delay, function()
			if(self.UndoList && self.UndoList[i])then
				for k,ent in pairs(self.UndoList[i]) do
					if(IsValid(ent)) then
						ent:Remove()
					end
				end
			end	
		end)
	end
	
end



function ENT:DoUndo( ply )
	
	if(!self.UndoList || #self.UndoList == 0)then return end

	local entities = self.UndoList[	#self.UndoList ]
	self.UndoList[	#self.UndoList ] = nil
	for _,ent in pairs(entities) do
		if (IsValid(ent)) then
			ent:Remove()
		end
	end
end

function ENT:TriggerInput(iname, value)
	local ply = self:GetPlayer()

	if(iname == "Spawn")then
		if ((value > 0) == self.SpawnLastValue) then return end
		self.SpawnLastValue = (value > 0)

		if(self.SpawnLastValue)then
			local delay = self:GetCreationDelay()
			if (delay == 0) then self:DoSpawn( ply ) return end
			if(CurTime() < self.LastSpawnTime)then return end
			self:DoSpawn( ply )
			self.LastSpawnTime=CurTime()+delay
		end
	elseif (iname == "Undo") then
		// Same here
		if((value > 0) == self.UndoLastValue)then return end
		self.UndoLastValue = (value > 0)

		if(self.UndoLastValue)then self:DoUndo(ply) end
	end
end

local text2 = {"Enabled", "Disabled"}
function ENT:ShowOutput()
	local text = "\nGravity: "
	if(self.DisableGravity==1)then text=text.."Enabled" else text=text.."Disabled" end
	text=text.."\nDrag: "
	if(self.DisableDrag==1)then text=text.."Enabled" else text=text.."Disabled" end
	text=text.."\nVelocity: "
	if(self.AddVelocity==1)then text=text.."Enabled" else text=text.."Disabled" end
	
	self.Entity:SetOverlayText(
		"Spawn Delay: " .. tostring(self:GetCreationDelay()) ..
		"\nUndo Delay: ".. tostring(self:GetDeletionDelay()) ..
		text
		)
		
end


/*-----------------------------------------------------------------------*
 * Handler for spawn keypad input
 *-----------------------------------------------------------------------*/
function SpawnContrSpawner( ply, ent )

	if (!ent || !ent:IsValid()) then return end

	local delay = ent:GetTable():GetCreationDelay()
	
	if(delay == 0) then 
		ent:DoSpawn( ply )
		return 
	end

	if(CurTime() < ent.LastSpawnTime)then return end
	ent:DoSpawn( ply )
	ent.LastSpawnTime=CurTime()+delay
end

/*-----------------------------------------------------------------------*
 * Handler for undo keypad input
 *-----------------------------------------------------------------------*/
function UndoContrSpawner( ply, ent )
	if (!ent || !ent:IsValid()) then return end
	ent:DoUndo( ply, true )
end

numpad.Register( "ContrSpawnerCreate",	SpawnContrSpawner )
numpad.Register( "ContrSpawnerUndo",		UndoContrSpawner  )

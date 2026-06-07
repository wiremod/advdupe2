include( "shared.lua" )

function ENT:Draw(flags)
	self.BaseClass.Draw(self, flags)
	self.Entity:DrawModel(flags)
end

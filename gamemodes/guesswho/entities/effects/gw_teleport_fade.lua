AddCSLuaFile()

local matRefract = Material( "models/spawn_effect" )

function EFFECT:Init( data )
    self.Duration = data:GetMagnitude()
    self.PlayBackwards = data:GetScale() < 0
    self.DontRemoveOverride = data:GetSurfaceProp() < 0
    self.EndTime = CurTime() + self.Duration

    local ent = data:GetEntity()

    if ( not IsValid( ent ) ) then return end
    if ( not ent:GetModel() ) then return end

    self.ParentEntity = ent
    self:SetModel( ent:GetModel() )
    self:SetPos( ent:GetPos() )
    self:SetAngles( ent:GetAngles() )
    self:SetParent( ent )

    self.ParentEntity.RenderOverride = self.RenderParent
    self.ParentEntity.SpawnEffect = self


end

function EFFECT:Think()

    if ( not IsValid( self.ParentEntity ) ) then return false end

    local PPos = self.ParentEntity:GetPos()
    self:SetPos( PPos + ( EyePos() - PPos ):GetNormal() )

    if ( self.EndTime > CurTime() ) then
        return true
    end

    self.ParentEntity.SpawnEffect = nil

    if self.ParentEntity:IsPlayer() and not self.ParentEntity:Alive() then
        self.ParentEntity.RenderOverride = nil
        return false
    end

    -- Hack so the object does not pop in for a short duration between fade out and fade in
    if self.DontRemoveOverride then
        self.ParentEntity.RenderOverride = self.DontDraw
    else
        self.ParentEntity.RenderOverride = nil
    end

    return false

end

function EFFECT:Render()
end

function EFFECT:DontDraw()
end

function EFFECT:RenderOverlay( entity )

    local Fraction = ( self.EndTime - CurTime() ) / self.Duration

    if (self.PlayBackwards) then
        Fraction = -(self.EndTime - CurTime() - self.Duration) / self.Duration
    end

    Fraction = math.Clamp( Fraction, 0, 1 )

    -- Place the camera a tiny bit closer to the entity.
    -- It will draw a big bigger and we will skip any z buffer problems
    local EyeNormal = entity:GetPos() - EyePos()
    local Distance = EyeNormal:Length()
    EyeNormal:Normalize()

    local Pos = EyePos() + EyeNormal * Distance * 0.01

    -- Start the new 3d camera position
    local bClipping = self:StartClip( entity, 1.2 )
    cam.Start3D( Pos, EyeAngles() )

        -- If our card is DX8 or above draw the refraction effect
        if ( render.GetDXLevel() >= 80 ) then

            -- Update the refraction texture with whatever is drawn right now
            render.UpdateRefractTexture()

            matRefract:SetFloat( "$refractamount", Fraction * 0.1 )

            -- Draw model with refraction texture
            render.MaterialOverride( matRefract )
                entity:DrawModel()
            render.MaterialOverride( 0 )

        end

    -- Set the camera back to how it was
    cam.End3D()
    render.PopCustomClipPlane()
    render.EnableClipping( bClipping )

end

function EFFECT:RenderParent()

    local bClipping = self.SpawnEffect:StartClip( self, 1 )

    self:DrawModel()
    render.PopCustomClipPlane()
    render.EnableClipping( bClipping )

    self.SpawnEffect:RenderOverlay( self )

end

function EFFECT:StartClip( model, spd )

    local mn, mx = model:GetRenderBounds()
    local Up = ( mx - mn ):GetNormal()
    local Bottom = model:GetPos() + mn
    local Top = model:GetPos() + mx

    local Fraction = (self.EndTime - CurTime()) / self.Duration
    
    if (self.PlayBackwards) then
        Fraction = -(self.EndTime - CurTime() - self.Duration) / self.Duration
    end

    Fraction = math.Clamp( Fraction / spd, 0, 1 )

    local Lerped = LerpVector( Fraction, Bottom, Top )

    local normal = Up
    local distance = normal:Dot( Lerped )

    local bEnabled = render.EnableClipping( true )
    render.PushCustomClipPlane( normal, distance )

    return bEnabled

end
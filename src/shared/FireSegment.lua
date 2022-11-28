-- Timestamp // 11/27/2022 09:59:00 MNT
-- Author // @iohgoodness
-- Description // Fire start module

--# example code for fire segment usage
--FireSegment.new()
--FireSegment.new(Vector3.new(3,0,0))
--FireSegment.new(Vector3.new(6,0,0), 5)

local FireSegment = {}

FireSegment.__index = FireSegment

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

function FireSegment:Destroy()
    Debris:AddItem(self._part,.4)
    self = nil
end

function FireSegment:FizzleOut()
    if not self._part then return end
    self._smokeObject.Enabled = false
    task.spawn(function()
        for i=1, 0, -.001 do
            self._fireObject.Lifetime = NumberRange.new(i,i)
            RunService.RenderStepped:Wait()
        end
    end)
    for i=1, 0, -.001 do
        self._fireObject.Size = NumberSequence.new(self._fireObject.Size.Keypoints[1].Value*i,self._fireObject.Size.Keypoints[2].Value*i)
        RunService.RenderStepped:Wait()
    end
    self:Active(false)
    self:Destroy()
end

function FireSegment:Active(active)
    self._fireObject.Enabled = active
    self._smokeObject.Enabled = active
end

function FireSegment.new(position, lifetime)
    local self = setmetatable({}, FireSegment)

    --# properties
    self._fire = {
        Brightness = .4,
        Color = ColorSequence.new(Color3.new(1,1,0), Color3.new(1,0,0)),
        LightEmission = 0,
        LightInfluence = .5,
        Orientation = Enum.ParticleOrientation.FacingCamera,
        Size = NumberSequence.new((math.random(1600,2400)/1000), (math.random(800,1100)/1000)),
        Lifetime = NumberRange.new(1,math.random(1000,2000)/1000),
        Rate = 20,
        Rotation = NumberRange.new(1,1),
        RotSpeed = NumberRange.new(5,12),
        Speed = NumberRange.new(3,5),
        SpreadAngle = Vector2.new(18, 30),
        Acceleration = Vector3.new(0, 0, 0),
        Enabled = false,
        Texture = 'http://www.roblox.com/asset/?id=160041569',
    }
    self._smoke = {
        Color = Color3.fromRGB(84,84,84),
        Opacity = (math.random(7,10)*.1),
        RiseVelocity = (math.random(5,8)),
        Size = .1,
        TimeScale = (math.random(8,9)/10),
        Enabled = false,
    }

    self._position = position or Vector3.new()
    self._lifetime = lifetime or 2

    --# creation of proxy part
    self._part = Instance.new('Part')
    self._part.Transparency = 1
    self._part.Size = Vector3.new(.1,.1,.1)
    self._part.CanCollide = false
    self._part.Locked = true
    self._part.Anchored = true
    self._part.Position = self._position

    --# set properties of fire and smoke
    self._fireObject = Instance.new('ParticleEmitter')
    for k,v in pairs(self._fire) do
        self._fireObject[k] = v
    end
    self._smokeObject = Instance.new('Smoke')
    for k,v in pairs(self._smoke) do
        self._smokeObject[k] = v
    end

    --# set parents
    self._fireObject.Parent = self._part
    self._smokeObject.Parent = self._part
    self._part.Parent = workspace.FireClass.FireSegments

    -- spawn fizzleout delay
    task.delay(self._lifetime, function() self:FizzleOut() end)

    self._biome = nil

    -- activate fire
    self:Active(true)

    return self
end

return FireSegment
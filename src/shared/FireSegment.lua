-- Timestamp // 11/27/2022 09:59:00 MNT
-- Author // @iohgoodness
-- Description // Basic module to create a fire particle
-- lots of other utility that go into the fire segments,
-- these are created on a client and stored in the Fire.lua module

local FireSegment = {}

FireSegment.__index = FireSegment

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

--# cleanup
function FireSegment:Destroy()
    Debris:AddItem(self._part,.4)
    self = nil
end

--# nice effect to make the fire go away
function FireSegment:FizzleOut()
    if not self then return end
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

--# turning the fire on or off
function FireSegment:Active(active : boolean)
    self._fireObject.Enabled = active
    self._smokeObject.Enabled = active
end


--# example code for fire segment usage
--FireSegment.new()
--FireSegment.new(Vector3.new(3,0,0))
--FireSegment.new(Vector3.new(6,0,0), 5)
--FireSegment.new(Vector3.new(6,0,0), 5, 10)
--FireSegment.new(Vector3.new(6,0,0), 5, 10, 'Redwoods')
function FireSegment.new(position : Vector3, lifetime : number, y : number, biome : string)
    local self = setmetatable({}, FireSegment)

    --# properties
    self._fire = {
        Brightness = .8,
        Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(246,250,36)),
            ColorSequenceKeypoint.new(0.758, Color3.fromRGB(238,129,40)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(240,0,0)),
        },
        LightEmission = .7,
        LightInfluence = .3,
        Orientation = Enum.ParticleOrientation.FacingCamera,
        Size = NumberSequence.new {
            NumberSequenceKeypoint.new(0, .932),
            NumberSequenceKeypoint.new(.199, 2.55),
            NumberSequenceKeypoint.new(.489, 2.86),
            NumberSequenceKeypoint.new(1, 2.55),
        },
        Transparency = NumberSequence.new {
            NumberSequenceKeypoint.new(0, .28),
            NumberSequenceKeypoint.new(1, .756),
        },
        Lifetime = NumberRange.new(1,1.495),
        Rate = 45+math.floor(y or 5),
        Rotation = NumberRange.new(1,1),
        RotSpeed = NumberRange.new(2,3),
        Speed = NumberRange.new(4,4),
        SpreadAngle = Vector2.new(math.random(15,25), math.random(25,35)), --Vector2.new(18, 30),
        Acceleration = Vector3.new(0, -2, 0),
        Enabled = false,
        Texture = 'http://www.roblox.com/asset/?id=160041569',
    }
    self._smoke = {
        Color = Color3.fromRGB(84,84,84),
        Opacity = (math.random(7,10)*.1),
        RiseVelocity = (math.random(4,12)),
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

    --# spawn fizzleout delay
    task.delay(self._lifetime, function() if self and self.FizzleOut then self:FizzleOut() end end)

    --# set biome that the fire will live in
    self._biome = biome or 'NONE'

    self:Active(true)

    return self
end

return FireSegment
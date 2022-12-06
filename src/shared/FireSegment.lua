-- Timestamp // 11/27/2022 09:59:00 MNT
-- Author // @iohgoodness
-- Description // Basic module to create a fire particle
-- lots of other utility that go into the fire segments,
-- these are created on a client and stored in the Fire.lua module

local FireSegment = {}

FireSegment.__index = FireSegment

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local fireParticle = ReplicatedStorage:WaitForChild('Assets'):WaitForChild('Particles'):WaitForChild('Fire')
local smokeParticle = ReplicatedStorage:WaitForChild('Assets'):WaitForChild('Particles'):WaitForChild('Smoke')

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
--FireSegment.new(Vector3.new(6,0,0), 5, 10, 'Redwoods', 20)
--FireSegment.new(Vector3.new(6,0,0), 5, 10, 'Redwoods', 20, 10)
function FireSegment.new(cf : CFrame, lifetime : number, objSize : number, biome : string, rate : number, size : number, rotation : Vector3)
    local self = setmetatable({}, FireSegment)

    self._cf = cf or CFrame.new()
    self._lifetime = lifetime or 2

    --# creation of proxy part
    self._part = Instance.new('Part')

    if not objSize then objSize=Vector3.new(2,2,2) end
    self._part.Transparency = 1;self._part.Size = Vector3.new(objSize.X,objSize.Y,objSize.Z);self._part.CanCollide = false;self._part.Locked = true;self._part.Anchored = true
    self._part.CFrame = self._cf

    self._fireObject = fireParticle:Clone()
    self._smokeObject = smokeParticle:Clone()
    local rateMulti = rate or 4 --[[(((rate or 10)/10))*.85]]
    local sizeMulti = size or 4 --[[((size or 20)/20)*3]]
    self._fireObject.Size = NumberSequence.new {
        --NumberSequenceKeypoint.new(0, 3.31*sizeMulti),
        --NumberSequenceKeypoint.new(.123, 2.81*sizeMulti),
        --NumberSequenceKeypoint.new(.179, 2.69*sizeMulti),
        --NumberSequenceKeypoint.new(.268, 2.56*sizeMulti),
        --NumberSequenceKeypoint.new(.43, 2.31*sizeMulti),
        --NumberSequenceKeypoint.new(.576, 2.19*sizeMulti),
        --NumberSequenceKeypoint.new(.576, 2.19*sizeMulti),
        --NumberSequenceKeypoint.new(.744, 1.75*sizeMulti),
        --NumberSequenceKeypoint.new(.905, .437*sizeMulti),
        --NumberSequenceKeypoint.new(1, .125*sizeMulti),
        NumberSequenceKeypoint.new(0, sizeMulti),
        NumberSequenceKeypoint.new(1, sizeMulti),
    }
    self._fireObject.Rate = rateMulti
    self._smokeObject.Size = NumberSequence.new {
        --NumberSequenceKeypoint.new(0, 3.31*sizeMulti),
        --NumberSequenceKeypoint.new(.123, 2.81*sizeMulti),
        --NumberSequenceKeypoint.new(.179, 2.69*sizeMulti),
        --NumberSequenceKeypoint.new(.268, 2.56*sizeMulti),
        --NumberSequenceKeypoint.new(.43, 2.31*sizeMulti),
        --NumberSequenceKeypoint.new(.576, 2.19*sizeMulti),
        --NumberSequenceKeypoint.new(.576, 2.19*sizeMulti),
        --NumberSequenceKeypoint.new(.744, 1.75*sizeMulti),
        --NumberSequenceKeypoint.new(.905, .437*sizeMulti),
        --NumberSequenceKeypoint.new(1, .125*sizeMulti),
        NumberSequenceKeypoint.new(0, sizeMulti),
        NumberSequenceKeypoint.new(1, sizeMulti),
    }
    self._smokeObject.Rate = rateMulti

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
-- Timestamp // 11/27/2022 10:09:54 MNT
-- Author // @iohgoodness
-- Description // Main client init for priorextinctionsample repo
-- nothing too special here, normally like to be more organized but for simplicity for the trial
-- keeping things a little more condensed

--# ensure new random values upon studio/server runtime
math.randomseed(tick())

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

--# data imports
local AmbienceData = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('AmbienceData'))
local LightningSoundData = AmbienceData.DisasterSound.Lightning
local WildfireSoundData = AmbienceData.DisasterSound.Wildfire

--# imports from other modules
local Fire = require(ReplicatedStorage['rojo-sync-shared'].Fire)
local FireSegment = require(ReplicatedStorage['rojo-sync-shared'].FireSegment)
local FireSpread = require(ReplicatedStorage['rojo-sync-shared'].FireSpread)

--# I didn't write the lightning module ~ so no comments included in said files
local LightningBolt = require(ReplicatedStorage['rojo-sync-shared'].Lightning.LightningBolt)
local LightningSparks = require(ReplicatedStorage['rojo-sync-shared'].Lightning.LightningSparks)
local LightningExplosion = require(ReplicatedStorage['rojo-sync-shared'].Lightning.LightningExplosion)

--# simple dirs for more organization
local fireClass = Instance.new('Folder')
fireClass.Name = 'FireClass'
fireClass.Parent = workspace
local fireSegments = Instance.new('Folder')
fireSegments.Name = 'FireSegments'
fireSegments.Parent = fireClass

--# get the player's mouse (deprecated in replacement of UIS/raycasting, I prefer :GetMouse() as it's produced better results in comparison)
--# that being said, I am very open to new ideas and new diction and keep up fairly well with luau API, just felt like it was important to explain the usage of the method :GetMouse()
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
--mouse.TargetFilter = workspace.Assets

--# spawn a few lightning bolts, nice animation to go along with the fire segment
function SpawnLightning(position)
    local p1,p2 = Instance.new('Part'),Instance.new('Part')
    p1.Anchored=true;p1.CanCollide=false;p1.Size=Vector3.new();p1.Position=(CFrame.new(position)*CFrame.new(math.random(-5,5),500,math.random(-5,5))).Position;p1.Transparency=1;p1.Parent=workspace;
    p2.Anchored=true;p2.CanCollide=false;p2.Size=Vector3.new(.1,.1,.1);p2.Position=(CFrame.new(position)*CFrame.new(math.random(-2,2),0,math.random(-2,2))).Position;p2.Transparency=1;p2.Parent=workspace;
    local at1,at2 = Instance.new('Attachment'),Instance.new('Attachment')
    at1.Parent=p1;at2.Parent=p2;
    for i=1, math.random(2,3) do
        task.delay(math.random(0,2000)/10000, function()
            local NewBolt = LightningBolt.new(at1, at2, math.random(40,60))
            NewBolt.CurveSize0, NewBolt.CurveSize1 = math.random(-5,5), math.random(4,6)
            NewBolt.PulseSpeed = math.random(12,15)
            NewBolt.PulseLength = 1.8
            NewBolt.FadeLength = 0.11
            NewBolt.MaxRadius = 10
            NewBolt.Color = Color3.fromRGB(241, 241, 114)
            LightningSparks.new(NewBolt, 30)
        end)
    end
    task.delay(6, function() p1:Destroy();p2:Destroy() end)
    local sound = Instance.new('Sound')
    sound.Name = 'LightningStrike'
    sound.SoundId = 'rbxassetid://' .. LightningSoundData.ID
    sound.Volume = LightningSoundData.Volume
    sound.RollOffMaxDistance = 2500
    sound.RollOffMinDistance = 2
    sound.RollOffMode = Enum.RollOffMode.Inverse
    sound.Parent = p2
    sound:Play()
end

--# used for sprint, as well as lighting fires with mouse clicks
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if not mouse.Target then return end
        local cf,position
        local size
        if mouse.Target.Parent:IsA('Model') and mouse.Target.Parent.Name ~= 'Workspace' then
            cf,size = mouse.Target.Parent:GetBoundingBox()
        end
        cf = cf or mouse.Hit
        position = position or cf.Position
        SpawnLightning(position)
        task.wait(.2)
        ReplicatedStorage.SpawnFire:FireServer(cf)
        table.insert(Fire.Segments, {nil, FireSegment.new(cf)})
        FireSpread.SetOnFire(cf)
    elseif input.UserInputType == Enum.UserInputType.Keyboard then
        local key = input.KeyCode
        if key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift then
            local character = player.Character or player.CharacterAdded:Wait()
            if not character then return end
            local humanoid = character:WaitForChild('Humanoid')
            if not humanoid then return end
            humanoid.WalkSpeed = 150
        end
    end
end)

--# using for Sprint to turn off
UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        local key = input.KeyCode
        if key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift then
            local character = player.Character or player.CharacterAdded:Wait()
            if not character then return end
            local humanoid = character:WaitForChild('Humanoid')
            if not humanoid then return end
            humanoid.WalkSpeed = 16
        end
    end
end)

--# used to replicate clients spawning lightning/fire/fire spread to other clients
ReplicatedStorage.SpawnFire.OnClientEvent:Connect(function(cf, lifetime, y, biome)
    SpawnLightning(cf)
    task.wait(.2)
    table.insert(Fire.Segments, {nil, FireSegment.new(cf, lifetime, y, biome)})
    FireSpread.SetOnFire(cf)
end)

--# used to replicate a fire dying to other clients
ReplicatedStorage.KillFire.OnClientEvent:Connect(function(biome)
    table.insert(FireSpread.extinguishBiome, biome)
    task.spawn(function()
        local oldBiome = biome
        task.wait(2)
        local oldBiomeIndex = table.find(FireSpread.extinguishBiome, oldBiome)
        table.remove(FireSpread.extinguishBiome, oldBiomeIndex)
    end)
    for index,v in pairs(FireSpread.nearIgnite) do
        if v[1][3] == biome then table.remove(FireSpread.nearIgnite, index) end
    end
    for _,v in pairs(Fire.Segments) do
        if v[2]._biome == biome then
            task.spawn(function() v[2]:FizzleOut() end)
            if v[1] then v[1]:GetAttribute('OnFire', nil) end
        end
    end
end)

FireSpread:init()
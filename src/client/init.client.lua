-- Timestamp // 11/27/2022 10:09:54 MNT
-- Author // @iohgoodness
-- Description // Main client init for priorextinctionsample repo

--# create simple dirs for testing

math.randomseed(tick())

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Fire = require(ReplicatedStorage['rojo-sync-shared'].Fire)
local FireSegment = require(ReplicatedStorage['rojo-sync-shared'].FireSegment)
local FireSpread = require(ReplicatedStorage['rojo-sync-shared'].FireSpread)
local LightningBolt = require(ReplicatedStorage['rojo-sync-shared'].Lightning.LightningBolt)
local LightningSparks = require(ReplicatedStorage['rojo-sync-shared'].Lightning.LightningSparks)
local LightningExplosion = require(ReplicatedStorage['rojo-sync-shared'].Lightning.LightningExplosion)

local fireClass = Instance.new('Folder')
fireClass.Name = 'FireClass'
fireClass.Parent = workspace

local fireSegments = Instance.new('Folder')
fireSegments.Name = 'FireSegments'
fireSegments.Parent = fireClass

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

mouse.TargetFilter = workspace.Assets

function SpawnLightning(position)
    local p1,p2 = Instance.new('Part'),Instance.new('Part')
    p1.Anchored=true;p1.CanCollide=false;p1.Size=Vector3.new();p1.Position=(CFrame.new(position)*CFrame.new(math.random(-5,5),150,math.random(-5,5))).Position;p1.Transparency=1;p1.Parent=workspace;
    p2.Anchored=true;p2.CanCollide=false;p2.Size=Vector3.new();p2.Position=(CFrame.new(position)*CFrame.new(math.random(-2,2),0,math.random(-2,2))).Position;p2.Transparency=1;p2.Parent=workspace;
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
            NewBolt.Color = Color3.new(1, 1, 0)
            LightningSparks.new(NewBolt, 30)
        end)
    end
    task.delay(2, function()
        p1:Destroy();p2:Destroy()
    end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if not mouse.Target then return end
        local position = mouse.Hit.Position
        SpawnLightning(position)
        task.wait(.2)
        ReplicatedStorage.SpawnFire:FireServer(position)
        table.insert(Fire.Segments, FireSegment.new(position))
        FireSpread.SetOnFire(position)
    elseif input.UserInputType == Enum.UserInputType.Keyboard then
        local key = input.KeyCode
        if key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift then
            local character = player.Character or player.CharacterAdded:Wait()
            if not character then return end
            local humanoid = character:WaitForChild('Humanoid')
            if not humanoid then return end
            humanoid.WalkSpeed = 100
        end
    end
end)

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

ReplicatedStorage.SpawnFire.OnClientEvent:Connect(function(position, lifetime)
    SpawnLightning(position)
    task.wait(.2)
    table.insert(Fire.Segments, FireSegment.new(position, lifetime))
    FireSpread.SetOnFire(position)
end)

ReplicatedStorage.KillFire.OnClientEvent:Connect(function(biome)
    
end)

FireSpread:init()
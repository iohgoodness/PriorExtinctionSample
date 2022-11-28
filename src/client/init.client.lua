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

local fireClass = Instance.new('Folder')
fireClass.Name = 'FireClass'
fireClass.Parent = workspace

local fireSegments = Instance.new('Folder')
fireSegments.Name = 'FireSegments'
fireSegments.Parent = fireClass

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

mouse.TargetFilter = workspace.Assets

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if not mouse.Target then return end
        local position = mouse.Hit.Position
        ReplicatedStorage.SpawnFire:FireServer(position)
        table.insert(Fire.Segments, FireSegment.new(position))
        FireSpread.SetOnFire(position)
    end
end)

ReplicatedStorage.SpawnFire.OnClientEvent:Connect(function(position, lifetime)
    table.insert(Fire.Segments, FireSegment.new(position, lifetime))
end)

FireSpread:init()
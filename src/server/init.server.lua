-- Timestamp // 11/27/2022 10:09:26 MNT
-- Author // @iohgoodness
-- Description // Main server init for priorextinctionsample repo

math.randomseed(tick())

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Fire = require(ReplicatedStorage['rojo-sync-shared'].Fire)

ReplicatedStorage.SpawnFire.OnServerEvent:Connect(function(player, position, lifetime, y, biome)
    for _,otherPlayer in pairs(Players:GetChildren()) do
        if player == otherPlayer then continue end
        ReplicatedStorage.SpawnFire:FireClient(otherPlayer, position, lifetime, y, biome)
    end
end)

Fire:Wildfires()
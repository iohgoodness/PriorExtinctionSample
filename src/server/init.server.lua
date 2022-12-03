-- Timestamp // 11/27/2022 10:09:26 MNT
-- Author // @iohgoodness
-- Description // Main server init for priorextinctionsample repo
-- fairly basic, for click-spawning fires and for setting up wildfires

math.randomseed(tick())

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Fire = require(ReplicatedStorage['rojo-sync-shared'].Fire)

--# lets a client click show fires to other clients (clicking is just in place for the test, just a little nicer to see!)
ReplicatedStorage.SpawnFire.OnServerEvent:Connect(function(player, position, lifetime, y, biome)
    for _,otherPlayer in pairs(Players:GetChildren()) do
        if player == otherPlayer then continue end
        ReplicatedStorage.SpawnFire:FireClient(otherPlayer, position, lifetime, y, biome)
    end
end)

--# Start the server wildfires (this is done on the server for all clients to see same visuals)
--# [NOTE] other clients joining in at random times would need to be handled for slightly differently,
--# that being said, this is a fairly niche case
Fire:Wildfires()
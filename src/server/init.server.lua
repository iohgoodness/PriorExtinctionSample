-- Timestamp // 11/27/2022 10:09:26 MNT
-- Author // @iohgoodness
-- Description // Main server init for priorextinctionsample repo

math.randomseed(tick())

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Fire = require(ReplicatedStorage['rojo-sync-shared'].Fire)

--[[
function getObject(value)
    if typeof(value) == "Vector3" then
        for index,ignitableData in pairs(FireSpread.ignitable) do
            local dist = (Vector3.new(value.X,0,value.Z)-Vector3.new(ignitableData[2].X,0,ignitableData[2].Z)).Magnitude
            local db = {ignitableData,FireSpread.GetObjectData('Floodplains', ignitableData),tick()}

            if dist <= IN_SPREAD_RANGE then
                if dist <= IN_IGNITE_RANGE and not table.find(FireSpread.cantIgnite, ignitableData) and db[2] then
                    table.insert(FireSpread.cantIgnite, ignitableData)
                    table.remove(FireSpread.ignitable, index)
                    ReplicatedStorage.SpawnFire:FireServer(ignitableData[2], db[2].BurnOutLimit)
                    require(script.Parent.FireSegment).new(ignitableData[2], db[2].BurnOutLimit)
                else
                    table.insert(FireSpread.willSpread, ignitableData)
                    table.insert(FireSpread.nearIgnite, db)
                end
            end
        end
    else
        --# [OPTIMIZATION IDEA] have all models related to each other at runtime to eliminate ( X · O(N) ) search
        local cf,size = value[1]:GetBoundingBox()
        local position = Vector3.new(((math.round(cf.Position.X*10))/10), ((math.round(cf.Position.Y*10))/10), ((math.round(cf.Position.Z*10))/10))
        for index,ignitableData in pairs(FireSpread.ignitable) do
            local dist = (Vector3.new(position.X,0,position.Z)-Vector3.new(ignitableData[2].X,0,ignitableData[2].Z)).Magnitude
            local db = {ignitableData,FireSpread.GetObjectData('Floodplains', ignitableData),tick()}

            if dist <= IN_SPREAD_RANGE then
                if dist <= IN_IGNITE_RANGE and not table.find(FireSpread.cantIgnite, ignitableData) then
                    table.insert(FireSpread.cantIgnite, ignitableData)
                    table.remove(FireSpread.ignitable, index)
                    ReplicatedStorage.SpawnFire:FireServer(ignitableData[2], db[2].BurnOutLimit)
                    require(script.Parent.FireSegment).new(ignitableData[2], db[2].BurnOutLimit)
                else
                    task.delay(1, function()
                        table.insert(FireSpread.willSpread, ignitableData)
                        table.insert(FireSpread.nearIgnite, db)
                    end)
                end
            end
        end
    end
end
]]--

ReplicatedStorage.SpawnFire.OnServerEvent:Connect(function(player, position, lifetime, spread)
    for _,otherPlayer in pairs(Players:GetChildren()) do
        if player == otherPlayer then continue end
        ReplicatedStorage.SpawnFire:FireClient(otherPlayer, position, lifetime, spread)
    end
end)

Fire:Wildfires()
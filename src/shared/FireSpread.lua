-- Timestamp // 11/27/2022 09:59:00 MNT
-- Author // @iohgoodness
-- Description // Custom fire spread module

local FireSpread = {}

FireSpread.__index = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WildfireData = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('WildfireData'))

local IN_SPREAD_RANGE = 10 -- STUDS
local IN_IGNITE_RANGE = 4 -- STUDS

local CHECK_SPREAD_TIMER = 2 -- SECONDS

--# thread that will always be checking to see if other objects should be catching on fire by checking the chance
function FireSpread.SpreadChecker()
    while task.wait(CHECK_SPREAD_TIMER) do
        for _,nearIgniteData in pairs(FireSpread.nearIgnite) do
            if not nearIgniteData[2] then --[[warn(nearIgniteData[1][1], 'DOES NOT HAVE SPREADCHANCE');]] continue end
            if math.random(1,100) <= nearIgniteData[2].SpreadChance then
                task.delay(math.random(1000, 2500)/1000, function()
                    if table.find(nearIgniteData, FireSpread.nearIgnite) then
                        FireSpread.SetOnFire(nearIgniteData[1])
                    end
                end)
            end
        end
    end
end

--# thread always checking to see if an object is ready to be dead
function FireSpread.DeadChecker()
    while task.wait(1) do
        for index,modelData in pairs(FireSpread.onFire) do
            local model = modelData[1]
            local deathTick = modelData[2]
            local biome = modelData[3]
            if tick() >= deathTick then
                table.remove(FireSpread.onFire, index)
                local mesh = model.Mesh:GetChildren()[1]
                local transparency = mesh.Transparency
                mesh.Transparency = .6
                table.insert(FireSpread.recovery, {model, tick()+WildfireData[biome].RecoveryTimer, transparency})
            end
        end
        for index,modelData in pairs(FireSpread.recovery) do
            local model = modelData[1]
            local aliveTick = modelData[2]
            local transparency = modelData[3]
            if tick() >= aliveTick then
                table.remove(FireSpread.recovery, index)
                model.Mesh:GetChildren()[1].Transparency = transparency
            end
        end
    end
end

--# utility function to get the data about the object that is on fire
--# THIS IS GETTING REPLACED LATER (SO ALL OF THIS CAN BE DONE AT RUNTIME CHANGING O(N)->O(1))
function FireSpread.GetObjectData(biome, obj)
    obj=obj[1]
    local spreadData = WildfireData[biome].WildFireSpreadData
    for objType,objData in pairs(spreadData) do
        if table.find(objData.PlantsIncluded, tostring(obj)) then
            return spreadData[objType]
        end
    end
end

--# set a position on fire and start checking for spread
function FireSpread.SetOnFire(value)
    if typeof(value) == "Vector3" then
        for index,ignitableData in pairs(FireSpread.ignitable) do
            local model = ignitableData[1]
            local cf,size = model:GetBoundingBox()
            local biome = ignitableData[3]
            local dist = (Vector3.new(value.X,0,value.Z)-Vector3.new(ignitableData[2].X,0,ignitableData[2].Z)).Magnitude
            local objectData = FireSpread.GetObjectData(biome, ignitableData)
            local db = {ignitableData,objectData,tick()}
            if dist <= IN_SPREAD_RANGE then
                if dist <= IN_IGNITE_RANGE and not model:GetAttribute('OnFire') and db[2] then
                    model:SetAttribute('OnFire', true)
                    table.remove(FireSpread.ignitable, index)
                    ReplicatedStorage.SpawnFire:FireServer(ignitableData[2], db[2].BurnOutLimit, size.Y, biome)
                    local fs = require(script.Parent.FireSegment).new(ignitableData[2], db[2].BurnOutLimit, size.Y, biome)
                    table.insert(require(script.Parent.Fire).Segments, {model, fs})
                    table.insert(FireSpread.onFire, {model, tick()+db[2].BurnOutLimit, biome})
                else
                    table.insert(FireSpread.willSpread, ignitableData)
                    table.insert(FireSpread.nearIgnite, db)
                end
            end
        end
    else --# a model itself
        --# [OPTIMIZATION] have all models related to each other at runtime to eliminate ( X · O(N) ) search
        local model = value[1]
        local cf,size = model:GetBoundingBox()
        local position = Vector3.new(((math.round(cf.Position.X*10))/10), ((math.round(cf.Position.Y*10))/10), ((math.round(cf.Position.Z*10))/10))
        for index,ignitableData in pairs(FireSpread.ignitable) do
            local model = ignitableData[1]
            local dist = (Vector3.new(position.X,0,position.Z)-Vector3.new(ignitableData[2].X,0,ignitableData[2].Z)).Magnitude
            local biome = ignitableData[3]
            local objectData = FireSpread.GetObjectData(ignitableData[3], ignitableData)
            local db = {ignitableData,objectData,tick()}
            if dist <= IN_SPREAD_RANGE then
                if dist <= IN_IGNITE_RANGE and not model:GetAttribute('OnFire') then
                    model:SetAttribute('OnFire', true)
                    table.remove(FireSpread.ignitable, index)
                    ReplicatedStorage.SpawnFire:FireServer(ignitableData[2], db[2].BurnOutLimit, size.Y, biome)
                    local fs = require(script.Parent.FireSegment).new(ignitableData[2], db[2].BurnOutLimit, size.Y, biome)
                    table.insert(require(script.Parent.Fire).Segments, {model, fs})
                    table.insert(FireSpread.onFire, {model, tick()+db[2].BurnOutLimit, biome})
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

--# get all bush positions and positions that are possible to spread to
--# this will happen at runtime so that the calculations don't have to happen as the fire is actively spreading
--# this will save on in-game processing
function FireSpread:init()
    self.ignitable = {}
    self.nearIgnite = {}
    self.cantIgnite = {}
    self.willSpread = {}
    self.onFire = {}
    self.recovery = {}
    local objects = {}
    for _,biomeFolder in pairs(workspace.Assets.Biomes:GetChildren()) do
        for _,burnableModel in pairs(biomeFolder:GetChildren()) do
            if not burnableModel:IsA('Model') then continue end
            table.insert(objects, {burnableModel, biomeFolder.Name})
        end
    end
    for _,burnableModelData in pairs(objects) do
        local cf,size = burnableModelData[1]:GetBoundingBox()
        table.insert(self.ignitable, {burnableModelData[1], Vector3.new(((math.round(cf.Position.X*10))/10), ((math.round(cf.Position.Y*10))/10), ((math.round(cf.Position.Z*10))/10)), burnableModelData[2]})
    end
    task.spawn(function() FireSpread.SpreadChecker() end)
    task.spawn(function() FireSpread.DeadChecker() end)
end

return FireSpread
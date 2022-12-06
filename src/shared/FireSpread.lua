-- Timestamp // 11/27/2022 09:59:00 MNT
-- Author // @iohgoodness
-- Description // Main fire spread module
-- a few different functions are shown here, there is a short description of each function
-- if it's fairly relevant O(N) will be described

local FireSpread = {}

FireSpread.__index = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WildfireData = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('WildfireData'))
local ExtraTreeFirePointsData = require(ReplicatedStorage:WaitForChild('Generated'):WaitForChild('ExtraTreeFirePoints'))

--# important fire spreading properties
local IN_SPREAD_RANGE    = 11 -- STUDS
local IN_IGNITE_RANGE    =  5 -- STUDS
local CHECK_SPREAD_TIMER =  4 -- SECONDS

--# thread that will always be checking to see if other objects should be catching on fire by checking the chance
function FireSpread.SpreadChecker()
    while task.wait(1) do
        for index,nearIgniteData in pairs(FireSpread.nearIgnite) do
            if not (tick() >= nearIgniteData[4]) then print 'not ready yet' continue end
            if not nearIgniteData[2] then --[[warn(nearIgniteData[1][1], 'DOES NOT HAVE SPREADCHANCE');]] continue end
            if math.random(1,100) <= nearIgniteData[2].SpreadChance then
                task.delay(0, function()
                    local found = false
                    for _,v in pairs(FireSpread.nearIgnite) do
                        if nearIgniteData[1] == v[1] then
                            found = true
                        end
                    end
                    if found then
                        if not table.find(FireSpread.extinguishBiome, nearIgniteData[1][3]) then
                            table.remove(FireSpread.nearIgnite, index)
                            FireSpread.SetOnFire(nearIgniteData[1])
                        end
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
                for _,v in pairs(model:GetDescendants()) do
                    if v:IsA('MeshPart') then
                        v.Transparency = .3
                    end
                end
                table.insert(FireSpread.recovery, {model, tick()+WildfireData[biome].RecoveryTimer, 0})
            end
        end
        for index,modelData in pairs(FireSpread.recovery) do
            local model = modelData[1]
            local aliveTick = modelData[2]
            local transparency = modelData[3]
            if tick() >= aliveTick then
                table.remove(FireSpread.recovery, index)
                model:SetAttribute('OnFire', nil)
                for _,v in pairs(model:GetDescendants()) do
                    if v:IsA('MeshPart') then
                        v.Transparency = transparency
                    end
                end
            end
        end
    end
end

--# utility function to get the data about the object that is on fire
--# [OPTIMIZATION] this could be established once in a variable at runtime O(N)->O(1)
function FireSpread.GetObjectData(biome, obj)
    obj=obj[1]
    local spreadData = WildfireData[biome].WildFireSpreadData
    for objType,objData in pairs(spreadData) do
        if table.find(objData.PlantsIncluded, tostring(obj)) then
            return spreadData[objType]
        end
    end
end

--# function to add extra fire to trees that exist
--# [OPTIMIZATION] ridding of extra variables (fairly cheap, but still notable)
function FireSpread.ExtraFire(pos, burnOutLimit, objSize, biome, model, foundEffectRate, foundEffectSize)
    local foundFoilageOfTree = false
    local largestVolume = 0
    for _,v in pairs(model:GetChildren()) do
        if v.Name == 'Leaves' or v.Name == 'Branches' then
            local size = v.Size
            local x,y,z = size.X,size.Y,size.Z
            local volume = x*y*z
            if volume > largestVolume then
                largestVolume = volume
            end
        end
    end
    for _,v in pairs(model:GetChildren()) do
        if v.Name == 'Leaves' then
            local cf,size = v.CFrame,v.Size
            local fs = require(script.Parent.FireSegment).new(cf, burnOutLimit, size, biome, foundEffectRate, foundEffectSize)
            table.insert(require(script.Parent.Fire).Segments, {v, fs})
            foundFoilageOfTree = true
        elseif v.Name == 'Branches' then
            local cf,size = v.CFrame,v.Size
            local newRate
            if largestVolume > 0 then
                local x,y,z = size.X,size.Y,size.Z
                local volume = x*y*z
                newRate = math.ceil( foundEffectRate * (volume / largestVolume) )
            end
            local fs = require(script.Parent.FireSegment).new(cf, burnOutLimit, size, biome, newRate or foundEffectRate, foundEffectSize)
            table.insert(require(script.Parent.Fire).Segments, {v, fs})
            foundFoilageOfTree = true
        end
    end
    if not foundFoilageOfTree then
        local obj = model:GetChildren()[1]
        if obj.Name == 'Trunk' then
            local cf,size = obj.CFrame,obj.Size
            local fs = require(script.Parent.FireSegment).new(cf, burnOutLimit, size, biome, foundEffectRate, foundEffectSize)
            table.insert(require(script.Parent.Fire).Segments, {obj, fs})
        end
    end
    --local positions = ExtraTreeFirePointsData[model:GetAttribute('TreeID')]
    --if not positions then return end
    --for _,p in pairs(positions) do
    --    local fs = require(script.Parent.FireSegment).new(p, burnOutLimit, nil, biome, foundEffectRate, foundEffectSize)
    --    table.insert(require(script.Parent.Fire).Segments, {model, fs})
    --end
end

function FireSpread.SearchNearIgnite(data)
    for _,v in pairs(FireSpread.nearIgnite) do
        if v[1][1] == data then
            return true
        end
    end
    return false
end

--# set a position on fire and start checking for spread
function FireSpread.SetOnFire(value)
    if typeof(value) == "CFrame" then --# set fire on a positional value
        for index,ignitableData in pairs(FireSpread.ignitable) do
            local model = ignitableData[1]
            local cf,size = model:GetBoundingBox()
            local biome = ignitableData[3]
            local dist = (Vector3.new(value.Position.X,0,value.Position.Z)-Vector3.new(ignitableData[2].X,0,ignitableData[2].Z)).Magnitude
            local objectData = FireSpread.GetObjectData(biome, ignitableData)

            local plantParentName = FireSpread.savedPlantParents[model.Name]
            local foundSpreadRange,foundIgniteRange,foundEffectRate,foundEffectSize,foundSpreadTimer
            if plantParentName then
                foundSpreadRange = WildfireData[biome].WildFireSpreadData[plantParentName].InSpreadRange
                foundIgniteRange = WildfireData[biome].WildFireSpreadData[plantParentName].InIgniteRange
                foundEffectRate = WildfireData[biome].WildFireSpreadData[plantParentName].EffectRate
                foundEffectSize = WildfireData[biome].WildFireSpreadData[plantParentName].EffectSize
                foundSpreadTimer = WildfireData[biome].WildFireSpreadData[plantParentName].SpreadTimer
            end

            foundSpreadTimer=foundSpreadTimer or CHECK_SPREAD_TIMER
            local db = {ignitableData,objectData,tick(), tick()+foundSpreadTimer}

            if dist <= (foundSpreadRange or IN_SPREAD_RANGE) then
                if dist <= (foundIgniteRange or IN_IGNITE_RANGE) and not model:GetAttribute('OnFire') and db[2] then
                    local newRate,newSize,isTree
                    if plantParentName == 'Large Trees' or plantParentName == 'Small Trees' then
                        newRate,newSize = 0,0
                        isTree = true
                    end
                    model:SetAttribute('OnFire', true)
                    table.remove(FireSpread.ignitable, index)
                    ReplicatedStorage.SpawnFire:FireServer(ignitableData[2], db[2].BurnOutLimit, size, biome, newRate or foundEffectRate, newSize or foundEffectSize)
                    local fs = require(script.Parent.FireSegment).new(ignitableData[2], db[2].BurnOutLimit, size, biome, newRate or foundEffectRate, newSize or foundEffectSize)
                    table.insert(require(script.Parent.Fire).Segments, {model, fs})
                    table.insert(FireSpread.onFire, {model, tick()+db[2].BurnOutLimit, biome})
                    if isTree then
                        FireSpread.ExtraFire(ignitableData[2], db[2].BurnOutLimit, size, biome, model, foundEffectRate, foundEffectSize)
                    end
                else
                    if not table.find(FireSpread.extinguishBiome, biome) and not FireSpread.SearchNearIgnite(db[1][1]) then
                        table.insert(FireSpread.willSpread, ignitableData)
                        table.insert(FireSpread.nearIgnite, db)
                    end
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

            local plantParentName = FireSpread.savedPlantParents[model.Name]
            local foundSpreadRange,foundIgniteRange,foundEffectRate,foundEffectSize,foundSpreadTimer
            if plantParentName then
                foundSpreadRange = WildfireData[biome].WildFireSpreadData[plantParentName].InSpreadRange
                foundIgniteRange = WildfireData[biome].WildFireSpreadData[plantParentName].InIgniteRange
                foundEffectRate = WildfireData[biome].WildFireSpreadData[plantParentName].EffectRate
                foundEffectSize = WildfireData[biome].WildFireSpreadData[plantParentName].EffectSize
                foundSpreadTimer = WildfireData[biome].WildFireSpreadData[plantParentName].SpreadTimer
            end

            foundSpreadTimer=foundSpreadTimer or CHECK_SPREAD_TIMER
            local db = {ignitableData,objectData,tick(), tick()+foundSpreadTimer}

            if dist <= (foundSpreadRange or IN_SPREAD_RANGE) then
                if dist <= (foundIgniteRange or IN_IGNITE_RANGE) and not model:GetAttribute('OnFire') and db[2] then
                    local newRate,newSize,isTree
                    if plantParentName == 'Large Trees' or plantParentName == 'Small Trees' then
                        newRate,newSize = 0,0
                        isTree = true
                    end
                    model:SetAttribute('OnFire', true)
                    table.remove(FireSpread.ignitable, index)
                    ReplicatedStorage.SpawnFire:FireServer(ignitableData[2], db[2].BurnOutLimit, size, biome, newRate or foundEffectRate, newSize or foundEffectSize)
                    local fs = require(script.Parent.FireSegment).new(ignitableData[2], db[2].BurnOutLimit, size, biome, newRate or foundEffectRate, newSize or foundEffectSize)
                    table.insert(require(script.Parent.Fire).Segments, {model, fs})
                    table.insert(FireSpread.onFire, {model, tick()+db[2].BurnOutLimit, biome})
                    if isTree then
                        FireSpread.ExtraFire(ignitableData[2], db[2].BurnOutLimit, size, biome, model, foundEffectRate, foundEffectSize)
                    end
                else
                    task.delay(1, function()
                        if not table.find(FireSpread.extinguishBiome, biome) and not FireSpread.SearchNearIgnite(db[1][1]) then
                            table.insert(FireSpread.willSpread, ignitableData)
                            table.insert(FireSpread.nearIgnite, db)
                        end
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
    self.savedPlantParents = {}
    self.extraFirePoints = {}
    self.extinguishBiome = {}
    self.ignitable = {}
    self.nearIgnite = {}
    self.cantIgnite = {}
    self.willSpread = {}
    self.onFire = {}
    self.recovery = {}
    local objects = {}
    --# for cached pulling of plant parent names
    for biome, biomeData in pairs(WildfireData) do
        for plantParentName, plantParentData in pairs(biomeData.WildFireSpreadData) do
            for _,plantName in pairs(plantParentData.PlantsIncluded) do
                self.savedPlantParents[plantName] = plantParentName
            end
        end
    end
    for _,biomeFolder in pairs(workspace.Assets.Biomes:GetChildren()) do
        for _,burnableModel in pairs(biomeFolder:GetChildren()) do
            if not burnableModel:IsA('Model') then continue end
            table.insert(objects, {burnableModel, biomeFolder.Name})
        end
    end
    for _,burnableModelData in pairs(objects) do
        local cf,size = burnableModelData[1]:GetBoundingBox()
        table.insert(self.ignitable, {burnableModelData[1], CFrame.new(((math.round(cf.Position.X*10))/10), ((math.round(cf.Position.Y*10))/10), ((math.round(cf.Position.Z*10))/10)), burnableModelData[2]})
    end
    task.spawn(function() FireSpread.SpreadChecker() end)
    task.spawn(function() FireSpread.DeadChecker() end)
end

return FireSpread
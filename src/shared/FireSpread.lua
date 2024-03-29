-- Timestamp // 11/27/2022 09:59:00 MNT
-- Author // @iohgoodness
-- Description // Main fire spread module
-- a few different functions are shown here, there is a short description of each function
-- if it's fairly relevant O(N) will be described

local FireSpread = {}

FireSpread.__index = {}

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--# data imports
local WildfireData = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('WildfireData'))
local AmbienceData = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('AmbienceData'))
local LightningSoundData = AmbienceData.DisasterSound.Lightning
local WildfireSoundData = AmbienceData.DisasterSound.Wildfire

local ExtraTreeFirePointsData = require(ReplicatedStorage:WaitForChild('Generated'):WaitForChild('ExtraTreeFirePoints'))

--# important fire spreading properties
local IN_SPREAD_RANGE    = 11 -- STUDS
local IN_IGNITE_RANGE    =  5 -- STUDS
local CHECK_SPREAD_TIMER =  4 -- SECONDS

--# thread that will always be checking to see if other objects should be catching on fire by checking the chance
function FireSpread.SpreadChecker()
    while task.wait(1) do
        for index,nearIgniteData in pairs(FireSpread.nearIgnite) do
            if not (tick() >= nearIgniteData[4]) then continue end
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

--# mdb4 = make a float divisible by 4
function mdb4(x)
    x=math.ceil(x)
    if x%4==0 then return x end
    return x + (4-(x % 4))
end

--# thread to check terrain to see if there is any terrain ready to revert back to it's original state
function FireSpread.TerrainChecker()
    while task.wait(1) do
        for index,regionChangedData in pairs(FireSpread.regionChanged) do
            if not (tick() > regionChangedData[4]) then continue end
            workspace.Terrain:ReplaceMaterial(regionChangedData[1], 4, Enum.Material[regionChangedData[3]], Enum.Material[regionChangedData[2]])
            table.remove(FireSpread.regionChanged,index)
            task.wait(.01)
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
                        if v.Name ~= 'Collider' and v.Name ~= 'LookPart' then
                            if not v:FindFirstChild('States') then
                                v.Transparency = 1
                            else
                                local newState = v.States.Burned:GetChildren()[1]:Clone()
                                if v:FindFirstChildOfClass('SurfaceAppearance') then v:FindFirstChildOfClass('SurfaceAppearance'):Destroy() end
                                newState.Parent = v
                            end
                        end
                    end
                end
                --# for changing terrain into desired scorched material
                local cf,size
                if model:FindFirstChild('Trunk') then
                    cf,size = model.Trunk.CFrame,model.Trunk.Size
                elseif model:FindFirstChild('Mesh') and model:FindFirstChild('Mesh'):IsA('Model') then
                    cf,size = model:GetBoundingBox()
                elseif model:FindFirstChild('Branches') then
                    cf,size = model.Branches.CFrame,model.Branches.Size
                end
                if not cf or not size then warn(tostring(model), 'not accounted for!') end
                local r1,r2 = 10,9
                for i=1, 3 do --# iterations for circle appearance
                    local x1,x2 = (cf.Position.X-size.X/2),(cf.Position.X+size.X/2)
                    local z1,z2 = (cf.Position.Z-size.Z/2),(cf.Position.Z+size.Z/2)
                    local y1,y2 = ((cf.Position.Y-size.Y/2)-2),(cf.Position.Y-size.Y/2+2)
                    if i == 2 then
                        x1+=math.random(-r1,-r2)
                        x2+=math.random(r2,r1)
                    elseif i == 3 then
                        z1+=math.random(-r1,-r2)
                        z2+=math.random(r2,r1)
                    end
                    local minTerrainEdit = 4*2
                    if (x1-x2) < minTerrainEdit*2 then x1 -= minTerrainEdit; x2 += minTerrainEdit end
                    if (z1-z2) < minTerrainEdit*2 then z1 -= minTerrainEdit; z2 += minTerrainEdit end
                    if (y1-y2) < minTerrainEdit*2 then y1 -= minTerrainEdit; y2 += minTerrainEdit end
                    x1,x2,z1,z2,y1,y2=mdb4(x1),mdb4(x2),mdb4(z1),mdb4(z2),mdb4(y1),mdb4(y2)
                    local min,max = Vector3.new(x1, y1, z1),Vector3.new(x2, y2, z2)
                    for m1,m2 in pairs(WildfireData.Biomes[biome].ScorchedMaterials) do
                        local region = Region3.new(min,max);
                        region = region:ExpandToGrid(4)
                        workspace.Terrain:ReplaceMaterial(region, 4, Enum.Material[m1], Enum.Material[m2.TurnInto])
                        table.insert(FireSpread.regionChanged, {region, m1, m2.TurnInto, tick()+m2.RevertToOriginal})
                    end
                end
                table.insert(FireSpread.recovery, {model, tick()+WildfireData.Biomes[biome].RecoveryTimer, 0})
            end
        end
        --# revert models back to an original state
        for index,modelData in pairs(FireSpread.recovery) do
            local model = modelData[1]
            local aliveTick = modelData[2]
            local transparency = modelData[3]
            if tick() >= aliveTick then
                table.remove(FireSpread.recovery, index)
                model:SetAttribute('OnFire', nil)
                for _,v in pairs(model:GetDescendants()) do
                    if v:IsA('MeshPart') then
                        if v.Name ~= 'Collider' and v.Name ~= 'LookPart' then
                            if not v:FindFirstChild('States') then
                                v.Transparency = transparency
                            else
                                local newState = v.States.Normal:GetChildren()[1]:Clone()
                                v:FindFirstChildOfClass('SurfaceAppearance'):Destroy()
                                newState.Parent = v
                            end
                        end
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
    local spreadData = WildfireData.Biomes[biome].WildFireSpreadData
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
            FireSpread.ExpandSound(size, cf.Position, burnOutLimit, biome, true)
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
            FireSpread.ExpandSound(size, cf.Position, burnOutLimit, biome)
            foundFoilageOfTree = true
        end
    end
    if not foundFoilageOfTree then
        local obj = model:GetChildren()[1]
        if obj.Name == 'Trunk' then
            local cf,size = obj.CFrame,obj.Size
            local fs = require(script.Parent.FireSegment).new(cf, burnOutLimit, size, biome, foundEffectRate, foundEffectSize)
            table.insert(require(script.Parent.Fire).Segments, {obj, fs})
            FireSpread.ExpandSound(size, cf.Position, burnOutLimit, biome, true)
        end
    end
    --local positions = ExtraTreeFirePointsData[model:GetAttribute('TreeID')]
    --if not positions then return end
    --for _,p in pairs(positions) do
    --    local fs = require(script.Parent.FireSegment).new(p, burnOutLimit, nil, biome, foundEffectRate, foundEffectSize)
    --    table.insert(require(script.Parent.Fire).Segments, {model, fs})
    --end
end

--# Search function for checking if ignitable object is near an on-fire object
function FireSpread.SearchNearIgnite(data)
    for _,v in pairs(FireSpread.nearIgnite) do
        if v[1][1] == data then
            return true
        end
    end
    return false
end

--# controller for the fire spread sound
function FireSpread.ExpandSound(size, position, lifetime, biome, confirmSound)

    if not confirmSound then
        local bool = math.random(1,12)~=12
        if bool then return end
    end

    lifetime = lifetime or 3
    local part = Instance.new('Part')
    part.Size = Vector3.new(math.clamp(size.X, 2, math.huge),math.clamp(size.Y, 2, math.huge),math.clamp(size.Z, 2, math.huge))
    part.Position = position
    part.Transparency = .78
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BrickColor = BrickColor.new('Hurricane grey')
    part.Material = Enum.Material.Neon
    part.CanCollide = false
    part.Anchored = true
    part.Parent = workspace
    FireSpread.fireSounds[position] = part

    local fireSound = Instance.new('Sound')
    fireSound.SoundId = 'rbxassetid://' .. WildfireSoundData.ID
    fireSound.Volume = WildfireSoundData.Volume
    fireSound.RollOffMaxDistance = WildfireData.Sounds.RollOffMaxDistance
    fireSound.Name = 'FireSound'
    fireSound.RollOffMinDistance = WildfireData.Sounds.RollOffMinDistance
    fireSound.RollOffMode = WildfireData.Sounds.RollOffMode
    fireSound.Looped = true
    fireSound.Parent = part
    fireSound.Volume = WildfireData.Sounds.Volume
    fireSound:Play()

    task.delay(lifetime-3, function()
        part:SetAttribute('Leaving', true)
        for i=1, 0, -.01 do
            part.FireSound.Volume = i
            task.wait(.03)
        end
    end)

    task.delay(lifetime, function()
        if part:FindFirstChild('FireSound') then
            for i=1, 0, -.01 do
                part.FireSound.Volume = i
                task.wait(.03)
            end
        end
        part:Destroy()
        FireSpread.fireSounds[position] = nil
    end)


    --[[
    for k,v in pairs(FireSpread.fireSounds) do
        if k==position then return end
    end
    lifetime = lifetime or 3
    local part = Instance.new('Part')
    part.Size = Vector3.new(math.clamp(size.X, 2, math.huge),math.clamp(size.Y, 2, math.huge),math.clamp(size.Z, 2, math.huge))
    part.Position = position
    part.Transparency = .9
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BrickColor = BrickColor.new('Carnation pink')
    part.Material = Enum.Material.Neon
    part.CanCollide = false
    part.Anchored = true
    
    --local sound = Instance.new('Sound')
    --sound.SoundId = 'rbxassetid://' .. WildfireSoundData.ID
    --sound.Volume = WildfireSoundData.Volume
    --sound.RollOffMaxDistance = 2500
    --sound.Name = 'FireSound'
    --sound.RollOffMinDistance = 100
    --sound.RollOffMode = Enum.RollOffMode.InverseTapered
    --sound.Looped = true
    --sound.Parent = part
    --FireSpread.fireSound.Parent = part
    FireSpread.lastFirePartMade = part
    if not FireSpread.fireSound and not FireSpread.fireSound.Parent then
        if FireSpread.fireSound then
            FireSpread.fireSound.Parent = part
        end
    end
    --
    if not FireSpread.fireSound.IsPlaying then
        FireSpread.fireSound:Play()
    end
    part.Parent = workspace
    FireSpread.fireSounds[position] = part
    --Debris:AddItem(part, lifetime+5)
    task.delay(lifetime, function()
        if FireSpread.fireSounds[position] then
            for i=1, 0, -.01 do
                if FireSpread.fireSounds[position] then
                    if FireSpread.fireSounds[position]:FindFirstChild('FireSound') then
                        FireSpread.fireSounds[position].FireSound.Volume = i
                    end
                end
                task.wait(.03)
                --RunService.RenderStepped:Wait()
            end
            if FireSpread.fireSounds[position] then
                FireSpread.fireSound.Parent = FireSpread.lastFirePartMade
                FireSpread.fireSounds[position]:Destroy()
                FireSpread.fireSounds[position] = nil
            end
        end
    end)
    ]]
end

function FireSpread.AlreadyAdded(part)
    
end

function FireSpread.Count()
    local c = 00
    for _,v in pairs(FireSpread.fireSounds) do
        c+=1
    end
    return c
end

--# thread to control the fire sounds that a player will be hearing
function FireSpread.FireSounds()
    task.spawn(function()
        while true do
            task.wait(3)
            for k,v in pairs(FireSpread.fireSounds) do
                if v:GetAttribute('Leaving') then continue end
                task.spawn(function()
                    v.FireSound:Pause()
                    v.FireSound.TimePosition = FireSpread.fireSoundTimePosition
                    v.FireSound:Play()
                end)
                --task.wait(.2)
                task.wait((1/FireSpread.Count())+.3)
            end
        end
    end)
    --[[
    FireSpread.fireSoundInstances = {}
    for i=1, 3 do
        local fireSound = Instance.new('Sound')
        fireSound.SoundId = 'rbxassetid://' .. WildfireSoundData.ID
        fireSound.Volume = WildfireSoundData.Volume
        fireSound.RollOffMaxDistance = WildfireData.Sounds.RollOffMaxDistance
        fireSound.Name = 'FireSound'
        fireSound.RollOffMinDistance = WildfireData.Sounds.RollOffMinDistance
        fireSound.RollOffMode = WildfireData.Sounds.RollOffMode
        fireSound.Looped = true
        fireSound:Play()
        table.insert(FireSpread.fireSoundInstances, {fireSound,nil})
    end
    local oldpart = nil
    while task.wait(.1) do
        local camera = workspace.CurrentCamera
        local camPos = camera.CFrame.Position
        local dist,position = math.huge,nil
        local part = nil
        for firePos,fireSoundPart in pairs(FireSpread.fireSounds) do
            local otherDist = (firePos-camPos).Magnitude
            if otherDist < dist then
                if fireSoundPart:GetAttribute('Leaving') ~= true then
                    dist = otherDist
                    position = firePos
                    part = fireSoundPart
                end
            end
        end
        if not position then continue end
        FireSpread.fireSound.Parent = part or ReplicatedStorage
        if oldpart then
            oldpart.BrickColor = BrickColor.new('Hurricane grey')
        end
        part.BrickColor = BrickColor.new('Lime green')
        oldpart = part
    end
    ]]
    --[[
    FireSpread.lastFirePartMade = nil
    FireSpread.fireSound = Instance.new('Sound')
    FireSpread.fireSound.SoundId = 'rbxassetid://' .. WildfireSoundData.ID
    FireSpread.fireSound.Volume = WildfireSoundData.Volume
    FireSpread.fireSound.RollOffMaxDistance = 2500
    FireSpread.fireSound.Name = 'FireSound'
    FireSpread.fireSound.RollOffMinDistance = 100
    FireSpread.fireSound.RollOffMode = Enum.RollOffMode.InverseTapered
    FireSpread.fireSound.Looped = true
    --FireSpread.fireSound.Parent = part
    while task.wait() do
        local camera = workspace.CurrentCamera
        local camPos = camera.CFrame.Position
        local dist,position = math.huge,nil
        local part = nil
        for firePos,fireSoundPart in pairs(FireSpread.fireSounds) do
            local otherDist = (firePos-camPos).Magnitude
            if otherDist < dist then
                dist = otherDist
                position = firePos
                part = fireSoundPart
            end
        end
        if not position then continue end
        if FireSpread.fireSound then
            FireSpread.fireSound.Parent = part
        end
        local pause = {}
        for firePos,fireSoundPart in pairs(FireSpread.fireSounds) do
            if position == firePos then continue end
            if fireSoundPart:FindFirstChild('FireSound') then
                if fireSoundPart.FireSound.IsPlaying then
                    table.insert(pause, fireSoundPart.FireSound)
                end
            end
        end
        for _,v in pairs(pause) do
            for i=1, 0, -.1 do
                v.Volume = i
                task.wait(.01)
            end
            v:Stop()
        end
        if FireSpread.fireSounds[position] then
            if FireSpread.fireSounds[position]:FindFirstChild('FireSound') then
                if not FireSpread.fireSounds[position].FireSound.IsPlaying then
                    FireSpread.fireSounds[position].FireSound.TimePosition = FireSpread.fireSoundTimePosition
                    FireSpread.fireSounds[position].FireSound:Play()
                end
            end
        end
    end
    ]]
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
                foundSpreadRange = WildfireData.Biomes[biome].WildFireSpreadData[plantParentName].InSpreadRange
                foundIgniteRange = WildfireData.Biomes[biome].WildFireSpreadData[plantParentName].InIgniteRange
                foundEffectRate = WildfireData.Biomes[biome].WildFireSpreadData[plantParentName].EffectRate
                foundEffectSize = WildfireData.Biomes[biome].WildFireSpreadData[plantParentName].EffectSize
                foundSpreadTimer = WildfireData.Biomes[biome].WildFireSpreadData[plantParentName].SpreadTimer
            end

            foundSpreadTimer=foundSpreadTimer or CHECK_SPREAD_TIMER
            local db = {ignitableData,objectData,tick(), tick()+foundSpreadTimer}

            local burnOutLimit
            if #db>=2 then if db[2] then burnOutLimit = db[2].BurnOutLimit end end

            if dist <= (foundSpreadRange or IN_SPREAD_RANGE) then
                if dist <= (foundIgniteRange or IN_IGNITE_RANGE) and not model:GetAttribute('OnFire') and db[2] then
                    local newRate,newSize,isTree
                    if plantParentName == 'Large Trees' or plantParentName == 'Small Trees' then
                        newRate,newSize = 0,0
                        isTree = true
                    end
                    model:SetAttribute('OnFire', true)
                    
                    table.remove(FireSpread.ignitable, index)
                    task.delay(db[2].BurnOutLimit+20, function()
                        table.insert(FireSpread.ignitable, ignitableData)
                    end)

                    ReplicatedStorage.SpawnFire:FireServer(ignitableData[2], db[2].BurnOutLimit, size, biome, newRate or foundEffectRate, newSize or foundEffectSize)
                    local fs = require(script.Parent.FireSegment).new(ignitableData[2], db[2].BurnOutLimit, size, biome, newRate or foundEffectRate, newSize or foundEffectSize)
                    table.insert(require(script.Parent.Fire).Segments, {model, fs})
                    table.insert(FireSpread.onFire, {model, tick()+db[2].BurnOutLimit, biome})

                    FireSpread.ExpandSound(size, cf.Position, db[2].BurnOutLimit, biome)

                    if isTree then
                        FireSpread.ExtraFire(ignitableData[2], db[2].BurnOutLimit, size, biome, model, foundEffectRate, foundEffectSize)
                    end
                else
                    if not table.find(FireSpread.extinguishBiome, biome) and not FireSpread.SearchNearIgnite(db[1][1]) then
                        table.insert(FireSpread.willSpread, ignitableData)
                        table.insert(FireSpread.nearIgnite, db)
                        local willSpreadIndex = #FireSpread.willSpread
                        local nearIgniteIndex = #FireSpread.nearIgnite
                        task.delay(burnOutLimit, function()
                            table.remove(FireSpread.willSpread, willSpreadIndex)
                            table.remove(FireSpread.nearIgnite, nearIgniteIndex)
                        end)
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
                foundSpreadRange = WildfireData.Biomes[biome].WildFireSpreadData[plantParentName].InSpreadRange
                foundIgniteRange = WildfireData.Biomes[biome].WildFireSpreadData[plantParentName].InIgniteRange
                foundEffectRate = WildfireData.Biomes[biome].WildFireSpreadData[plantParentName].EffectRate
                foundEffectSize = WildfireData.Biomes[biome].WildFireSpreadData[plantParentName].EffectSize
                foundSpreadTimer = WildfireData.Biomes[biome].WildFireSpreadData[plantParentName].SpreadTimer
            end

            foundSpreadTimer=foundSpreadTimer or CHECK_SPREAD_TIMER
            local db = {ignitableData,objectData,tick(), tick()+foundSpreadTimer}
            
            local burnOutLimit
            if #db>=2 then if db[2] then burnOutLimit = db[2].BurnOutLimit end end

            if dist <= (foundSpreadRange or IN_SPREAD_RANGE) then
                if dist <= (foundIgniteRange or IN_IGNITE_RANGE) and not model:GetAttribute('OnFire') and db[2] then
                    local newRate,newSize,isTree
                    if plantParentName == 'Large Trees' or plantParentName == 'Small Trees' then
                        newRate,newSize = 0,0
                        isTree = true
                    end
                    model:SetAttribute('OnFire', true)
                    table.remove(FireSpread.ignitable, index)
                    task.delay(db[2].BurnOutLimit+20, function()
                        table.insert(FireSpread.ignitable, ignitableData)
                    end)

                    ReplicatedStorage.SpawnFire:FireServer(ignitableData[2], db[2].BurnOutLimit, size, biome, newRate or foundEffectRate, newSize or foundEffectSize)
                    local fs = require(script.Parent.FireSegment).new(ignitableData[2], db[2].BurnOutLimit, size, biome, newRate or foundEffectRate, newSize or foundEffectSize)
                    table.insert(require(script.Parent.Fire).Segments, {model, fs})
                    table.insert(FireSpread.onFire, {model, tick()+db[2].BurnOutLimit, biome})
                    
                    FireSpread.ExpandSound(size, cf.Position, db[2].BurnOutLimit, biome)

                    if isTree then
                        FireSpread.ExtraFire(ignitableData[2], db[2].BurnOutLimit, size, biome, model, foundEffectRate, foundEffectSize)
                    end
                else
                    task.delay(1, function()
                        if not table.find(FireSpread.extinguishBiome, biome) and not FireSpread.SearchNearIgnite(db[1][1]) then
                            table.insert(FireSpread.willSpread, ignitableData)
                            table.insert(FireSpread.nearIgnite, db)
                            local willSpreadIndex = #FireSpread.willSpread
                            local nearIgniteIndex = #FireSpread.nearIgnite
                            task.delay(burnOutLimit, function()
                                table.remove(FireSpread.willSpread, willSpreadIndex)
                                table.remove(FireSpread.nearIgnite, nearIgniteIndex)
                            end)
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
    self.fireSounds = {}
    self.fireSoundTimePosition = 0
    self.regionChanged = {}
    self.savedPlantParents = {}
    self.extraFirePoints = {}
    self.extinguishBiome = {}
    self.ignitable = {}
    self.terrainChanged = {}
    self.nearIgnite = {}
    self.cantIgnite = {}
    self.willSpread = {}
    self.onFire = {}
    self.recovery = {}
    local objects = {}

    task.spawn(function()
        while true do
            for i=0, 151, 1 do
                self.fireSoundTimePosition = i
                task.wait(1)
            end
            task.wait(.2)
        end
    end)

    -- object to make fire sound timestamps identical to each other
    self.fireSoundTracker = Instance.new('Sound')
    self.fireSoundTracker.SoundId = 'rbxassetid://' .. WildfireSoundData.ID
    self.fireSoundTracker.Volume = WildfireSoundData.Volume
    self.fireSoundTracker.RollOffMaxDistance = WildfireData.Sounds.RollOffMaxDistance
    self.fireSoundTracker.Name = '_fireSoundTracker'
    self.fireSoundTracker.RollOffMinDistance = WildfireData.Sounds.RollOffMinDistance
    self.fireSoundTracker.RollOffMode = WildfireData.Sounds.RollOffMode
    self.fireSoundTracker.Looped = true
    self.fireSoundTracker.Parent = ReplicatedStorage
    self.fireSoundTracker.Volume = 0
    self.fireSoundTracker:Play()

    --# for cached pulling of plant parent names
    for biome, biomeData in pairs(WildfireData.Biomes) do
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
    task.spawn(function() FireSpread.TerrainChecker() end)
    task.spawn(function() FireSpread.FireSounds() end)
end

return FireSpread
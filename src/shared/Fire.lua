-- Timestamp // 11/28/2022 08:49:42 MNT
-- Author // @iohgoodness
-- Description // Main controller for the fires

local Fire = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WildfireData = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('WildfireData'))
local BiomesDir = workspace.Assets.Biomes

Fire.Segments = {}
Fire.FireActive = {}

local function shuffle(t)
    local j, temp
    for i = #t, 1, -1 do
        j = math.random(i)
        temp = t[i]
        t[i] = t[j]
        t[j] = temp
    end
end

Fire.Wildfires = function()
    local found = false
    local biomes = {}
    for biomeName,_ in pairs(WildfireData) do Fire.FireActive[biomeName] = false end
    for biomeName,biomeData in pairs(WildfireData) do table.insert(biomes,{biomeName,biomeData}) end
    task.spawn(function()
        while task.wait(5--[[600]]) do
            shuffle(biomes)
            for _,data in ipairs(biomes) do
                local biomeName = data[1]
                local biomeData = data[2]
                local chance = (math.random(1, 100*10))
                if true --[[(chance <= biomeData.RandomWildFireChance*10)]] then
                    local biomeDir = BiomesDir[biomeName]
                    local options = {}
                    for _,v in pairs(biomeDir:GetChildren()) do
                        if v:IsA('Model') then
                            table.insert(options, v)
                        end
                    end
                    local cf,size = (options[math.random(1, #options)]):GetBoundingBox()
                    ReplicatedStorage.SpawnFire:FireAllClients(cf.Position)
                    Fire.FireActive[biomeName] = true
                    local waitTime = math.random(biomeData.WildFireLength.Lowest, biomeData.WildFireLength.Highest)
                    task.delay(5--[[waitTime]], function()
                        Fire.FireActive[biomeName] = false
                        --print('killing', biomeName, 'fire')
                        ReplicatedStorage.KillFire:FireAllClients(biomeName)
                    end)
                    found = true
                end
                if found then found = false break end
            end
            task.wait(60)
        end
    end)
end

return Fire
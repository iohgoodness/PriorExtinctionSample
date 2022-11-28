-- Timestamp // 11/28/2022 08:49:42 MNT
-- Author // @iohgoodness
-- Description // Main controller for the fires

local Fire = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WildfireData = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('WildfireData'))
local BiomesDir = workspace.Assets.Biomes

Fire.Segments = {}
Fire.FireActive = {}

Fire.Wildfires = function()
    for biomeName,_ in pairs(WildfireData) do Fire.FireActive[biomeName] = false end
    task.spawn(function()
        while task.wait(600) do
            for biomeName,biomeData in pairs(WildfireData) do
                if (math.random(1, 1000)) <= biomeData.RandomWildFireChance*10 then
                    local biomeDir = BiomesDir[biomeName]
                    local options = {}
                    for _,v in pairs(biomeDir:GetChildren()) do
                        if v:IsA('Model') then
                            table.insert(options, v)
                        end
                    end
                    require(ReplicatedStorage['rojo-sync-shared'].FireSpread).SetOnFire(options[math.random(1, #options)])
                    Fire.FireActive[biomeName] = true
                end
            end
        end
    end)
end

return Fire
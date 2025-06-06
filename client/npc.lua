local spawnedNPCs = {}
local blips = {}

-- NPC管理系统
local NPCManager = {}
NPCManager.__index = NPCManager

function NPCManager:new()
    local instance = setmetatable({}, NPCManager)
    instance.npcs = {}
    instance.activeNPCs = {}
    return instance
end

-- 创建NPC
function NPCManager:spawnNPC(npcData)
    local model = GetHashKey(npcData.model)
    
    if not HasModelLoaded(model) then
        RequestModel(model)
        local timeout = 0
        while not HasModelLoaded(model) and timeout < 10000 do
            Wait(100)
            timeout = timeout + 100
        end
        
        if not HasModelLoaded(model) then
            print(string.format('[Bear_SellNpc] 无法加载NPC模型: %s', npcData.model))
            return nil
        end
    end
    
    local ped = CreatePed(4, model, npcData.coords.x, npcData.coords.y, npcData.coords.z - 1.0, npcData.coords.w, false, true)
    
    if not DoesEntityExist(ped) then
        print(string.format('[Bear_SellNpc] 无法创建NPC: %s', npcData.id))
        return nil
    end
    
    -- 设置属性让NPC更稳定
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanPlayAmbientAnims(ped, true)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetEntityCanBeDamaged(ped, false)
    
    if npcData.scenario then
        TaskStartScenarioInPlace(ped, npcData.scenario, 0, true)
    end
    
    -- 地图标记
    if npcData.blip and npcData.blip.enabled then
        local blip = AddBlipForEntity(ped)
        SetBlipSprite(blip, npcData.blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, npcData.blip.scale)
        SetBlipColour(blip, npcData.blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(npcData.blip.name)
        EndTextCommandSetBlipName(blip)
        
        blips[npcData.id] = blip
    end
    
    self:setupTarget(ped, npcData)
    
    SetModelAsNoLongerNeeded(model)
    
    return ped
end

function NPCManager:setupTarget(ped, npcData)
    local targetOptions = {
        {
            name = 'bear_sell_' .. npcData.id,
            icon = 'fas fa-handshake',
            label = '与 ' .. npcData.name .. ' 交易',
            onSelect = function()
                self:handleInteraction(npcData)
            end,
            canInteract = function()
                return HasPermission(Config.SellPermissions[npcData.id] or {})
            end
        }
    }
    
    if Config.Target == 'ox_target' then
        exports.ox_target:addLocalEntity(ped, targetOptions)
    elseif Config.Target == 'qb-target' then
        exports['qb-target']:AddTargetEntity(ped, {
            options = targetOptions,
            distance = Config.InteractionDistance
        })
    end
end

function NPCManager:handleInteraction(npcData)
    if not HasPermission(Config.SellPermissions[npcData.id] or {}) then
        ShowNotification(Config.Lang.no_permission, 'error')
        return
    end
    
    OpenSellMenu(npcData)
end

function NPCManager:spawnAllNPCs()
    for _, npcData in ipairs(Config.NPCs) do
        CreateThread(function()
            local ped = self:spawnNPC(npcData)
            if ped then
                self.activeNPCs[npcData.id] = ped
                spawnedNPCs[npcData.id] = ped
                
                if Config.Debug then
                    print(string.format('[Bear_SellNpc] NPC生成成功: %s 在 %s', npcData.name, npcData.coords))
                end
            end
        end)
    end
end

function NPCManager:cleanup()
    for id, ped in pairs(self.activeNPCs) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
        
        if blips[id] then
            RemoveBlip(blips[id])
            blips[id] = nil
        end
    end
    
    self.activeNPCs = {}
    spawnedNPCs = {}
end

-- 远距离隐藏NPC
function NPCManager:startDistanceCheck()
    CreateThread(function()
        while true do
            local playerCoords = GetEntityCoords(PlayerPedId())
            
            for id, ped in pairs(self.activeNPCs) do
                if DoesEntityExist(ped) then
                    local npcCoords = GetEntityCoords(ped)
                    local distance = #(playerCoords - npcCoords)
                    
                    if distance > Config.NPCRenderDistance then
                        SetEntityVisible(ped, false, false)
                    else
                        SetEntityVisible(ped, true, false)
                    end
                end
            end
            
            Wait(1000)
        end
    end)
end

local npcManager = NPCManager:new()

RegisterNetEvent('Bear:SellNpc:InitializeNPCs', function()
    npcManager:spawnAllNPCs()
    npcManager:startDistanceCheck()
end)

RegisterNetEvent('Bear:SellNpc:CleanupNPCs', function()
    npcManager:cleanup()
end)

exports('GetNPCManager', function()
    return npcManager
end)

exports('GetSpawnedNPCs', function()
    return spawnedNPCs
end)

exports('GetNPCById', function(id)
    return spawnedNPCs[id]
end) 
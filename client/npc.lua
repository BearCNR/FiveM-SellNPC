local spawnedNPCs = {}
local blips = {}

-- NPC管理类
local NPCManager = {}
NPCManager.__index = NPCManager

function NPCManager:new()
    local instance = setmetatable({}, NPCManager)
    instance.npcs = {}
    instance.activeNPCs = {}
    return instance
end

-- 生成单个NPC
function NPCManager:spawnNPC(npcData)
    local model = GetHashKey(npcData.model)
    
    -- 请求模型
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
    
    -- 创建NPC
    local ped = CreatePed(4, model, npcData.coords.x, npcData.coords.y, npcData.coords.z - 1.0, npcData.coords.w, false, true)
    
    if not DoesEntityExist(ped) then
        print(string.format('[Bear_SellNpc] 无法创建NPC: %s', npcData.id))
        return nil
    end
    
    -- 设置NPC属性
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanPlayAmbientAnims(ped, true)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetEntityCanBeDamaged(ped, false)
    
    -- 设置场景动画
    if npcData.scenario then
        TaskStartScenarioInPlace(ped, npcData.scenario, 0, true)
    end
    
    -- 创建地图标记
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
    
    -- 设置目标交互
    self:setupTarget(ped, npcData)
    
    -- 释放模型
    SetModelAsNoLongerNeeded(model)
    
    return ped
end

-- 设置目标交互
function NPCManager:setupTarget(ped, npcData)
    if not Config.UseTarget then
        self:setupKeyInteraction(ped, npcData)
        return
    end
    
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
    
    if Config.Target == 'ox_target' and GetResourceState('ox_target') == 'started' then
        exports.ox_target:addLocalEntity(ped, targetOptions)
    elseif Config.Target == 'qb-target' and GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddTargetEntity(ped, {
            options = targetOptions,
            distance = Config.InteractionDistance
        })
    else
        -- 备用键盘交互
        self:setupKeyInteraction(ped, npcData)
    end
end

-- 设置键盘交互（备用方案）
function NPCManager:setupKeyInteraction(ped, npcData)
    CreateThread(function()
        while DoesEntityExist(ped) do
            local playerCoords = GetEntityCoords(PlayerPedId())
            local npcCoords = GetEntityCoords(ped)
            local distance = #(playerCoords - npcCoords)
            
            if distance <= Config.InteractionDistance then
                -- 显示交互提示
                SetTextComponentFormat('STRING')
                AddTextComponentString(string.format(Config.Lang.npc_interaction, npcData.name))
                DisplayHelpTextFromStringLabel(0, 0, 1, -1)
                
                -- 检测按键
                if IsControlJustPressed(0, 38) then -- E键
                    if HasPermission(Config.SellPermissions[npcData.id] or {}) then
                        self:handleInteraction(npcData)
                    else
                        ShowNotification(Config.Lang.no_permission, 'error')
                    end
                end
            end
            
            Wait(0)
        end
    end)
end

-- 处理交互
function NPCManager:handleInteraction(npcData)
    if not HasPermission(Config.SellPermissions[npcData.id] or {}) then
        ShowNotification(Config.Lang.no_permission, 'error')
        return
    end
    
    OpenSellMenu(npcData)
end

-- 生成所有NPC
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

-- 清理所有NPC
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
    
    if Config.Debug then
        print('[Bear_SellNpc] NPC清理完成')
    end
end

-- 距离检查线程
function NPCManager:startDistanceCheck()
    CreateThread(function()
        while true do
            local playerCoords = GetEntityCoords(PlayerPedId())
            
            for id, ped in pairs(self.activeNPCs) do
                if DoesEntityExist(ped) then
                    local npcCoords = GetEntityCoords(ped)
                    local distance = #(playerCoords - npcCoords)
                    
                    -- 如果距离过远，设置为不可见以优化性能
                    if distance > Config.NPCRenderDistance then
                        SetEntityVisible(ped, false, false)
                    else
                        SetEntityVisible(ped, true, false)
                    end
                end
            end
            
            Wait(1000) -- 每秒检查一次
        end
    end)
end

-- 全局NPC管理器实例
local npcManager = NPCManager:new()

-- 事件处理器
RegisterNetEvent('Bear:SellNpc:InitializeNPCs', function()
    npcManager:spawnAllNPCs()
    npcManager:startDistanceCheck()
end)

RegisterNetEvent('Bear:SellNpc:CleanupNPCs', function()
    npcManager:cleanup()
end)

-- 导出函数
exports('GetNPCManager', function()
    return npcManager
end)

exports('GetSpawnedNPCs', function()
    return spawnedNPCs
end)

exports('GetNPCById', function(id)
    return spawnedNPCs[id]
end) 
local ESX, QBCore = nil, nil
local Framework = nil
local PlayerData = {}

-- 检测框架类型
local function InitializeFramework()
    if Config.Framework == 'auto' then
        if GetResourceState('es_extended') == 'started' then
            Config.Framework = 'esx'
        elseif GetResourceState('qb-core') == 'started' then
            Config.Framework = 'qb'
        else
            print('[Bear_SellNpc] 错误: 未检测到支持的框架')
            return false
        end
    end

    if Config.Framework == 'esx' then
        ESX = exports['es_extended']:getSharedObject()
        Framework = ESX
        
        RegisterNetEvent('esx:playerLoaded', function(xPlayer)
            PlayerData = xPlayer
        end)
        
        RegisterNetEvent('esx:setJob', function(job)
            PlayerData.job = job
        end)
        
    elseif Config.Framework == 'qb' then
        QBCore = exports['qb-core']:GetCoreObject()
        Framework = QBCore
        
        RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
            PlayerData = QBCore.Functions.GetPlayerData()
        end)
        
        RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
            PlayerData.job = JobInfo
        end)
    end
    
    return true
end

function GetPlayerData()
    if Config.Framework == 'esx' then
        return ESX.GetPlayerData()
    elseif Config.Framework == 'qb' then
        return QBCore.Functions.GetPlayerData()
    end
    return {}
end

function HasPermission(permissions)
    if not permissions or #permissions == 0 then
        return true
    end
    
    local playerData = GetPlayerData()
    
    for _, permission in ipairs(permissions) do
        if Config.Framework == 'esx' then
            if playerData.group and playerData.group == permission then
                return true
            end
        elseif Config.Framework == 'qb' then
            if QBCore.Functions.HasPermission(permission) then
                return true
            end
        end
    end
    
    return false
end

function ShowNotification(message, type)
    if Config.Framework == 'esx' then
        ESX.ShowNotification(message)
    elseif Config.Framework == 'qb' then
        QBCore.Functions.Notify(message, type or 'primary', 5000)
    end
end

function OpenSellMenu(npcData)
    local options = {}
    TriggerServerEvent('Bear:SellNpc:GetPlayerItems', npcData.id)
end

RegisterNetEvent('Bear:SellNpc:ShowSellMenu', function(npcId, playerItems)
    local npcData = nil
    for _, npc in ipairs(Config.NPCs) do
        if npc.id == npcId then
            npcData = npc
            break
        end
    end
    
    if not npcData then return end
    
    local options = {}
    
    for _, sellItem in ipairs(npcData.items) do
        local playerItem = playerItems[sellItem.name]
        if playerItem and playerItem.count > 0 then
            table.insert(options, {
                title = sellItem.label,
                description = string.format('价格: $%d/个 | 拥有: %d个', sellItem.price, playerItem.count),
                icon = 'fas fa-dollar-sign',
                onSelect = function()
                    OpenAmountMenu(npcData, sellItem, playerItem.count)
                end
            })
        end
    end
    
    if #options == 0 then
        ShowNotification(Config.Lang.no_items, 'error')
        return
    end
    
    local menu = {
        id = 'bear_sell_menu',
        title = string.format(Config.Lang.sell_menu_title, npcData.name),
        position = 'top-right',
        options = options
    }
    
    exports.ox_lib:registerContext(menu)
    exports.ox_lib:showContext('bear_sell_menu')
end)

function OpenAmountMenu(npcData, sellItem, maxAmount)
    local input = exports.ox_lib:inputDialog(Config.Lang.select_amount, {
        {
            type = 'number',
            label = string.format('数量 (最大: %d)', maxAmount),
            placeholder = '1',
            min = 1,
            max = maxAmount,
            required = true
        }
    })
    
    if input and input[1] then
        local amount = tonumber(input[1])
        if amount and amount > 0 and amount <= maxAmount then
            ConfirmSale(npcData, sellItem, amount)
        else
            ShowNotification(Config.Lang.invalid_amount, 'error')
        end
    end
end

function ConfirmSale(npcData, sellItem, amount)
    local totalPrice = sellItem.price * amount
    
    local alert = exports.ox_lib:alertDialog({
        header = Config.Lang.confirm_sale,
        content = string.format('出售 %s x%d\n总价: $%d', sellItem.label, amount, totalPrice),
        centered = true,
        cancel = true
    })
    
    if alert == 'confirm' then
        TriggerServerEvent('Bear:SellNpc:SellItem', npcData.id, sellItem.name, amount, totalPrice)
    end
end



CreateThread(function()
    if not InitializeFramework() then
        return
    end
    
    while not PlayerData or not PlayerData.identifier do
        PlayerData = GetPlayerData()
        Wait(1000)
    end
    
    TriggerEvent('Bear:SellNpc:InitializeNPCs')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        TriggerEvent('Bear:SellNpc:CleanupNPCs')
    end
end) 
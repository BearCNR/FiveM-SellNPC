local ESX, QBCore = nil, nil
local Framework = nil
local PlayerData = {}

-- 框架检测和初始化
local function InitializeFramework()
    if Config.Framework == 'auto' then
        -- 自动检测框架
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

-- 获取玩家数据
function GetPlayerData()
    if Config.Framework == 'esx' then
        return ESX.GetPlayerData()
    elseif Config.Framework == 'qb' then
        return QBCore.Functions.GetPlayerData()
    end
    return {}
end

-- 检查权限
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

-- 显示通知
function ShowNotification(message, type)
    if Config.Framework == 'esx' then
        ESX.ShowNotification(message)
    elseif Config.Framework == 'qb' then
        QBCore.Functions.Notify(message, type or 'primary', 5000)
    else
        -- 备用通知方式
        SetNotificationTextEntry('STRING')
        AddTextComponentString(message)
        DrawNotification(0, 1)
    end
end

-- 打开销售菜单
function OpenSellMenu(npcData)
    local options = {}
    
    -- 获取玩家可出售的物品
    TriggerServerEvent('Bear:SellNpc:GetPlayerItems', npcData.id)
end

-- 接收玩家物品数据并显示菜单
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
    
    if GetResourceState('ox_lib') == 'started' then
        exports.ox_lib:registerContext(menu)
        exports.ox_lib:showContext('bear_sell_menu')
    else
        -- 备用菜单系统
        ShowBasicMenu(options, npcData.name)
    end
end)

-- 数量选择菜单
function OpenAmountMenu(npcData, sellItem, maxAmount)
    if GetResourceState('ox_lib') == 'started' then
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
    else
        -- 备用输入方式
        DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP8", "", "", "", "", "", 10)
        while UpdateOnscreenKeyboard() == 0 do
            Wait(0)
        end
        
        if GetOnscreenKeyboardResult() then
            local amount = tonumber(GetOnscreenKeyboardResult())
            if amount and amount > 0 and amount <= maxAmount then
                ConfirmSale(npcData, sellItem, amount)
            else
                ShowNotification(Config.Lang.invalid_amount, 'error')
            end
        end
    end
end

-- 确认销售
function ConfirmSale(npcData, sellItem, amount)
    local totalPrice = sellItem.price * amount
    
    if GetResourceState('ox_lib') == 'started' then
        local alert = exports.ox_lib:alertDialog({
            header = Config.Lang.confirm_sale,
            content = string.format('出售 %s x%d\n总价: $%d', sellItem.label, amount, totalPrice),
            centered = true,
            cancel = true
        })
        
        if alert == 'confirm' then
            -- 使用Token保护的事件触发
            exports["BEAR_GOOD"]:ExecuteServerEvent('Bear:SellNpc:SellItem', npcData.id, sellItem.name, amount, totalPrice)
        end
    else
        -- 使用Token保护的事件触发
        exports["BEAR_GOOD"]:ExecuteServerEvent('Bear:SellNpc:SellItem', npcData.id, sellItem.name, amount, totalPrice)
    end
end

-- 基础菜单系统（备用）
function ShowBasicMenu(options, npcName)
    local elements = {}
    
    for i, option in ipairs(options) do
        table.insert(elements, {
            label = option.title .. ' - ' .. option.description,
            value = i
        })
    end
    
    -- 这里可以实现一个基础的菜单显示
    -- 由于没有前端，我们简化处理
    ShowNotification('请查看聊天框获取可出售物品列表', 'info')
    
    for i, option in ipairs(options) do
        TriggerEvent('chat:addMessage', {
            color = {0, 255, 0},
            multiline = true,
            args = {string.format('[%d] %s - %s', i, option.title, option.description)}
        })
    end
end

-- 资源启动
CreateThread(function()
    if not InitializeFramework() then
        return
    end
    
    -- 等待玩家加载
    while not PlayerData or not PlayerData.identifier do
        PlayerData = GetPlayerData()
        Wait(1000)
    end
    
    -- 初始化NPC系统
    TriggerEvent('Bear:SellNpc:InitializeNPCs')
    
    if Config.Debug then
        print('[Bear_SellNpc] 客户端初始化完成')
    end
end)

-- 资源停止清理
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        TriggerEvent('Bear:SellNpc:CleanupNPCs')
    end
end) 
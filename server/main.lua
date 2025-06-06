local ESX, QBCore = nil, nil
local Framework = nil

-- 启动时检测使用的框架
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
    elseif Config.Framework == 'qb' then
        QBCore = exports['qb-core']:GetCoreObject()
        Framework = QBCore
    end
    
    return true
end

-- 获取玩家对象
function GetPlayer(source)
    if Config.Framework == 'esx' then
        return ESX.GetPlayerFromId(source)
    elseif Config.Framework == 'qb' then
        return QBCore.Functions.GetPlayer(source)
    end
    return nil
end

-- 检查玩家权限
function HasPlayerPermission(source, permissions)
    if not permissions or #permissions == 0 then
        return true
    end
    
    local xPlayer = GetPlayer(source)
    if not xPlayer then return false end
    
    for _, permission in ipairs(permissions) do
        if Config.Framework == 'esx' then
            if xPlayer.getGroup() == permission then
                return true
            end
        elseif Config.Framework == 'qb' then
            if QBCore.Functions.HasPermission(source, permission) then
                return true
            end
        end
    end
    
    return false
end

-- 获取玩家物品
function GetPlayerItems(source)
    local xPlayer = GetPlayer(source)
    if not xPlayer then return {} end
    
    local items = {}
    
    if Config.Framework == 'esx' then
        local inventory = xPlayer.getInventory()
        for _, item in pairs(inventory) do
            if item.count and item.count > 0 then
                items[item.name] = {
                    name = item.name,
                    label = item.label,
                    count = item.count
                }
            end
        end
    elseif Config.Framework == 'qb' then
        local inventory = xPlayer.PlayerData.items
        for _, item in pairs(inventory) do
            if item.amount and item.amount > 0 then
                items[item.name] = {
                    name = item.name,
                    label = item.label,
                    count = item.amount
                }
            end
        end
    end
    
    return items
end

-- 移除玩家物品
function RemovePlayerItem(source, itemName, amount)
    local xPlayer = GetPlayer(source)
    if not xPlayer then return false end
    
    if Config.Framework == 'esx' then
        local item = xPlayer.getInventoryItem(itemName)
        if item and item.count >= amount then
            xPlayer.removeInventoryItem(itemName, amount)
            return true
        end
    elseif Config.Framework == 'qb' then
        if xPlayer.Functions.RemoveItem(itemName, amount) then
            return true
        end
    end
    
    return false
end

-- 给玩家金钱
function AddPlayerMoney(source, amount)
    local xPlayer = GetPlayer(source)
    if not xPlayer then return false end
    
    if Config.Framework == 'esx' then
        xPlayer.addMoney(amount)
        return true
    elseif Config.Framework == 'qb' then
        xPlayer.Functions.AddMoney('cash', amount)
        return true
    end
    
    return false
end

-- 发送通知
function SendNotification(source, message, type)
    if Config.Framework == 'esx' then
        TriggerClientEvent('esx:showNotification', source, message)
    elseif Config.Framework == 'qb' then
        TriggerClientEvent('QBCore:Notify', source, message, type or 'primary', 5000)
    end
end

-- 记录日志
function LogTransaction(source, npcId, itemName, amount, totalPrice)
    local xPlayer = GetPlayer(source)
    if not xPlayer then return end
    
    local identifier = nil
    local playerName = GetPlayerName(source)
    
    if Config.Framework == 'esx' then
        identifier = xPlayer.identifier
    elseif Config.Framework == 'qb' then
        identifier = xPlayer.PlayerData.citizenid
    end
    
    local logData = {
        type = 'item_sell',
        player_id = source,
        identifier = identifier,
        player_name = playerName,
        npc_id = npcId,
        item_name = itemName,
        amount = amount,
        price_per_item = math.floor(totalPrice / amount),
        total_price = totalPrice,
        timestamp = os.time()
    }
        
    -- 控制台日志
    print(string.format('[Bear_SellNpc] %s (%s) 向 %s 出售了 %s x%d，获得 $%d', 
        playerName, identifier or 'unknown', npcId, itemName, amount, totalPrice))
    
    -- 触发自定义日志事件
    TriggerEvent('Bear:SellNpc:TransactionLogged', logData)
end

-- 防作弊数据
local AntiCheatData = {
    suspiciousPlayers = {},
    maxWarnings = Config.AntiCheat.maxWarnings or 3,
    banDuration = 86400,
    priceTolerancePercent = (Config.AntiCheat.priceTolerancePercent or 10) / 100
}

-- 检查价格是否被篡改
function ValidatePrice(npcId, itemName, amount, claimedPrice)
    local basePrice = nil
    for _, npc in ipairs(Config.NPCs) do
        if npc.id == npcId then
            for _, item in ipairs(npc.items) do
                if item.name == itemName then
                    basePrice = item.price
                    break
                end
            end
            break
        end
    end
    
    if not basePrice then
        return false, 'CONFIG_PRICE_NOT_FOUND'
    end
    
    local expectedTotalPrice = basePrice * amount
    local minAllowedPrice = math.floor(expectedTotalPrice * 0.9)
    local maxAllowedPrice = math.floor(expectedTotalPrice * 1.1)
    
    if claimedPrice < minAllowedPrice or claimedPrice > maxAllowedPrice then
        return false, 'PRICE_MANIPULATION', {
            expected = expectedTotalPrice,
            claimed = claimedPrice,
            basePrice = basePrice,
            amount = amount
        }
    end
    
    return true, 'PRICE_VALID'
end

-- 检查背包物品数量
function ValidateInventory(source, itemName, amount)
    local playerItems = GetPlayerItems(source)
    local playerItem = playerItems[itemName]
    
    if not playerItem then
        return false, 'ITEM_NOT_FOUND'
    end
    
    if playerItem.count < amount then
        return false, 'INSUFFICIENT_ITEMS', {
            claimed = amount,
            actual = playerItem.count
        }
    end
    
    return true, 'INVENTORY_VALID'
end

-- 记录可疑操作
function RecordSuspiciousActivity(source, cheatType, details)
    local identifier = GetPlayerIdentifier(source)
    local playerName = GetPlayerName(source)
    
    if not AntiCheatData.suspiciousPlayers[identifier] then
        AntiCheatData.suspiciousPlayers[identifier] = {
            warnings = 0,
            lastWarning = 0,
            activities = {}
        }
    end
    
    local playerData = AntiCheatData.suspiciousPlayers[identifier]
    playerData.warnings = playerData.warnings + 1
    playerData.lastWarning = os.time()
    
    table.insert(playerData.activities, {
        type = cheatType,
        details = details,
        timestamp = os.time()
    })
    
    print(string.format('[Bear_SellNpc] 🚨 反作弊警告: %s (%s) - %s | 警告次数: %d/%d', 
        playerName, identifier, cheatType, playerData.warnings, AntiCheatData.maxWarnings))
    
    TriggerEvent('Bear:SellNpc:CheatDetected', {
        source = source,
        identifier = identifier,
        playerName = playerName,
        cheatType = cheatType,
        details = details,
        warnings = playerData.warnings
    })
    
    return playerData.warnings
end

-- 执行作弊惩罚
function ExecuteAntiCheatPunishment(source, cheatType, details)
    local xPlayer = GetPlayer(source)
    if not xPlayer then return end
    
    local playerName = GetPlayerName(source)
    local identifier = GetPlayerIdentifier(source)
    
    -- 清空背包
    if Config.Framework == 'esx' then
        local inventory = xPlayer.getInventory()
        for _, item in pairs(inventory) do
            if item.count > 0 then
                xPlayer.removeInventoryItem(item.name, item.count)
            end
        end
    elseif Config.Framework == 'qb' then
        local inventory = xPlayer.PlayerData.items
        for slot, item in pairs(inventory) do
            if item and item.amount > 0 then
                xPlayer.Functions.RemoveItem(item.name, item.amount, slot)
            end
        end
    end
    
    SendNotification(source, '逗逗你而已啦😄', 'error')
    
    if Config.AntiCheat.punishmentActions.kickPlayer then
        DropPlayer(source, string.format('Bear反作弊系统: 检测到作弊行为 - %s', cheatType))
    end
    
    print(string.format('[Bear_SellNpc] 🔨 执行反作弊惩罚: %s (%s) - %s', 
        playerName, identifier, cheatType))
    
    local logEntry = string.format('[%s] %s (%s) - %s - Details: %s\n', 
        os.date('%Y-%m-%d %H:%M:%S'), playerName, identifier, cheatType, json.encode(details))
    
    TriggerEvent('Bear:SellNpc:CheatPunishmentExecuted', {
        source = source,
        identifier = identifier,
        playerName = playerName,
        cheatType = cheatType,
        details = details,
        timestamp = os.time()
    })
end

-- 验证交易合法性
function ValidateTransaction(source, npcId, itemName, amount, claimedPrice)
    local npcData = nil
    for _, npc in ipairs(Config.NPCs) do
        if npc.id == npcId then
            npcData = npc
            break
        end
    end
    
    if not npcData then
        RecordSuspiciousActivity(source, 'INVALID_NPC', {npcId = npcId})
        return false, '无效的NPC'
    end
    
    if not HasPlayerPermission(source, Config.SellPermissions[npcId] or {}) then
        return false, Config.Lang.no_permission
    end
    
    local sellItem = nil
    for _, item in ipairs(npcData.items) do
        if item.name == itemName then
            sellItem = item
            break
        end
    end
    
    if not sellItem then
        RecordSuspiciousActivity(source, 'INVALID_ITEM', {
            npcId = npcId,
            itemName = itemName
        })
        return false, '该商人不收购此物品'
    end
    
    if not amount or amount <= 0 or amount > 999 then
        RecordSuspiciousActivity(source, 'INVALID_AMOUNT', {
            itemName = itemName,
            amount = amount
        })
        return false, Config.Lang.invalid_amount
    end
    
    -- 检查库存
    local inventoryValid, inventoryError, inventoryDetails = ValidateInventory(source, itemName, amount)
    if not inventoryValid then
        local warnings = RecordSuspiciousActivity(source, 'INVENTORY_CHEAT', {
            error = inventoryError,
            details = inventoryDetails,
            itemName = itemName,
            amount = amount
        })
        
        if warnings >= AntiCheatData.maxWarnings then
            ExecuteAntiCheatPunishment(source, 'INVENTORY_MANIPULATION', inventoryDetails)
            return false, '检测到库存作弊'
        end
        
        return false, Config.Lang.not_enough_items
    end
    
    -- 检查价格
    if claimedPrice then
        local priceValid, priceError, priceDetails = ValidatePrice(npcId, itemName, amount, claimedPrice)
        if not priceValid then
            local warnings = RecordSuspiciousActivity(source, 'PRICE_MANIPULATION', {
                error = priceError,
                details = priceDetails,
                npcId = npcId,
                itemName = itemName,
                amount = amount,
                claimedPrice = claimedPrice
            })
            
            if priceError == 'PRICE_MANIPULATION' then
                ExecuteAntiCheatPunishment(source, 'PRICE_CHEAT', priceDetails)
                return false, '检测到价格作弊'
            end
        end
    end
    
    return true, npcData, sellItem
end

RegisterNetEvent('Bear:SellNpc:GetPlayerItems', function(npcId)
    local source = source
    local playerItems = GetPlayerItems(source)
    
    TriggerClientEvent('Bear:SellNpc:ShowSellMenu', source, npcId, playerItems)
end)

RegisterNetEvent('Bear:SellNpc:SellItem', function(npcId, itemName, amount, claimedTotalPrice)
    local source = source
    
    local expectedPrice = nil
    for _, npc in ipairs(Config.NPCs) do
        if npc.id == npcId then
            for _, item in ipairs(npc.items) do
                if item.name == itemName then
                    expectedPrice = item.price * amount
                    break
                end
            end
            break
        end
    end
    
    local isValid, npcDataOrError, sellItem = ValidateTransaction(source, npcId, itemName, amount, claimedTotalPrice)
    
    if not isValid then
        SendNotification(source, npcDataOrError, 'error')
        return
    end
    
    local npcData = npcDataOrError
    local actualTotalPrice = sellItem.price * amount
    
    -- 价格差异检查
    if claimedTotalPrice and math.abs(claimedTotalPrice - actualTotalPrice) > (actualTotalPrice * 0.1) then
        RecordSuspiciousActivity(source, 'PRICE_DESYNC', {
            claimed = claimedTotalPrice,
            actual = actualTotalPrice,
            difference = math.abs(claimedTotalPrice - actualTotalPrice),
            itemName = itemName,
            amount = amount
        })
    end
    
    if RemovePlayerItem(source, itemName, amount) then
        if AddPlayerMoney(source, actualTotalPrice) then
            SendNotification(source, string.format(Config.Lang.item_sold, sellItem.label, amount, actualTotalPrice), 'success')
            
            LogTransaction(source, npcId, itemName, amount, actualTotalPrice)
            
            TriggerEvent('Bear:SellNpc:ItemSold', {
                source = source,
                npcId = npcId,
                itemName = itemName,
                amount = amount,
                totalPrice = actualTotalPrice
            })
        else
            -- 退还物品
            if Config.Framework == 'esx' then
                local xPlayer = GetPlayer(source)
                if xPlayer then
                    xPlayer.addInventoryItem(itemName, amount)
                end
            elseif Config.Framework == 'qb' then
                local xPlayer = GetPlayer(source)
                if xPlayer then
                    xPlayer.Functions.AddItem(itemName, amount)
                end
            end
            
            SendNotification(source, '交易失败：无法添加金钱', 'error')
        end
    else
        SendNotification(source, Config.Lang.not_enough_items, 'error')
    end
end)



-- 资源启动
CreateThread(function()
    if not InitializeFramework() then
        return
    end
    
    print(string.format('[Bear_SellNpc] 框架: %s', Config.Framework))
    print(string.format('[Bear_SellNpc] 已加载 %d 个NPC配置', #Config.NPCs))
end)

-- 导出函数
exports('GetPlayerItems', GetPlayerItems)
exports('ValidateTransaction', ValidateTransaction)
exports('HasPlayerPermission', HasPlayerPermission) 
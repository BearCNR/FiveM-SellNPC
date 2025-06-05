local ESX, QBCore = nil, nil
local Framework = nil

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
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 255, 255},
            multiline = true,
            args = {"[系统]", message}
        })
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

-- 反作弊系统数据
local AntiCheatData = {
    suspiciousPlayers = {},
    maxWarnings = Config.AntiCheat.maxWarnings or 3,
    banDuration = 86400, -- 24小时
    priceTolerancePercent = (Config.AntiCheat.priceTolerancePercent or 10) / 100 -- 转换为小数
}

-- 反作弊 - 价格验证
function ValidatePrice(npcId, itemName, amount, claimedPrice)
    -- 获取配置中的基础价格
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
    
    -- 计算期望的总价格
    local expectedTotalPrice = basePrice * amount
    
    -- 允许的价格范围（考虑动态定价，最多70%到110%）
    local minAllowedPrice = math.floor(expectedTotalPrice * 0.7)
    local maxAllowedPrice = math.floor(expectedTotalPrice * 1.1)
    
    -- 检查价格是否在合理范围内
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

-- 反作弊 - 库存验证
function ValidateInventory(source, itemName, amount)
    local playerItems = GetPlayerItems(source)
    local playerItem = playerItems[itemName]
    
    -- 验证玩家是否真的拥有这些物品
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

-- 反作弊 - 记录可疑行为
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
    
    -- 记录到控制台
    print(string.format('[Bear_SellNpc] 🚨 反作弊警告: %s (%s) - %s | 警告次数: %d/%d', 
        playerName, identifier, cheatType, playerData.warnings, AntiCheatData.maxWarnings))
    
    -- 触发管理员通知事件
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

-- 反作弊 - 执行惩罚
function ExecuteAntiCheatPunishment(source, cheatType, details)
    local xPlayer = GetPlayer(source)
    if not xPlayer then return end
    
    local playerName = GetPlayerName(source)
    local identifier = GetPlayerIdentifier(source)
    
    -- 清空玩家背包（逗逗你而已啦）
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
    
    -- 发送"友好"的消息
    SendNotification(source, '逗逗你而已啦😄', 'error')
    
    -- 踢出玩家（可选）
    if Config.AntiCheat.punishmentActions.kickPlayer then
        DropPlayer(source, string.format('Bear反作弊系统: 检测到作弊行为 - %s', cheatType))
    end
    
    -- 管理员日志
    print(string.format('[Bear_SellNpc] 🔨 执行反作弊惩罚: %s (%s) - %s', 
        playerName, identifier, cheatType))
    
    -- 记录到作弊日志文件
    local logEntry = string.format('[%s] %s (%s) - %s - Details: %s\n', 
        os.date('%Y-%m-%d %H:%M:%S'), playerName, identifier, cheatType, json.encode(details))
    
    -- 这里可以写入到文件系统或数据库
    TriggerEvent('Bear:SellNpc:CheatPunishmentExecuted', {
        source = source,
        identifier = identifier,
        playerName = playerName,
        cheatType = cheatType,
        details = details,
        timestamp = os.time()
    })
end

-- 强化的交易验证系统
function ValidateTransaction(source, npcId, itemName, amount, claimedPrice)
    -- 基础验证
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
    
    -- 检查权限
    if not HasPlayerPermission(source, Config.SellPermissions[npcId] or {}) then
        return false, Config.Lang.no_permission
    end
    
    -- 检查物品是否在NPC的购买列表中
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
    
    -- 验证数量
    if not amount or amount <= 0 or amount > 999 then -- 限制最大数量防止溢出
        RecordSuspiciousActivity(source, 'INVALID_AMOUNT', {
            itemName = itemName,
            amount = amount
        })
        return false, Config.Lang.invalid_amount
    end
    
    -- 🔒 反作弊核心验证
    
    -- 1. 库存验证
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
    
    -- 2. 价格验证（如果提供了声称的价格）
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
            
            -- 价格作弊立即执行惩罚
            if priceError == 'PRICE_MANIPULATION' then
                ExecuteAntiCheatPunishment(source, 'PRICE_CHEAT', priceDetails)
                return false, '检测到价格作弊，逗逗你而已啦！'
            end
        end
    end
    
    return true, npcData, sellItem
end

-- 网络事件处理
RegisterNetEvent('Bear:SellNpc:GetPlayerItems', function(npcId)
    local source = source
    local playerItems = GetPlayerItems(source)
    
    TriggerClientEvent('Bear:SellNpc:ShowSellMenu', source, npcId, playerItems)
end)

-- 注册为安全事件，替换原有的RegisterNetEvent  
AddEventHandler("bear:safe:Bear:SellNpc:SellItem", function(source, npcId, itemName, amount, claimedTotalPrice)
    -- Token系统已经验证，source参数已由Token系统传递
    
    -- 计算预期价格用于验证
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
    
    -- 强化验证交易（包含价格验证）
    local isValid, npcDataOrError, sellItem = ValidateTransaction(source, npcId, itemName, amount, claimedTotalPrice)
    
    if not isValid then
        SendNotification(source, npcDataOrError, 'error')
        return
    end
    
    local npcData = npcDataOrError
    
    -- 使用服务端计算的价格，不信任客户端
    local actualTotalPrice = sellItem.price * amount
    
    -- 如果客户端声称的价格与服务端计算的差异过大，记录可疑行为
    if claimedTotalPrice and math.abs(claimedTotalPrice - actualTotalPrice) > (actualTotalPrice * 0.1) then
        RecordSuspiciousActivity(source, 'PRICE_DESYNC', {
            claimed = claimedTotalPrice,
            actual = actualTotalPrice,
            difference = math.abs(claimedTotalPrice - actualTotalPrice),
            itemName = itemName,
            amount = amount
        })
    end
    
    -- 执行交易
    if RemovePlayerItem(source, itemName, amount) then
        if AddPlayerMoney(source, actualTotalPrice) then
            -- 交易成功
            SendNotification(source, string.format(Config.Lang.item_sold, sellItem.label, amount, actualTotalPrice), 'success')
            
            -- 记录日志
            LogTransaction(source, npcId, itemName, amount, actualTotalPrice)
            
            -- 触发交易成功事件
            TriggerEvent('Bear:SellNpc:ItemSold', {
                source = source,
                npcId = npcId,
                itemName = itemName,
                amount = amount,
                totalPrice = actualTotalPrice
            })
        else
            -- 添加金钱失败，退还物品
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

-- 获取交易统计（管理员命令）
RegisterCommand('sellnpc_stats', function(source, args)
    if source == 0 or HasPlayerPermission(source, {'admin'}) then
        -- 这里可以实现统计功能
        local message = '[Bear_SellNpc] 统计功能暂未实现'
        if source == 0 then
            print(message)
        else
            SendNotification(source, message, 'info')
        end
    end
end, false)

-- 重新加载NPC配置（管理员命令）
RegisterCommand('sellnpc_reload', function(source, args)
    if source == 0 or HasPlayerPermission(source, {'admin'}) then
        -- 通知所有客户端重新加载NPC
        TriggerClientEvent('Bear:SellNpc:CleanupNPCs', -1)
        Wait(1000)
        TriggerClientEvent('Bear:SellNpc:InitializeNPCs', -1)
        
        local message = '[Bear_SellNpc] NPC配置已重新加载'
        if source == 0 then
            print(message)
        else
            SendNotification(source, message, 'success')
        end
    end
end, false)

-- 查看反作弊数据（管理员命令）
RegisterCommand('sellnpc_anticheat', function(source, args)
    if source == 0 or HasPlayerPermission(source, {'admin'}) then
        local suspiciousCount = 0
        for identifier, data in pairs(AntiCheatData.suspiciousPlayers) do
            suspiciousCount = suspiciousCount + 1
        end
        
        local message = string.format('[Bear_SellNpc] 反作弊状态: %d 名可疑玩家', suspiciousCount)
        if source == 0 then
            print(message)
            
            -- 详细信息显示在控制台
            for identifier, data in pairs(AntiCheatData.suspiciousPlayers) do
                print(string.format('  玩家: %s | 警告: %d | 最后警告: %s', 
                    identifier, data.warnings, os.date('%Y-%m-%d %H:%M:%S', data.lastWarning)))
            end
        else
            SendNotification(source, message, 'info')
        end
    end
end, false)

-- 清除玩家反作弊记录（管理员命令）
RegisterCommand('sellnpc_clear_warnings', function(source, args)
    if source == 0 or HasPlayerPermission(source, {'admin'}) then
        if args[1] then
            local targetIdentifier = args[1]
            if AntiCheatData.suspiciousPlayers[targetIdentifier] then
                AntiCheatData.suspiciousPlayers[targetIdentifier] = nil
                local message = string.format('[Bear_SellNpc] 已清除玩家 %s 的反作弊记录', targetIdentifier)
                if source == 0 then
                    print(message)
                else
                    SendNotification(source, message, 'success')
                end
            else
                local message = '[Bear_SellNpc] 未找到该玩家的反作弊记录'
                if source == 0 then
                    print(message)
                else
                    SendNotification(source, message, 'error')
                end
            end
        else
            local message = '[Bear_SellNpc] 用法: /sellnpc_clear_warnings <玩家标识符>'
            if source == 0 then
                print(message)
            else
                SendNotification(source, message, 'info')
            end
        end
    end
end, false)

-- 资源启动
CreateThread(function()
    if not InitializeFramework() then
        return
    end
    
    -- 等待Token系统初始化
    while GetResourceState('BEAR_GOOD') ~= 'started' do
        print('[Bear_SellNpc] 等待Token保护系统 (BEAR_GOOD) 启动...')
        Wait(1000)
    end
    
    -- 注册安全事件到Token系统
    Wait(2000) -- 确保Token系统完全加载
    
    local success, message = exports["BEAR_GOOD"]:RegisterSafeEvent('Bear:SellNpc:SellItem', {
        ban = true,   -- 启用自动封禁
        log = true    -- 记录所有调用
    }, false)         -- 禁止外部资源调用
    
    if success then
        print('[Bear_SellNpc] ✅ Token保护已启用: Bear:SellNpc:SellItem')
    else
        print('[Bear_SellNpc] ❌ Token保护注册失败: ' .. tostring(message))
    end
    
    print('[Bear_SellNpc] 服务端初始化完成')
    print(string.format('[Bear_SellNpc] 框架: %s', Config.Framework))
    print(string.format('[Bear_SellNpc] 已加载 %d 个NPC配置', #Config.NPCs))
    print('[Bear_SellNpc] 🛡️ Token安全保护已激活')
end)

-- 导出函数
exports('GetPlayerItems', GetPlayerItems)
exports('ValidateTransaction', ValidateTransaction)
exports('HasPlayerPermission', HasPlayerPermission) 
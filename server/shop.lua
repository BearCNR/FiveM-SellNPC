-- 商店管理系统
local ShopManager = {}
ShopManager.__index = ShopManager

-- 商店数据存储
local shopData = {
    transactions = {},
    dailyStats = {},
    playerCooldowns = {}
}

function ShopManager:new()
    local instance = setmetatable({}, ShopManager)
    instance.shops = {}
    return instance
end

-- 记录销售数据
function ShopManager:updateSaleStats(npcId, itemName, amount, totalPrice)
    local today = os.date('%Y-%m-%d')
    if not shopData.dailyStats[today] then
        shopData.dailyStats[today] = {}
    end
    
    if not shopData.dailyStats[today][npcId] then
        shopData.dailyStats[today][npcId] = {
            totalSales = 0,
            totalRevenue = 0,
            itemsSold = {}
        }
    end
    
    local todayStats = shopData.dailyStats[today][npcId]
    todayStats.totalSales = todayStats.totalSales + amount
    todayStats.totalRevenue = todayStats.totalRevenue + totalPrice
    
    if not todayStats.itemsSold[itemName] then
        todayStats.itemsSold[itemName] = 0
    end
    todayStats.itemsSold[itemName] = todayStats.itemsSold[itemName] + amount
end

-- 防刷冷却检查
function ShopManager:checkPlayerCooldown(source, npcId, itemName)
    local playerId = GetPlayerIdentifier(source)
    local cooldownKey = string.format('%s_%s_%s', playerId, npcId, itemName)
    
    if shopData.playerCooldowns[cooldownKey] then
        local lastSale = shopData.playerCooldowns[cooldownKey]
        local currentTime = os.time()
        local cooldownTime = 30
        
        if currentTime - lastSale < cooldownTime then
            local remainingTime = cooldownTime - (currentTime - lastSale)
            return false, remainingTime
        end
    end
    
    return true, 0
end

-- 设置冷却时间
function ShopManager:setPlayerCooldown(source, npcId, itemName)
    local playerId = GetPlayerIdentifier(source)
    local cooldownKey = string.format('%s_%s_%s', playerId, npcId, itemName)
    shopData.playerCooldowns[cooldownKey] = os.time()
end

-- 获取玩家标识符
function GetPlayerIdentifier(source)
    local xPlayer = GetPlayer(source)
    if not xPlayer then return tostring(source) end
    
    if Config.Framework == 'esx' then
        return xPlayer.identifier
    elseif Config.Framework == 'qb' then
        return xPlayer.PlayerData.citizenid
    end
    
    return tostring(source)
end

-- 批量出售处理
function ShopManager:processBulkSale(source, npcId, items)
    local results = {
        successful = {},
        failed = {},
        totalRevenue = 0
    }
    
    for _, saleData in ipairs(items) do
        local itemName = saleData.itemName
        local amount = saleData.amount
        
        local isValid, npcDataOrError, sellItem = ValidateTransaction(source, npcId, itemName, amount)
        
        if isValid then
            local canSell, cooldownRemaining = self:checkPlayerCooldown(source, npcId, itemName)
            if not canSell then
                table.insert(results.failed, {
                    itemName = itemName,
                    reason = string.format('冷却中，剩余 %d 秒', cooldownRemaining)
                })
            else
                local totalPrice = sellItem.price * amount
                
                if RemovePlayerItem(source, itemName, amount) then
                    if AddPlayerMoney(source, totalPrice) then
                        table.insert(results.successful, {
                            itemName = itemName,
                            amount = amount,
                            price = sellItem.price,
                            totalPrice = totalPrice
                        })
                        
                        results.totalRevenue = results.totalRevenue + totalPrice
                        
                        self:updateSaleStats(npcId, itemName, amount, totalPrice)
                        self:setPlayerCooldown(source, npcId, itemName)
                        
                        LogTransaction(source, npcId, itemName, amount, totalPrice)
                    else
                        -- 退还物品
                        if Config.Framework == 'esx' then
                            local xPlayer = GetPlayer(source)
                            if xPlayer then xPlayer.addInventoryItem(itemName, amount) end
                        elseif Config.Framework == 'qb' then
                            local xPlayer = GetPlayer(source)
                            if xPlayer then xPlayer.Functions.AddItem(itemName, amount) end
                        end
                        
                        table.insert(results.failed, {
                            itemName = itemName,
                            reason = '无法添加金钱'
                        })
                    end
                else
                    table.insert(results.failed, {
                        itemName = itemName,
                        reason = '物品不足'
                    })
                end
            end
        else
            table.insert(results.failed, {
                itemName = itemName,
                reason = npcDataOrError
            })
        end
    end
    
    return results
end

-- 查看销售统计
function ShopManager:getShopStats(npcId, days)
    days = days or 7
    local stats = {
        totalSales = 0,
        totalRevenue = 0,
        itemBreakdown = {},
        dailyBreakdown = {}
    }
    
    local currentDate = os.time()
    for i = 0, days - 1 do
        local checkDate = os.date('%Y-%m-%d', currentDate - (i * 86400))
        if shopData.dailyStats[checkDate] and shopData.dailyStats[checkDate][npcId] then
            local dayStats = shopData.dailyStats[checkDate][npcId]
            stats.totalSales = stats.totalSales + dayStats.totalSales
            stats.totalRevenue = stats.totalRevenue + dayStats.totalRevenue
            
            stats.dailyBreakdown[checkDate] = {
                sales = dayStats.totalSales,
                revenue = dayStats.totalRevenue
            }
            
            for itemName, amount in pairs(dayStats.itemsSold) do
                if not stats.itemBreakdown[itemName] then
                    stats.itemBreakdown[itemName] = 0
                end
                stats.itemBreakdown[itemName] = stats.itemBreakdown[itemName] + amount
            end
        end
    end
    
    return stats
end

-- 清理旧数据
function ShopManager:resetDailyStats()
    local weekAgo = os.date('%Y-%m-%d', os.time() - (7 * 86400))
    for date, _ in pairs(shopData.dailyStats) do
        if date < weekAgo then
            shopData.dailyStats[date] = nil
        end
    end
end

local shopManager = ShopManager:new()

-- 定时清理数据
CreateThread(function()
    while true do
        local currentTime = os.time()
        local currentHour = tonumber(os.date('%H', currentTime))
        
        if currentHour == 0 then
            shopManager:resetDailyStats()
            print('[Bear_SellNpc] 数据清理完成')
        end
        
        Wait(3600000)
    end
end)

RegisterNetEvent('Bear:SellNpc:BulkSell', function(npcId, items)
    local source = source
    local results = shopManager:processBulkSale(source, npcId, items)
    
    TriggerClientEvent('Bear:SellNpc:BulkSaleResult', source, results)
end)

RegisterNetEvent('Bear:SellNpc:GetStats', function(npcId, days)
    local source = source
    
    if not HasPlayerPermission(source, {'admin'}) then
        SendNotification(source, '权限不足', 'error')
        return
    end
    
    local stats = shopManager:getShopStats(npcId, days)
    TriggerClientEvent('Bear:SellNpc:ShowStats', source, npcId, stats)
end)

exports('GetShopManager', function()
    return shopManager
end)

exports('GetShopStats', function(npcId, days)
    return shopManager:getShopStats(npcId, days)
end) 
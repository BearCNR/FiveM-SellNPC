-- 商店管理类
local ShopManager = {}
ShopManager.__index = ShopManager

-- 初始化商店数据
local shopData = {
    transactions = {},
    dailyStats = {},
    playerCooldowns = {},
    dynamicPricing = {}
}

function ShopManager:new()
    local instance = setmetatable({}, ShopManager)
    instance.shops = {}
    instance:initializeDynamicPricing()
    return instance
end

-- 初始化动态定价系统
function ShopManager:initializeDynamicPricing()
    for _, npc in ipairs(Config.NPCs) do
        shopData.dynamicPricing[npc.id] = {}
        for _, item in ipairs(npc.items) do
            shopData.dynamicPricing[npc.id][item.name] = {
                basePrice = item.price,
                currentPrice = item.price,
                lastUpdate = os.time(),
                soldToday = 0,
                priceModifier = 1.0
            }
        end
    end
end

-- 计算动态价格
function ShopManager:calculateDynamicPrice(npcId, itemName)
    local priceData = shopData.dynamicPricing[npcId] and shopData.dynamicPricing[npcId][itemName]
    if not priceData then return nil end
    
    local basePrice = priceData.basePrice
    local currentTime = os.time()
    local timeSinceUpdate = currentTime - priceData.lastUpdate
    
    -- 基于销售数量的价格调整
    local demandModifier = 1.0
    if priceData.soldToday > 0 then
        -- 销售越多，价格逐渐降低（供需关系）
        demandModifier = math.max(0.7, 1.0 - (priceData.soldToday * 0.02))
    end
    
    -- 时间衰减：随时间恢复到基础价格
    local timeDecayModifier = 1.0
    if timeSinceUpdate > 3600 then -- 1小时后开始恢复
        local decayHours = math.floor(timeSinceUpdate / 3600)
        timeDecayModifier = math.min(1.0, 0.7 + (decayHours * 0.1))
    end
    
    -- 计算最终价格
    local finalModifier = demandModifier * timeDecayModifier
    local finalPrice = math.floor(basePrice * finalModifier)
    
    -- 更新价格数据
    priceData.currentPrice = finalPrice
    priceData.priceModifier = finalModifier
    priceData.lastUpdate = currentTime
    
    return finalPrice
end

-- 更新销售统计
function ShopManager:updateSaleStats(npcId, itemName, amount, totalPrice)
    -- 更新动态定价数据
    if shopData.dynamicPricing[npcId] and shopData.dynamicPricing[npcId][itemName] then
        shopData.dynamicPricing[npcId][itemName].soldToday = 
            shopData.dynamicPricing[npcId][itemName].soldToday + amount
    end
    
    -- 更新日统计
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

-- 检查玩家冷却时间
function ShopManager:checkPlayerCooldown(source, npcId, itemName)
    local playerId = GetPlayerIdentifier(source)
    local cooldownKey = string.format('%s_%s_%s', playerId, npcId, itemName)
    
    if shopData.playerCooldowns[cooldownKey] then
        local lastSale = shopData.playerCooldowns[cooldownKey]
        local currentTime = os.time()
        local cooldownTime = 30 -- 30秒冷却
        
        if currentTime - lastSale < cooldownTime then
            local remainingTime = cooldownTime - (currentTime - lastSale)
            return false, remainingTime
        end
    end
    
    return true, 0
end

-- 设置玩家冷却时间
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

-- 批量销售功能
function ShopManager:processBulkSale(source, npcId, items)
    local results = {
        successful = {},
        failed = {},
        totalRevenue = 0
    }
    
    for _, saleData in ipairs(items) do
        local itemName = saleData.itemName
        local amount = saleData.amount
        
        -- 验证单项交易
        local isValid, npcDataOrError, sellItem = ValidateTransaction(source, npcId, itemName, amount)
        
        if isValid then
            -- 检查冷却时间
            local canSell, cooldownRemaining = self:checkPlayerCooldown(source, npcId, itemName)
            if not canSell then
                table.insert(results.failed, {
                    itemName = itemName,
                    reason = string.format('冷却中，剩余 %d 秒', cooldownRemaining)
                })
            else
                -- 计算动态价格
                local dynamicPrice = self:calculateDynamicPrice(npcId, itemName)
                local finalPrice = dynamicPrice or sellItem.price
                local totalPrice = finalPrice * amount
                
                -- 执行交易
                if RemovePlayerItem(source, itemName, amount) then
                    if AddPlayerMoney(source, totalPrice) then
                        -- 成功
                        table.insert(results.successful, {
                            itemName = itemName,
                            amount = amount,
                            price = finalPrice,
                            totalPrice = totalPrice
                        })
                        
                        results.totalRevenue = results.totalRevenue + totalPrice
                        
                        -- 更新统计和冷却
                        self:updateSaleStats(npcId, itemName, amount, totalPrice)
                        self:setPlayerCooldown(source, npcId, itemName)
                        
                        -- 记录日志
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

-- 获取商店统计信息
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

-- 重置每日统计
function ShopManager:resetDailyStats()
    local yesterday = os.date('%Y-%m-%d', os.time() - 86400)
    
    -- 清理7天前的数据
    local weekAgo = os.date('%Y-%m-%d', os.time() - (7 * 86400))
    for date, _ in pairs(shopData.dailyStats) do
        if date < weekAgo then
            shopData.dailyStats[date] = nil
        end
    end
    
    -- 重置今日动态定价统计
    for npcId, npcPricing in pairs(shopData.dynamicPricing) do
        for itemName, priceData in pairs(npcPricing) do
            priceData.soldToday = 0
        end
    end
end

-- 创建全局商店管理器实例
local shopManager = ShopManager:new()

-- 每日重置定时器
CreateThread(function()
    while true do
        local currentTime = os.time()
        local currentHour = tonumber(os.date('%H', currentTime))
        
        -- 每天凌晨0点重置
        if currentHour == 0 then
            shopManager:resetDailyStats()
            print('[Bear_SellNpc] 每日统计已重置')
        end
        
        Wait(3600000) -- 每小时检查一次
    end
end)

-- 高级销售事件
RegisterNetEvent('Bear:SellNpc:BulkSell', function(npcId, items)
    local source = source
    local results = shopManager:processBulkSale(source, npcId, items)
    
    TriggerClientEvent('Bear:SellNpc:BulkSaleResult', source, results)
end)

-- 获取商店统计事件
RegisterNetEvent('Bear:SellNpc:GetStats', function(npcId, days)
    local source = source
    
    if not HasPlayerPermission(source, {'admin'}) then
        SendNotification(source, '权限不足', 'error')
        return
    end
    
    local stats = shopManager:getShopStats(npcId, days)
    TriggerClientEvent('Bear:SellNpc:ShowStats', source, npcId, stats)
end)

-- 获取动态价格
RegisterNetEvent('Bear:SellNpc:GetDynamicPrices', function(npcId)
    local source = source
    local prices = {}
    
    if shopData.dynamicPricing[npcId] then
        for itemName, priceData in pairs(shopData.dynamicPricing[npcId]) do
            local currentPrice = shopManager:calculateDynamicPrice(npcId, itemName)
            prices[itemName] = {
                basePrice = priceData.basePrice,
                currentPrice = currentPrice,
                modifier = priceData.priceModifier,
                soldToday = priceData.soldToday
            }
        end
    end
    
    TriggerClientEvent('Bear:SellNpc:DynamicPrices', source, npcId, prices)
end)

-- 导出函数
exports('GetShopManager', function()
    return shopManager
end)

exports('GetShopStats', function(npcId, days)
    return shopManager:getShopStats(npcId, days)
end)

exports('GetDynamicPrice', function(npcId, itemName)
    return shopManager:calculateDynamicPrice(npcId, itemName)
end) 
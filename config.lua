Config = {}

-- 系统设置
Config.Framework = 'auto' -- 'esx', 'qb', 'auto'
Config.Inventory = 'ox_inventory' -- 'ox_inventory', 'esx_inventoryhud', 'qb-inventory'
Config.Target = 'ox_target' -- 'ox_target', 'qb-target'
Config.Debug = false

-- 反作弊设置
Config.AntiCheat = {
    enabled = true, -- 启用反作弊系统
    maxWarnings = 3, -- 最大警告次数
    priceTolerancePercent = 10, -- 价格容忍百分比（动态定价考虑）
    maxItemAmount = 999, -- 单次交易最大物品数量
    clearWarningsDaily = true, -- 每日清除警告记录
    punishmentActions = {
        clearInventory = true, -- 清空背包
        kickPlayer = false, -- 踢出玩家
        notifyAdmins = true -- 通知管理员
    }
}

-- 交互设置
Config.InteractionDistance = 2.0
Config.NPCRenderDistance = 50.0
Config.UseTarget = true

-- NPC配置
Config.NPCs = {
    -- 武器商人 - 军事基地
    {
        id = 'weapon_dealer',
        name = '武器商人',
        model = 's_m_y_blackops_01',
        coords = vector4(2570.84, -383.01, 92.99, 82.36),
        scenario = 'WORLD_HUMAN_GUARD_STAND',
        items = {
            {name = 'weapon_pistol', price = 5000, label = '手枪'},
            {name = 'weapon_smg', price = 15000, label = '冲锋枪'},
            {name = 'ammo-9', price = 50, label = '9mm子弹'},
            {name = 'ammo-45', price = 60, label = '.45口径子弹'}
        },
        blip = {
            enabled = true,
            sprite = 110,
            color = 1,
            scale = 0.8,
            name = '武器商人'
        }
    },

    -- 药品商人 - 医院附近
    {
        id = 'drug_dealer',
        name = '药品商人',
        model = 's_m_m_doctor_01',
        coords = vector4(308.73, -595.12, 43.28, 69.59),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        items = {
            {name = 'medikit', price = 500, label = '医疗包'},
            {name = 'bandage', price = 100, label = '绷带'},
            {name = 'painkillers', price = 200, label = '止痛药'},
            {name = 'morphine', price = 800, label = '吗啡'}
        },
        blip = {
            enabled = true,
            sprite = 61,
            color = 2,
            scale = 0.8,
            name = '药品商人'
        }
    },

    -- 电子产品商人 - 市中心
    {
        id = 'tech_dealer',
        name = '电子产品商人',
        model = 's_m_m_scientist_01',
        coords = vector4(-47.02, -1757.51, 29.42, 48.73),
        scenario = 'WORLD_HUMAN_STAND_MOBILE',
        items = {
            {name = 'phone', price = 1000, label = '手机'},
            {name = 'radio', price = 800, label = '对讲机'},
            {name = 'tablet', price = 2500, label = '平板电脑'},
            {name = 'laptop', price = 5000, label = '笔记本电脑'}
        },
        blip = {
            enabled = true,
            sprite = 521,
            color = 3,
            scale = 0.8,
            name = '电子产品商人'
        }
    },

    -- 食品商人 - 海滩
    {
        id = 'food_dealer',
        name = '食品商人',
        model = 's_m_m_chef_01',
        coords = vector4(-1218.92, -1367.85, 5.11, 289.76),
        scenario = 'WORLD_HUMAN_AA_COFFEE',
        items = {
            {name = 'bread', price = 10, label = '面包'},
            {name = 'water', price = 5, label = '水'},
            {name = 'sandwich', price = 25, label = '三明治'},
            {name = 'coffee', price = 15, label = '咖啡'},
            {name = 'burger', price = 35, label = '汉堡'}
        },
        blip = {
            enabled = true,
            sprite = 52,
            color = 5,
            scale = 0.8,
            name = '食品商人'
        }
    }
}

-- 销售权限设置
Config.SellPermissions = {
    weapon_dealer = {'weapon.dealer', 'admin'},
    drug_dealer = {'drug.dealer', 'admin'},
    tech_dealer = {'tech.dealer', 'admin'},
    food_dealer = {} -- 无权限限制
}

-- 语言配置
Config.Lang = {
    no_permission = '你没有权限与此商人交易',
    no_items = '你没有可出售的物品',
    item_sold = '成功出售 %s x%d，获得 $%d',
    invalid_amount = '无效的数量',
    not_enough_items = '你没有足够的物品',
    npc_interaction = '按 [E] 与 %s 交易',
    sell_menu_title = '出售物品 - %s',
    sell_item = '出售 %s ($%d/个)',
    select_amount = '选择数量',
    confirm_sale = '确认出售',
    cancel = '取消',
    
    -- 反作弊消息
    cheat_detected = '检测到异常交易行为',
    price_manipulation = '价格操作被检测到',
    inventory_manipulation = '库存操作被检测到',
    punishment_message = '逗逗你而已啦 😄'
} 
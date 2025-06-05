# Bear 出售NPC系统

一个专业的FiveM出售NPC系统，采用现代化的Lua编程模式和模块化架构设计。

## 🚀 核心特性

### 💼 高端架构设计
- **模块化代码结构** - 清晰分离客户端和服务端逻辑
- **面向对象编程** - 使用Lua类和继承机制
- **双框架支持** - 自动检测并支持ESX和QBCore
- **多库兼容** - 支持ox_lib、ox_target、ox_inventory等现代库

### 🎯 智能NPC系统
- **动态NPC生成** - 基于配置自动创建和管理NPC
- **智能交互系统** - 支持ox_target和键盘交互备用方案
- **性能优化** - 距离检测、可见性控制、模型缓存
- **权限控制** - 基于框架的精细权限管理

### 💰 高级商店功能
- **动态定价系统** - 基于供需关系的智能价格调整
- **销售统计** - 详细的日销量、收入分析
- **冷却机制** - 防刷新的玩家交易冷却
- **批量销售** - 支持一次性出售多种物品

### 📊 数据管理
- **交易日志** - 完整的交易记录和审计跟踪
- **统计分析** - 商店表现和玩家行为分析
- **自动清理** - 智能数据清理和存储优化

## 📋 系统要求

- **FiveM服务器** (最新版本)
- **框架支持**: ESX 1.9+ 或 QBCore 1.0+
- **推荐库**: ox_lib, ox_target, ox_inventory
- **Lua版本**: 5.4 (建议)

## 🛠️ 安装步骤

1. **下载资源**
   ```bash
   git clone <repository_url> Bear_SellNpc
   ```

2. **配置server.cfg**
   ```cfg
   ensure Bear_SellNpc
   ```

3. **重启服务器**
   ```bash
   restart Bear_SellNpc
   ```

## ⚙️ 配置指南

### 基础设置
编辑 `config.lua` 文件中的系统设置：

```lua
Config.Framework = 'auto'  -- 'esx', 'qb', 'auto'
Config.Target = 'ox_target'  -- 'ox_target', 'qb-target'
Config.Debug = false  -- 开发调试模式
```

### 添加新的NPC商人

在 `Config.NPCs` 表中添加新的NPC配置：

```lua
{
    id = 'my_dealer',  -- 唯一标识符
    name = '我的商人',  -- 显示名称
    model = 's_m_y_dealer_01',  -- NPC模型
    coords = vector4(x, y, z, heading),  -- 位置坐标
    scenario = 'WORLD_HUMAN_STAND_IMPATIENT',  -- 动画场景
    items = {  -- 可出售物品列表
        {name = 'bread', price = 10, label = '面包'},
        {name = 'water', price = 5, label = '水'}
    },
    blip = {  -- 地图标记（可选）
        enabled = true,
        sprite = 52,
        color = 2,
        scale = 0.8,
        name = '我的商人'
    }
}
```

### 权限配置

在 `Config.SellPermissions` 中设置NPC访问权限：

```lua
Config.SellPermissions = {
    my_dealer = {'dealer.license', 'admin'},  -- 需要的权限组
    food_dealer = {}  -- 空数组表示无权限限制
}
```

## 🎮 使用方法

### 玩家交互
1. **靠近NPC** - 自动显示交互提示
2. **使用ox_target** - 右键点击NPC选择交易选项
3. **键盘交互** - 按E键开始交易（备用方案）
4. **选择物品** - 从菜单中选择要出售的物品
5. **输入数量** - 指定出售数量
6. **确认交易** - 完成出售获得金钱

### 管理员命令

```bash
# 查看交易统计
/sellnpc_stats

# 重新加载NPC配置
/sellnpc_reload
```

## 🔧 高级功能

### 动态定价系统
系统会根据以下因素自动调整价格：
- **销售量影响** - 销售越多价格越低
- **时间恢复** - 价格随时间逐渐恢复到基础值
- **供需平衡** - 模拟真实的市场供需关系

### 批量销售
支持一次性出售多种物品，提高交易效率：
```lua
-- 客户端调用示例
TriggerServerEvent('Bear:SellNpc:BulkSell', npcId, {
    {itemName = 'bread', amount = 10},
    {itemName = 'water', amount = 5}
})
```

### 统计分析
获取详细的商店运营数据：
```lua
-- 获取7天统计数据
local stats = exports['Bear_SellNpc']:GetShopStats('food_dealer', 7)
```

## 🔌 API接口

### 客户端导出
```lua
-- 获取NPC管理器
local npcManager = exports['Bear_SellNpc']:GetNPCManager()

-- 获取已生成的NPC
local npcs = exports['Bear_SellNpc']:GetSpawnedNPCs()

-- 根据ID获取特定NPC
local npc = exports['Bear_SellNpc']:GetNPCById('weapon_dealer')
```

### 服务端导出
```lua
-- 获取玩家物品
local items = exports['Bear_SellNpc']:GetPlayerItems(source)

-- 验证交易
local isValid, error = exports['Bear_SellNpc']:ValidateTransaction(source, npcId, itemName, amount)

-- 检查权限
local hasPermission = exports['Bear_SellNpc']:HasPlayerPermission(source, {'admin'})

-- 获取商店统计
local stats = exports['Bear_SellNpc']:GetShopStats('weapon_dealer', 30)

-- 获取动态价格
local price = exports['Bear_SellNpc']:GetDynamicPrice('weapon_dealer', 'weapon_pistol')
```

## 🎯 事件系统

### 客户端事件
```lua
-- NPC系统初始化
RegisterNetEvent('Bear:SellNpc:InitializeNPCs')

-- 显示销售菜单
RegisterNetEvent('Bear:SellNpc:ShowSellMenu')

-- 批量销售结果
RegisterNetEvent('Bear:SellNpc:BulkSaleResult')
```

### 服务端事件
```lua
-- 获取玩家物品
RegisterNetEvent('Bear:SellNpc:GetPlayerItems')

-- 出售物品
RegisterNetEvent('Bear:SellNpc:SellItem')

-- 批量销售
RegisterNetEvent('Bear:SellNpc:BulkSell')

-- 交易完成触发
AddEventHandler('Bear:SellNpc:ItemSold', function(data)
    -- data包含交易详情
end)
```

## 🐛 故障排除

### 常见问题

1. **NPC不显示**
   - 检查模型名称是否正确
   - 确认坐标是否有效
   - 查看控制台错误信息

2. **交互无响应**
   - 验证ox_target是否正确安装
   - 检查权限配置
   - 尝试使用键盘交互备用方案

3. **框架检测失败**
   - 确认ESX或QBCore正确安装
   - 检查框架版本兼容性
   - 手动设置Config.Framework

### 调试模式
启用调试模式获取详细日志：
```lua
Config.Debug = true
```

## 📄 许可证

版权所有 © 2025 Bear - 保留所有权利

本资源仅供学习和个人使用，禁止商业分发。

## 🤝 支持与反馈

如果您遇到问题或有改进建议，请联系开发者或提交issue。

---

**享受您的高端出售NPC系统！** 🎉 
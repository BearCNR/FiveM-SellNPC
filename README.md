# Bear 出售NPC系统 / Bear Sell NPC System

一个简单实用的FiveM出售NPC脚本，让玩家可以向NPC商人出售物品赚钱。

A simple and practical FiveM sell NPC script that allows players to sell items to NPC merchants for money.

## 功能特点 / Features

### 🏪 NPC商店系统
- 在地图上放置多个NPC商人
- 每个商人收购不同类型的物品
- 支持自定义商人位置和外观
- 地图标记显示商人位置

### 💰 交易系统  
- 简单的交易界面
- 支持批量出售物品
- 实时价格显示
- 交易完成后获得金钱

### 🔧 兼容性
- 支持ESX和QBCore框架
- 兼容ox_lib菜单系统
- 支持ox_target交互
- 适配现代FiveM资源

---

### 🏪 NPC Shop System
- Place multiple NPC merchants on the map
- Each merchant buys different types of items  
- Support custom merchant locations and appearance
- Map markers showing merchant locations

### 💰 Trading System
- Simple trading interface
- Support bulk selling items
- Real-time price display
- Receive money after successful transactions

### 🔧 Compatibility  
- Support ESX and QBCore frameworks
- Compatible with ox_lib menu system
- Support ox_target interaction
- Adapted for modern FiveM resources

## 安装说明 / Installation

### 中文安装步骤
1. 下载脚本文件到你的resources文件夹
2. 在server.cfg中添加 `ensure Bear_SellNpc`
3. 重启服务器
4. 根据需要修改config.lua配置文件

### English Installation Steps
1. Download script files to your resources folder
2. Add `ensure Bear_SellNpc` to server.cfg  
3. Restart the server
4. Modify config.lua configuration file as needed

## 配置说明 / Configuration

### 基础设置 / Basic Settings
```lua
Config.Framework = 'auto'  -- 框架类型 / Framework type
Config.Target = 'ox_target'  -- 交互系统 / Interaction system
Config.Debug = false  -- 调试模式 / Debug mode
```

### 添加NPC / Add NPC
```lua
{
    id = 'my_dealer',  -- 唯一ID / Unique ID
    name = '商人名称',  -- 显示名称 / Display name
    model = 's_m_y_dealer_01',  -- NPC模型 / NPC model
    coords = vector4(x, y, z, heading),  -- 坐标 / Coordinates
    items = {  -- 收购物品 / Items to buy
        {name = 'bread', price = 10, label = '面包'},
        {name = 'water', price = 5, label = '水'}
    }
}
```

## 使用方法 / How to Use

### 玩家操作 / Player Actions
1. 走近NPC商人 / Walk close to NPC merchant
2. 右键点击选择交易 / Right-click to select trade
3. 选择要出售的物品 / Choose items to sell
4. 输入出售数量 / Enter quantity to sell
5. 确认交易获得金钱 / Confirm trade to get money

## 权限设置 / Permission Settings

```lua
Config.SellPermissions = {
    weapon_dealer = {'weapon.dealer', 'admin'},  -- 需要权限 / Required permissions
    food_dealer = {}  -- 无权限限制 / No permission required
}
```

## 支持的框架 / Supported Frameworks

- **ESX** - 完全支持 / Fully supported
- **QBCore** - 完全支持 / Fully supported

## 依赖资源 / Dependencies

- ox_lib (推荐 / Recommended)
- ox_target 或 qb-target / or qb-target

## 常见问题 / FAQ

### 中文FAQ
**Q: NPC不显示怎么办？**
A: 检查坐标是否正确，确认模型名称没有错误

**Q: 无法交易怎么办？**  
A: 确认ox_target已正确安装，检查权限配置

**Q: 支持哪些物品？**
A: 支持所有ESX/QBCore物品，在config.lua中配置

### English FAQ
**Q: NPC not showing up?**
A: Check if coordinates are correct and model name is valid

**Q: Cannot trade?**
A: Make sure ox_target is properly installed, check permission config

**Q: What items are supported?**
A: Supports all ESX/QBCore items, configure in config.lua

## 更新日志 / Changelog

### v1.0.0
- 初始版本发布 / Initial release
- 基础NPC交易功能 / Basic NPC trading functionality
- 双框架支持 / Dual framework support

## 版权信息 / Copyright

版权所有 © 2025 Bear  
Copyright © 2025 Bear

本脚本仅供学习和个人服务器使用。  
This script is for learning and personal server use only.
---

**祝您游戏愉快！ / Enjoy your game!** 

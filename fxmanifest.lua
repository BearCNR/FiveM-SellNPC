fx_version 'cerulean'
game 'gta5'

name 'Bear_SellNpc'
author 'Bear'
version '1.0.0'
description 'Professional Sell NPC System'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/npc.lua'
}

server_scripts {
    'server/main.lua',
    'server/shop.lua'
}

lua54 'yes' 
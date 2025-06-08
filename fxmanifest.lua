-- fxmanifest.lua
fx_version 'cerulean'
game 'gta5'

author 'Vous'
description 'Système de point de blanchiment avec ox_inventory et NativeUI'
version '1.0.0'

-- Dépendances
dependency 'ox_inventory'
dependency 'ox_lib'
dependency 'es_extended'
dependency 'mysql-async'  -- ou ghmattimysql selon votre config

server_scripts {
    '@ox_inventory/lib/server.lua',  -- si demandé par ox_inventory
    '@mysql-async/lib/MySQL.lua',    -- ou '@ghmattimysql/ghmattimysql.lua'
    'server.lua'
}

client_scripts {
    '@ox_inventory/lib/client.lua',  -- si demandé par ox_inventory
    'client.lua'
}

-- Utilise la ressource NativeUI déjà installée
dependency 'NativeUI'
shared_scripts {
    '@NativeUI/NativeUI.lua'
}

-- fxmanifest.lua
fx_version 'cerulean'
game 'gta5'

author 'Vous'
description 'Système de point de blanchiment avec ox_inventory et NativeUI'
version '1.0.0'

-- Dépendances
dependency 'ox_inventory'
dependency 'ox_core'
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

-- NativeUI (inclure dans votre ressource ou installer séparément)
shared_scripts {
    'NativeUI.lua'
}

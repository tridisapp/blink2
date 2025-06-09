-- server.lua

ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Référence vers les exports d'ox_inventory
local ox_inventory = exports.ox_inventory

-- Paramètres par défaut
local DEFAULT_CAPACITY   = 50000    -- 50 kg
local DEFAULT_SLOTS      = 16
-- Seul l'argent liquide est accepté dans le coffre

-- Stockage en mémoire des coords
local stashCoords = {}
local stashNames  = {}
local allowedItem = {}
local transformItem = {}

-- 1) Au démarrage, charger tous les points enregistrés
MySQL.ready(function()
    local rows = MySQL.Sync.fetchAll("SELECT * FROM blanchiment_points")
    for _, row in ipairs(rows) do
        local stashName = 'blanch_' .. row.id
        stashCoords[row.id] = vector3(row.x, row.y, row.z)
        stashNames[row.id]  = row.name
        allowedItem[row.id]   = row.allowed_item or 'black_money'
        transformItem[row.id] = row.transform_item or 'money'
        -- Le label doit être fourni avant les paramètres slots et poids
        -- RegisterStash(name, label, slots, maxWeight)
        ox_inventory:RegisterStash(stashName, row.name, DEFAULT_SLOTS, DEFAULT_CAPACITY)
    end
end)

-- 2) Création d’un point via /blink → NativeUI → client → serveur
RegisterNetEvent('blanchiment:createPoint')
AddEventHandler('blanchiment:createPoint', function(name, coords)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    -- Persister en base
    local insertId = MySQL.Sync.insert([[
        INSERT INTO blanchiment_points
          (owner, name, x, y, z, inventory, allowed_item, transform_item)
        VALUES
          (@owner, @name, @x, @y, @z, @inventory, @allowed, @transform)
    ]], {
        ['@owner']     = xPlayer.identifier,
        ['@name']      = name,
        ['@x']         = coords.x,
        ['@y']         = coords.y,
        ['@z']         = coords.z,
        ['@inventory'] = json.encode({count = 0, slot = 1, name = ''}),
        ['@allowed']   = 'black_money',
        ['@transform'] = 'money'
    })
    -- Enregistrer côté serveur
    stashCoords[insertId] = vector3(coords.x, coords.y, coords.z)
    stashNames[insertId]  = name
    allowedItem[insertId]   = 'black_money'
    transformItem[insertId] = 'money'
    -- Utilise l'API RegisterStash(name, label, slots, maxWeight)
    ox_inventory:RegisterStash('blanch_'..insertId, name, DEFAULT_SLOTS, DEFAULT_CAPACITY)
    -- Informer le client
    TriggerClientEvent('blanchiment:pointCreated', src, insertId, coords, name)
end)

-- Envoi des points existants à un joueur
RegisterNetEvent('blanchiment:requestPoints')
AddEventHandler('blanchiment:requestPoints', function()
    local src    = source
    local points = {}
    for id, coords in pairs(stashCoords) do
        points[#points+1] = {
            id   = id,
            x    = coords.x,
            y    = coords.y,
            z    = coords.z,
            name = stashNames[id]
        }
    end
    TriggerClientEvent('blanchiment:loadPoints', src, points)
end)

-- 3) Limiter l’ajout aux seuls items autorisés
local processing = {}

local function startProcessing(id)
    if processing[id] then return end
    processing[id] = true
    local stash = 'blanch_' .. id
    CreateThread(function()
        Wait(200)
        while true do
            local item = ox_inventory:GetItem(stash, allowedItem[id])
            if not item or item.count <= 0 then break end
            ox_inventory:RemoveItem(stash, allowedItem[id], 1)
            Wait(2000)
            ox_inventory:AddItem(stash, transformItem[id], 1)
        end
        processing[id] = nil
    end)
end

AddEventHandler('ox_inventory:beforeItemAdded', function(source, stashName, itemName, count, meta, callback)
    local id = stashName:match('blanch_(%d+)')
    if id then
        id = tonumber(id)
        if itemName ~= allowedItem[id] then
            callback(false)
            return
        end
        callback(true)
        startProcessing(id)
    else
        callback(true)
    end
end)


-- server.lua

ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Référence vers les exports d'ox_inventory
local ox_inventory = exports.ox_inventory

-- Paramètres par défaut
local DEFAULT_CAPACITY   = 0        -- poids illimité
local DEFAULT_SLOTS      = 16
-- Stockage en mémoire des coords
local stashCoords = {}
local stashNames  = {}

-- 1) Au démarrage, charger tous les points enregistrés
MySQL.ready(function()
    local rows = MySQL.Sync.fetchAll("SELECT * FROM blanchiment_points")
    for _, row in ipairs(rows) do
        local stashName = 'blanch_' .. row.id
        stashCoords[row.id] = vector3(row.x, row.y, row.z)
        stashNames[row.id]  = row.name
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
          (owner, name, x, y, z, inventory)
        VALUES
          (@owner, @name, @x, @y, @z, @inventory)
    ]], {
        ['@owner']     = xPlayer.identifier,
        ['@name']      = name,
        ['@x']         = coords.x,
        ['@y']         = coords.y,
        ['@z']         = coords.z,
        ['@inventory'] = json.encode({count = 0, slot = 1, name = ''})
    })
    -- Enregistrer côté serveur
    stashCoords[insertId] = vector3(coords.x, coords.y, coords.z)
    stashNames[insertId]  = name
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


-- Stockage d'un homme de main en base
RegisterNetEvent('blanchiment:addPed')
AddEventHandler('blanchiment:addPed', function(name)
    MySQL.Sync.insert(
        'INSERT INTO blanchiment_ped (name) VALUES (@name)',
        { ['@name'] = name }
    )
end)

-- Stockage d'un point de rendez-vous
RegisterNetEvent('blanchiment:addPedPoint')
AddEventHandler('blanchiment:addPedPoint', function(coords)
    MySQL.Sync.insert(
        'INSERT INTO blanchiment_ped_point (x, y, z) VALUES (@x, @y, @z)',
        {
            ['@x'] = coords.x,
            ['@y'] = coords.y,
            ['@z'] = coords.z
        }
    )
end)




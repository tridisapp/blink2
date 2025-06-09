-- server.lua

ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Référence vers les exports d'ox_inventory
local ox_inventory = exports.ox_inventory

-- Paramètres par défaut
local DEFAULT_CAPACITY   = 0        -- poids illimité
local DEFAULT_SLOTS      = 16
-- Stockage en mémoire des coords
local stashCoords    = {}
local stashNames     = {}
local stashPedModels = {}

local function getRandomPedPoint()
    local rows = MySQL.Sync.fetchAll(
        'SELECT x, y, z FROM blanchiment_ped_point ORDER BY RAND() LIMIT 1'
    )
    if rows[1] then
        return vector3(rows[1].x, rows[1].y, rows[1].z)
    end
    return nil
end

local function getRandomPedName()
    local rows = MySQL.Sync.fetchAll(
        'SELECT name FROM blanchiment_ped ORDER BY RAND() LIMIT 1'
    )
    if rows[1] then
        return rows[1].name
    end
    return 'Unknown'
end

-- 1) Au démarrage, charger tous les points enregistrés
MySQL.ready(function()
    local rows = MySQL.Sync.fetchAll("SELECT * FROM blanchiment_points")
    for _, row in ipairs(rows) do
        local stashName = 'blanch_' .. row.id
        stashCoords[row.id]    = vector3(row.x, row.y, row.z)
        stashNames[row.id]     = row.name
        stashPedModels[row.id] = row.ped or 'u_m_y_smugmech_01'
        -- Le label doit être fourni avant les paramètres slots et poids
        -- RegisterStash(name, label, slots, maxWeight)
        ox_inventory:RegisterStash(stashName, row.name, DEFAULT_SLOTS, DEFAULT_CAPACITY)
    end
end)

-- 2) Création d’un point via /blink → NativeUI → client → serveur
RegisterNetEvent('blanchiment:createPoint')
AddEventHandler('blanchiment:createPoint', function(name)
    local src     = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local coords  = getRandomPedPoint()
    if not coords then
        TriggerClientEvent('esx:showNotification', src, 'Aucun point disponible')
        return
    end
    local pedName = getRandomPedName()
    -- Persister en base
    local insertId = MySQL.Sync.insert([[
        INSERT INTO blanchiment_points
          (owner, name, x, y, z, ped, inventory)
        VALUES
          (@owner, @name, @x, @y, @z, @ped, @inventory)
    ]], {
        ['@owner']     = xPlayer.identifier,
        ['@name']      = name,
        ['@x']         = coords.x,
        ['@y']         = coords.y,
        ['@z']         = coords.z,
        ['@ped']       = pedName,
        ['@inventory'] = json.encode({count = 0, slot = 1, name = ''})
    })
    -- Enregistrer côté serveur
    stashCoords[insertId]    = vector3(coords.x, coords.y, coords.z)
    stashNames[insertId]     = name
    stashPedModels[insertId] = pedName
    -- Utilise l'API RegisterStash(name, label, slots, maxWeight)
    ox_inventory:RegisterStash('blanch_'..insertId, name, DEFAULT_SLOTS, DEFAULT_CAPACITY)
    -- Informer le client
    TriggerClientEvent('blanchiment:pointCreated', src, insertId, coords, name, pedName)
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
            name = stashNames[id],
            ped  = stashPedModels[id]
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




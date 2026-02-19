QBCore.Players = {}
QBCore.Player = {}

-- Player class this is extremely important
-- Don't touch any of this unless you know what you are doing
-- Will cause major issues!

local resourceName = GetCurrentResourceName()

-- Player Class

local Private = setmetatable({}, { __mode = "k" })

local QBPlayer = {}
QBPlayer.__index = QBPlayer
QBPlayer.__metatable = false

function QBPlayer.new(PlayerData, Offline)
    local self = setmetatable({}, {
        __index = function(t, key)
            local priv = Private[t]
            if priv and priv.extra_methods[key] then
                return function(...) return priv.extra_methods[key](t, ...) end
            end
            return QBPlayer[key]
        end
    })

    Private[self] = {
        PlayerData = PlayerData,
        Offline = Offline or false,
        extra_methods = {},
        extra_fields = {}
    }

    self.PlayerData = Private[self].PlayerData
    self.Offline = Private[self].Offline

    return self
end

function QBPlayer:UpdatePlayerData()
    if Private[self].Offline then return end
    local pd = Private[self].PlayerData
    TriggerEvent('QBCore:Player:SetPlayerData', pd)
    TriggerClientEvent('QBCore:Player:SetPlayerData', pd.source, pd)
end

function QBPlayer:SetPlayerData(key, val)
    if not key or type(key) ~= 'string' then return end
    Private[self].PlayerData[key] = val
    self:UpdatePlayerData()
end

function QBPlayer:SetMetaData(meta, val)
    if not meta or type(meta) ~= 'string' then return end
    if meta == 'hunger' or meta == 'thirst' then
        val = val > 100 and 100 or val
    end
    Private[self].PlayerData.metadata[meta] = val
    self:UpdatePlayerData()
end

function QBPlayer:GetMetaData(meta)
    if not meta or type(meta) ~= 'string' then return end
    return Private[self].PlayerData.metadata[meta]
end

function QBPlayer:AddRep(rep, amount)
    if not rep or not amount then return end
    local pd = Private[self].PlayerData
    local current = pd.metadata['rep'][rep] or 0
    pd.metadata['rep'][rep] = current + tonumber(amount)
    self:UpdatePlayerData()
end

function QBPlayer:RemoveRep(rep, amount)
    if not rep or not amount then return end
    local pd = Private[self].PlayerData
    local current = pd.metadata['rep'][rep] or 0
    local new = current - tonumber(amount)
    pd.metadata['rep'][rep] = new < 0 and 0 or new
    self:UpdatePlayerData()
end

function QBPlayer:GetRep(rep)
    if not rep then return end
    return Private[self].PlayerData.metadata['rep'][rep] or 0
end

function QBPlayer:AddMoney(moneytype, amount, reason)
    reason = reason or 'unknown'
    moneytype = moneytype:lower()
    amount = tonumber(amount)
    if amount < 0 then return end
    local pd = Private[self].PlayerData
    if not pd.money[moneytype] then return false end
    pd.money[moneytype] = pd.money[moneytype] + amount 

    if not Private[self].Offline then
        self:UpdatePlayerData()
        if amount > 100000 then
            TriggerEvent('qb-log:server:CreateLog', 'playermoney', 'AddMoney', 'lightgreen', '**' .. GetPlayerName(pd.source) .. ' (citizenid: ' .. pd.citizenid .. ' | id: ' .. pd.source .. ')** $' .. amount .. ' (' .. moneytype .. ') added, new ' .. moneytype .. ' balance: ' .. pd.money[moneytype] .. ' reason: ' .. reason, true)
        else
            TriggerEvent('qb-log:server:CreateLog', 'playermoney', 'AddMoney', 'lightgreen', '**' .. GetPlayerName(pd.source) .. ' (citizenid: ' .. pd.citizenid .. ' | id: ' .. pd.source .. ')** $' .. amount .. ' (' .. moneytype .. ') added, new ' .. moneytype .. ' balance: ' .. pd.money[moneytype] .. ' reason: ' .. reason)
        end
        TriggerClientEvent('hud:client:OnMoneyChange', pd.source, moneytype, amount, false)
        TriggerClientEvent('QBCore:Client:OnMoneyChange', pd.source, moneytype, amount, 'add', reason)
        TriggerEvent('QBCore:Server:OnMoneyChange', pd.source, moneytype, amount, 'add', reason)
    end

    return true
end

function QBPlayer:RemoveMoney(moneytype, amount, reason)
    reason = reason or 'unknown'
    moneytype = moneytype:lower()
    amount = tonumber(amount)
    if amount < 0 then return end
    local pd = Private[self].PlayerData
    if not pd.money[moneytype] then return false end

    for _, mtype in pairs(QBCore.Config.Money.DontAllowMinus) do
        if mtype == moneytype then
            if (pd.money[moneytype] - amount) < 0 then return false end
        end
    end

    if pd.money[moneytype] - amount < QBCore.Config.Money.MinusLimit then return false end
    pd.money[moneytype] = pd.money[moneytype] - amount

    if not Private[self].Offline then
        self:UpdatePlayerData()
        if amount > 100000 then
            TriggerEvent('qb-log:server:CreateLog', 'playermoney', 'RemoveMoney', 'red', '**' .. GetPlayerName(pd.source) .. ' (citizenid: ' .. pd.citizenid .. ' | id: ' .. pd.source .. ')** $' .. amount .. ' (' .. moneytype .. ') removed, new ' .. moneytype .. ' balance: ' .. pd.money[moneytype] .. ' reason: ' .. reason, true)
        else
            TriggerEvent('qb-log:server:CreateLog', 'playermoney', 'RemoveMoney', 'red', '**' .. GetPlayerName(pd.source) .. ' (citizenid: ' .. pd.citizenid .. ' | id: ' .. pd.source .. ')** $' .. amount .. ' (' .. moneytype .. ') removed, new ' .. moneytype .. ' balance: ' .. pd.money[moneytype] .. ' reason: ' .. reason)
        end
        TriggerClientEvent('hud:client:OnMoneyChange', pd.source, moneytype, amount, true)
        if moneytype == 'bank' then
            TriggerClientEvent('qb-phone:client:RemoveBankMoney', pd.source, amount)
        end
        TriggerClientEvent('QBCore:Client:OnMoneyChange', pd.source, moneytype, amount, 'remove', reason)
        TriggerEvent('QBCore:Server:OnMoneyChange', pd.source, moneytype, amount, 'remove', reason)
    end

    return true
end

function QBPlayer:SetMoney(moneytype, amount, reason)
    reason = reason or 'unknown'
    moneytype = moneytype:lower()
    amount = tonumber(amount)
    if amount < 0 then return false end
    local pd = Private[self].PlayerData
    if not pd.money[moneytype] then return false end
    local difference = amount - pd.money[moneytype]
    pd.money[moneytype] = amount

    if not Private[self].Offline then
        self:UpdatePlayerData()
        TriggerEvent('qb-log:server:CreateLog', 'playermoney', 'SetMoney', 'green', '**' .. GetPlayerName(pd.source) .. ' (citizenid: ' .. pd.citizenid .. ' | id: ' .. pd.source .. ')** $' .. amount .. ' (' .. moneytype .. ') set, new ' .. moneytype .. ' balance: ' .. pd.money[moneytype] .. ' reason: ' .. reason)
        TriggerClientEvent('hud:client:OnMoneyChange', pd.source, moneytype, math.abs(difference), difference < 0)
        TriggerClientEvent('QBCore:Client:OnMoneyChange', pd.source, moneytype, amount, 'set', reason)
        TriggerEvent('QBCore:Server:OnMoneyChange', pd.source, moneytype, amount, 'set', reason)
    end

    return true
end

function QBPlayer:GetMoney(moneytype)
    if not moneytype then return false end
    moneytype = moneytype:lower()
    return Private[self].PlayerData.money[moneytype]
end

function QBPlayer:SetJob(job, grade)
    job = job:lower()
    grade = grade or '0'
    if not QBCore.Shared.Jobs[job] then return false end
    local pd = Private[self].PlayerData
    pd.job = {
        name = job,
        label = QBCore.Shared.Jobs[job].label,
        onduty = QBCore.Shared.Jobs[job].defaultDuty,
        type = QBCore.Shared.Jobs[job].type or 'none',
        grade = {
            name = 'No Grades',
            level = 0,
            payment = 30,
            isboss = false
        }
    }
    local gradeKey = tostring(grade)
    local jobGradeInfo = QBCore.Shared.Jobs[job].grades[gradeKey]
    if jobGradeInfo then
        pd.job.grade.name = jobGradeInfo.name
        pd.job.grade.level = tonumber(gradeKey)
        pd.job.grade.payment = jobGradeInfo.payment
        pd.job.grade.isboss = jobGradeInfo.isboss or false
        pd.job.isboss = jobGradeInfo.isboss or false
    end

    if not Private[self].Offline then
        self:UpdatePlayerData()
        TriggerEvent('QBCore:Server:OnJobUpdate', pd.source, pd.job)
        TriggerClientEvent('QBCore:Client:OnJobUpdate', pd.source, pd.job)
    end

    return true
end

function QBPlayer:SetGang(gang, grade)
    gang = gang:lower()
    grade = grade or '0'
    if not QBCore.Shared.Gangs[gang] then return false end
    local pd = Private[self].PlayerData
    pd.gang = {
        name = gang,
        label = QBCore.Shared.Gangs[gang].label,
        grade = {
            name = 'No Grades',
            level = 0,
            isboss = false
        }
    }
    local gradeKey = tostring(grade)
    local gangGradeInfo = QBCore.Shared.Gangs[gang].grades[gradeKey]
    if gangGradeInfo then
        pd.gang.grade.name = gangGradeInfo.name
        pd.gang.grade.level = tonumber(gradeKey)
        pd.gang.grade.isboss = gangGradeInfo.isboss or false
        pd.gang.isboss = gangGradeInfo.isboss or false
    end

    if not Private[self].Offline then
        self:UpdatePlayerData()
        TriggerEvent('QBCore:Server:OnGangUpdate', pd.source, pd.gang)
        TriggerClientEvent('QBCore:Client:OnGangUpdate', pd.source, pd.gang)
    end

    return true
end

function QBPlayer:SetJobDuty(onDuty)
    local pd = Private[self].PlayerData
    pd.job.onduty = not not onDuty
    TriggerEvent('QBCore:Server:OnJobUpdate', pd.source, pd.job)
    TriggerClientEvent('QBCore:Client:OnJobUpdate', pd.source, pd.job)
    self:UpdatePlayerData()
end

function QBPlayer:Notify(text, type, length)
    TriggerClientEvent('QBCore:Notify', Private[self].PlayerData.source, text, type, length)
end

function QBPlayer:HasItem(items, amount)
    return QBCore.Functions.HasItem(Private[self].PlayerData.source, items, amount)
end

function QBPlayer:GetName()
    local charinfo = Private[self].PlayerData.charinfo
    return charinfo.firstname .. ' ' .. charinfo.lastname
end

function QBPlayer:Save()
    local priv = Private[self]
    if priv.Offline then
        QBCore.Player.SaveOffline(priv.PlayerData)
    else
        QBCore.Player.Save(priv.PlayerData.source)
    end
end

function QBPlayer:Logout()
    if Private[self].Offline then return end
    QBCore.Player.Logout(Private[self].PlayerData.source)
end

function QBPlayer:AddMethod(methodName, handler)
    Private[self].extra_methods[methodName] = handler
end

function QBPlayer:AddField(fieldName, data)
    Private[self].extra_fields[fieldName] = data
end

function QBPlayer:GetAllExtraMethods()
    return Private[self].extra_methods
end

function QBPlayer:GetAllExtraFields()
    return Private[self].extra_fields
end

-- QBCore.Player Functions

-- On player login get their data or set defaults
-- Don't touch any of this unless you know what you are doing
-- Will cause major issues!

function QBCore.Player.Login(source, citizenid, newData)
    if source and source ~= '' then
        if citizenid then
            local license = QBCore.Functions.GetIdentifier(source, 'license')
            local PlayerData = MySQL.prepare.await('SELECT * FROM players where citizenid = ?', { citizenid })
            if PlayerData and license == PlayerData.license then
                PlayerData.money = json.decode(PlayerData.money)
                PlayerData.job = json.decode(PlayerData.job)
                PlayerData.gang = json.decode(PlayerData.gang)
                PlayerData.position = json.decode(PlayerData.position)
                PlayerData.metadata = json.decode(PlayerData.metadata)
                PlayerData.charinfo = json.decode(PlayerData.charinfo)
                QBCore.Player.CheckPlayerData(source, PlayerData)
            else
                DropPlayer(source, Lang:t('info.exploit_dropped'))
                TriggerEvent('qb-log:server:CreateLog', 'anticheat', 'Anti-Cheat', 'white', GetPlayerName(source) .. ' Has Been Dropped For Character Joining Exploit', false)
            end
        else
            QBCore.Player.CheckPlayerData(source, newData)
        end
        return true
    else
        QBCore.ShowError(resourceName, 'ERROR QBCORE.PLAYER.LOGIN - NO SOURCE GIVEN!')
        return false
    end
end

function QBCore.Player.GetOfflinePlayer(citizenid)
    if citizenid then
        local PlayerData = MySQL.prepare.await('SELECT * FROM players where citizenid = ?', { citizenid })
        if PlayerData then
            PlayerData.money = json.decode(PlayerData.money)
            PlayerData.job = json.decode(PlayerData.job)
            PlayerData.gang = json.decode(PlayerData.gang)
            PlayerData.position = json.decode(PlayerData.position)
            PlayerData.metadata = json.decode(PlayerData.metadata)
            PlayerData.charinfo = json.decode(PlayerData.charinfo)
            return QBCore.Player.CheckPlayerData(nil, PlayerData)
        end
    end
    return nil
end

function QBCore.Player.GetPlayerByLicense(license)
    if license then
        local source = QBCore.Functions.GetSource(license)
        if source > 0 then
            return QBCore.Players[source]
        else
            return QBCore.Player.GetOfflinePlayerByLicense(license)
        end
    end
    return nil
end

function QBCore.Player.GetOfflinePlayerByLicense(license)
    if license then
        local PlayerData = MySQL.prepare.await('SELECT * FROM players where license = ?', { license })
        if PlayerData then
            PlayerData.money = json.decode(PlayerData.money)
            PlayerData.job = json.decode(PlayerData.job)
            PlayerData.gang = json.decode(PlayerData.gang)
            PlayerData.position = json.decode(PlayerData.position)
            PlayerData.metadata = json.decode(PlayerData.metadata)
            PlayerData.charinfo = json.decode(PlayerData.charinfo)
            return QBCore.Player.CheckPlayerData(nil, PlayerData)
        end
    end
    return nil
end

local function applyDefaults(playerData, defaults)
    for key, value in pairs(defaults) do
        if type(value) == 'function' then
            playerData[key] = playerData[key] or value()
        elseif type(value) == 'table' then
            playerData[key] = playerData[key] or {}
            applyDefaults(playerData[key], value)
        else
            playerData[key] = playerData[key] or value
        end
    end
end

function QBCore.Player.CheckPlayerData(source, PlayerData)
    PlayerData = PlayerData or {}
    local Offline = not source

    if source then
        PlayerData.source = source
        PlayerData.license = PlayerData.license or QBCore.Functions.GetIdentifier(source, 'license')
        PlayerData.name = GetPlayerName(source)
    end

    local validatedJob = false
    if PlayerData.job and PlayerData.job.name ~= nil and PlayerData.job.grade and PlayerData.job.grade.level ~= nil then
        local jobInfo = QBCore.Shared.Jobs[PlayerData.job.name]
        if jobInfo then
            local jobGradeInfo = jobInfo.grades[tostring(PlayerData.job.grade.level)]
            if jobGradeInfo then
                PlayerData.job.label = jobInfo.label
                PlayerData.job.grade.name = jobGradeInfo.name
                PlayerData.job.payment = jobGradeInfo.payment
                PlayerData.job.grade.isboss = jobGradeInfo.isboss or false
                PlayerData.job.isboss = jobGradeInfo.isboss or false
                validatedJob = true
            end
        end
    end

    if validatedJob == false then
        -- set to nil, as the default job (unemployed) will be added by `applyDefaults`
        PlayerData.job = nil
    end

    local validatedGang = false
    if PlayerData.gang and PlayerData.gang.name ~= nil and PlayerData.gang.grade and PlayerData.gang.grade.level ~= nil then
        local gangInfo = QBCore.Shared.Gangs[PlayerData.gang.name]
        if gangInfo then
            local gangGradeInfo = gangInfo.grades[tostring(PlayerData.gang.grade.level)]
            if gangGradeInfo then
                PlayerData.gang.label = gangInfo.label
                PlayerData.gang.grade.name = gangGradeInfo.name
                PlayerData.gang.payment = gangGradeInfo.payment
                PlayerData.gang.grade.isboss = gangGradeInfo.isboss or false
                PlayerData.gang.isboss = gangGradeInfo.isboss or false
                validatedGang = true
            end
        end
    end

    if validatedGang == false then
        -- set to nil, as the default gang (unemployed) will be added by `applyDefaults`
        PlayerData.gang = nil
    end

    applyDefaults(PlayerData, QBCore.Config.Player.PlayerDefaults)
    if PlayerData.job and QBCore.Shared.ForceJobDefaultDutyAtLogin then
        local jobInfo = QBCore.Shared.Jobs[PlayerData.job.name]
        if jobInfo then
            PlayerData.job.onduty = jobInfo.defaultDuty
        end
    end

    if GetResourceState('qb-inventory') ~= 'missing' then
        PlayerData.items = exports['qb-inventory']:LoadInventory(PlayerData.source, PlayerData.citizenid)
    end

    return QBCore.Player.CreatePlayer(PlayerData, Offline)
end

-- On player logout

function QBCore.Player.Logout(source)
    TriggerClientEvent('QBCore:Client:OnPlayerUnload', source)
    TriggerEvent('QBCore:Server:OnPlayerUnload', source)
    TriggerClientEvent('QBCore:Player:UpdatePlayerData', source)
    Wait(200)
    QBCore.Players[source] = nil
end

-- Create a new character
-- Don't touch any of this unless you know what you are doing
-- Will cause major issues!

function QBCore.Player.CreatePlayer(PlayerData, Offline)
    local player = QBPlayer.new(PlayerData, Offline)

    if Offline then
        return player
    end

    QBCore.Players[PlayerData.source] = player
    QBCore.Player.Save(PlayerData.source)
    TriggerEvent('QBCore:Server:PlayerLoaded', player)
    player:UpdatePlayerData()
end

-- Add a new function to the Functions table of the player class
-- Use-case:
--[[
    AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
        QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, "functionName", function(oneArg, orMore)
            -- do something here
        end)
    end)
]]

function QBCore.Functions.AddPlayerMethod(ids, methodName, handler)
    local idType = type(ids)
    if idType == 'number' then
        if ids == -1 then
            for _, v in pairs(QBCore.Players) do
                v:AddMethod(methodName, handler)
            end
        else
            if not QBCore.Players[ids] then return end
            QBCore.Players[ids]:AddMethod(methodName, handler)
        end
    elseif idType == 'table' and table.type(ids) == 'array' then
        for i = 1, #ids do
            QBCore.Functions.AddPlayerMethod(ids[i], methodName, handler)
        end
    end
end

-- Add a new field table of the player class
-- Use-case:
--[[
    AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
        QBCore.Functions.AddPlayerField(Player.PlayerData.source, "fieldName", "fieldData")
    end)
]]

function QBCore.Functions.AddPlayerField(ids, fieldName, data)
    local idType = type(ids)
    if idType == 'number' then
        if ids == -1 then
            for _, v in pairs(QBCore.Players) do
                v:AddField(fieldName, data)
            end
        else
            if not QBCore.Players[ids] then return end
            QBCore.Players[ids]:AddField(fieldName, data)
        end
    elseif idType == 'table' and table.type(ids) == 'array' then
        for i = 1, #ids do
            QBCore.Functions.AddPlayerField(ids[i], fieldName, data)
        end
    end
end

-- Save player info to database (make sure citizenid is the primary key in your database)

function QBCore.Player.Save(source)
    local ped = GetPlayerPed(source)
    local pcoords = GetEntityCoords(ped)
    local PlayerData = QBCore.Players[source].PlayerData
    if PlayerData then
        MySQL.insert('INSERT INTO players (citizenid, cid, license, name, money, charinfo, job, gang, position, metadata) VALUES (:citizenid, :cid, :license, :name, :money, :charinfo, :job, :gang, :position, :metadata) ON DUPLICATE KEY UPDATE cid = :cid, name = :name, money = :money, charinfo = :charinfo, job = :job, gang = :gang, position = :position, metadata = :metadata', {
            citizenid = PlayerData.citizenid,
            cid = tonumber(PlayerData.cid),
            license = PlayerData.license,
            name = PlayerData.name,
            money = json.encode(PlayerData.money),
            charinfo = json.encode(PlayerData.charinfo),
            job = json.encode(PlayerData.job),
            gang = json.encode(PlayerData.gang),
            position = json.encode(pcoords),
            metadata = json.encode(PlayerData.metadata)
        })
        if GetResourceState('qb-inventory') ~= 'missing' then exports['qb-inventory']:SaveInventory(source) end
        QBCore.ShowSuccess(resourceName, PlayerData.name .. ' PLAYER SAVED!')
    else
        QBCore.ShowError(resourceName, 'ERROR QBCORE.PLAYER.SAVE - PLAYERDATA IS EMPTY!')
    end
end

function QBCore.Player.SaveOffline(PlayerData)
    if PlayerData then
        MySQL.insert('INSERT INTO players (citizenid, cid, license, name, money, charinfo, job, gang, position, metadata) VALUES (:citizenid, :cid, :license, :name, :money, :charinfo, :job, :gang, :position, :metadata) ON DUPLICATE KEY UPDATE cid = :cid, name = :name, money = :money, charinfo = :charinfo, job = :job, gang = :gang, position = :position, metadata = :metadata', {
            citizenid = PlayerData.citizenid,
            cid = tonumber(PlayerData.cid),
            license = PlayerData.license,
            name = PlayerData.name,
            money = json.encode(PlayerData.money),
            charinfo = json.encode(PlayerData.charinfo),
            job = json.encode(PlayerData.job),
            gang = json.encode(PlayerData.gang),
            position = json.encode(PlayerData.position),
            metadata = json.encode(PlayerData.metadata)
        })
        if GetResourceState('qb-inventory') ~= 'missing' then exports['qb-inventory']:SaveInventory(PlayerData, true) end
        QBCore.ShowSuccess(resourceName, PlayerData.name .. ' OFFLINE PLAYER SAVED!')
    else
        QBCore.ShowError(resourceName, 'ERROR QBCORE.PLAYER.SAVEOFFLINE - PLAYERDATA IS EMPTY!')
    end
end

-- Delete character

local playertables = { -- Add tables as needed
    { table = 'players' },
    { table = 'apartments' },
    { table = 'bank_accounts' },
    { table = 'crypto_transactions' },
    { table = 'phone_invoices' },
    { table = 'phone_messages' },
    { table = 'playerskins' },
    { table = 'player_contacts' },
    { table = 'player_houses' },
    { table = 'player_mails' },
    { table = 'player_outfits' },
    { table = 'player_vehicles' }
}

function QBCore.Player.DeleteCharacter(source, citizenid)
    local license = QBCore.Functions.GetIdentifier(source, 'license')
    local result = MySQL.scalar.await('SELECT license FROM players where citizenid = ?', { citizenid })
    if license == result then
        local query = 'DELETE FROM %s WHERE citizenid = ?'
        local tableCount = #playertables
        local queries = table.create(tableCount, 0)
        for i = 1, tableCount do
            queries[i] = { query = query:format(playertables[i].table), values = { citizenid } }
        end
        MySQL.transaction(queries, function(result2)
            if result2 then
                TriggerEvent('qb-log:server:CreateLog', 'joinleave', 'Character Deleted', 'red', '**' .. GetPlayerName(source) .. '** ' .. license .. ' deleted **' .. citizenid .. '**..')
            end
        end)
    else
        DropPlayer(source, Lang:t('info.exploit_dropped'))
        TriggerEvent('qb-log:server:CreateLog', 'anticheat', 'Anti-Cheat', 'white', GetPlayerName(source) .. ' Has Been Dropped For Character Deletion Exploit', true)
    end
end

function QBCore.Player.ForceDeleteCharacter(citizenid)
    local result = MySQL.scalar.await('SELECT license FROM players where citizenid = ?', { citizenid })
    if result then
        local query = 'DELETE FROM %s WHERE citizenid = ?'
        local tableCount = #playertables
        local queries = table.create(tableCount, 0)
        local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
        if Player then
            DropPlayer(Player.PlayerData.source, 'An admin deleted the character which you are currently using')
        end
        for i = 1, tableCount do
            queries[i] = { query = query:format(playertables[i].table), values = { citizenid } }
        end
        MySQL.transaction(queries, function(result2)
            if result2 then
                TriggerEvent('qb-log:server:CreateLog', 'joinleave', 'Character Force Deleted', 'red', 'Character **' .. citizenid .. '** got deleted')
            end
        end)
    end
end

-- Inventory Backwards Compatibility

function QBCore.Player.SaveInventory(source)
    if GetResourceState('qb-inventory') == 'missing' then return end
    exports['qb-inventory']:SaveInventory(source, false)
end

function QBCore.Player.SaveOfflineInventory(PlayerData)
    if GetResourceState('qb-inventory') == 'missing' then return end
    exports['qb-inventory']:SaveInventory(PlayerData, true)
end

function QBCore.Player.GetTotalWeight(items)
    if GetResourceState('qb-inventory') == 'missing' then return end
    return exports['qb-inventory']:GetTotalWeight(items)
end

function QBCore.Player.GetSlotsByItem(items, itemName)
    if GetResourceState('qb-inventory') == 'missing' then return end
    return exports['qb-inventory']:GetSlotsByItem(items, itemName)
end

function QBCore.Player.GetFirstSlotByItem(items, itemName)
    if GetResourceState('qb-inventory') == 'missing' then return end
    return exports['qb-inventory']:GetFirstSlotByItem(items, itemName)
end

-- Util Functions

function QBCore.Player.CreateCitizenId()
    local CitizenId = tostring(QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(5)):upper()
    local result = MySQL.prepare.await('SELECT EXISTS(SELECT 1 FROM players WHERE citizenid = ?) AS uniqueCheck', { CitizenId })
    if result == 0 then return CitizenId end
    return QBCore.Player.CreateCitizenId()
end

function QBCore.Functions.CreateAccountNumber()
    local AccountNumber = 'US0' .. math.random(1, 9) .. 'QBCore' .. math.random(1111, 9999) .. math.random(1111, 9999) .. math.random(11, 99)
    local result = MySQL.prepare.await('SELECT EXISTS(SELECT 1 FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, "$.account")) = ?) AS uniqueCheck', { AccountNumber })
    if result == 0 then return AccountNumber end
    return QBCore.Functions.CreateAccountNumber()
end

function QBCore.Functions.CreatePhoneNumber()
    local PhoneNumber = math.random(100, 999) .. math.random(1000000, 9999999)
    local result = MySQL.prepare.await('SELECT EXISTS(SELECT 1 FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, "$.phone")) = ?) AS uniqueCheck', { PhoneNumber })
    if result == 0 then return PhoneNumber end
    return QBCore.Functions.CreatePhoneNumber()
end

function QBCore.Player.CreateFingerId()
    local FingerId = tostring(QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(1) .. QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(4))
    local result = MySQL.prepare.await('SELECT EXISTS(SELECT 1 FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(metadata, "$.fingerprint")) = ?) AS uniqueCheck', { FingerId })
    if result == 0 then return FingerId end
    return QBCore.Player.CreateFingerId()
end

function QBCore.Player.CreateWalletId()
    local WalletId = 'QB-' .. math.random(11111111, 99999999)
    local result = MySQL.prepare.await('SELECT EXISTS(SELECT 1 FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(metadata, "$.walletid")) = ?) AS uniqueCheck', { WalletId })
    if result == 0 then return WalletId end
    return QBCore.Player.CreateWalletId()
end

function QBCore.Player.CreateSerialNumber()
    local SerialNumber = math.random(11111111, 99999999)
    local result = MySQL.prepare.await('SELECT EXISTS(SELECT 1 FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(metadata, "$.phonedata.SerialNumber")) = ?) AS uniqueCheck', { SerialNumber })
    if result == 0 then return SerialNumber end
    return QBCore.Player.CreateSerialNumber()
end

PaycheckInterval() -- This starts the paycheck system
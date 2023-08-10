local QBCore = exports['qb-core']:GetCoreObject()

local PendingList = {}

local function SendFinalPurchase(args)
    if Config.WebhookLink ~= nil then
        if Config.WebhookLink ~= 'none' or false then
            local first,last,store,gun = args.fir, args.las, tonumber(args.stor), tonumber(args.gu)
            local date = os.date()
            local time = os.time()
            print('fd'..gun)
            print('a'..first)
            print('b'..last)
            print('c'..Config.WeaponsForPurchase[store][gun].ItemLabel)
            print('d'..Config.DealerLocations[store].BlipInformation.Label)
            print('e'..date)
            print('f'..time)
            local embed = {
                {
                    ["color"] = 23295,
                    ["title"] = "**ATF Form 4473 Logger**",
                    ["description"] = first..' '..last..' has purchased a(n) '..Config.WeaponsForPurchase[store][gun].ItemLabel..' at '..Config.DealerLocations[store].BlipInformation.Label..' on '..date,
                    ["footer"] = {
                        ["text"] = 'Thank you for using my script!',
                    },
                }
            }
        
            PerformHttpRequest(Config.WebhookLink, function(err, text, headers) end, 'POST', json.encode({username = tostring(first..' '..last), embeds = embed}), { ['Content-Type'] = 'application/json' })
        else
            print('Please put a proper webhook link or "none" or false into pn-4473\'s config!')
        end
    end
end
  

QBCore.Functions.CreateCallback('pn-4473:get:IsReady', function(source, value)
    local Player = QBCore.Functions.GetPlayer(source)
    local cid = Player.PlayerData.citizenid
    if PendingList[cid] then
        print(json.encode(PendingList))
        if PendingList[cid].status == 'pending' then
            local current = os.date('*t')
            local v1 = os.time(current)
            local v2 = os.time(json.decode(PendingList[cid].date))
            if os.difftime(v2, v1) <= 0 then
                value(true)
            else
                value(false)
            end
        else
            value(false)
        end
    else
        value(false)
    end
end)

QBCore.Functions.CreateCallback('pn-4473:get:PurchaseHistory', function(source, result, store)
    local passedValue = {}
    local SQL = MySQL.query.await('SELECT * FROM 4473_purchasehistory')
    if SQL then
        for i,v in pairs(SQL) do
            local storevalue = json.decode(v.main).store
            if tonumber(storevalue) == tonumber(store) then
                passedValue[#passedValue+1] = v
            end
        end
    end
    result(passedValue)
end)

QBCore.Functions.CreateCallback('pn-4473:get:CorrectStore', function(source, cb, args)
    local cid = QBCore.Functions.GetPlayer(source).PlayerData.citizenid
    local value = MySQL.scalar.await('SELECT store FROM 4473_queue WHERE cid = ?', { cid })
    cb(value)
end)

RegisterNetEvent('pn-4473:4473TimerForm', function(args)
    local Player = QBCore.Functions.GetPlayer(source)
    local citizenid = Player.PlayerData.citizenid
    if not MySQL.scalar.await('SELECT cid FROM 4473_queue where cid = ?', { citizenid }) then
        local unitcap = {
            month = 12,
            day = 31,
            hour = 23,
            min = 59,
            sec = 61,
            yday = 366,
        }
        local unitup = {
            month = 'year',
            day = 'month',
            hour = 'day',
            min = 'hour',
            sec = 'min',
            yday = 'year',

        }
        local cdate = os.date('*t')
        local enddate = cdate

        if cdate[Config.WaitTime.type] then
            if enddate[Config.WaitTime.type]+Config.WaitTime.time > unitcap[Config.WaitTime.type] then
            enddate[unitup[Config.WaitTime.type]] = enddate[unitup[Config.WaitTime.type]]+1
            end


            enddate[Config.WaitTime.type] = enddate[Config.WaitTime.type]+Config.WaitTime.time
        else
            return
        end
        local eval = json.encode(enddate)
        MySQL.insert.await(
            "INSERT INTO 4473_queue (cid, store, weaponname, date, status) VALUES(:cid, :store, :weaponname, :date, :status)", {
                ['cid'] = citizenid,
                ['store'] = args.vars.index,
                ['weaponname'] = args.vars.id,
                ['date'] = eval,
                ['status'] = 'waiting'
            }
        )
    else
        TriggerClientEvent('QBCore:Notify', Player.PlayerData.cid, 'You already have a request to fill out a form. Please Wait.', 'primary', 4000)
    end
end)

QBCore.Functions.CreateCallback('pn-4473:get:PlayerData', function(source, PlayerData)
    local Player = QBCore.Functions.GetPlayer(source)
    PlayerData(Player.PlayerData)
end)

RegisterNetEvent('pn-4473:SuccessfulForm', function()
    local Player = QBCore.Functions.GetPlayer(source)
    local cid = Player.PlayerData.citizenid
    local data = MySQL.single.await('SELECT * FROM 4473_queue WHERE cid = ?', { cid })
    local pid = nil
    if Player.Functions.RemoveMoney(Config.DealerLocations[tonumber(data.store)].MoneyType, Config.WeaponsForPurchase[tonumber(data.store)][tonumber(data.weaponname)].Price, 'Purchased a '..Config.WeaponsForPurchase[tonumber(data.store)][tonumber(data.weaponname)].ItemLabel..' at '..Config.DealerLocations[tonumber(data.store)].BlipInformation.Label) and Player.Functions.AddItem(Config.WeaponsForPurchase[tonumber(data.store)][tonumber(data.weaponname)].ItemName, 1) then

        repeat
            print(data.store)
            pid = tostring(Config.DealerLocations[tonumber(data.store)].InformationalPrefix)..math.random(1000, 9999)
            print(pid)
            local pid2 = MySQL.scalar.await('SELECT purchaseid FROM 4473_purchasehistory WHERE purchaseid = ?', {pid})
        until pid ~= pid2
        local datatable = {['weaponname'] = data.weaponname, ['firstname'] = Player.PlayerData.charinfo.firstname, ['lastname'] = Player.PlayerData.charinfo.lastname}
        local primarytable = {['date'] = os.date(), ['cid'] = cid, ['store'] = data.store}
        MySQL.insert.await(
            "INSERT INTO 4473_purchasehistory (purchaseid, main, data) VALUES(:purchaseid, :main, :data)", {
                ['purchaseid'] = tostring(pid),
                ['main'] = json.encode(primarytable),
                ['data'] = json.encode(datatable),
            }
        )
        local itemname = Config.WeaponsForPurchase[tonumber(data.store)][tonumber(data.weaponname)].ItemName
        TriggerClientEvent('inventory:client:ItemBox', Player.PlayerData.cid, QBCore.Shared.Items[itemname], 'add')
        local args = {
            fir = Player.PlayerData.charinfo.firstname,
            las = Player.PlayerData.charinfo.lastname,
            stor = data.store,
            gu = data.weaponname,
        }
        if Config.WebhookLink ~= nil then
            SendFinalPurchase(args)
        end

        MySQL.single.await('DELETE FROM 4473_queue WHERE cid = ?', { cid })
        for i,v in pairs(PendingList) do
            print(json.encode(v))
            if string.lower(i) == string.lower(cid) then
                PendingList[i] = nil
                break
            end
            Wait(1)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        local current = os.date('*t')
        local SQL = MySQL.query.await('SELECT * FROM 4473_queue')
        for i, v in pairs(SQL) do
            if v.status == 'waiting' then
                if v.date then
                    local v1 = os.time(current)
                    local v2 = os.time(json.decode(v.date))
                    if os.difftime(v2, v1) <= 0 then
                        local Player = QBCore.Functions.GetPlayerByCitizenId(v.cid)
                        MySQL.update.await('UPDATE 4473_queue SET status = ? WHERE cid = ?', { 'pending', v.cid })
                        if QBCore.Players[Player.PlayerData.cid] then
                            local MailData = {
                                sender = Config.DealerLocations[tonumber(v.store)].BlipInformation.Label,
                                subject = 'Your form is ready!',
                                message = "Your 4473 form is ready for you! The weapon it's for is the " ..Config.WeaponsForPurchase[tonumber(v.store)][tonumber(v.weaponname)].ItemLabel
                            }
                            exports['qb-phone']:sendNewMailToOffline(v.cid, MailData)
                        end
                    end
                end
            elseif v.status == 'pending' then
                local Player = QBCore.Functions.GetPlayerByCitizenId(v.cid)
                if Player ~= nil and PendingList[v.cid] == nil then
                    TriggerClientEvent('pn-4473:ReadyToDestination', Player.PlayerData.cid, v.store)
                end
                PendingList[v.cid] = v
            end
            Wait(1)
        end

        Wait(1000)
    end
end)
QBCore.Functions.CreateCallback('pn-4473:get:ErrorCount', function(source, result)
    local Player = QBCore.Functions.GetPlayer(source)
    local initValue = MySQL.scalar.await('SELECT errors FROM 4473_errorcount WHERE cid = ?', { Player.PlayerData.citizenid })
    if initValue ~= nil then
        local newValue = initValue+1
        if newValue > Config.MaximumFailures then
            MySQL.single.await('DELETE FROM 4473_errorcount WHERE cid = ?', { Player.PlayerData.citizenid })
        else
            MySQL.update.await('UPDATE 4473_errorcount SET errors = ? WHERE cid = ?', {newValue, Player.PlayerData.citizenid})
        end
    else
        MySQL.Async.fetchAll('INSERT INTO 4473_errorcount (cid, errors) VALUES(:cid, :errors)', {
            ['cid'] = Player.PlayerData.citizenid,
            ['errors'] = 1,
        })
    end
end)

QBCore.Functions.CreateCallback('pn-4473:server:CheckID', function(source, cb, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if Config.DealerLocations[args.index].CheckLicenses == true then
        local LicensesCarried = {}
        for i,d in pairs(Config.DealerLocations[args.index].LicensesToCheck) do
            for k,v in pairs(Player.PlayerData.items) do
                if string.lower(v.name) == string.lower(d) then
                    -- This will fire if the user does have an id.
                    LicensesCarried[#LicensesCarried+1] = {
                        item = d,
                        slot = v.slot,
                        info = v.info,
                    }
                else
                    -- This will fire if the user doesn't have an id.
                    -- As for now, nothing to fire.
                end
            end
        end
        if LicensesCarried == {} or #LicensesCarried < #Config.DealerLocations[args.index].LicensesToCheck then
            cb(false)
        else
            cb(LicensesCarried)
        end
    end
end)
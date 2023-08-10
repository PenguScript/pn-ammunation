local QBCore = exports['qb-core']:GetCoreObject()
while not Config do
    Wait(1)
end

Citizen.CreateThread(function()
    for i,v in pairs(Config.DealerLocations) do
        RequestModel(v.Model)
        while not HasModelLoaded(v.Model) do
            RequestModel(v.Model)
            Wait(1)
        end
        local DealerPed = CreatePed(0, v.Model, v.Location.x, v.Location.y, v.Location.z, v.Location.w, true)
        if DealerPed ~= 0 or nil then

            local DealerPedBlip = AddBlipForCoord(v.Location.x, v.Location.y, v.Location.z)
            SetBlipSprite (DealerPedBlip, v.BlipInformation.Sprite)
            SetBlipDisplay(DealerPedBlip, v.BlipInformation.Display)
            SetBlipScale  (DealerPedBlip, v.BlipInformation.Scale)
            SetBlipAsShortRange(DealerPedBlip, v.BlipInformation.ShortRange)
            SetBlipColour(DealerPedBlip, v.BlipInformation.Color)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(v.BlipInformation.Label)
            EndTextCommandSetBlipName(DealerPedBlip)
        
            SetEntityInvincible(DealerPed, true)
            SetBlockingOfNonTemporaryEvents(DealerPed, true)
            Citizen.Wait(1350)
            TaskStartScenarioInPlace(DealerPed, "CODE_HUMAN_CROSS_ROAD_WAIT", 0, true)
            FreezeEntityPosition(DealerPed, true)
            exports['qb-target']:AddTargetEntity(DealerPed, {
                options = {
                    {
                        type = "Client",
                        event = "pn-4473:PreMenu",
                        args = {
                            id = i
                        },
                        icon = Config.DealerTargetIcon,
                        label = v.Name,
                    }
                },
                distance = 2.5,
            })
        end
    end
end)

RegisterNetEvent('pn-4473:PreMenu', function(data)
    QBCore.Functions.TriggerCallback('pn-4473:get:IsReady', function(value)
        QBCore.Functions.TriggerCallback('pn-4473:get:PlayerData', function(PlayerData)
            local isPolice = false
            if Config.PoliceJobs then
                if Config.PoliceMustBeOnDuty == true then
                    if PlayerData.job.onduty == true then
                        for i,v in pairs(Config.PoliceJobs) do
                            if string.lower(v) == string.lower(PlayerData.job.name) then
                                isPolice = true
                                break
                            end
                        end
                    end
                else
                    for i,v in pairs(Config.PoliceJobs) do
                        if string.lower(v) == string.lower(PlayerData.job.name) then
                            isPolice = true
                            break
                        end
                    end
                end
            end
            local dealerinfo = Config.DealerLocations[data.args.id]
            local menu = {}
            menu[#menu+1] = {
                header = "| "..dealerinfo.BlipInformation.Label.." |",
                isMenuHeader = true
            }
            menu[#menu+1] = {
                header = "Check "..dealerinfo.BlipInformation.Label.."'s Inventory",
                params = {
                    event = "pn-4473:ShopMenu",
                    args = data,
                }
            }
            if value == true then
                menu[#menu+1] = {
                    header = "Fill out Form",
                    params = {
                        event = "pn-4473:FillOut4473",
                        args = data,
                    }
                }
            end
            if isPolice == true then
                menu[#menu+1] = {
                    header = "View Purchase History",
                    params = {
                        event = "pn-4473:ViewHistory",
                        args = data,
                    }
                }
            end
            exports['qb-menu']:openMenu(menu)            
        end)
    end)
end)

RegisterNetEvent('pn-4473:ViewHistory', function(data)
    QBCore.Functions.TriggerCallback('pn-4473:get:PurchaseHistory', function(result)
        local menu = {}
        menu[#menu+1] = {
            header = "| Purchase History |",
            isMenuHeader = true
        }
        for i,v in pairs(result) do
            local decoded = json.decode(v.data)
            menu[#menu+1] = {
                header = decoded.lastname..', '..decoded.firstname.. ' | '..Config.WeaponsForPurchase[tonumber(data.args.id)][tonumber(decoded.weaponname)].ItemLabel,
                disabled = true
            }
        end
        exports['qb-menu']:openMenu(menu)            
    end, data.args.id)
end)

RegisterNetEvent('pn-4473:ShopMenu', function(data)
    local dealerinfo = Config.DealerLocations[data.args.id]
    local menu = {}

    menu[#menu+1] = {
        header = "| "..dealerinfo.BlipInformation.Label.." |",
        isMenuHeader = true
    }
    for k,v in pairs(Config.WeaponsForPurchase[data.args.id]) do
        local v1 = ""
        local v3 = GetLocalTime()
        if Config.ShowPrice == true then v1 = ' | '..Config.CurrencyUnit..v.Price end
        menu[#menu+1] = {
            header = v.ItemLabel..v1,
            params = {
                event = "pn-4473:Start4473Form",
                args = {
                    id = k,
                    index = data.args.id,
                    time = v3
                }    
            }
        }
    end
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('pn-4473:FormReadyToTake', function(data)
    local MailData = {
        sender = Config.DealerLocations[tonumber(data[1])].BlipInformation.Label,
        subject = 'Your form is ready!',
        message = "Your 4473 form is ready for you! The weapon it's for is the "..Config.WeaponsForPurchase[tonumber(data[1])][tonumber(data[2])].ItemLabel
    }
    TriggerServerEvent('qb-phone:server:sendNewMail', MailData)
end)

RegisterNetEvent('pn-4473:ReadyToDestination', function(store)
    QBCore.Functions.Notify('Your 4473 form is ready! Please head to the destination on your map!', 'primary')
    local coords = Config.DealerLocations[tonumber(store)].Location
    SetNewWaypoint(coords.x, coords.y)
end)

RegisterNetEvent('pn-4473:FillOut4473', function(args)
    QBCore.Functions.TriggerCallback('pn-4473:get:CorrectStore', function(value)
        if args.args.id == tonumber(value) then
            local FormTest = exports['qb-input']:ShowInput(Config.FormFormat)
            if FormTest ~= nil then
                QBCore.Functions.TriggerCallback('pn-4473:get:PlayerData', function(PlayerData)
                    local currentErrors, maximumErrors = 0, Config.MaximumErrors
                    for i,v in pairs(Config.MustBeYes) do
                        if not tostring(FormTest[v]) == 'yes' then
                            currentErrors = currentErrors + 1
                        end
                    end
                    for k,d in pairs(Config.MustBeNo) do
                        if not tostring(FormTest[d]) == 'no' then
                            currentErrors = currentErrors + 1
                        end
                    end
                        if string.lower(PlayerData.charinfo.firstname..' '..PlayerData.charinfo.lastname) ~= string.lower(FormTest.fullname) then
                            currentErrors = currentErrors + 1
                        end
                        local correctCity = false
                        for i,v in pairs(Config.CityNames) do
                            if string.lower(v) == string.lower(FormTest.addresscity) then
                                correctCity = true
                            end
                        end
                        if correctCity ~= true then
                            QBCore.Functions.Notify("That city doesn't exist.", 'error', 4000)
                            currentErrors = currentErrors + 1
                        end
                    print(currentErrors..' | '..maximumErrors)
                    if currentErrors > maximumErrors then
                        if Config.MaximumFailures ~= 0 then
                            QBCore.Functions.TriggerCallback('pn-4473:get:ErrorCount', function(result)
                                QBCore.Functions.Notify("You've made a critical mistake on your 4473 form.", 'error')
                            end)
                        else
                            QBCore.Functions.Notify("You've failed your 4473 Form. Try again at a later date", 'error')
                        end
                    else
                        QBCore.Functions.Notify("We have accepted your 4473 Form.", 'success')
                        TriggerServerEvent('pn-4473:SuccessfulForm')
                    end
                end)
            end
        else
            QBCore.Functions.Notify("You're at the wrong place! Check your map.", 'primary', 6000)
            local location = Config.DealerLocations[tonumber(value)].Location
            SetNewWaypoint(location.x, location.y)
        end
    end)
end)

RegisterNetEvent('pn-4473:Start4473Form', function(args)
    QBCore.Functions.TriggerCallback('pn-4473:server:CheckID', function(cb)
        if cb ~= nil or {} then
            local menu, info, cvar = {}, {}, ""
            if Config.WaitEnabled == true then
                cvar = 'Timer'
            end
            menu[#menu+1] = {
                header = Config.DealerLocations[args.index].Name..": Who are you?",
                isMenuHeader = true
            }
            for k,v in pairs(cb) do
                if not info[v.info.firstname..v.info.lastname] then
                    info[v.info.firstname..v.info.lastname] = {
                        types = {v.item},
                        name = {first = v.info.firstname, last = v.info.lastname},
                        birthdate = v.info.birthdate,
                    }
                else
                    if v.info.firstname == info[v.info.firstname..v.info.lastname].name.first and v.info.lastname == info[v.info.firstname..v.info.lastname].name.last and v.info.birthdate == info[v.info.firstname..v.info.lastname].birthdate then
                        menu[#menu+1] = {
                            header = info[v.info.firstname..v.info.lastname].name.first..' '..info[v.info.firstname..v.info.lastname].name.last,
                            txt = "This response will be documented",
                            params = {
                                isServer = true,
                                event = 'pn-4473:4473TimerForm',
                                args = {vars = args, info = info[v.info.firstname..v.info.lastname]}
                            }
                        }
                    end
                end
            end
            if #menu == 1 then
                menu[#menu+1] = {
                    header = "Please go to Cityhall to collect your licenses",
                    disabled = true
                }
            end
            exports['qb-menu']:openMenu(menu)
        else
            QBCore.Functions.Notify("Wait, what did you say?", 'error')
        end
    end, args)
end)

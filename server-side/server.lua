local Proxy = Proxy or {}
Tunnel = Tunnel or {}

Proxy = module("vrp", "lib/Proxy")
Tunnel = module("vrp", "lib/Tunnel")

vRP = Proxy.getInterface("vRP")
vRPclient = Tunnel.getInterface("vRP", "helicopterFunctions") -- USEI VRP COMO BASE PARA CHECAGEM DE PERMISSÕES, TROQUE PELA BASE DE CHECAGEM DE PERMISSÃO NA SUA BASE

RegisterNetEvent("checkPlayerPermission")
AddEventHandler("checkPlayerPermission", function()
    local src = source
    local user_id = vRP.getUserId(src)
    local hasPermission = false

    if user_id then
        if vRP.hasPermission(user_id, "Police") or vRP.hasPermission(user_id, "Paramedic") then -- coloquei Police e Paramedic mas e somente trocar.
            hasPermission = true
        else
            hasPermission = false
        end
    end

    -- Envia a resposta para o cliente
    TriggerClientEvent('onPlayerPermissionChecked', src, hasPermission)
end)

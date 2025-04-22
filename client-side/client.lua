-----------------------------------------------------------------------------------------------------------------------------------------
-- VEHCAMERA
-----------------------------------------------------------------------------------------------------------------------------------------
local fov_max = 80.0
local fov_min = 10.0
local speed_lr = 20.0
local speed_ud = 20.0
local zoomspeed = 20.0
local vehCamera = false
local visionMode = 0
local fov = (fov_max + fov_min) * 0.5

-- Hash de helis permitidos
local allowedHelicopters = {
    [GetHashKey("as350")] = true,
    [GetHashKey("polmav")] = true
}

local hasPermission = false

-----------------------------------------------------------------------------------------------------------------------------------------
-- VERIFICA PERMISSÃO AO ENTRAR NO HELICÓPTERO
-----------------------------------------------------------------------------------------------------------------------------------------
Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped)
        
        if veh ~= 0 and IsPedInAnyHeli(ped) then
            local vehModel = GetEntityModel(veh)
            if allowedHelicopters[vehModel] then
                TriggerServerEvent('checkPlayerPermission')
            end
        end

        Citizen.Wait(20)
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- RETORNA A PERMISSÃO DO SERVIDOR
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent('onPlayerPermissionChecked')
AddEventHandler('onPlayerPermissionChecked', function(permission)
    hasPermission = permission
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREAD PRINCIPAL
-----------------------------------------------------------------------------------------------------------------------------------------
Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped)

        if veh ~= 0 and IsPedInAnyHeli(ped) and allowedHelicopters[GetEntityModel(veh)] and hasPermission then
            
            -- Ativa a câmera com a tecla 'E'
            if IsControlJustPressed(1, 51) and GetPedInVehicleSeat(veh, 0) == ped then
                TriggerEvent("hudActived", false)
                TriggerEvent("Notify", "azul", "Câmera Ativada", 5000) -- Notify do seu server (Troque caso necessário)
                vehCamera = true
            end

            -- Iniciar Rapel com a tecla 'X'
            if IsControlJustPressed(1, 73) and (GetPedInVehicleSeat(veh, 1) == ped or GetPedInVehicleSeat(veh, 2) == ped) then
                PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
                TriggerEvent("Notify", "azul", "Rapel Iniciado", 5000) -- Notify do seu server (Troque caso necessário)
                TaskRappelFromHeli(ped, 1)  
            end

            -- Ativar função Camera
            if vehCamera then
                handleHeliCamera(veh)
            end
        end
        
        Citizen.Wait(20)
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- FUNÇÃO DA CÂMERA
-----------------------------------------------------------------------------------------------------------------------------------------
function handleHeliCamera(veh)
    local scaleform = RequestScaleformMovie("HELI_CAM")
    while not HasScaleformMovieLoaded(scaleform) do
        Citizen.Wait(1)
    end

    local cam = CreateCam("DEFAULT_SCRIPTED_FLY_CAMERA", true)
    AttachCamToEntity(cam, veh, -0.8, 2.2, -1.5, true) -- Posição ajustada somente para o As350 (ajuste dependendo da aeronave)
    SetCamRot(cam, 0.0, 0.0, GetEntityHeading(veh))
    SetCamFov(cam, fov)
    RenderScriptCams(true, false, 0, 1, 0)
    
    PushScaleformMovieFunction(scaleform, "SET_CAM_LOGO")
    PushScaleformMovieFunctionParameterInt(0)
    PopScaleformMovieFunctionVoid()
    SetVehicleRadioEnabled(veh,false)
    -- Filtro Padrão Cinza
    SetTimecycleModifierStrength(0.7)
    SetTimecycleModifier("heliGunCam")

    while vehCamera do
        -- desativar(caso de DV etc)
        if not IsPedInAnyVehicle(PlayerPedId()) then
            disableHeliCamera(scaleform, cam)
        end
        
        -- Caso ele mude de lugar pelo /seat e a camera continue ativa
        if GetPedInVehicleSeat(veh, 0) == 0 then
            disableHeliCamera(scaleform, cam)
        end

        -- Alternar visão normal/noturna /térmica
        if IsControlJustPressed(1, 25) then
            visionMode = (visionMode + 1) % 3
            if visionMode == 0 then
                SetSeethrough(false)
                SetNightvision(false)
            elseif visionMode == 1 then
                SetNightvision(true)
            elseif visionMode == 2 then
                SetSeethrough(true)
            end
        end

        -- Desativar câmera com a tecla 'E'
        if IsControlJustPressed(1, 51) then
            TriggerEvent("Notify", "azul", "Câmera Desativada", 5000) -- Notify do seu server (Troque caso necessário)
            disableHeliCamera(scaleform, cam)
        end

        local zoomvalue = (1.0 / (fov_max - fov_min)) * (fov - fov_min)
        CheckInputRotation(cam, zoomvalue)
        HandleZoom(cam)
        HideHudAndRadarThisFrame(19)
        PushScaleformMovieFunction(scaleform, "SET_ALT_FOV_HEADING")
        PushScaleformMovieFunctionParameterFloat(GetEntityCoords(veh).z)
        PushScaleformMovieFunctionParameterFloat(zoomvalue)
        PushScaleformMovieFunctionParameterFloat(GetCamRot(cam, 2).z)
        PopScaleformMovieFunctionVoid()
        DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)

        Citizen.Wait(4) -- Loop ultra leve durante a câmera
    end

    disableHeliCamera(scaleform, cam)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- FUNÇÃO PARA DESATIVAR A CÂMERA
-----------------------------------------------------------------------------------------------------------------------------------------
function disableHeliCamera(scaleform, cam)
    vehCamera = false
    ClearTimecycleModifier()
    RenderScriptCams(false, false, 0, 1, 0)
    SetScaleformMovieAsNoLongerNeeded(scaleform)
    DestroyCam(cam, false)
    SetNightvision(false)
    SetSeethrough(false)
    TriggerEvent("hudActived", true)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHECKINPUTROTATION
-----------------------------------------------------------------------------------------------------------------------------------------
function CheckInputRotation(cam, zoomvalue)
    local rightAxisX = GetDisabledControlNormal(0, 220)  -- Eixo X (horizontal)
    local rightAxisY = GetDisabledControlNormal(0, 221)  -- Eixo Y (vertical)
    local rotation = GetCamRot(cam, 2)

    if rightAxisX ~= 0.0 or rightAxisY ~= 0.0 then
        local new_z = rotation.z + rightAxisX * -1.0 * (speed_lr) * (zoomvalue + 0.1)
        local new_x = math.max(math.min(20.0, rotation.x + rightAxisY * -1.0 * (speed_ud) * (zoomvalue + 0.1)), -89.5)

        SetCamRot(cam, new_x, 0.0, new_z, 2)
    end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- HANDLEZOOM
-----------------------------------------------------------------------------------------------------------------------------------------
function HandleZoom(cam)
    if IsControlJustPressed(1, 241) then
        fov = math.max(fov - zoomspeed, fov_min)
    end

    if IsControlJustPressed(1, 242) then
        fov = math.min(fov + zoomspeed, fov_max)
    end
    SetCamFov(cam, fov)
end

FrameworkBridges = FrameworkBridges or {}
FrameworkBridges.qbcore = { name = 'qbcore' }

local Bridge = FrameworkBridges.qbcore
local QBCore

function Bridge.detect()
    return GetResourceState('qb-core') == 'started'
end

function Bridge.init()
    QBCore = exports['qb-core']:GetCoreObject()
    return QBCore ~= nil
end

function Bridge.player(source)
    if not QBCore then Bridge.init() end
    return QBCore and QBCore.Functions.GetPlayer(source)
end

function Bridge.identifier(source)
    local player = Bridge.player(source)
    return player and player.PlayerData and player.PlayerData.citizenid
end

function Bridge.activeJob(source)
    local player = Bridge.player(source)
    local job = player and player.PlayerData and player.PlayerData.job
    if not job then return nil end

    return {
        name = job.name,
        label = job.label,
        grade = tonumber(job.grade and job.grade.level) or 0,
        rank = job.grade and job.grade.name,
        salary = tonumber(job.payment or job.grade and job.grade.payment) or 0,
        onDuty = job.onduty == true
    }
end

function Bridge.jobInfo(jobName, grade)
    if not QBCore then Bridge.init() end

    local job = QBCore and QBCore.Shared and QBCore.Shared.Jobs and QBCore.Shared.Jobs[jobName]
    if not job then return nil end

    grade = tonumber(grade) or 0
    local gradeData = job.grades and (job.grades[grade] or job.grades[tostring(grade)]) or nil
    if not gradeData then return nil end

    return {
        label = job.label or jobName,
        rank = gradeData and gradeData.name or tostring(grade),
        salary = tonumber(gradeData and gradeData.payment) or 0
    }
end

function Bridge.setActiveJob(source, jobName, grade, duty)
    local player = Bridge.player(source)
    if not player then return false, 'Player not found.' end

    local ok = player.Functions.SetJob(jobName, tonumber(grade) or 0)
    if ok == false then return false, 'Unable to switch jobs.' end

    if duty ~= nil then
        player.Functions.SetJobDuty(duty)
    end

    return true
end

function Bridge.setDuty(source, duty)
    local player = Bridge.player(source)
    if not player then return false end

    player.Functions.SetJobDuty(duty)
    return true
end

function Bridge.notify(source, message, notifyType)
    TriggerClientEvent('QBCore:Notify', source, message, notifyType or 'primary')
end

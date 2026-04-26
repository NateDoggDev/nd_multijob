FrameworkBridges = FrameworkBridges or {}
FrameworkBridges.esx = { name = 'esx' }

local Bridge = FrameworkBridges.esx
local ESX

local function loadObject()
    if ESX then return ESX end

    local ok, object = pcall(function()
        return exports.es_extended:getSharedObject()
    end)

    if ok and object then
        ESX = object
        return ESX
    end

    TriggerEvent('esx:getSharedObject', function(object)
        ESX = object
    end)

    return ESX
end

function Bridge.detect()
    return GetResourceState('es_extended') == 'started'
end

function Bridge.init()
    return loadObject() ~= nil
end

function Bridge.player(source)
    local object = loadObject()
    return object and object.GetPlayerFromId(source)
end

function Bridge.identifier(source)
    local player = Bridge.player(source)
    if not player then return nil end
    return player.getIdentifier and player.getIdentifier() or player.identifier
end

function Bridge.activeJob(source)
    local player = Bridge.player(source)
    if not player then return nil end

    local job = player.getJob and player.getJob() or player.job
    if not job then return nil end

    return {
        name = job.name,
        label = job.label,
        grade = tonumber(job.grade) or 0,
        rank = job.grade_label or job.grade_name,
        salary = tonumber(job.grade_salary) or 0,
        onDuty = job.onDuty == true
    }
end

function Bridge.jobInfo(jobName, grade)
    local object = loadObject()
    if not object then return nil end

    grade = tonumber(grade) or 0

    if object.DoesJobExist and not object.DoesJobExist(jobName, grade) then
        return nil
    end

    local jobs = object.GetJobs and object.GetJobs() or object.Jobs
    local job = jobs and jobs[jobName]
    if not job then return nil end

    local gradeData = job and job.grades and (job.grades[grade] or job.grades[tostring(grade)]) or nil
    if job.grades and not gradeData then return nil end

    return {
        label = job.label or jobName,
        rank = gradeData and (gradeData.label or gradeData.name) or tostring(grade),
        salary = tonumber(gradeData and (gradeData.salary or gradeData.payment)) or 0
    }
end

function Bridge.setActiveJob(source, jobName, grade, duty)
    local player = Bridge.player(source)
    if not player then return false, 'Player not found.' end

    grade = tonumber(grade) or 0

    if duty == nil then
        player.setJob(jobName, grade)
    else
        player.setJob(jobName, grade, duty)
    end

    return true
end

function Bridge.setDuty(source, duty)
    local active = Bridge.activeJob(source)
    if not active then return false end

    return Bridge.setActiveJob(source, active.name, active.grade, duty)
end

function Bridge.notify(source, message, notifyType)
    local player = Bridge.player(source)
    if player and player.showNotification then
        player.showNotification(message, notifyType or 'info')
        return
    end

    TriggerClientEvent('esx:showNotification', source, message)
end

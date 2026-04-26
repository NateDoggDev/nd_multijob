FrameworkBridges = FrameworkBridges or {}
FrameworkBridges.qbox = { name = 'qbox' }

local Bridge = FrameworkBridges.qbox

function Bridge.detect()
    return GetResourceState('qbx_core') == 'started'
end

function Bridge.player(source)
    return exports.qbx_core:GetPlayer(source)
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
        salary = tonumber(job.payment) or 0,
        onDuty = job.onduty == true
    }
end

function Bridge.ownedJobs(source)
    local player = Bridge.player(source)
    local data = player and player.PlayerData
    if not data then return {} end

    local jobs = {}
    for name, grade in pairs(data.jobs or {}) do
        jobs[name] = tonumber(grade) or 0
    end

    local active = data.job
    if active and active.name and active.name ~= Config.UnemployedJob then
        jobs[active.name] = tonumber(active.grade and active.grade.level) or 0
    end

    return jobs
end

function Bridge.jobInfo(jobName, grade)
    local job = exports.qbx_core:GetJob(jobName)
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
    if jobName == Config.UnemployedJob then
        local ok = exports.qbx_core:SetJob(source, Config.UnemployedJob, Config.UnemployedGrade)
        if duty ~= nil then exports.qbx_core:SetJobDuty(source, duty) end
        return ok ~= false
    end

    local identifier = Bridge.identifier(source)
    if not identifier then return false, 'Player not found.' end

    local owned = Bridge.ownedJobs(source)
    if not owned[jobName] then return false, 'You do not have that job.' end

    local ok = exports.qbx_core:SetPlayerPrimaryJob(identifier, jobName)
    if ok == false then return false, 'Unable to switch jobs.' end

    if duty ~= nil then
        exports.qbx_core:SetJobDuty(source, duty)
    end

    return true
end

function Bridge.setDuty(source, duty)
    return exports.qbx_core:SetJobDuty(source, duty) ~= false
end

function Bridge.addJob(identifier, jobName, grade)
    local ok, err = exports.qbx_core:AddPlayerToJob(identifier, jobName, tonumber(grade) or 0)
    if ok == false then
        return false, type(err) == 'table' and err.code or err
    end

    return true
end

function Bridge.removeJob(identifier, jobName)
    local ok, err = exports.qbx_core:RemovePlayerFromJob(identifier, jobName)
    if ok == false then
        return false, type(err) == 'table' and err.code or err
    end

    return true
end

function Bridge.setGrade(identifier, jobName, grade)
    return Bridge.addJob(identifier, jobName, grade)
end

function Bridge.notify(source, message, notifyType)
    exports.qbx_core:Notify(source, message, notifyType or 'inform')
end

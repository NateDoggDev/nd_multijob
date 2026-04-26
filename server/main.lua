local Bridge
local pendingRefresh = {}
local lastActiveJob = {}
local recentlyFired = {}

local function notify(source, message, notifyType)
    if not Config.Notify or not Bridge or not Bridge.notify then return end
    Bridge.notify(source, message, notifyType)
end

local function cleanName(value)
    if type(value) ~= 'string' then return nil end
    local trimmed = value:match('^%s*(.-)%s*$'):lower()
    return trimmed ~= '' and trimmed or nil
end

local function jobShort(name, label)
    local text = label or name or ''
    local words = {}

    for word in text:gmatch('%w+') do
        words[#words + 1] = word
    end

    if #words > 1 then
        local short = ''
        for i = 1, math.min(#words, 4) do
            short = short .. words[i]:sub(1, 1):upper()
        end
        return short
    end

    return text:sub(1, 4):upper()
end

local function jobIcon(name)
    return Config.JobIcons and Config.JobIcons[tostring(name or ''):lower()] or 'briefcase'
end

local function getBridge()
    if Bridge then return Bridge end

    local wanted = Config.Framework ~= 'auto' and Config.Framework or nil
    local order = wanted and { wanted } or { 'qbox', 'qbcore', 'esx' }

    for i = 1, #order do
        local bridge = FrameworkBridges[order[i]]
        if bridge and bridge.detect and bridge.detect() then
            if not bridge.init or bridge.init() then
                Bridge = bridge
                return Bridge
            end
        end
    end

    return nil
end

local function waitForBridge()
    for _ = 1, 30 do
        if getBridge() then
            print(('[nd_multijob] Using %s bridge'):format(Bridge.name))
            if Bridge.name ~= 'qbox' then
                Storage.Init()
            elseif GetConvarInt('qbx:max_jobs_per_player', 1) < Config.MaxJobs then
                print(('[nd_multijob] Qbox max jobs is lower than Config.MaxJobs. Set "setr qbx:max_jobs_per_player %s" before qbx_core if you want that limit.'):format(Config.MaxJobs))
            end
            return true
        end

        Wait(500)
    end

    print('[nd_multijob] No supported framework found')
    return false
end

local function resolveTarget(target)
    if type(target) == 'number' then
        return target, Bridge.identifier(target)
    end

    if type(target) ~= 'string' then return nil, nil end

    for _, playerId in ipairs(GetPlayers()) do
        local source = tonumber(playerId)
        if Bridge.identifier(source) == target then
            return source, target
        end
    end

    return nil, target
end

local function readOwnedJobs(source)
    if not Bridge then return {} end

    if Bridge.name == 'qbox' then
        return Bridge.ownedJobs(source)
    end

    local identifier = Bridge.identifier(source)
    if not identifier then return {} end

    local rows = Storage.Read(identifier)
    local jobs = {}
    for i = 1, #rows do
        jobs[rows[i].job_name] = tonumber(rows[i].grade) or 0
    end
    return jobs
end

local function chooseNextJob(jobs, excluded)
    local names = {}

    for jobName in pairs(jobs or {}) do
        if jobName ~= excluded and jobName ~= Config.UnemployedJob then
            names[#names + 1] = jobName
        end
    end

    table.sort(names)

    local nextJob = names[1]
    if not nextJob then return nil, nil end

    return nextJob, jobs[nextJob]
end

local function formatJob(source, jobName, grade, active)
    local info = Bridge.jobInfo(jobName, grade)

    if not info and active and active.name == jobName then
        info = active
    end

    if not info and jobName ~= Config.UnemployedJob then
        return nil
    end

    info = info or { label = 'Unemployed', rank = 'Civilian', salary = 0 }

    return {
        id = jobName,
        name = info.label or jobName,
        short = jobShort(jobName, info.label),
        rank = info.rank or tostring(grade or 0),
        grade = tonumber(grade) or 0,
        salary = tonumber(info.salary) or 0,
        icon = jobIcon(jobName)
    }
end

local function syncActiveJob(source, active)
    if not active or Bridge.name == 'qbox' then return end

    local identifier = Bridge.identifier(source)
    if not identifier then return end

    if active.name == Config.UnemployedJob then return end

    Storage.Upsert(identifier, active.name, active.grade, true)
end

local function buildPayload(source)
    if not Bridge then return nil end

    local active = Bridge.activeJob(source)
    if not active then return nil end

    syncActiveJob(source, active)

    local owned = readOwnedJobs(source)
    local jobs = {}

    for jobName, grade in pairs(owned) do
        if Config.IncludeUnemployed or jobName ~= Config.UnemployedJob then
            local formatted = formatJob(source, jobName, grade, active)
            if formatted then
                jobs[#jobs + 1] = formatted
            end
        end
    end

    table.sort(jobs, function(a, b)
        if a.id == active.name then return true end
        if b.id == active.name then return false end
        return a.name < b.name
    end)

    local current = formatJob(source, active.name, active.grade, active)
    lastActiveJob[source] = active.name ~= Config.UnemployedJob and active.name or lastActiveJob[source]

    return {
        framework = Bridge.name,
        active = active.name,
        onDuty = active.onDuty,
        current = current,
        jobs = jobs,
        settings = Config.Menu,
        maxJobs = Config.MaxJobs
    }
end

local function refreshPlayer(source)
    source = tonumber(source)
    if not source or GetPlayerPing(source) <= 0 then return false end
    if not Bridge and not getBridge() then return false end

    local payload = buildPayload(source)
    if not payload then return false end

    TriggerClientEvent('nd_multijob:client:setData', source, payload)
    return true
end

local function queueRefresh(source)
    source = tonumber(source)
    if not source or pendingRefresh[source] then return end

    pendingRefresh[source] = true

    SetTimeout(Config.RefreshDelay, function()
        pendingRefresh[source] = nil
        refreshPlayer(source)
    end)
end

local function setActiveJob(source, jobName)
    jobName = cleanName(jobName)
    if not jobName then return false, 'Invalid job.' end

    local owned = readOwnedJobs(source)
    local grade = owned[jobName]
    if not grade then return false, 'You do not have that job.' end

    if not Bridge.jobInfo(jobName, grade) then
        return false, 'Invalid job grade.'
    end

    local identifier = Bridge.identifier(source)
    if Bridge.name ~= 'qbox' and identifier then
        Storage.SetActive(identifier, jobName)
    end

    local ok, err = Bridge.setActiveJob(source, jobName, grade, Config.DutyOnSwitch)
    if ok then
        lastActiveJob[source] = jobName
    end

    return ok, err
end

local function setFallbackJob(source, previousJobs, removedJob)
    local nextJob, grade = chooseNextJob(previousJobs, removedJob)

    if nextJob then
        if Bridge.name ~= 'qbox' then
            local identifier = Bridge.identifier(source)
            if identifier then
                Storage.SetActive(identifier, nextJob)
            end
        end

        Bridge.setActiveJob(source, nextJob, grade, Config.DutyOnSwitch)
        lastActiveJob[source] = nextJob
        return
    end

    Bridge.setActiveJob(source, Config.UnemployedJob, Config.UnemployedGrade, false)
    lastActiveJob[source] = nil
end

local function removeOwnedJob(target, jobName)
    if not Bridge and not getBridge() then return false, 'Framework not ready.' end

    jobName = cleanName(jobName)
    if not jobName or jobName == Config.UnemployedJob then return false, 'Invalid job.' end

    local source, identifier = resolveTarget(target)
    if not identifier then return false, 'Player not found.' end

    -- Mark this removal so handleExternalJobUpdate skips its heuristic auto-removal
    -- when the framework subsequently fires SetJob('unemployed') on the player.
    recentlyFired[identifier] = jobName
    SetTimeout(3000, function()
        if recentlyFired[identifier] == jobName then
            recentlyFired[identifier] = nil
        end
    end)

    local previousJobs = source and readOwnedJobs(source) or {}
    local active = source and Bridge.activeJob(source) or nil
    local wasActive = active and active.name == jobName

    if Bridge.name == 'qbox' then
        local ok, err = Bridge.removeJob(identifier, jobName)
        if not ok then return false, err or 'Failed to remove job.' end
    else
        Storage.Remove(identifier, jobName)
    end

    if source then
        if wasActive then
            setFallbackJob(source, previousJobs, jobName)
        end
        queueRefresh(source)
    end

    return true
end

local function addOwnedJob(target, jobName, grade, makeActive)
    if not Bridge and not getBridge() then return false, 'Framework not ready.' end

    jobName = cleanName(jobName)
    grade = tonumber(grade) or 0

    if not jobName or jobName == Config.UnemployedJob then return false, 'Invalid job.' end
    if not Bridge.jobInfo(jobName, grade) then return false, 'Invalid job grade.' end

    local source, identifier = resolveTarget(target)
    if not identifier then return false, 'Player not found.' end

    local owned = source and readOwnedJobs(source) or {}
    local count = 0
    for _ in pairs(owned) do count = count + 1 end
    if count >= Config.MaxJobs and not owned[jobName] then
        return false, 'Maximum jobs reached.'
    end

    if Bridge.name == 'qbox' then
        local ok, err = Bridge.addJob(identifier, jobName, grade)
        if not ok then return false, err or 'Failed to save job.' end
    else
        Storage.Upsert(identifier, jobName, grade, makeActive == true)
    end

    if source and makeActive then
        Bridge.setActiveJob(source, jobName, grade, Config.DutyOnSwitch)
        lastActiveJob[source] = jobName
    end

    if source then queueRefresh(source) end
    return true
end

local function setOwnedJobGrade(target, jobName, grade)
    if not Bridge and not getBridge() then return false, 'Framework not ready.' end

    jobName = cleanName(jobName)
    grade = tonumber(grade) or 0

    if not jobName or not Bridge.jobInfo(jobName, grade) then return false, 'Invalid job grade.' end

    local source, identifier = resolveTarget(target)
    if not identifier then return false, 'Player not found.' end

    if Bridge.name == 'qbox' then
        if not Bridge.setGrade(identifier, jobName, grade) then
            return false, 'You do not have that job.'
        end
    else
        if not Storage.Has(identifier, jobName) then
            return false, 'You do not have that job.'
        end
        Storage.SetGrade(identifier, jobName, grade)
    end

    local active = source and Bridge.activeJob(source) or nil
    if source and active and active.name == jobName then
        Bridge.setActiveJob(source, jobName, grade, active.onDuty)
    end

    if source then queueRefresh(source) end
    return true
end

local function handleExternalJobUpdate(source, job)
    if not Bridge or Bridge.name == 'qbox' then
        queueRefresh(source)
        return
    end

    local jobName = type(job) == 'table' and job.name or job
    local identifier = Bridge.identifier(source)

    if identifier and jobName == Config.UnemployedJob then
        local previous = lastActiveJob[source]

        if not previous then
            local rows = Storage.Read(identifier)
            for i = 1, #rows do
                if rows[i].active then
                    previous = rows[i].job_name
                    break
                end
            end
        end

        if previous and not recentlyFired[identifier] then
            Storage.Remove(identifier, previous)
        end

        lastActiveJob[source] = nil
    end

    queueRefresh(source)
end

CreateThread(waitForBridge)

RegisterNetEvent('nd_multijob:server:requestData', function()
    refreshPlayer(source)
end)

RegisterNetEvent('nd_multijob:server:switchJob', function(jobName)
    local src = source
    if not Bridge and not getBridge() then return end

    local ok, err = setActiveJob(src, jobName)
    if not ok then
        notify(src, err or 'Unable to switch jobs.', 'error')
    end

    queueRefresh(src)
end)

RegisterNetEvent('nd_multijob:server:toggleDuty', function()
    local src = source
    if not Bridge and not getBridge() then return end

    local active = Bridge.activeJob(src)
    if not active or active.name == Config.UnemployedJob then
        notify(src, 'No active job to toggle.', 'error')
        queueRefresh(src)
        return
    end

    if not Bridge.setDuty(src, not active.onDuty) then
        notify(src, 'Unable to update duty status.', 'error')
    end

    queueRefresh(src)
end)

RegisterNetEvent('nd_multijob:server:leaveJob', function()
    local src = source
    if not Bridge and not getBridge() then return end

    local active = Bridge.activeJob(src)
    if not active or active.name == Config.UnemployedJob then
        notify(src, 'You cannot leave that job.', 'error')
        queueRefresh(src)
        return
    end

    local ok, err = removeOwnedJob(src, active.name)
    if not ok then
        notify(src, err or 'Unable to leave job.', 'error')
    end

    queueRefresh(src)
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function(src)
    queueRefresh(src or source)
end)

AddEventHandler('QBCore:Server:OnJobUpdate', function(src, job)
    if type(source) == 'number' and source > 0 then return end
    handleExternalJobUpdate(src, job)
end)

AddEventHandler('QBCore:Server:SetDuty', function(src)
    queueRefresh(src)
end)

AddEventHandler('qbx_core:server:onGroupUpdate', function(src)
    queueRefresh(src)
end)

AddEventHandler('esx:playerLoaded', function(src)
    queueRefresh(src)
end)

AddEventHandler('esx:setJob', function(src, job)
    if type(source) == 'number' and source > 0 then return end
    handleExternalJobUpdate(src, job)
end)

AddEventHandler('playerDropped', function()
    pendingRefresh[source] = nil
    lastActiveJob[source] = nil
end)

exports('AddJob', addOwnedJob)
exports('RemoveJob', removeOwnedJob)
exports('SetJobGrade', setOwnedJobGrade)
exports('RefreshPlayer', refreshPlayer)

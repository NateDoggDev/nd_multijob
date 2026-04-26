# nd_multijob

Join discord for any support, and check out the store for my paid scripts :)
Discord: https://discord.com/invite/ey2sMahZ6t Lint Error Store: https://linterror.com

Clean and simple multijob resource for Qbox, QBCore, and ESX that doesnt cost $20 for no reason.

## Install

1. Place this folder in your resources directory.
2. Ensure your framework starts before this resource.
3. Ensure `oxmysql` starts before this resource.
4. Import `sql/install.sql` if `Config.Database.autoCreate` is disabled.
5. Add `ensure nd_multijob` to `server.cfg`.

Qbox uses native player job groups. QBCore and ESX use the small `nd_multijob_jobs` table because those frameworks do not have native multijob.

For Qbox, make sure `setr qbx:max_jobs_per_player 5` or higher is set if you want players to hold five jobs also need to set `qbx:setjob_replaces` to false. Qbox enforces these inside `qbx_core`.

## Boss Menu Integration

Use exports when hiring, firing, or promoting so the menu updates immediately.

```lua
exports['nd_multijob']:AddJob(source, 'police', 2, true)
exports['nd_multijob']:RemoveJob(source, 'police')
exports['nd_multijob']:SetJobGrade(source, 'police', 3)
exports['nd_multijob']:RefreshPlayer(source)
```

The target can be source or character identifier/citizenid.

## Framework sync (QBCore / ESX)

QBCore and ESX only track one job per player, so their boss menus can't tell nd_multijob which job a player was fired from. Add the patches below to keep the list in sync, including for offline players. **Qbox is supported natively, no patch.**

`target` accepts source or citizenid/identifier.

```lua
exports['nd_multijob']:AddJob(target, jobName, grade, false)  -- hire
exports['nd_multijob']:RemoveJob(target, jobName)              -- fire
exports['nd_multijob']:SetJobGrade(target, jobName, grade)     -- promote/demote
```

### `qb-management/server/sv_boss.lua`

Add above line 91 (`if Employee.Functions.SetJob(Player.PlayerData.job.name, data.grade) then`):
```lua
if GetResourceState('nd_multijob') == 'started' then
    exports['nd_multijob']:SetJobGrade(data.cid, Player.PlayerData.job.name, data.grade)
end
```

Add above line 124 (`if Employee.Functions.SetJob('unemployed', '0') then`):
```lua
if GetResourceState('nd_multijob') == 'started' then
    exports['nd_multijob']:RemoveJob(target, Player.PlayerData.job.name)
end
```

Add above line 150 (`if Target and Target.Functions.SetJob(Player.PlayerData.job.name, 0) then`):
```lua
if GetResourceState('nd_multijob') == 'started' then
    exports['nd_multijob']:AddJob(Target.PlayerData.citizenid, Player.PlayerData.job.name, 0, false)
end
```

### `esx_society/server/main.lua`

Add above line 281 (`if not xTarget then`):
```lua
if GetResourceState('nd_multijob') == 'started' then
    if actionType == 'hire' then
        exports['nd_multijob']:AddJob(identifier, job, grade, false)
    elseif actionType == 'fire' then
        exports['nd_multijob']:RemoveJob(identifier, job)
    elseif actionType == 'promote' or actionType == 'demote' then
        exports['nd_multijob']:SetJobGrade(identifier, job, grade)
    end
end
```

---

Join Discord for support and check out our paid scripts. 

Discord: **https://discord.com/invite/ey2sMahZ6t**

Lint Error Store: **https://linterror.com**

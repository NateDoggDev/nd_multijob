Config = {}

Config.Framework = 'auto'
Config.Command = 'multijob'
Config.Keybind = 'F6'

Config.MaxJobs = 5
Config.UnemployedJob = 'unemployed'
Config.UnemployedGrade = 0
Config.IncludeUnemployed = false
Config.DutyOnSwitch = false

Config.Notify = true
Config.RefreshDelay = 250

Config.Menu = {
    accent = '#c8ccd1',
    radius = 12,
    scale = 1.0,
    iconStyle = 'outline'
}

Config.Database = {
    autoCreate = true,
    tableName = 'nd_multijob_jobs'
}

-- Icons use Font Awesome 6 Free (Solid). Find them here :)
--   https://fontawesome.com/search?o=r&m=free&s=solid
Config.JobIcons = {
    police     = 'shield-halved',
    bcso       = 'shield-halved',
    sasp       = 'shield-halved',
    sheriff    = 'shield-halved',
    ambulance  = 'truck-medical',
    ems        = 'truck-medical',
    doctor     = 'user-doctor',
    fire       = 'fire',
    mechanic   = 'wrench',
    tow        = 'truck-pickup',
    taxi       = 'taxi',
    trucker    = 'truck',
    cardealer  = 'car',
    realestate = 'house'
}

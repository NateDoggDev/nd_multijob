fx_version 'cerulean'
game 'gta5'

author 'Nate Dogg (LintError)'
description 'Clean and simple multijob menu for Qbox, QBCore, and ESX that doesnt cost 20$ for no reason :)'
version '1.0.0'

dependency 'oxmysql'

ui_page 'web/index.html'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/storage.lua',
    'server/bridge/qbox.lua',
    'server/bridge/qbcore.lua',
    'server/bridge/esx.lua',
    'server/main.lua'
}

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

Storage = {}

local tableName = ('`%s`'):format(Config.Database.tableName)

function Storage.Init()
    if not Config.Database.autoCreate then return end

    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS %s (
          `identifier` varchar(80) NOT NULL,
          `job_name` varchar(64) NOT NULL,
          `grade` int NOT NULL DEFAULT 0,
          `active` tinyint(1) NOT NULL DEFAULT 0,
          `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (`identifier`, `job_name`),
          KEY `idx_nd_multijob_identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]):format(tableName))
end

function Storage.Read(identifier)
    local rows = MySQL.query.await(
        ('SELECT `job_name`, `grade`, `active` FROM %s WHERE `identifier` = ? ORDER BY `active` DESC, `job_name` ASC'):format(tableName),
        { identifier }
    ) or {}

    for i = 1, #rows do
        rows[i].grade = tonumber(rows[i].grade) or 0
        rows[i].active = rows[i].active == true or rows[i].active == 1
    end

    return rows
end

function Storage.Has(identifier, jobName)
    return MySQL.scalar.await(
        ('SELECT 1 FROM %s WHERE `identifier` = ? AND `job_name` = ? LIMIT 1'):format(tableName),
        { identifier, jobName }
    ) ~= nil
end

function Storage.Upsert(identifier, jobName, grade, active)
    grade = tonumber(grade) or 0
    active = active and 1 or 0

    if active == 1 then
        MySQL.query.await(('UPDATE %s SET `active` = 0 WHERE `identifier` = ?'):format(tableName), { identifier })
    end

    MySQL.query.await(
        ([[
            INSERT INTO %s (`identifier`, `job_name`, `grade`, `active`)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE `grade` = VALUES(`grade`), `active` = VALUES(`active`)
        ]]):format(tableName),
        { identifier, jobName, grade, active }
    )
end

function Storage.Replace(identifier, jobName, grade)
    MySQL.query.await(('DELETE FROM %s WHERE `identifier` = ?'):format(tableName), { identifier })
    Storage.Upsert(identifier, jobName, grade, true)
end

function Storage.SetActive(identifier, jobName)
    if not Storage.Has(identifier, jobName) then return false end

    MySQL.query.await(('UPDATE %s SET `active` = 0 WHERE `identifier` = ?'):format(tableName), { identifier })
    MySQL.query.await(
        ('UPDATE %s SET `active` = 1 WHERE `identifier` = ? AND `job_name` = ?'):format(tableName),
        { identifier, jobName }
    )

    return true
end

function Storage.SetGrade(identifier, jobName, grade)
    MySQL.query.await(
        ('UPDATE %s SET `grade` = ? WHERE `identifier` = ? AND `job_name` = ?'):format(tableName),
        { tonumber(grade) or 0, identifier, jobName }
    )
end

function Storage.Remove(identifier, jobName)
    MySQL.query.await(
        ('DELETE FROM %s WHERE `identifier` = ? AND `job_name` = ?'):format(tableName),
        { identifier, jobName }
    )
end

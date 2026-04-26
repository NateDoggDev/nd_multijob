CREATE TABLE IF NOT EXISTS `nd_multijob_jobs` (
  `identifier` varchar(80) NOT NULL,
  `job_name` varchar(64) NOT NULL,
  `grade` int NOT NULL DEFAULT 0,
  `active` tinyint(1) NOT NULL DEFAULT 0,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`, `job_name`),
  KEY `idx_nd_multijob_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

USE abroadmates_db;

-- Safe to run on an existing project: this does NOT drop or recreate data.
-- Your Step 1 schema already creates mentor_profiles with this relationship.
CREATE TABLE IF NOT EXISTS mentor_profiles (
  mentor_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL UNIQUE,
  headline VARCHAR(180) NULL,
  bio TEXT NULL,
  years_experience TINYINT UNSIGNED NOT NULL DEFAULT 0,
  profile_photo_path VARCHAR(500) NULL,
  cv_file_path VARCHAR(500) NULL,
  is_published BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_mentor_user FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

-- Backfill mentor profiles for Mentor accounts that already exist.
-- The LEFT JOIN prevents duplicate profiles if this script is run again.
INSERT INTO mentor_profiles (user_id)
SELECT u.user_id
FROM users u
JOIN roles r ON r.role_id = u.role_id
LEFT JOIN mentor_profiles mp ON mp.user_id = u.user_id
WHERE r.role_name = 'Mentor'
  AND mp.user_id IS NULL;

DROP PROCEDURE IF EXISTS sp_get_auth_user_by_id;
DROP PROCEDURE IF EXISTS sp_get_mentor_profile_by_user_id;

DELIMITER $$
CREATE PROCEDURE sp_get_auth_user_by_id(IN p_user_id BIGINT UNSIGNED)
BEGIN
  SELECT u.user_id, u.full_name, u.email, u.is_active, r.role_name
  FROM users u
  JOIN roles r ON r.role_id = u.role_id
  WHERE u.user_id = p_user_id
  LIMIT 1;
END$$

CREATE PROCEDURE sp_get_mentor_profile_by_user_id(IN p_user_id BIGINT UNSIGNED)
BEGIN
  SELECT mentor_id, user_id, headline, bio, years_experience,
         profile_photo_path, cv_file_path, is_published, created_at
  FROM mentor_profiles
  WHERE user_id = p_user_id
  LIMIT 1;
END$$
DELIMITER ;

-- Verification: expected one row per Mentor user.
SELECT u.user_id, u.full_name, u.email, mp.mentor_id, mp.is_published
FROM users u
JOIN roles r ON r.role_id = u.role_id
LEFT JOIN mentor_profiles mp ON mp.user_id = u.user_id
WHERE r.role_name = 'Mentor'
ORDER BY u.user_id DESC;

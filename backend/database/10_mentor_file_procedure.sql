USE abroadmates_db;

DROP PROCEDURE IF EXISTS sp_get_my_mentor_file_paths;

DELIMITER //

CREATE PROCEDURE sp_get_my_mentor_file_paths(
    IN p_user_id BIGINT UNSIGNED
)
BEGIN
    SELECT
        mentor_id,
        profile_photo_path,
        cv_file_path
    FROM mentor_profiles
    WHERE user_id = p_user_id
    LIMIT 1;
END //

DELIMITER ;
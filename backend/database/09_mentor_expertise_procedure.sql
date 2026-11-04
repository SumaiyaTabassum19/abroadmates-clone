USE abroadmates_db;

DROP PROCEDURE IF EXISTS sp_get_my_mentor_expertise;

DELIMITER //

CREATE PROCEDURE sp_get_my_mentor_expertise(
    IN p_user_id BIGINT UNSIGNED
)
BEGIN
    DECLARE v_mentor_id BIGINT UNSIGNED;

    SELECT mentor_id
    INTO v_mentor_id
    FROM mentor_profiles
    WHERE user_id = p_user_id
    LIMIT 1;

    -- Result set 1: selected countries
    SELECT
        country_id
    FROM mentor_countries
    WHERE mentor_id = v_mentor_id;

    -- Result set 2: selected universities
    SELECT
        university_id
    FROM mentor_universities
    WHERE mentor_id = v_mentor_id;

    -- Result set 3: consultation plans
    SELECT
        plan_id,
        duration_minutes,
        price,
        currency,
        is_active
    FROM mentor_plans
    WHERE mentor_id = v_mentor_id
    ORDER BY duration_minutes;
END //

DELIMITER ;
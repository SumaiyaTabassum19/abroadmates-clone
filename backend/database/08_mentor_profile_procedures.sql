USE abroadmates_db;

DROP PROCEDURE IF EXISTS sp_get_my_mentor_profile;

DELIMITER $$

CREATE PROCEDURE sp_get_my_mentor_profile(
    IN p_user_id BIGINT UNSIGNED
)
BEGIN

    -- 1. Mentor basic profile
    SELECT
        mp.mentor_id,
        mp.user_id,
        u.full_name,
        u.email,
        mp.headline,
        mp.bio,
        mp.years_experience,
        mp.profile_photo_path,
        mp.cv_file_path,
        mp.is_published
    FROM mentor_profiles mp
    INNER JOIN users u
        ON u.user_id = mp.user_id
    WHERE mp.user_id = p_user_id
    LIMIT 1;

    -- 2. Consultation plans
    SELECT
        plan_id,
        duration_minutes,
        price,
        currency,
        is_active
    FROM mentor_plans
    WHERE mentor_id = (
        SELECT mentor_id
        FROM mentor_profiles
        WHERE user_id = p_user_id
    );

    -- 3. Selected countries
    SELECT
        c.country_id,
        c.country_name
    FROM mentor_countries mc
    INNER JOIN countries c
        ON c.country_id = mc.country_id
    WHERE mc.mentor_id = (
        SELECT mentor_id
        FROM mentor_profiles
        WHERE user_id = p_user_id
    );

    -- 4. Selected universities
    SELECT
        un.university_id,
        un.university_name,
        un.country_id
    FROM mentor_universities mu
    INNER JOIN universities un
        ON un.university_id = mu.university_id
    WHERE mu.mentor_id = (
        SELECT mentor_id
        FROM mentor_profiles
        WHERE user_id = p_user_id
    );

END$$

DELIMITER ;
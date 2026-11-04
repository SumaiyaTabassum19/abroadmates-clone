DELIMITER //

-- Public mentor details and expertise
CREATE PROCEDURE sp_get_public_mentor_details(
    IN p_mentor_id BIGINT UNSIGNED
)
BEGIN
    -- 1. Mentor profile
    SELECT
        mp.mentor_id,
        u.full_name,
        mp.headline,
        mp.bio,
        mp.years_experience,
        mp.profile_photo_path
    FROM mentor_profiles mp
    INNER JOIN users u ON u.user_id = mp.user_id
    WHERE mp.mentor_id = p_mentor_id
      AND mp.is_published = 1;

    -- 2. Active consultation plans
    SELECT
        plan_id,
        duration_minutes,
        price,
        currency
    FROM mentor_plans
    WHERE mentor_id = p_mentor_id
      AND is_active = 1
    ORDER BY duration_minutes;

    -- 3. Countries
    SELECT c.country_id, c.country_name
    FROM mentor_countries mc
    INNER JOIN countries c ON c.country_id = mc.country_id
    WHERE mc.mentor_id = p_mentor_id
      AND c.is_active = 1
    ORDER BY c.country_name;

    -- 4. Universities
    SELECT un.university_id, un.university_name, c.country_name
    FROM mentor_universities mu
    INNER JOIN universities un ON un.university_id = mu.university_id
    INNER JOIN countries c ON c.country_id = un.country_id
    WHERE mu.mentor_id = p_mentor_id
    ORDER BY un.university_name;

    -- 5. Programs
    SELECT p.program_id, p.program_name, p.degree_level
    FROM mentor_programs mp
    INNER JOIN programs p ON p.program_id = mp.program_id
    WHERE mp.mentor_id = p_mentor_id
      AND p.is_active = 1
    ORDER BY p.program_name;

    -- 6. Services
    SELECT s.service_id, s.service_name
    FROM mentor_services ms
    INNER JOIN services s ON s.service_id = ms.service_id
    WHERE ms.mentor_id = p_mentor_id
      AND s.is_active = 1
    ORDER BY s.service_name;

    -- 7. Scholarships
    SELECT
        sh.scholarship_id,
        sh.scholarship_name,
        sh.provider_name,
        c.country_name
    FROM mentor_scholarships msh
    INNER JOIN scholarships sh
        ON sh.scholarship_id = msh.scholarship_id
    LEFT JOIN countries c ON c.country_id = sh.country_id
    WHERE msh.mentor_id = p_mentor_id
      AND sh.is_active = 1
    ORDER BY sh.scholarship_name;
END //


-- Create a booking after validating the mentor and plan
CREATE PROCEDURE sp_create_booking(
    IN p_student_user_id BIGINT UNSIGNED,
    IN p_mentor_id BIGINT UNSIGNED,
    IN p_plan_id BIGINT UNSIGNED,
    IN p_scheduled_at DATETIME,
    IN p_student_note VARCHAR(1000)
)
BEGIN
    DECLARE v_plan_count INT DEFAULT 0;
    DECLARE v_mentor_count INT DEFAULT 0;

    SELECT COUNT(*)
    INTO v_mentor_count
    FROM mentor_profiles
    WHERE mentor_id = p_mentor_id
      AND is_published = 1;

    IF v_mentor_count = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Mentor is not available';
    END IF;

    SELECT COUNT(*)
    INTO v_plan_count
    FROM mentor_plans
    WHERE plan_id = p_plan_id
      AND mentor_id = p_mentor_id
      AND is_active = 1;

    IF v_plan_count = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Selected consultation plan is not available';
    END IF;

    IF p_scheduled_at IS NULL OR p_scheduled_at <= NOW() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Please select a future booking date and time';
    END IF;

    INSERT INTO bookings (
        student_user_id,
        mentor_id,
        plan_id,
        scheduled_at,
        status,
        student_note
    )
    VALUES (
        p_student_user_id,
        p_mentor_id,
        p_plan_id,
        p_scheduled_at,
        'pending',
        p_student_note
    );

    SELECT LAST_INSERT_ID() AS booking_id;
END //

DELIMITER ;
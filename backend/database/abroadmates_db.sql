-- Database: `abroadmates_db`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_cancel_mentor_booking` (IN `p_mentor_user_id` BIGINT UNSIGNED, IN `p_booking_id` BIGINT UNSIGNED)   BEGIN
    DECLARE v_mentor_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_booking_status VARCHAR(20) DEFAULT NULL;

    SELECT mentor_id
    INTO v_mentor_id
    FROM mentor_profiles
    WHERE user_id = p_mentor_user_id
    LIMIT 1;

    IF v_mentor_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Mentor profile not found.';
    END IF;

    SELECT status
    INTO v_booking_status
    FROM bookings
    WHERE booking_id = p_booking_id
      AND mentor_id = v_mentor_id
    LIMIT 1;

    IF v_booking_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Booking not found for this mentor.';
    END IF;

    IF v_booking_status NOT IN ('pending', 'confirmed') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'This booking cannot be cancelled.';
    END IF;

    UPDATE bookings
    SET status = 'cancelled'
    WHERE booking_id = p_booking_id
      AND mentor_id = v_mentor_id;

    SELECT booking_id, status
    FROM bookings
    WHERE booking_id = p_booking_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_complete_mentor_booking` (IN `p_mentor_user_id` BIGINT UNSIGNED, IN `p_booking_id` BIGINT UNSIGNED)   BEGIN
    DECLARE v_mentor_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_booking_status VARCHAR(20) DEFAULT NULL;

    SELECT mentor_id
    INTO v_mentor_id
    FROM mentor_profiles
    WHERE user_id = p_mentor_user_id
    LIMIT 1;

    IF v_mentor_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Mentor profile not found.';
    END IF;

    SELECT status
    INTO v_booking_status
    FROM bookings
    WHERE booking_id = p_booking_id
      AND mentor_id = v_mentor_id
    LIMIT 1;

    IF v_booking_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Booking not found for this mentor.';
    END IF;

    IF v_booking_status <> 'confirmed' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only confirmed bookings can be completed.';
    END IF;

    UPDATE bookings
    SET status = 'completed'
    WHERE booking_id = p_booking_id
      AND mentor_id = v_mentor_id;

    SELECT booking_id, status
    FROM bookings
    WHERE booking_id = p_booking_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_confirm_mentor_booking` (IN `p_mentor_user_id` BIGINT UNSIGNED, IN `p_booking_id` BIGINT UNSIGNED, IN `p_meeting_link` VARCHAR(500))   BEGIN
    DECLARE v_mentor_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_booking_status VARCHAR(20) DEFAULT NULL;

    SELECT mentor_id
    INTO v_mentor_id
    FROM mentor_profiles
    WHERE user_id = p_mentor_user_id
    LIMIT 1;

    IF v_mentor_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Mentor profile not found.';
    END IF;

    SELECT status
    INTO v_booking_status
    FROM bookings
    WHERE booking_id = p_booking_id
      AND mentor_id = v_mentor_id
    LIMIT 1;

    IF v_booking_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Booking not found for this mentor.';
    END IF;

    IF v_booking_status <> 'pending' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only pending bookings can be confirmed.';
    END IF;

    UPDATE bookings
    SET status = 'confirmed',
        meeting_link = NULLIF(TRIM(p_meeting_link), '')
    WHERE booking_id = p_booking_id
      AND mentor_id = v_mentor_id;

    SELECT booking_id, status, meeting_link
    FROM bookings
    WHERE booking_id = p_booking_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_auth_user_by_id` (IN `p_user_id` BIGINT UNSIGNED)   BEGIN
    SELECT
        u.user_id,
        u.full_name,
        u.email,
        u.is_active,
        r.role_name
    FROM users u
    INNER JOIN roles r
        ON r.role_id = u.role_id
    WHERE u.user_id = p_user_id
    LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_countries` ()   BEGIN
    SELECT
        country_id,
        country_name,
        slug,
        page_title,
        page_description
    FROM countries
    WHERE is_active = 1
    ORDER BY country_name ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_mentor_by_id` (IN `p_mentor_id` BIGINT UNSIGNED)   BEGIN
    -- Result set 1: mentor profile
    SELECT
        mp.mentor_id,
        mp.user_id,
        u.full_name,
        u.email,
        mp.headline,
        mp.bio,
        mp.years_experience,
        mp.profile_photo_path,
        mp.cv_file_path

    FROM mentor_profiles mp
    INNER JOIN users u
        ON u.user_id = mp.user_id

    WHERE mp.mentor_id = p_mentor_id
      AND mp.is_published = 1
      AND u.is_active = 1;

    -- Result set 2: active consultation plans
    SELECT
        plan_id,
        mentor_id,
        duration_minutes,
        price,
        currency

    FROM mentor_plans
    WHERE mentor_id = p_mentor_id
      AND is_active = 1
    ORDER BY duration_minutes ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_mentor_earnings_report` (IN `p_mentor_user_id` BIGINT UNSIGNED, IN `p_start_date` DATE, IN `p_end_date` DATE, IN `p_status` VARCHAR(20))   BEGIN
    DECLARE v_mentor_id BIGINT UNSIGNED DEFAULT NULL;

    SELECT mentor_id
    INTO v_mentor_id
    FROM mentor_profiles
    WHERE user_id = p_mentor_user_id
    LIMIT 1;

    IF v_mentor_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Mentor profile not found.';
    END IF;

    IF p_status NOT IN (
        'all', 'pending', 'confirmed', 'completed', 'cancelled'
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid booking status.';
    END IF;

    IF p_start_date IS NOT NULL
       AND p_end_date IS NOT NULL
       AND p_start_date > p_end_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Start date cannot be after end date.';
    END IF;

    
    SELECT
        COUNT(*) AS totalBookings,
        SUM(b.status = 'pending') AS pendingBookings,
        SUM(b.status = 'confirmed') AS confirmedBookings,
        SUM(b.status = 'completed') AS completedBookings,
        SUM(b.status = 'cancelled') AS cancelledBookings,
        COALESCE(
            SUM(
                CASE WHEN b.status = 'completed'
                    THEN mp.price ELSE 0
                END
            ), 0
        ) AS totalEarnings,
        COALESCE(MAX(mp.currency), 'BDT') AS currency
    FROM bookings b
    INNER JOIN mentor_plans mp
        ON mp.plan_id = b.plan_id
    WHERE b.mentor_id = v_mentor_id
      AND (p_start_date IS NULL OR DATE(b.scheduled_at) >= p_start_date)
      AND (p_end_date IS NULL OR DATE(b.scheduled_at) <= p_end_date)
      AND (p_status = 'all' OR b.status = p_status);

    
    SELECT
        DATE_FORMAT(b.scheduled_at, '%Y-%m') AS month,
        SUM(mp.price) AS earnings,
        mp.currency,
        COUNT(*) AS completedBookings
    FROM bookings b
    INNER JOIN mentor_plans mp
        ON mp.plan_id = b.plan_id
    WHERE b.mentor_id = v_mentor_id
      AND b.status = 'completed'
      AND (p_start_date IS NULL OR DATE(b.scheduled_at) >= p_start_date)
      AND (p_end_date IS NULL OR DATE(b.scheduled_at) <= p_end_date)
      AND (p_status = 'all' OR b.status = p_status)
    GROUP BY DATE_FORMAT(b.scheduled_at, '%Y-%m'), mp.currency
    ORDER BY month ASC;

    
    SELECT
        b.booking_id,
        b.student_user_id,
        student.full_name AS student_name,
        student.email AS student_email,
        mp.duration_minutes,
        mp.price,
        mp.currency,
        b.scheduled_at,
        b.status,
        b.meeting_link,
        b.student_note,
        b.created_at
    FROM bookings b
    INNER JOIN users student
        ON student.user_id = b.student_user_id
    INNER JOIN mentor_plans mp
        ON mp.plan_id = b.plan_id
    WHERE b.mentor_id = v_mentor_id
      AND (p_start_date IS NULL OR DATE(b.scheduled_at) >= p_start_date)
      AND (p_end_date IS NULL OR DATE(b.scheduled_at) <= p_end_date)
      AND (p_status = 'all' OR b.status = p_status)
    ORDER BY b.scheduled_at DESC, b.booking_id DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_mentor_list` (IN `p_country_id` INT UNSIGNED, IN `p_program_id` INT UNSIGNED, IN `p_service_id` INT UNSIGNED, IN `p_scholarship_id` BIGINT UNSIGNED, IN `p_search` VARCHAR(150), IN `p_sort` VARCHAR(30))   BEGIN
    SELECT
        mp.mentor_id,
        u.full_name,
        mp.headline,
        mp.bio,
        mp.years_experience,
        mp.profile_photo_path,

        COALESCE(r.avg_rating, 0) AS average_rating,
        COALESCE(r.review_count, 0) AS review_count,
        COALESCE(b.session_count, 0) AS session_count,

        p.minimum_price,
        p.currency

    FROM mentor_profiles mp

    INNER JOIN users u
        ON u.user_id = mp.user_id

    LEFT JOIN (
        SELECT
            mentor_id,
            AVG(rating) AS avg_rating,
            COUNT(*) AS review_count
        FROM reviews
        GROUP BY mentor_id
    ) r ON r.mentor_id = mp.mentor_id

    LEFT JOIN (
        SELECT
            mentor_id,
            COUNT(*) AS session_count
        FROM bookings
        GROUP BY mentor_id
    ) b ON b.mentor_id = mp.mentor_id

    LEFT JOIN (
        SELECT
            mentor_id,
            MIN(price) AS minimum_price,
            MIN(currency) AS currency
        FROM mentor_plans
        WHERE is_active = 1
        GROUP BY mentor_id
    ) p ON p.mentor_id = mp.mentor_id

    WHERE
        mp.is_published = 1
        AND u.is_active = 1

        AND (
            p_country_id IS NULL
            OR EXISTS (
                SELECT 1
                FROM mentor_countries mc
                WHERE mc.mentor_id = mp.mentor_id
                  AND mc.country_id = p_country_id
            )
        )

        AND (
            p_program_id IS NULL
            OR EXISTS (
                SELECT 1
                FROM mentor_programs mpr
                WHERE mpr.mentor_id = mp.mentor_id
                  AND mpr.program_id = p_program_id
            )
        )

        AND (
            p_service_id IS NULL
            OR EXISTS (
                SELECT 1
                FROM mentor_services ms
                WHERE ms.mentor_id = mp.mentor_id
                  AND ms.service_id = p_service_id
            )
        )

        AND (
            p_scholarship_id IS NULL
            OR EXISTS (
                SELECT 1
                FROM mentor_scholarships msh
                WHERE msh.mentor_id = mp.mentor_id
                  AND msh.scholarship_id = p_scholarship_id
            )
        )

        AND (
            p_search IS NULL
            OR p_search = ''
            OR u.full_name LIKE CONCAT('%', p_search, '%')
            OR EXISTS (
                SELECT 1
                FROM mentor_universities mu
                INNER JOIN universities un
                    ON un.university_id = mu.university_id
                WHERE mu.mentor_id = mp.mentor_id
                  AND un.university_name LIKE CONCAT('%', p_search, '%')
            )
        )

    ORDER BY
        CASE WHEN p_sort = 'top_rated'
            THEN COALESCE(r.avg_rating, 0) END DESC,

        CASE WHEN p_sort = 'most_sessions'
            THEN COALESCE(b.session_count, 0) END DESC,

        CASE WHEN p_sort = 'price_low'
            THEN p.minimum_price END ASC,

        mp.mentor_id DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_mentor_profile_by_user_id` (IN `p_user_id` BIGINT UNSIGNED)   BEGIN
    SELECT
        mentor_id,
        user_id,
        headline,
        bio,
        years_experience,
        profile_photo_path,
        cv_file_path,
        is_published,
        created_at,
        updated_at
    FROM mentor_profiles
    WHERE user_id = p_user_id
    LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_my_bookings_detailed` (IN `p_student_user_id` BIGINT UNSIGNED)   BEGIN
    SELECT
        b.booking_id,
        b.student_user_id,
        b.mentor_id,
        mentor_user.full_name AS mentor_name,
        mentor_profile.headline AS mentor_headline,
        mentor_profile.profile_photo_path AS mentor_photo,
        b.plan_id,
        plan.duration_minutes,
        plan.price,
        plan.currency,
        b.scheduled_at,
        b.status,
        b.meeting_link,
        b.student_note,
        b.created_at
    FROM bookings b
    INNER JOIN mentor_profiles mentor_profile
        ON mentor_profile.mentor_id = b.mentor_id
    INNER JOIN users mentor_user
        ON mentor_user.user_id = mentor_profile.user_id
    INNER JOIN mentor_plans plan
        ON plan.plan_id = b.plan_id
    WHERE b.student_user_id = p_student_user_id
    ORDER BY b.scheduled_at DESC, b.booking_id DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_my_group_registrations` (IN `p_student_user_id` BIGINT UNSIGNED)   BEGIN
    SELECT
        sr.registration_id,
        sr.session_id,
        sr.student_user_id,
        sr.registered_at,
        sr.status AS registration_status,

        gs.category_id,
        sc.category_name,
        gs.title,
        gs.description,
        gs.starts_at,
        gs.ends_at,
        gs.capacity,
        gs.status AS session_status,
        gs.meeting_link,

        gs.mentor_id,
        mentor_user.full_name AS mentor_name,
        mentor_profile.headline AS mentor_headline,
        mentor_profile.profile_photo_path AS mentor_photo,

        (
            SELECT COUNT(*)
            FROM session_registrations active_registrations
            WHERE active_registrations.session_id = gs.session_id
              AND active_registrations.status = 'registered'
        ) AS registered_count

    FROM session_registrations sr
    INNER JOIN group_sessions gs
        ON gs.session_id = sr.session_id
    INNER JOIN session_categories sc
        ON sc.category_id = gs.category_id
    INNER JOIN mentor_profiles mentor_profile
        ON mentor_profile.mentor_id = gs.mentor_id
    INNER JOIN users mentor_user
        ON mentor_user.user_id = mentor_profile.user_id

    WHERE sr.student_user_id = p_student_user_id
    ORDER BY gs.starts_at DESC, sr.registration_id DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_my_group_sessions` (IN `p_user_id` BIGINT UNSIGNED)   BEGIN
    DECLARE v_mentor_id BIGINT UNSIGNED DEFAULT NULL;

    SELECT mentor_id
    INTO v_mentor_id
    FROM mentor_profiles
    WHERE user_id = p_user_id
    LIMIT 1;

    IF v_mentor_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Mentor profile not found.';
    END IF;

    SELECT
        gs.session_id,
        gs.category_id,
        sc.category_name,
        gs.title,
        gs.description,
        gs.starts_at,
        gs.ends_at,
        gs.capacity,
        gs.meeting_link,
        gs.status,
        COUNT(CASE
            WHEN sr.status = 'registered' THEN sr.registration_id
        END) AS registered_count
    FROM group_sessions gs
    INNER JOIN session_categories sc
        ON sc.category_id = gs.category_id
    LEFT JOIN session_registrations sr
        ON sr.session_id = gs.session_id
    WHERE gs.mentor_id = v_mentor_id
    GROUP BY
        gs.session_id,
        gs.category_id,
        sc.category_name,
        gs.title,
        gs.description,
        gs.starts_at,
        gs.ends_at,
        gs.capacity,
        gs.meeting_link,
        gs.status
    ORDER BY gs.starts_at DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_my_mentor_bookings` (IN `p_mentor_user_id` BIGINT UNSIGNED)   BEGIN
    DECLARE v_mentor_id BIGINT UNSIGNED DEFAULT NULL;

    SELECT mentor_id
    INTO v_mentor_id
    FROM mentor_profiles
    WHERE user_id = p_mentor_user_id
    LIMIT 1;

    IF v_mentor_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Mentor profile not found.';
    END IF;

    SELECT
        b.booking_id,
        b.student_user_id,
        student.full_name AS student_name,
        student.email AS student_email,
        b.mentor_id,
        b.plan_id,
        mp.duration_minutes,
        mp.price,
        mp.currency,
        b.scheduled_at,
        b.status,
        b.meeting_link,
        b.student_note,
        b.created_at
    FROM bookings b
    INNER JOIN users student
        ON student.user_id = b.student_user_id
    INNER JOIN mentor_plans mp
        ON mp.plan_id = b.plan_id
    WHERE b.mentor_id = v_mentor_id
    ORDER BY b.scheduled_at DESC, b.booking_id DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_my_mentor_expertise` (IN `p_user_id` BIGINT UNSIGNED)   BEGIN
    DECLARE v_mentor_id BIGINT UNSIGNED DEFAULT NULL;

    SELECT mentor_id
    INTO v_mentor_id
    FROM mentor_profiles
    WHERE user_id = p_user_id
    LIMIT 1;

    -- Result set 1: Selected countries
    SELECT
        c.country_id,
        c.country_name
    FROM mentor_countries mc
    INNER JOIN countries c
        ON c.country_id = mc.country_id
    WHERE mc.mentor_id = v_mentor_id
    ORDER BY c.country_name ASC;

    -- Result set 2: Selected universities
    SELECT
        un.university_id,
        un.country_id,
        un.university_name
    FROM mentor_universities mu
    INNER JOIN universities un
        ON un.university_id = mu.university_id
    WHERE mu.mentor_id = v_mentor_id
    ORDER BY un.university_name ASC;

    -- Result set 3: Consultation plans
    SELECT
        plan_id,
        duration_minutes,
        price,
        currency,
        is_active
    FROM mentor_plans
    WHERE mentor_id = v_mentor_id
    ORDER BY duration_minutes ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_my_mentor_profile` (IN `p_user_id` BIGINT UNSIGNED)   BEGIN
    DECLARE v_mentor_id BIGINT UNSIGNED DEFAULT NULL;

    SELECT mentor_id
    INTO v_mentor_id
    FROM mentor_profiles
    WHERE user_id = p_user_id
    LIMIT 1;

    -- Result set 1: Profile
    SELECT
        mentor_id,
        user_id,
        headline,
        bio,
        years_experience,
        profile_photo_path,
        cv_file_path,
        is_published,
        created_at,
        updated_at
    FROM mentor_profiles
    WHERE mentor_id = v_mentor_id;

    -- Result set 2: Consultation plans
    SELECT
        plan_id,
        mentor_id,
        duration_minutes,
        price,
        currency,
        is_active
    FROM mentor_plans
    WHERE mentor_id = v_mentor_id
    ORDER BY duration_minutes ASC;

    -- Result set 3: Countries
    SELECT
        c.country_id,
        c.country_name,
        c.slug
    FROM mentor_countries mc
    INNER JOIN countries c
        ON c.country_id = mc.country_id
    WHERE mc.mentor_id = v_mentor_id
    ORDER BY c.country_name ASC;

    -- Result set 4: Universities
    SELECT
        un.university_id,
        un.country_id,
        un.university_name
    FROM mentor_universities mu
    INNER JOIN universities un
        ON un.university_id = mu.university_id
    WHERE mu.mentor_id = v_mentor_id
    ORDER BY un.university_name ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_public_group_sessions` (IN `p_view` VARCHAR(10), IN `p_category_id` INT UNSIGNED, IN `p_student_user_id` BIGINT UNSIGNED)   BEGIN
    IF LOWER(p_view) NOT IN ('upcoming', 'past') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid session view.';
    END IF;

    SELECT
        gs.session_id,
        gs.category_id,
        sc.category_name,
        gs.mentor_id,
        u.full_name AS mentor_name,
        mp.headline AS mentor_headline,
        gs.title,
        gs.description,
        gs.starts_at,
        gs.ends_at,
        gs.capacity,
        gs.status,
        COUNT(DISTINCT CASE
            WHEN sr.status = 'registered' THEN sr.registration_id
        END) AS registered_count,
        CASE
            WHEN p_student_user_id IS NULL THEN 0
            WHEN EXISTS (
                SELECT 1
                FROM session_registrations mine
                WHERE mine.session_id = gs.session_id
                  AND mine.student_user_id = p_student_user_id
                  AND mine.status = 'registered'
            ) THEN 1
            ELSE 0
        END AS is_registered
    FROM group_sessions gs
    INNER JOIN session_categories sc
        ON sc.category_id = gs.category_id
    INNER JOIN mentor_profiles mp
        ON mp.mentor_id = gs.mentor_id
    INNER JOIN users u
        ON u.user_id = mp.user_id
    LEFT JOIN session_registrations sr
        ON sr.session_id = gs.session_id
    WHERE
        (p_category_id IS NULL OR gs.category_id = p_category_id)
        AND (
            (
                LOWER(p_view) = 'upcoming'
                AND gs.status = 'scheduled'
                AND gs.starts_at >= NOW()
            )
            OR
            (
                LOWER(p_view) = 'past'
                AND (
                    gs.ends_at < NOW()
                    OR gs.status = 'completed'
                )
            )
        )
    GROUP BY
        gs.session_id,
        gs.category_id,
        sc.category_name,
        gs.mentor_id,
        u.full_name,
        mp.headline,
        gs.title,
        gs.description,
        gs.starts_at,
        gs.ends_at,
        gs.capacity,
        gs.status
    ORDER BY
        CASE WHEN LOWER(p_view) = 'upcoming'
            THEN gs.starts_at END ASC,
        CASE WHEN LOWER(p_view) = 'past'
            THEN gs.starts_at END DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_role_by_name` (IN `p_role_name` VARCHAR(30))   BEGIN
    SELECT
        role_id,
        role_name
    FROM roles
    WHERE LOWER(role_name) = LOWER(TRIM(p_role_name))
    LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_session_categories` ()   BEGIN
    SELECT
        category_id,
        category_name
    FROM session_categories
    ORDER BY category_name ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_universities_by_country` (IN `p_country_id` INT UNSIGNED)   BEGIN
    SELECT
        university_id,
        country_id,
        university_name,
        external_api_id,
        website_url
    FROM universities
    WHERE country_id = p_country_id
    ORDER BY university_name ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_user_by_email` (IN `p_email` VARCHAR(190))   BEGIN
    SELECT
        u.user_id,
        u.full_name,
        u.email,
        u.password_hash,
        u.is_active,
        r.role_name
    FROM users u
    INNER JOIN roles r
        ON r.role_id = u.role_id
    WHERE u.email = LOWER(TRIM(p_email))
    LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_register_for_group_session` (IN `p_session_id` BIGINT UNSIGNED, IN `p_student_user_id` BIGINT UNSIGNED)   BEGIN
    DECLARE v_capacity INT UNSIGNED DEFAULT 0;
    DECLARE v_starts_at DATETIME DEFAULT NULL;
    DECLARE v_session_status VARCHAR(20) DEFAULT NULL;
    DECLARE v_role_id TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_is_active TINYINT DEFAULT 0;
    DECLARE v_registered_count INT DEFAULT 0;
    DECLARE v_existing_status VARCHAR(20) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT role_id, is_active
    INTO v_role_id, v_is_active
    FROM users
    WHERE user_id = p_student_user_id
    FOR UPDATE;

    IF v_role_id IS NULL OR v_role_id <> 1 OR v_is_active <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'An active student account is required.';
    END IF;

    SELECT capacity, starts_at, status
    INTO v_capacity, v_starts_at, v_session_status
    FROM group_sessions
    WHERE session_id = p_session_id
    FOR UPDATE;

    IF v_session_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Group session not found.';
    END IF;

    IF v_session_status <> 'scheduled' OR v_starts_at <= NOW() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Registration for this session is closed.';
    END IF;

    SELECT status
    INTO v_existing_status
    FROM session_registrations
    WHERE session_id = p_session_id
      AND student_user_id = p_student_user_id
    LIMIT 1;

    IF v_existing_status = 'registered' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'You are already registered for this session.';
    END IF;

    SELECT COUNT(*)
    INTO v_registered_count
    FROM session_registrations
    WHERE session_id = p_session_id
      AND status = 'registered';

    IF v_registered_count >= v_capacity THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'This group session is full.';
    END IF;

    IF v_existing_status = 'cancelled' THEN
        UPDATE session_registrations
        SET status = 'registered',
            registered_at = CURRENT_TIMESTAMP()
        WHERE session_id = p_session_id
          AND student_user_id = p_student_user_id;
    ELSE
        INSERT INTO session_registrations (
            session_id,
            student_user_id,
            status
        )
        VALUES (
            p_session_id,
            p_student_user_id,
            'registered'
        );
    END IF;

    COMMIT;

    SELECT
        registration_id,
        session_id,
        student_user_id,
        registered_at,
        status
    FROM session_registrations
    WHERE session_id = p_session_id
      AND student_user_id = p_student_user_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_save_my_mentor_expertise` (IN `p_user_id` BIGINT UNSIGNED, IN `p_country_ids` LONGTEXT, IN `p_university_ids` LONGTEXT, IN `p_plans` LONGTEXT)   BEGIN
    DECLARE v_mentor_id BIGINT UNSIGNED;
    DECLARE v_count INT DEFAULT 0;
    DECLARE v_i INT DEFAULT 0;
    DECLARE v_j INT DEFAULT 0;
    DECLARE v_len INT DEFAULT 0;
    DECLARE v_id BIGINT UNSIGNED;
    DECLARE v_country_id BIGINT UNSIGNED;
    DECLARE v_university_id BIGINT UNSIGNED;
    DECLARE v_plan_id BIGINT UNSIGNED;
    DECLARE v_duration INT;
    DECLARE v_price DECIMAL(10,2);
    DECLARE v_currency CHAR(3);
    DECLARE v_value VARCHAR(100);
    DECLARE v_plan LONGTEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    
    IF p_country_ids IS NULL OR JSON_VALID(p_country_ids) = 0
       OR JSON_TYPE(p_country_ids) <> 'ARRAY' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid country IDs JSON array.';
    END IF;

    IF p_university_ids IS NULL OR JSON_VALID(p_university_ids) = 0
       OR JSON_TYPE(p_university_ids) <> 'ARRAY' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid university IDs JSON array.';
    END IF;

    IF p_plans IS NULL OR JSON_VALID(p_plans) = 0
       OR JSON_TYPE(p_plans) <> 'ARRAY' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid consultation plans JSON array.';
    END IF;

    
    SELECT MAX(mentor_id)
    INTO v_mentor_id
    FROM mentor_profiles
    WHERE user_id = p_user_id;

    IF v_mentor_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Mentor profile not found.';
    END IF;

    
    SET v_i = 0;
    SET v_len = JSON_LENGTH(p_country_ids);

    WHILE v_i < v_len DO
        SET v_value = JSON_UNQUOTE(
            JSON_EXTRACT(p_country_ids, CONCAT('$[', v_i, ']'))
        );

        IF v_value IS NULL OR v_value NOT REGEXP '^[0-9]+$'
           OR CAST(v_value AS UNSIGNED) = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid country ID.';
        END IF;

        SET v_id = CAST(v_value AS UNSIGNED);

        SELECT COUNT(*) INTO v_count
        FROM countries
        WHERE country_id = v_id
          AND is_active = 1;

        IF v_count = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Selected country does not exist or is inactive.';
        END IF;

        SET v_i = v_i + 1;
    END WHILE;

    
    SET v_i = 0;
    SET v_len = JSON_LENGTH(p_university_ids);

    WHILE v_i < v_len DO
        SET v_value = JSON_UNQUOTE(
            JSON_EXTRACT(p_university_ids, CONCAT('$[', v_i, ']'))
        );

        IF v_value IS NULL OR v_value NOT REGEXP '^[0-9]+$'
           OR CAST(v_value AS UNSIGNED) = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid university ID.';
        END IF;

        SET v_university_id = CAST(v_value AS UNSIGNED);

        SELECT MAX(country_id) INTO v_country_id
        FROM universities
        WHERE university_id = v_university_id;

        IF v_country_id IS NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Selected university does not exist.';
        END IF;

        SELECT COUNT(*) INTO v_count
        FROM countries
        WHERE country_id = v_country_id
          AND is_active = 1;

        IF v_count = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'University country is inactive or unavailable.';
        END IF;

        SELECT COUNT(*) INTO v_count
        FROM JSON_TABLE_PLACEHOLDER
        WHERE 1 = 0;

        SET v_j = 0;

        WHILE v_j < JSON_LENGTH(p_country_ids) DO
            IF CAST(
                JSON_UNQUOTE(
                    JSON_EXTRACT(p_country_ids, CONCAT('$[', v_j, ']'))
                ) AS UNSIGNED
            ) = v_country_id THEN
                SET v_count = 1;
            END IF;

            SET v_j = v_j + 1;
        END WHILE;

        IF v_count = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'University country must be selected first.';
        END IF;

        SET v_count = 0;
        SET v_i = v_i + 1;
    END WHILE;

    
    SET v_i = 0;
    SET v_len = JSON_LENGTH(p_plans);

    WHILE v_i < v_len DO
        SET v_plan = JSON_EXTRACT(
            p_plans, CONCAT('$[', v_i, ']')
        );

        IF JSON_TYPE(v_plan) <> 'OBJECT' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid consultation plan.';
        END IF;

        SET v_duration = CAST(
            JSON_UNQUOTE(JSON_EXTRACT(v_plan, '$.duration_minutes'))
            AS UNSIGNED
        );

        SET v_price = CAST(
            JSON_UNQUOTE(JSON_EXTRACT(v_plan, '$.price'))
            AS DECIMAL(10,2)
        );

        SET v_currency = UPPER(COALESCE(
            JSON_UNQUOTE(JSON_EXTRACT(v_plan, '$.currency')),
            'BDT'
        ));

        IF v_duration NOT IN (20, 40)
           OR v_price IS NULL
           OR v_price < 0
           OR v_currency NOT REGEXP '^[A-Z]{3}$' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid consultation plan details.';
        END IF;

        
        SET v_j = 0;

        WHILE v_j < v_i DO
            IF CAST(
                JSON_UNQUOTE(
                    JSON_EXTRACT(
                        p_plans,
                        CONCAT('$[', v_j, '].duration_minutes')
                    )
                ) AS UNSIGNED
            ) = v_duration THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Duplicate consultation duration.';
            END IF;

            SET v_j = v_j + 1;
        END WHILE;

        SET v_i = v_i + 1;
    END WHILE;

    
    START TRANSACTION;

    
    DELETE FROM mentor_countries
    WHERE mentor_id = v_mentor_id;

    SET v_i = 0;
    SET v_len = JSON_LENGTH(p_country_ids);

    WHILE v_i < v_len DO
        SET v_id = CAST(
            JSON_UNQUOTE(
                JSON_EXTRACT(p_country_ids, CONCAT('$[', v_i, ']'))
            ) AS UNSIGNED
        );

        INSERT INTO mentor_countries (mentor_id, country_id)
        VALUES (v_mentor_id, v_id);

        SET v_i = v_i + 1;
    END WHILE;

    
    DELETE FROM mentor_universities
    WHERE mentor_id = v_mentor_id;

    SET v_i = 0;
    SET v_len = JSON_LENGTH(p_university_ids);

    WHILE v_i < v_len DO
        SET v_id = CAST(
            JSON_UNQUOTE(
                JSON_EXTRACT(p_university_ids, CONCAT('$[', v_i, ']'))
            ) AS UNSIGNED
        );

        INSERT INTO mentor_universities (mentor_id, university_id)
        VALUES (v_mentor_id, v_id);

        SET v_i = v_i + 1;
    END WHILE;

    
    UPDATE mentor_plans
    SET is_active = 0
    WHERE mentor_id = v_mentor_id
      AND duration_minutes IN (20, 40);

    
    SET v_i = 0;
    SET v_len = JSON_LENGTH(p_plans);

    WHILE v_i < v_len DO
        SET v_plan = JSON_EXTRACT(
            p_plans, CONCAT('$[', v_i, ']')
        );

        SET v_duration = CAST(
            JSON_UNQUOTE(JSON_EXTRACT(v_plan, '$.duration_minutes'))
            AS UNSIGNED
        );

        SET v_price = CAST(
            JSON_UNQUOTE(JSON_EXTRACT(v_plan, '$.price'))
            AS DECIMAL(10,2)
        );

        SET v_currency = UPPER(COALESCE(
            JSON_UNQUOTE(JSON_EXTRACT(v_plan, '$.currency')),
            'BDT'
        ));

        SELECT MAX(plan_id) INTO v_plan_id
        FROM mentor_plans
        WHERE mentor_id = v_mentor_id
          AND duration_minutes = v_duration;

        IF v_plan_id IS NULL THEN
            INSERT INTO mentor_plans (
                mentor_id,
                duration_minutes,
                price,
                currency,
                is_active
            )
            VALUES (
                v_mentor_id,
                v_duration,
                v_price,
                v_currency,
                1
            );
        ELSE
            UPDATE mentor_plans
            SET price = v_price,
                currency = v_currency,
                is_active = 1
            WHERE plan_id = v_plan_id;
        END IF;

        SET v_i = v_i + 1;
    END WHILE;

    COMMIT;

    SELECT 'Mentor expertise and consultation plans saved successfully.'
    AS message;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_update_my_mentor_profile` (IN `p_user_id` BIGINT UNSIGNED, IN `p_headline` VARCHAR(180), IN `p_bio` TEXT, IN `p_years_experience` TINYINT UNSIGNED)   BEGIN
    UPDATE mentor_profiles
    SET
        headline = p_headline,
        bio = p_bio,
        years_experience = p_years_experience,
        updated_at = CURRENT_TIMESTAMP
    WHERE user_id = p_user_id;

    SELECT 'Mentor profile updated successfully.' AS message;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `bookings`
--

CREATE TABLE `bookings` (
  `booking_id` bigint(20) UNSIGNED NOT NULL,
  `student_user_id` bigint(20) UNSIGNED NOT NULL,
  `mentor_id` bigint(20) UNSIGNED NOT NULL,
  `plan_id` bigint(20) UNSIGNED NOT NULL,
  `scheduled_at` datetime NOT NULL,
  `status` enum('pending','confirmed','cancelled','completed') NOT NULL DEFAULT 'pending',
  `meeting_link` varchar(500) DEFAULT NULL,
  `student_note` varchar(1000) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `bookings`
--

INSERT INTO `bookings` (`booking_id`, `student_user_id`, `mentor_id`, `plan_id`, `scheduled_at`, `status`, `meeting_link`, `student_note`, `created_at`) VALUES
(1, 2, 1, 1, '2026-11-04 22:34:00', 'pending', NULL, 'Hello!', '2026-11-03 16:34:32');

-- --------------------------------------------------------

--
-- Table structure for table `countries`
--

CREATE TABLE `countries` (
  `country_id` int(10) UNSIGNED NOT NULL,
  `country_name` varchar(100) NOT NULL,
  `slug` varchar(120) NOT NULL,
  `page_title` varchar(180) NOT NULL,
  `page_description` varchar(500) NOT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `countries`
--

INSERT INTO `countries` (`country_id`, `country_name`, `slug`, `page_title`, `page_description`, `is_active`) VALUES
(1, 'United States', 'united-states', 'Study in the United States', 'Explore universities, scholarships and study opportunities in the United States.', 1),
(2, 'United Kingdom', 'united-kingdom', 'Study in the United Kingdom', 'Discover UK universities and scholarship opportunities.', 1),
(3, 'Canada', 'canada', 'Study in Canada', 'Explore Canadian universities and study opportunities.', 1),
(4, 'Australia', 'australia', 'Study in Australia', 'Find Australian universities and scholarship opportunities.', 1),
(5, 'Germany', 'germany', 'Study in Germany', 'Discover German universities and study opportunities.', 1);

-- --------------------------------------------------------

--
-- Table structure for table `faqs`
--

CREATE TABLE `faqs` (
  `faq_id` int(10) UNSIGNED NOT NULL,
  `question` varchar(500) NOT NULL,
  `answer` text NOT NULL,
  `display_order` int(11) NOT NULL DEFAULT 0,
  `is_published` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `group_sessions`
--

CREATE TABLE `group_sessions` (
  `session_id` bigint(20) UNSIGNED NOT NULL,
  `category_id` int(10) UNSIGNED NOT NULL,
  `mentor_id` bigint(20) UNSIGNED NOT NULL,
  `title` varchar(180) NOT NULL,
  `description` text DEFAULT NULL,
  `starts_at` datetime NOT NULL,
  `ends_at` datetime NOT NULL,
  `capacity` int(10) UNSIGNED NOT NULL,
  `meeting_link` varchar(500) DEFAULT NULL,
  `status` enum('scheduled','cancelled','completed') NOT NULL DEFAULT 'scheduled',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ;

--
-- Dumping data for table `group_sessions`
--

INSERT INTO `group_sessions` (`session_id`, `category_id`, `mentor_id`, `title`, `description`, `starts_at`, `ends_at`, `capacity`, `meeting_link`, `status`, `created_at`) VALUES
(1, 2, 1, 'How to apply Canada University.', 'Students will be able to learn about all the processes.', '2026-11-04 07:00:00', '2026-11-04 08:00:00', 20, 'https://meet.google.com/jwb-onrb-guc', 'scheduled', '2026-11-03 17:02:11'),
(2, 1, 1, 'Session for how to apply Monroe College', 'Students will be able to learn about all the processes involved in university admission.', '2026-11-10 16:00:00', '2026-11-11 18:00:00', 25, 'https://meet.google.com/jvy-trvy-brv', 'scheduled', '2026-11-04 06:58:53');

-- --------------------------------------------------------

--
-- Table structure for table `mentor_countries`
--

CREATE TABLE `mentor_countries` (
  `mentor_id` bigint(20) UNSIGNED NOT NULL,
  `country_id` int(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `mentor_countries`
--

INSERT INTO `mentor_countries` (`mentor_id`, `country_id`) VALUES
(1, 1);

-- --------------------------------------------------------

--
-- Table structure for table `mentor_plans`
--

CREATE TABLE `mentor_plans` (
  `plan_id` bigint(20) UNSIGNED NOT NULL,
  `mentor_id` bigint(20) UNSIGNED NOT NULL,
  `duration_minutes` smallint(5) UNSIGNED NOT NULL,
  `price` decimal(10,2) NOT NULL,
  `currency` char(3) NOT NULL DEFAULT 'USD',
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ;

--
-- Dumping data for table `mentor_plans`
--

INSERT INTO `mentor_plans` (`plan_id`, `mentor_id`, `duration_minutes`, `price`, `currency`, `is_active`, `created_at`) VALUES
(1, 1, 20, 200.00, 'BDT', 1, '2026-11-03 14:40:28'),
(2, 1, 40, 400.00, 'BDT', 1, '2026-11-03 14:40:28');

-- --------------------------------------------------------

--
-- Table structure for table `mentor_profiles`
--

CREATE TABLE `mentor_profiles` (
  `mentor_id` bigint(20) UNSIGNED NOT NULL,
  `user_id` bigint(20) UNSIGNED NOT NULL,
  `headline` varchar(180) DEFAULT NULL,
  `bio` text DEFAULT NULL,
  `years_experience` tinyint(3) UNSIGNED NOT NULL DEFAULT 0,
  `profile_photo_path` varchar(500) DEFAULT NULL,
  `cv_file_path` varchar(500) DEFAULT NULL,
  `is_published` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `mentor_profiles`
--

INSERT INTO `mentor_profiles` (`mentor_id`, `user_id`, `headline`, `bio`, `years_experience`, `profile_photo_path`, `cv_file_path`, `is_published`, `created_at`, `updated_at`) VALUES
(1, 1, NULL, NULL, 5, 'uploads/mentor-photos/1793717910320-c7633aa8-57c2-403a-8391-9c31d7f8896d.jpg', 'uploads/mentor-cvs/1793717912082-513b5b7d-c119-4058-a5d9-a7825cd14c81.pdf', 1, '2026-11-03 11:04:34', '2026-11-05 14:17:17'),
(2, 4, NULL, NULL, 0, NULL, NULL, 0, '2026-11-05 17:19:22', '2026-11-05 17:19:22');

-- --------------------------------------------------------

--
-- Table structure for table `mentor_programs`
--

CREATE TABLE `mentor_programs` (
  `mentor_id` bigint(20) UNSIGNED NOT NULL,
  `program_id` int(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `mentor_programs`
--

INSERT INTO `mentor_programs` (`mentor_id`, `program_id`) VALUES
(1, 17);

-- --------------------------------------------------------

--
-- Table structure for table `mentor_scholarships`
--

CREATE TABLE `mentor_scholarships` (
  `mentor_id` bigint(20) UNSIGNED NOT NULL,
  `scholarship_id` bigint(20) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `mentor_services`
--

CREATE TABLE `mentor_services` (
  `mentor_id` bigint(20) UNSIGNED NOT NULL,
  `service_id` int(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `mentor_services`
--

INSERT INTO `mentor_services` (`mentor_id`, `service_id`) VALUES
(1, 1),
(1, 2);

-- --------------------------------------------------------

--
-- Table structure for table `mentor_universities`
--

CREATE TABLE `mentor_universities` (
  `mentor_id` bigint(20) UNSIGNED NOT NULL,
  `university_id` bigint(20) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `mentor_universities`
--

INSERT INTO `mentor_universities` (`mentor_id`, `university_id`) VALUES
(1, 1425);

-- --------------------------------------------------------

--
-- Table structure for table `programs`
--

CREATE TABLE `programs` (
  `program_id` int(10) UNSIGNED NOT NULL,
  `program_name` varchar(150) NOT NULL,
  `degree_level` varchar(60) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `programs`
--

INSERT INTO `programs` (`program_id`, `program_name`, `degree_level`, `is_active`) VALUES
(17, 'Computer Science - Bachelor', 'Bachelor', 1),
(18, 'Computer Science - Master', 'Master', 1),
(19, 'Business Administration - Bachelor', 'Bachelor', 1),
(20, 'Business Administration - Master', 'Master', 1),
(21, 'Electrical Engineering - Bachelor', 'Bachelor', 1),
(22, 'Data Science - Master', 'Master', 1),
(23, 'Public Health - Master', 'Master', 1),
(24, 'Civil Engineering - Bachelor', 'Bachelor', 1);

-- --------------------------------------------------------

--
-- Table structure for table `reviews`
--

CREATE TABLE `reviews` (
  `review_id` bigint(20) UNSIGNED NOT NULL,
  `booking_id` bigint(20) UNSIGNED NOT NULL,
  `student_user_id` bigint(20) UNSIGNED NOT NULL,
  `mentor_id` bigint(20) UNSIGNED NOT NULL,
  `rating` tinyint(3) UNSIGNED NOT NULL,
  `review_text` varchar(2000) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ;

-- --------------------------------------------------------

--
-- Table structure for table `roles`
--

CREATE TABLE `roles` (
  `role_id` tinyint(3) UNSIGNED NOT NULL,
  `role_name` varchar(30) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `roles`
--

INSERT INTO `roles` (`role_id`, `role_name`) VALUES
(2, 'Mentor'),
(1, 'Student');

-- --------------------------------------------------------

--
-- Table structure for table `scholarships`
--

CREATE TABLE `scholarships` (
  `scholarship_id` bigint(20) UNSIGNED NOT NULL,
  `country_id` int(10) UNSIGNED DEFAULT NULL,
  `scholarship_name` varchar(180) NOT NULL,
  `provider_name` varchar(180) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `application_url` varchar(500) DEFAULT NULL,
  `deadline` date DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `scholarships`
--

INSERT INTO `scholarships` (`scholarship_id`, `country_id`, `scholarship_name`, `provider_name`, `description`, `application_url`, `deadline`, `is_active`) VALUES
(1, 1, 'Australia Awards Scholarships', 'Australian Government', 'Scholarship support for eligible international students.', 'https://www.dfat.gov.au/people-to-people/australia-awards', NULL, 1),
(2, 2, 'Chevening Scholarships', 'UK Government', 'Scholarships for eligible international students studying in the UK.', 'https://www.chevening.org/', NULL, 1),
(3, 3, 'Vanier Canada Graduate Scholarships', 'Government of Canada', 'Graduate scholarship program for eligible doctoral students.', 'https://vanier.gc.ca/', NULL, 1),
(4, 4, 'DAAD Scholarships', 'DAAD', 'Scholarship opportunities for international students in Germany.', 'https://www.daad.de/en/', NULL, 1),
(5, 5, 'Fulbright Foreign Student Program', 'Fulbright Program', 'Scholarship opportunities for international graduate students in the United States.', 'https://foreign.fulbrightonline.org/', NULL, 1);

-- --------------------------------------------------------

--
-- Table structure for table `services`
--

CREATE TABLE `services` (
  `service_id` int(10) UNSIGNED NOT NULL,
  `service_name` varchar(120) NOT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `services`
--

INSERT INTO `services` (`service_id`, `service_name`, `is_active`) VALUES
(1, 'University Selection', 1),
(2, 'Application Guidance', 1),
(3, 'Scholarship Guidance', 1),
(4, 'Visa Guidance', 1),
(5, 'Personal Statement Review', 1);

-- --------------------------------------------------------

--
-- Table structure for table `session_categories`
--

CREATE TABLE `session_categories` (
  `category_id` int(10) UNSIGNED NOT NULL,
  `category_name` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `session_categories`
--

INSERT INTO `session_categories` (`category_id`, `category_name`) VALUES
(2, 'Scholarships'),
(4, 'Student Life'),
(1, 'University Applications'),
(3, 'Visa & Immigration');

-- --------------------------------------------------------

--
-- Table structure for table `session_registrations`
--

CREATE TABLE `session_registrations` (
  `registration_id` bigint(20) UNSIGNED NOT NULL,
  `session_id` bigint(20) UNSIGNED NOT NULL,
  `student_user_id` bigint(20) UNSIGNED NOT NULL,
  `registered_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `status` enum('registered','cancelled','attended') NOT NULL DEFAULT 'registered'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `session_registrations`
--

INSERT INTO `session_registrations` (`registration_id`, `session_id`, `student_user_id`, `registered_at`, `status`) VALUES
(1, 1, 2, '2026-11-03 17:47:16', 'registered'),
(2, 2, 2, '2026-11-04 06:59:42', 'registered');

-- --------------------------------------------------------

--
-- Table structure for table `universities`
--

CREATE TABLE `universities` (
  `university_id` bigint(20) UNSIGNED NOT NULL,
  `country_id` int(10) UNSIGNED NOT NULL,
  `university_name` varchar(180) NOT NULL,
  `external_api_id` varchar(255) DEFAULT NULL,
  `website_url` varchar(500) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `universities`
--

INSERT INTO `universities` (`university_id`, `country_id`, `university_name`, `external_api_id`, `website_url`) VALUES
(1, 1, 'Marywood University', 'marywood.edu', 'http://www.marywood.edu/'),
(2, 1, 'Lindenwood University', 'lindenwood.edu', 'http://www.lindenwood.edu/'),
(3, 1, 'Sullivan University', 'sullivan.edu', 'https://sullivan.edu/'),
(4, 1, 'Florida State College at Jacksonville', 'fscj.edu', 'https://www.fscj.edu/'),
(5, 1, 'Xavier University', 'xavier.edu', 'https://www.xavier.edu/'),
(6, 1, 'Tusculum College', 'tusculum.edu', 'https://home.tusculum.edu/'),
(7, 1, 'Claremont School of Theology', 'cst.edu', 'https://cst.edu/'),
(8, 1, 'Columbia College (SC)', 'columbiasc.edu', 'https://www.columbiasc.edu/'),
(9, 1, 'Chabot-Las Positas Community College District', 'clpccd.edu', 'http://www.clpccd.edu/'),
(10, 1, 'Keller Graduate School of Management', 'keller.edu', 'https://www.keller.edu/'),
(11, 1, 'Monroe College', 'monroecollege.edu', 'https://monroecollege.edu/'),
(12, 1, 'San Mateo County Community College District', 'smccd.edu', 'https://smccd.edu/'),
(13, 1, 'Los Rios Community College District', 'losrios.edu', 'http://losrios.edu/'),
(14, 1, 'DigiPen Institute of Technology', 'digipen.edu', 'https://www.digipen.edu/'),
(15, 1, 'University of Pittsburgh Medical Center', 'upmc.edu', 'https://www.upmc.com/'),
(16, 1, 'Claremont Graduate University', 'cgu.edu', 'https://www.cgu.edu/'),
(17, 1, 'The University of Texas at Rio Grande Valley', 'utrgv.edu', 'https://www.utrgv.edu/'),
(18, 1, 'College of Mount Saint Vincent', 'mountsaintvincent.edu', 'https://mountsaintvincent.edu/'),
(19, 1, 'University of Arkansas System eVersity', 'uasys.edu', 'https://www.uasys.edu/'),
(20, 1, 'ECPI University', 'ecpi.edu', 'https://www.ecpi.edu/'),
(21, 1, 'University of Mary Washington', 'umw.edu', 'https://www.umw.edu/'),
(22, 1, 'Baldwin Wallace University', 'bw.edu', 'https://www.bw.edu/'),
(23, 1, 'California State University Channel Islands', 'csuci.edu', 'https://www.csuci.edu/'),
(24, 1, 'Brandman University', 'brandman.edu', 'https://www.brandman.edu/'),
(25, 1, 'United States Coast Guard Academy', 'uscga.edu', 'http://www.uscga.edu/'),
(26, 1, 'Athens State University', 'athens.edu', 'http://www.athens.edu/'),
(27, 1, 'The Scripps Research Institute', 'scripps.edu', 'https://scripps.edu/'),
(28, 1, 'Eastern Florida State College', 'easternflorida.edu', 'http://www.easternflorida.edu/'),
(29, 1, 'Western New England University', 'wne.edu', 'http://www1.wne.edu/'),
(30, 1, 'King University', 'king.edu', 'https://king.edu/'),
(31, 1, 'Georgia Gwinnett College', 'ggc.edu', 'https://ggc.edu/'),
(32, 1, 'Trident University', 'trident.edu', 'https://www.trident.edu/'),
(33, 1, 'Alliant International University', 'alliant.edu', 'https://www.alliant.edu/'),
(34, 1, 'Mississippi Valley State University', 'mvsu.edu', 'https://mvsu.edu/'),
(35, 1, 'Roosevelt University', 'roosevelt.edu', 'https://www.roosevelt.edu/'),
(36, 1, 'ITT Technical Institute', 'itt-tech.info', 'http://itt-tech.info/'),
(37, 1, 'Illinois Eastern Community Colleges', 'iecc.edu', 'https://iecc.edu/'),
(38, 1, 'Park University', 'park.edu', 'https://park.edu/'),
(39, 1, 'Icahn School of Medicine at Mount Sinai', 'mssm.edu', 'http://icahn.mssm.edu/'),
(40, 1, 'Utah Valley University', 'uvu.edu', 'https://uvu.edu/'),
(41, 1, 'Wisconsin Lutheran College', 'wlc.edu', 'http://www.wlc.edu/'),
(42, 1, 'Riverside Community College District', 'rccd.edu', 'http://www.rccd.edu/'),
(43, 1, 'Wake Forest Baptist Health', 'wakehealth.edu', 'http://www.wakehealth.edu/'),
(44, 1, 'University of Massachusetts Boston', 'umb.edu', 'https://www.umb.edu/'),
(45, 1, 'Florida Polytechnic University', 'floridapoly.edu', 'https://floridapoly.edu/'),
(46, 1, 'Wagner College', 'wagner.edu', 'https://wagner.edu/'),
(47, 1, 'Wilmington University', 'wilmu.edu', 'https://www.wilmu.edu/'),
(48, 1, 'International Technological University', 'itu.edu', 'https://itu.edu/'),
(49, 1, 'Young Harris College', 'yhc.edu', 'https://www.yhc.edu/'),
(50, 1, 'University of Findlay', 'findlay.edu', 'https://www.findlay.edu/'),
(51, 1, 'Philadelphia College of Osteopathic Medicine', 'pcom.edu', 'https://www.pcom.edu/'),
(52, 1, 'Yosemite Community College District', 'yosemite.edu', 'https://www.yosemite.edu/'),
(53, 1, 'Coastal Alabama Community College', 'coastalalabama.edu', 'http://www.coastalalabama.edu/'),
(54, 1, 'Purdue University Northwest', 'pnw.edu', 'https://www.pnw.edu/'),
(55, 1, 'Columbia Basin College', 'columbiabasin.edu', 'http://www.columbiabasin.edu/'),
(56, 1, 'Seattle Colleges', 'seattlecolleges.edu', 'https://www.seattlecolleges.edu/'),
(57, 1, 'Lipscomb University', 'lipscomb.edu', 'https://www.lipscomb.edu/'),
(58, 1, 'Tiffin University', 'tiffin.edu', 'http://www.tiffin.edu/'),
(59, 1, 'Troy University', 'troy.edu', 'https://troy.edu/'),
(60, 1, '42 US', 'student.42.us.org', 'http://www.42.us.org/'),
(61, 1, 'California Baptist University', 'calbaptist.edu', 'http://www.calbaptist.edu/'),
(62, 1, 'Stevenson University', 'stevenson.edu', 'http://www.stevenson.edu/'),
(63, 1, 'Marine Biological Laboratory', 'mbl.edu', 'http://www.mbl.edu/'),
(64, 1, 'Maryville University', 'maryville.edu', 'http://www.maryville.edu/'),
(65, 1, 'The Art Institutes', 'aii.edu', 'http://www.aii.edu/'),
(66, 1, 'University of Mississippi Medical Center', 'umc.edu', 'http://www.umc.edu/'),
(67, 1, 'University of Central Oklahoma', 'uco.edu', 'http://www.uco.edu/'),
(68, 1, 'Hallmark University', 'hallmarkuniversity.edu', 'http://www.hallmarkuniversity.edu/'),
(69, 1, 'Keiser University', 'keiseruniversity.edu', 'http://www.keiseruniversity.edu/'),
(70, 1, 'St. Johns River State College', 'sjrstate.edu', 'http://www.sjrstate.edu/'),
(71, 1, 'Indian River State College', 'irsc.edu', 'http://www.irsc.edu/'),
(72, 1, 'Barnard College', 'barnard.edu', 'http://www.barnard.edu/'),
(73, 1, 'California Southern University', 'calsouthern.edu', 'http://www.calsouthern.edu/'),
(74, 1, 'University of La Verne', 'laverne.edu', 'http://www.laverne.edu/'),
(75, 1, 'Washington & Jefferson College', 'washjeff.edu', 'http://www.washjeff.edu/'),
(76, 1, 'University of the People', 'uopeople.edu', 'http://www.uopeople.edu/'),
(77, 1, 'Touro College', 'touro.edu', 'http://www.touro.edu/'),
(78, 1, 'New Jersey City University', 'njcu.edu', 'http://www.njcu.edu/'),
(79, 1, 'Lander University', 'lander.edu', 'http://www.lander.edu/'),
(80, 1, 'SUNY Maritime College', 'sunymaritime.edu', 'http://www.sunymaritime.edu/'),
(81, 1, 'Lesley University', 'lesley.edu', 'http://www.lesley.edu/'),
(82, 1, 'Laurus College', 'lauruscollege.edu', 'http://www.lauruscollege.edu/'),
(83, 1, 'National Park College', 'np.edu', 'http://www.np.edu/'),
(84, 1, 'Oklahoma Christian University', 'oc.edu', 'http://www.oc.edu/'),
(85, 1, 'San Diego Christian College', 'sdcc.edu', 'http://www.sdcc.edu/'),
(86, 1, 'SANS Technology Institute', 'sans.edu', 'http://www.sans.edu/'),
(87, 1, 'Pasco-Hernando State College', 'phsc.edu', 'http://www.phsc.edu/'),
(88, 1, 'New College of Florida', 'ncf.edu', 'http://www.ncf.edu/'),
(89, 1, 'Grand Canyon University', 'gcu.edu', 'http://www.gcu.edu/'),
(90, 1, 'Cold Spring Harbor Laboratory', 'cshl.edu', 'http://www.cshl.edu/'),
(91, 1, 'Albany State University', 'asurams.edu', 'http://www.asurams.edu/'),
(92, 1, 'Lasell College', 'lasell.edu', 'http://www.lasell.edu/'),
(93, 1, 'Contra Costa Community College District', '4cd.edu', 'http://www.4cd.edu/'),
(94, 1, 'Mount St. Mary\'s University', 'msmary.edu', 'http://www.msmary.edu/'),
(95, 1, 'Robert Morris University Illinois', 'robertmorris.edu', 'http://www.robertmorris.edu/'),
(96, 1, 'Northwest Florida State College', 'nwfsc.edu', 'http://www.nwfsc.edu/'),
(97, 1, 'West Virginia Wesleyan College', 'wvwc.edu', 'http://www.wvwc.edu/'),
(98, 1, 'Utica College', 'utica.edu', 'http://www.utica.edu/'),
(99, 1, 'Career College of Northern Nevada', 'ccnn.edu', 'http://www.ccnn.edu/'),
(100, 1, 'College of Southern Nevada', 'csn.edu', 'https://www.csn.edu/'),
(101, 1, 'University of North Georgia', 'ung.edu', 'http://www.ung.edu/'),
(102, 1, 'The Principia', 'principia.edu', 'http://www.principia.edu/'),
(103, 1, 'Lynn University', 'lynn.edu', 'http://www.lynn.edu/'),
(104, 1, 'Colorado Community College System', 'cccs.edu', 'http://www.cccs.edu/'),
(105, 1, 'Valencia College', 'valenciacollege.edu', 'http://www.valenciacollege.edu/'),
(106, 1, 'St. Petersburg College', 'spcollege.edu', 'http://www.spcollege.edu/'),
(107, 1, 'Globe University & Minnesota School of Business', 'msbcollege.edu', 'http://www.msbcollege.edu/'),
(108, 1, 'Everest College', 'everest.edu', 'http://www.everest.edu/'),
(109, 1, 'Southwest Research Institute', 'swri.edu', 'http://www.swri.edu/'),
(110, 1, 'American Public University System', 'apus.edu', 'http://www.apus.edu/'),
(111, 1, 'Full Sail University', 'fullsail.edu', 'http://www.fullsail.edu/'),
(112, 1, 'YTI Career Institute', 'yti.edu', 'http://www.yti.edu/'),
(113, 1, 'Defense Language Institute Foreign Language Center', 'dliflc.edu', 'http://www.dliflc.edu/'),
(114, 1, 'Columbus State University', 'columbusstate.edu', 'http://www.columbusstate.edu/'),
(115, 1, 'Morehead State University', 'moreheadstate.edu', 'http://www.moreheadstate.edu/'),
(116, 1, 'Colorado State University - Global Campus', 'csuglobal.edu', 'http://www.csuglobal.edu/'),
(117, 1, 'North Dakota University System', 'ndus.edu', 'http://www.ndus.edu/'),
(118, 1, 'University of Houston-Downtown', 'uhd.edu', 'http://www.uhd.edu/'),
(119, 1, 'Stratford University', 'stratford.edu', 'http://www.stratford.edu/'),
(120, 1, 'California Polytechnic State University, Pomona', 'cpp.edu', 'http://www.cpp.edu/'),
(121, 1, 'Baker College', 'baker.edu', 'http://www.baker.edu/'),
(122, 1, 'The College of New Jersey', 'tcnj.edu', 'http://www.tcnj.edu/'),
(123, 1, 'Abilene Christian University', 'acu.edu', 'http://www.acu.edu/'),
(124, 1, 'A.T. Still University', 'atsu.edu', 'https://www.atsu.edu/'),
(125, 1, 'Adelphi University', 'adelphi.edu', 'http://www.adelphi.edu/'),
(126, 1, 'Agnes Scott College', 'agnesscott.edu', 'http://www.agnesscott.edu/'),
(127, 1, 'Aiken Technical College', 'atc.edu', 'http://www.atc.edu/'),
(128, 1, 'Air Force Institute of Technology', 'afit.edu', 'http://www.afit.edu/'),
(129, 1, 'Alabama A&M University', 'aamu.edu', 'http://www.aamu.edu/'),
(130, 1, 'Alabama State University', 'alasu.edu', 'http://www.alasu.edu/'),
(131, 1, 'Alamo Colleges', 'aloma.edu', 'http://www.alamo.edu/'),
(132, 1, 'Albertson College of Idaho', 'acofi.edu', 'http://www.acofi.edu/'),
(133, 1, 'Albion College', 'albion.edu', 'http://www.albion.edu/'),
(134, 1, 'Alfred University', 'alfred.edu', 'http://www.alfred.edu/'),
(135, 1, 'Allegheny College', 'alleg.edu', 'http://www.alleg.edu/'),
(136, 1, 'Allentown College of Saint Francis de Sales', 'allencol.edu', 'http://www.allencol.edu/'),
(137, 1, 'Alma College', 'alma.edu', 'http://www.alma.edu/'),
(138, 1, 'Alverno College', 'alverno.edu', 'http://www.alverno.edu/'),
(139, 1, 'Ambassador University', 'ambassador.edu', 'http://www.ambassador.edu/'),
(140, 1, 'American Coastline University', 'amercoastuniv.edu', 'http://www.amercoastuniv.edu/'),
(141, 1, 'American International College', 'aic.edu', 'http://www.aic.edu/'),
(142, 1, 'American University', 'american.edu', 'http://www.american.edu/'),
(143, 1, 'Amherst College', 'amherst.edu', 'http://www.amherst.edu/'),
(144, 1, 'Andrews University', 'andrews.edu', 'http://www.andrews.edu/'),
(145, 1, 'Angelo State University', 'angelo.edu', 'http://www.angelo.edu/'),
(146, 1, 'Anne Arundel Community College', 'aacc.edu', 'http://www.aacc.edu/'),
(147, 1, 'Antioch New England', 'antiochne.edu', 'http://www.antiochne.edu/'),
(148, 1, 'Antioch University', 'antioch.edu', 'http://www.antioch.edu/'),
(149, 1, 'Antioch University - Los Angeles', 'antiochla.edu', 'http://www.antiochla.edu/'),
(150, 1, 'Antioch University - Seattle', 'seattleantioch.edu', 'http://www.seattleantioch.edu/'),
(151, 1, 'Appalachian State University', 'appstate.edu', 'http://www.appstate.edu/'),
(152, 1, 'Aquinas College', 'aquinas.edu', 'http://www.aquinas.edu/'),
(153, 1, 'Arcadia College', 'arcadia.edu', 'http://www.arcadia.edu/'),
(154, 1, 'Arizona State University', 'asu.edu', 'http://www.asu.edu/'),
(155, 1, 'Arizona Western College', 'azwestern.edu', 'http://www.azwestern.edu/'),
(156, 1, 'Arkansas State University', 'astate.edu', 'http://www.astate.edu/'),
(157, 1, 'Arkansas Tech University', 'atu.edu', 'http://www.atu.edu/'),
(158, 1, 'Armstrong State College', 'armstrong.edu', 'http://www.armstrong.edu/'),
(159, 1, 'Ashland University', 'ashland.edu', 'http://www.ashland.edu/'),
(160, 1, 'Assumption College', 'assumption.edu', 'http://www.assumption.edu/'),
(161, 1, 'Auburn University', 'auburn.edu', 'http://www.auburn.edu/'),
(162, 1, 'Auburn University at Montgomery', 'aum.edu', 'http://www.aum.edu/'),
(163, 1, 'Augsburg College', 'augsburg.edu', 'http://www.augsburg.edu/'),
(164, 1, 'Augustana College (IL)', 'augustana.edu', 'http://www.augustana.edu/'),
(165, 1, 'Augustana College (SD)', 'augie.edu', 'http://www.augie.edu/'),
(166, 1, 'Augusta University', 'augusta.edu', 'http://www.augusta.edu/'),
(167, 1, 'Aurora University', 'aurora.edu', 'http://www.aurora.edu/'),
(168, 1, 'Austin College', 'austincollege.edu', 'http://www.austincollege.edu/'),
(169, 1, 'Austin Community College', 'austincc.edu', 'http://www.austincc.edu/'),
(170, 1, 'Austin Peay State University', 'apsu.edu', 'http://www.apsu.edu/'),
(171, 1, 'Averett College', 'averett.edu', 'http://www.averett.edu/'),
(172, 1, 'Avila College', 'avila.edu', 'http://www.avila.edu/'),
(173, 1, 'Azusa Pacific University', 'apu.edu', 'http://www.apu.edu/'),
(174, 1, 'Babson College', 'babson.edu', 'http://www.babson.edu/'),
(175, 1, 'Baker University', 'bakeru.edu', 'http://www.bakeru.edu/'),
(176, 1, 'Ball State University', 'bsu.edu', 'http://www.bsu.edu/'),
(177, 1, 'Baptist Bible College', 'bbc.edu', 'http://www.bbc.edu/'),
(178, 1, 'Bard College', 'bard.edu', 'http://www.bard.edu/'),
(179, 1, 'Barry University', 'barry.edu', 'http://www.barry.edu/'),
(180, 1, 'Bastyr University', 'bastyr.edu', 'http://www.bastyr.edu/'),
(181, 1, 'Bates College', 'bates.edu', 'http://www.bates.edu/'),
(182, 1, 'Baylor College of Medicine', 'bcm.edu', 'http://www.bcm.edu/'),
(183, 1, 'Baylor University', 'baylor.edu', 'http://www.baylor.edu/'),
(184, 1, 'Bellevue University', 'bellevue.edu', 'http://www.bellevue.edu/'),
(185, 1, 'Belmont University', 'belmont.edu', 'http://www.belmont.edu/'),
(186, 1, 'Beloit College', 'beloit.edu', 'http://www.beloit.edu/'),
(187, 1, 'Bemidji State University', 'bemidjistate.edu', 'http://www.bemidjistate.edu/'),
(188, 1, 'Benedictine College', 'benedictine.edu', 'http://www.benedictine.edu/'),
(189, 1, 'Bennington College', 'bennington.edu', 'http://www.bennington.edu/'),
(190, 1, 'Bentley University', 'bentley.edu', 'http://www.bentley.edu/'),
(191, 1, 'Berea College', 'berea.edu', 'http://www.berea.edu/'),
(192, 1, 'Berklee College of Music', 'berklee.edu', 'http://www.berklee.edu/'),
(193, 1, 'Bethany College', 'bethanywv.edu', 'http://www.bethanywv.edu/'),
(194, 1, 'Bethel College (KS)', 'bethelks.edu', 'http://www.bethelks.edu/'),
(195, 1, 'Bethel University', 'bethel.edu', 'http://www.bethel.edu/'),
(196, 1, 'Biola University', 'biola.edu', 'http://www.biola.edu/'),
(197, 1, 'Birmingham-Southern College', 'bsc.edu', 'http://www.bsc.edu/'),
(198, 1, 'Black Hills State University', 'bhsu.edu', 'http://www.bhsu.edu/'),
(199, 1, 'Bloomsburg University of Pennsylvania', 'bloomu.edu', 'http://www.bloomu.edu/'),
(200, 1, 'Bluffton College', 'bluffton.edu', 'http://www.bluffton.edu/'),
(201, 1, 'Bob Jones University', 'bju.edu', 'http://www.bju.edu/'),
(202, 1, 'Boise State University', 'boisestate.edu', 'http://www.boisestate.edu/'),
(203, 1, 'Boston College', 'bc.edu', 'http://www.bc.edu/'),
(204, 1, 'Boston Graduate School of Psychoanalysis', 'bgsp.edu', 'http://www.bgsp.edu/'),
(205, 1, 'Boston University', 'bu.edu', 'http://www.bu.edu/'),
(206, 1, 'Bowdoin College', 'bowdoin.edu', 'http://www.bowdoin.edu/'),
(207, 1, 'Bowie State University', 'bowiestate.edu', 'http://www.bowiestate.edu/'),
(208, 1, 'Bowling Green State University', 'bgsu.edu', 'http://www.bgsu.edu/'),
(209, 1, 'Bradley University', 'bradley.edu', 'http://www.bradley.edu/'),
(210, 1, 'Brandeis University', 'brandeis.edu', 'http://www.brandeis.edu/'),
(211, 1, 'Brenau University', 'brenau.edu', 'http://www.brenau.edu/'),
(212, 1, 'Briar Cliff College', 'briar-cliff.edu', 'http://www.briar-cliff.edu/'),
(213, 1, 'Bridgewater College', 'bridgewater.edu', 'http://www.bridgewater.edu/'),
(214, 1, 'Brigham Young University', 'byu.edu', 'http://www.byu.edu/'),
(215, 1, 'Brigham Young University - Idaho', 'byui.edu', 'http://www.byui.edu/'),
(216, 1, 'Brigham Young University Hawaii', 'byuh.edu', 'http://www.byuh.edu/'),
(217, 1, 'Broward College', 'broward.edu', 'http://www.broward.edu/'),
(218, 1, 'Brown University', 'brown.edu', 'http://www.brown.edu/'),
(219, 1, 'Bryant University', 'bryant.edu', 'http://www.bryant.edu/'),
(220, 1, 'Bryn Mawr College', 'brynmawr.edu', 'http://www.brynmawr.edu/'),
(221, 1, 'Bucknell University', 'bucknell.edu', 'http://www.bucknell.edu/'),
(222, 1, 'Buena Vista University', 'bvu.edu', 'http://www.bvu.edu/'),
(223, 1, 'Butler University', 'butler.edu', 'http://www.butler.edu/'),
(224, 1, 'California Coast University', 'calcoast.edu', 'http://www.calcoast.edu/'),
(225, 1, 'California Institute of Technology', 'caltech.edu', 'http://www.caltech.edu/'),
(226, 1, 'California Lutheran University', 'callutheran.edu', 'http://www.callutheran.edu/'),
(227, 1, 'California Maritime Academy', 'csum.edu', 'http://www.csum.edu/'),
(228, 1, 'California National University', 'cnuas.edu', 'http://www.cnuas.edu/'),
(229, 1, 'California Polytechnic State University, San Luis Obispo', 'calpoly.edu', 'http://www.calpoly.edu/'),
(230, 1, 'California State University, Bakersfield', 'csub.edu', 'http://www.csub.edu/'),
(231, 1, 'California State University, Chico', 'csuchico.edu', 'http://www.csuchico.edu/'),
(232, 1, 'California State University, Dominguez Hills', 'csudh.edu', 'http://www.csudh.edu/'),
(233, 1, 'California State University, Fresno', 'csufresno.edu', 'http://www.csufresno.edu/'),
(234, 1, 'California State University, Fullerton', 'fullerton.edu', 'http://www.fullerton.edu/'),
(235, 1, 'California State University, Hayward', 'csuhayward.edu', 'http://www.csuhayward.edu/'),
(236, 1, 'California State University, Long Beach', 'csulb.edu', 'http://www.csulb.edu/'),
(237, 1, 'California State University, Los Angeles', 'calstatela.edu', 'http://www.calstatela.edu/'),
(238, 1, 'California State University, Monterey Bay', 'csumb.edu', 'http://www.csumb.edu/'),
(239, 1, 'California State University, Northridge', 'csun.edu', 'http://www.csun.edu/'),
(240, 1, 'California State University, Sacramento', 'csus.edu', 'http://www.csus.edu/'),
(241, 1, 'California State University, San Bernardino', 'csusb.edu', 'http://www.csusb.edu/'),
(242, 1, 'California State University, San Marcos', 'csusm.edu', 'https://www.csusm.edu/'),
(243, 1, 'California State University, Stanislaus', 'csustan.edu', 'http://www.csustan.edu/'),
(244, 1, 'California State University System', 'calstate.edu', 'http://www.calstate.edu/'),
(245, 1, 'California University of Pennsylvania', 'cup.edu', 'http://www.cup.edu/'),
(246, 1, 'Calvin College', 'calvin.edu', 'http://www.calvin.edu/'),
(247, 1, 'Cameron University', 'cameron.edu', 'http://www.cameron.edu/'),
(248, 1, 'Campbellsville College', 'campbellsville.edu', 'http://www.campbellsville.edu/'),
(249, 1, 'Campbell University', 'campbell.edu', 'http://www.campbell.edu/'),
(250, 1, 'Canisius College', 'canisius.edu', 'http://www.canisius.edu/'),
(251, 1, 'Capella University', 'capella.edu', 'http://www.capella.edu/'),
(252, 1, 'Capitol Technology University', 'captechu.edu', 'http://www.captechu.edu/'),
(253, 1, 'Carleton College', 'carleton.edu', 'http://www.carleton.edu/'),
(254, 1, 'Carlow College', 'carlow.edu', 'http://www.carlow.edu/'),
(255, 1, 'Carnegie Mellon University', 'cmu.edu', 'http://www.cmu.edu/'),
(256, 1, 'Carroll College', 'carroll.edu', 'http://www.carroll.edu/'),
(257, 1, 'Carroll University', 'carrollu.edu', 'http://www.carrollu.edu/'),
(258, 1, 'Carson-Newman College', 'cn.edu', 'http://www.cn.edu/'),
(259, 1, 'Carthage College', 'carthage.edu', 'http://www.carthage.edu/'),
(260, 1, 'Case Western Reserve University', 'case.edu', 'http://www.case.edu/'),
(261, 1, 'Castleton State University', 'castleton.edu', 'http://www.castleton.edu/'),
(262, 1, 'Catholic University of America', 'cua.edu', 'http://www.cua.edu/'),
(263, 1, 'Cedarville College', 'cedarville.edu', 'http://www.cedarville.edu/'),
(264, 1, 'Centenary College of Louisiana', 'centenary.edu', 'http://www.centenary.edu/'),
(265, 1, 'Central College', 'central.edu', 'http://www.central.edu/'),
(266, 1, 'Central Connecticut State University', 'ccsu.edu', 'http://www.ccsu.edu/'),
(267, 1, 'Central Methodist College', 'cmc.edu', 'http://www.cmc.edu/'),
(268, 1, 'Central Michigan University', 'cmich.edu', 'http://www.cmich.edu/'),
(269, 1, 'Central Washington University', 'cwu.edu', 'http://www.cwu.edu/'),
(270, 1, 'Centre College', 'centre.edu', 'http://www.centre.edu/'),
(271, 1, 'Chadron State College', 'csc.edu', 'http://www.csc.edu/'),
(272, 1, 'Champlain College', 'champlain.edu', 'http://www.champlain.edu/'),
(273, 1, 'Chapman University', 'chapman.edu', 'http://www.chapman.edu/'),
(274, 1, 'Chatham College', 'chatham.edu', 'http://www.chatham.edu/'),
(275, 1, 'Chesapeake College', 'chesapeake.edu', 'http://www.chesapeake.edu/'),
(276, 1, 'Cheyney University', 'cheyney.edu', 'http://www.cheyney.edu/'),
(277, 1, 'Chicago School of Professional Psychology', 'csopp.edu', 'http://www.csopp.edu/'),
(278, 1, 'Christian Brothers University', 'cbu.edu', 'http://www.cbu.edu/'),
(279, 1, 'Christian Theological Seminary', 'cts.edu', 'http://www.cts.edu/'),
(280, 1, 'Christopher Newport University', 'cnu.edu', 'http://www.cnu.edu/'),
(281, 1, 'City University', 'cityu.edu', 'http://www.cityu.edu/'),
(282, 1, 'City University of New York', 'cuny.edu', 'http://www.cuny.edu/'),
(283, 1, 'Claremont Graduate School', 'cgs.edu', 'http://www.cgs.edu/'),
(284, 1, 'Claremont McKenna College', 'claremontmckenna.edu', 'http://www.cmc.edu/'),
(285, 1, 'Clarion University of Pennsylvania', 'clarion.edu', 'http://www.clarion.edu/'),
(286, 1, 'Clarke College', 'clarke.edu', 'http://www.clarke.edu/'),
(287, 1, 'Clarkson University', 'clarkson.edu', 'http://www.clarkson.edu/'),
(288, 1, 'Clark University', 'clarku.edu', 'http://www.clarku.edu/'),
(289, 1, 'Clayton State College', 'clayton.edu', 'http://www.clayton.edu/'),
(290, 1, 'Clemson University', 'clemson.edu', 'http://www.clemson.edu/'),
(291, 1, 'Cleveland State University', 'csuohio.edu', 'http://www.csuohio.edu/'),
(292, 1, 'Clinch Valley College', 'clinch.edu', 'http://www.clinch.edu/'),
(293, 1, 'Coastal Carolina University', 'coastal.edu', 'http://www.coastal.edu/'),
(294, 1, 'Coast Colleges', 'cccd.edu', 'http://www.cccd.edu/'),
(295, 1, 'Coe College', 'coe.edu', 'http://www.coe.edu/'),
(296, 1, 'Coker College', 'coker.edu', 'http://www.coker.edu/'),
(297, 1, 'Colby College', 'colby.edu', 'http://www.colby.edu/'),
(298, 1, 'Colgate University', 'colgate.edu', 'http://www.colgate.edu/'),
(299, 1, 'College of Charleston', 'cofc.edu', 'http://www.cofc.edu/'),
(300, 1, 'College of Eastern Utah', 'ceu.edu', 'http://www.ceu.edu/'),
(301, 1, 'College of New Rochelle', 'cnr.edu', 'http://www.cnr.edu/'),
(302, 1, 'College of Saint Benedict', 'csbsju.edu', 'http://www.csbsju.edu/'),
(303, 1, 'College of Saint Catherine', 'stkate.edu', 'http://www.stkate.edu/'),
(304, 1, 'College of Saint Rose', 'strose.edu', 'http://www.strose.edu/'),
(305, 1, 'College of St. Francis', 'stfrancis.edu', 'http://www.stfrancis.edu/'),
(306, 1, 'College of St. Scholastica', 'css.edu', 'http://www.css.edu/'),
(307, 1, 'College of the Atlantic', 'coa.edu', 'http://www.coa.edu/'),
(308, 1, 'College of the Holy Cross', 'holycross.edu', 'http://www.holycross.edu/'),
(309, 1, 'College of William and Mary', 'wm.edu', 'http://www.wm.edu/'),
(310, 1, 'College of Wooster', 'wooster.edu', 'http://www.wooster.edu/'),
(311, 1, 'Colorado Christian University', 'ccu.edu', 'http://www.ccu.edu/'),
(312, 1, 'Colorado College', 'coloradocollege.edu', 'http://www.coloradocollege.edu/'),
(313, 1, 'Colorado Mesa University', 'coloradomesa.edu', 'http://www.coloradomesa.edu/'),
(314, 1, 'Colorado School of Mines', 'mines.edu', 'http://www.mines.edu/'),
(315, 1, 'Colorado State University', 'colostate.edu', 'http://www.colostate.edu/'),
(316, 1, 'Colorado Technical University', 'coloradotech.edu', 'http://www.coloradotech.edu/'),
(317, 1, 'University of Colorado Anschutz Medical Campus', 'cuanschutz.edu', 'https://www.cuanschutz.edu/'),
(318, 1, 'Columbia College Chicago', 'colum.edu', 'http://www.colum.edu/'),
(319, 1, 'Columbia Southern University', 'colsouth.edu', 'http://www.colsouth.edu/'),
(320, 1, 'Columbia Union College', 'cuc.edu', 'http://www.cuc.edu/'),
(321, 1, 'Columbia University', 'columbia.edu', 'http://www.columbia.edu/'),
(322, 1, 'Community College of Baltimore County', 'ccbcmd.edu', 'http://www.ccbcmd.edu/'),
(323, 1, 'Concordia College - Ann Arbor', 'ccaa.edu', 'http://www.ccaa.edu/'),
(324, 1, 'Concordia College - Moorhead', 'cord.edu', 'http://www.cord.edu/'),
(325, 1, 'Concordia College - Seward', 'ccsn.edu', 'http://www.ccsn.edu/'),
(326, 1, 'Concordia College - St. Paul', 'csp.edu', 'http://www.csp.edu/'),
(327, 1, 'Connecticut College', 'conncoll.edu', 'http://www.conncoll.edu/'),
(328, 1, 'Connecticut State University System', 'ct.edu', 'http://www.ct.edu/'),
(329, 1, 'Cooper Union for the Advancement of Science and Art', 'cooper.edu', 'http://www.cooper.edu/'),
(330, 1, 'Coppin State University', 'coppin.edu', 'http://www.coppin.edu/'),
(331, 1, 'Allen College', 'allencollege.edu', 'https://www.allencollege.edu/'),
(332, 1, 'Cornell College', 'cornellcollege.edu', 'https://cornellcollege.edu/'),
(333, 1, 'Cornell University', 'cornell.edu', 'http://www.cornell.edu/'),
(334, 1, 'Corning Community College', 'corning-cc.edu', 'http://www.corning-cc.edu/'),
(335, 1, 'Creighton University', 'creighton.edu', 'http://www.creighton.edu/'),
(336, 1, 'Curry College', 'curry.edu', 'http://www.curry.edu/'),
(337, 1, 'Daemen College', 'daemen.edu', 'http://www.daemen.edu/'),
(338, 1, 'Dakota State University', 'dsu.edu', 'http://www.dsu.edu/'),
(339, 1, 'Dakota Wesleyan University', 'dwu.edu', 'http://www.dwu.edu/'),
(340, 1, 'Dallas Baptist University', 'dbu.edu', 'http://www.dbu.edu/'),
(341, 1, 'Dallas County Community College', 'dcccd.edu', 'http://www.dcccd.edu/'),
(342, 1, 'Dana College', 'dana.edu', 'http://www.dana.edu/'),
(343, 1, 'Daniel Webster College', 'dwc.edu', 'http://www.dwc.edu/'),
(344, 1, 'Dartmouth College', 'dartmouth.edu', 'http://www.dartmouth.edu/'),
(345, 1, 'Davenport University', 'davenport.edu', 'http://www.davenport.edu/'),
(346, 1, 'Davidson College', 'davidson.edu', 'http://www.davidson.edu/'),
(347, 1, 'Davis & Elkins College', 'dewv.edu', 'https://dewv.edu/'),
(348, 1, 'Daytona State College', 'daytonastate.edu', 'http://www.daytonastate.edu/'),
(349, 1, 'Delaware State University', 'desu.edu', 'http://www.desu.edu/'),
(350, 1, 'Delta State University', 'deltastate.edu', 'http://www.deltastate.edu/'),
(351, 1, 'Denison University', 'denison.edu', 'http://www.denison.edu/'),
(352, 1, 'DePaul University', 'depaul.edu', 'http://www.depaul.edu/'),
(353, 1, 'DePauw University', 'depauw.edu', 'http://www.depauw.edu/'),
(354, 1, 'DeVry Institute of Technology', 'devry.edu', 'http://www.devry.edu/'),
(355, 1, 'Dickinson College', 'dickinson.edu', 'http://www.dickinson.edu/'),
(356, 1, 'Dickinson State University', 'dickinsonstate.edu', 'http://www.dickinsonstate.edu/'),
(357, 1, 'Dillard University', 'dillard.edu', 'http://www.dillard.edu/'),
(358, 1, 'Dominican College', 'dominican.edu', 'http://www.dominican.edu/'),
(359, 1, 'Dordt College', 'dordt.edu', 'http://www.dordt.edu/'),
(360, 1, 'Dowling College', 'dowling.edu', 'http://www.dowling.edu/'),
(361, 1, 'Drake University', 'drake.edu', 'http://www.drake.edu/'),
(362, 1, 'Drew University', 'drew.edu', 'http://www.drew.edu/'),
(363, 1, 'Drexel University', 'drexel.edu', 'http://www.drexel.edu/'),
(364, 1, 'Drury College', 'drury.edu', 'http://www.drury.edu/'),
(365, 1, 'Duquesne University', 'duq.edu', 'http://www.duq.edu/'),
(366, 1, 'Earlham College', 'earlham.edu', 'http://www.earlham.edu/'),
(367, 1, 'East Carolina University', 'ecu.edu', 'http://www.ecu.edu/'),
(368, 1, 'East Central University', 'ecok.edu', 'http://www.ecok.edu/'),
(369, 1, 'Eastern Connecticut State University', 'easternct.edu', 'http://www.easternct.edu/'),
(370, 1, 'Eastern Illinois University', 'eiu.edu', 'http://www.eiu.edu/'),
(371, 1, 'Eastern Kentucky University', 'eku.edu', 'http://www.eku.edu/'),
(372, 1, 'Eastern Mennonite University', 'emu.edu', 'http://www.emu.edu/'),
(373, 1, 'Eastern Michigan University', 'emich.edu', 'http://www.emich.edu/'),
(374, 1, 'Eastern New Mexico University', 'enmu.edu', 'http://www.enmu.edu/'),
(375, 1, 'Eastern Oregon State College', 'eou.edu', 'http://www.eou.edu/'),
(376, 1, 'Eastern Washington University', 'ewu.edu', 'http://www.ewu.edu/'),
(377, 1, 'East Stroudsburg State University of Pennsylvania', 'esu.edu', 'http://www.esu.edu/'),
(378, 1, 'East Tennessee State University', 'etsu.edu', 'http://www.etsu.edu/'),
(379, 1, 'Edgewood College', 'edgewood.edu', 'http://www.edgewood.edu/'),
(380, 1, 'Edinboro University of Pennsylvania', 'edinboro.edu', 'http://www.edinboro.edu/'),
(381, 1, 'Elizabeth City State University', 'ecsu.edu', 'http://www.ecsu.edu/'),
(382, 1, 'Elizabethtown College', 'etown.edu', 'http://www.etown.edu/'),
(383, 1, 'Elmhurst College', 'elmhurst.edu', 'http://www.elmhurst.edu/'),
(384, 1, 'Elon College', 'elon.edu', 'http://www.elon.edu/'),
(385, 1, 'Embry-Riddle Aeronautical University', 'erau.edu', 'http://www.erau.edu/'),
(386, 1, 'Emerson College', 'emerson.edu', 'http://www.emerson.edu/'),
(387, 1, 'Emmanuel College', 'emmanuel.edu', 'http://www.emmanuel.edu/'),
(388, 1, 'Emory University', 'emory.edu', 'http://www.emory.edu/'),
(389, 1, 'Emory & Henry College', 'ehc.edu', 'https://www.ehc.edu/'),
(390, 1, 'Emporia State University', 'emporia.edu', 'http://www.emporia.edu/'),
(391, 1, 'Erie Community College', 'ecc.edu', 'http://www.ecc.edu/'),
(392, 1, 'Lake Erie College of Osteopathic Medicine', 'lecom.edu', 'https://lecom.edu/'),
(393, 1, 'East Texas Baptist University', 'etbu.edu', 'https://www.etbu.edu/'),
(394, 1, 'Evergreen State College', 'evergreen.edu', 'http://www.evergreen.edu/'),
(395, 1, 'Fairleigh Dickinson University', 'fdu.edu', 'http://www.fdu.edu/'),
(396, 1, 'Fairmont State College', 'fairmontstate.edu', 'http://www.fairmontstate.edu/'),
(397, 1, 'Fayetteville State University', 'uncfsu.edu', 'http://www.uncfsu.edu/'),
(398, 1, 'Ferris State University', 'ferris.edu', 'http://www.ferris.edu/'),
(399, 1, 'Fielding Institute', 'fielding.edu', 'http://www.fielding.edu/'),
(400, 1, 'Fisk University', 'fisk.edu', 'http://www.fisk.edu/'),
(401, 1, 'Fitchburg State College', 'fsc.edu', 'http://www.fsc.edu/'),
(402, 1, 'Florida Agricultural and Mechanical University', 'famu.edu', 'http://www.famu.edu/'),
(403, 1, 'Florida Atlantic University', 'fau.edu', 'http://www.fau.edu/'),
(404, 1, 'Florida Gulf Coast University', 'fgcu.edu', 'http://www.fgcu.edu/'),
(405, 1, 'Florida Institute of Technology', 'fit.edu', 'http://www.fit.edu/'),
(406, 1, 'Florida International University', 'fiu.edu', 'http://www.fiu.edu/'),
(407, 1, 'Florida State University', 'fsu.edu', 'http://www.fsu.edu/'),
(408, 1, 'Fontbonne College', 'fontbonne.edu', 'http://www.fontbonne.edu/'),
(409, 1, 'Fordham University', 'fordham.edu', 'http://www.fordham.edu/'),
(410, 1, 'Fort Hays State University', 'fhsu.edu', 'http://www.fhsu.edu/'),
(411, 1, 'Fort Lewis College', 'fortlewis.edu', 'http://www.fortlewis.edu/'),
(412, 1, 'Fountainhead College of Technology', 'fountainheadcollege.edu', 'http://fountainheadcollege.edu/'),
(413, 1, 'Franklin and Marshall College', 'fandm.edu', 'http://www.fandm.edu/'),
(414, 1, 'Franklin Pierce Law Center', 'fplc.edu', 'http://www.fplc.edu/'),
(415, 1, 'Franklin University', 'franklin.edu', 'http://www.franklin.edu/'),
(416, 1, 'Frederick Community College', 'frederick.edu', 'http://www.frederick.edu/'),
(417, 1, 'Fresno Pacific University', 'fresno.edu', 'http://www.fresno.edu/'),
(418, 1, 'Friends University', 'friends.edu', 'http://www.friends.edu/'),
(419, 1, 'Frostburg State University', 'frostburg.edu', 'http://www.frostburg.edu/'),
(420, 1, 'Fuller Theological Seminary', 'fuller.edu', 'http://www.fuller.edu/'),
(421, 1, 'Furman University', 'furman.edu', 'http://www.furman.edu/'),
(422, 1, 'Gallaudet University', 'gallaudet.edu', 'http://www.gallaudet.edu/'),
(423, 1, 'Gannon University', 'gannon.edu', 'http://www.gannon.edu/'),
(424, 1, 'Geneva College', 'geneva.edu', 'http://www.geneva.edu/'),
(425, 1, 'George Fox College', 'gfc.edu', 'http://www.gfc.edu/'),
(426, 1, 'George Mason University', 'gmu.edu', 'http://www.gmu.edu/'),
(427, 1, 'Georgetown University', 'georgetown.edu', 'http://www.georgetown.edu/'),
(428, 1, 'George Washington University', 'gwu.edu', 'http://www.gwu.edu/'),
(429, 1, 'Georgia College', 'gcsu.edu', 'http://www.gcsu.edu/'),
(430, 1, 'Georgia Institute of Technology', 'gatech.edu', 'http://www.gatech.edu/'),
(431, 1, 'Georgian Court University', 'georgian.edu', 'http://www.georgian.edu/'),
(432, 1, 'Georgia Southern University', 'georgiasouthern.edu', 'http://www.georgiasouthern.edu/'),
(433, 1, 'Georgia Southwestern State University', 'gsw.edu', 'http://gsw.edu/'),
(434, 1, 'Georgia State University', 'gsu.edu', 'http://www.gsu.edu/'),
(435, 1, 'Gettysburg College', 'gettysburg.edu', 'http://www.gettysburg.edu/'),
(436, 1, 'GMI Engineering and Management Institute', 'gmi.edu', 'http://www.gmi.edu/'),
(437, 1, 'Golden Gate University', 'ggu.edu', 'http://www.ggu.edu/'),
(438, 1, 'Goldey-Beacom College', 'gbc.edu', 'http://www.gbc.edu/'),
(439, 1, 'Gonzaga University', 'gonzaga.edu', 'http://www.gonzaga.edu/'),
(440, 1, 'Goshen College', 'goshen.edu', 'http://www.goshen.edu/'),
(441, 1, 'Goucher College', 'goucher.edu', 'http://www.goucher.edu/'),
(442, 1, 'Governors State University', 'govst.edu', 'http://www.govst.edu/'),
(443, 1, 'Grace College', 'grace.edu', 'http://www.grace.edu/'),
(444, 1, 'Graceland College', 'graceland.edu', 'http://www.graceland.edu/'),
(445, 1, 'Grand Valley State University', 'gvsu.edu', 'http://www.gvsu.edu/'),
(446, 1, 'Greenleaf University', 'greenleaf.edu', 'http://www.greenleaf.edu/'),
(447, 1, 'Grinnell College', 'grinnell.edu', 'http://www.grinnell.edu/'),
(448, 1, 'Guilford College', 'guilford.edu', 'http://www.guilford.edu/'),
(449, 1, 'Gustavus Adolphus College', 'gac.edu', 'https://www.gac.edu/'),
(450, 1, 'Hagerstown Community College', 'hagerstowncc.edu', 'http://www.hagerstowncc.edu/'),
(451, 1, 'Hamilton College', 'hamilton.edu', 'http://www.hamilton.edu/'),
(452, 1, 'Hamline University', 'hamline.edu', 'http://www.hamline.edu/'),
(453, 1, 'Hampden-Sydney College', 'hsc.edu', 'http://www.hsc.edu/'),
(454, 1, 'Hampshire College', 'hampshire.edu', 'http://www.hampshire.edu/'),
(455, 1, 'Hampton University', 'hamptonu.edu', 'http://www.hamptonu.edu/'),
(456, 1, 'Hanover College', 'hanover.edu', 'http://www.hanover.edu/'),
(457, 1, 'Harding University', 'harding.edu', 'http://www.harding.edu/'),
(458, 1, 'Harford Community College', 'harford.edu', 'http://www.harford.edu/'),
(459, 1, 'Hartwick College', 'hartwick.edu', 'http://www.hartwick.edu/'),
(460, 1, 'Harvard University', 'harvard.edu', 'http://www.harvard.edu/'),
(461, 1, 'Harvey Mudd College', 'hmc.edu', 'http://www.hmc.edu/'),
(462, 1, 'Haskell Indian Nations University', 'haskell.edu', 'http://www.haskell.edu/'),
(463, 1, 'Hastings College', 'hastings.edu', 'http://www.hastings.edu/'),
(464, 1, 'Haverford College in Pennsylvania', 'haverford.edu', 'http://www.haverford.edu/'),
(465, 1, 'Hawaii Pacific University', 'hpu.edu', 'http://www.hpu.edu/'),
(466, 1, 'Heidelberg College', 'heidelberg.edu', 'http://www.heidelberg.edu/'),
(467, 1, 'Hendrix College', 'hendrix.edu', 'http://www.hendrix.edu/'),
(468, 1, 'Hesston College', 'hesston.edu', 'http://www.hesston.edu/'),
(469, 1, 'High Point University', 'highpoint.edu', 'http://www.highpoint.edu/'),
(470, 1, 'Hillsdale College', 'hillsdale.edu', 'http://www.hillsdale.edu/'),
(471, 1, 'Hiram College', 'hiram.edu', 'http://www.hiram.edu/'),
(472, 1, 'Hobart and William Smith Colleges', 'hws.edu', 'http://www.hws.edu/'),
(473, 1, 'Hofstra University', 'hofstra.edu', 'http://www.hofstra.edu/'),
(474, 1, 'Hollins College', 'hollins.edu', 'http://www.hollins.edu/'),
(475, 1, 'Hood College', 'hood.edu', 'http://www.hood.edu/'),
(476, 1, 'Hope College', 'hope.edu', 'http://www.hope.edu/'),
(477, 1, 'Howard Community College', 'howardcc.edu', 'http://www.howardcc.edu/'),
(478, 1, 'Howard University', 'howard.edu', 'http://www.howard.edu/'),
(479, 1, 'Humboldt State University', 'humboldt.edu', 'http://www.humboldt.edu/'),
(480, 1, 'Huntingdon College', 'huntingdon.edu', 'http://www.huntingdon.edu/'),
(481, 1, 'Huntington University', 'huntington.edu', 'http://www.huntington.edu/'),
(482, 1, 'ICI University', 'ici.edu', 'http://www.ici.edu/'),
(483, 1, 'Idaho State University', 'isu.edu', 'http://www.isu.edu/'),
(484, 1, 'Illinois Benedictine College', 'ibc.edu', 'http://www.ibc.edu/'),
(485, 1, 'Illinois Institute of Technology', 'iit.edu', 'http://www.iit.edu/'),
(486, 1, 'Illinois State University', 'illinoisstate.edu', 'http://www.illinoisstate.edu/'),
(487, 1, 'Indiana Institute of Technology', 'indianatech.edu', 'http://www.indianatech.edu/'),
(488, 1, 'Indiana State University', 'indstate.edu', 'http://www.indstate.edu/'),
(489, 1, 'Indiana University', 'iu.edu', 'http://www.iu.edu/'),
(490, 1, 'Indiana University - Bloomington', 'indiana.edu', 'https://bloomington.iu.edu/'),
(491, 1, 'Indiana University at South Bend', 'iusb.edu', 'http://www.iusb.edu/'),
(492, 1, 'Indiana University of Pennsylvania', 'iup.edu', 'http://www.iup.edu/'),
(493, 1, 'Indiana University/Purdue University at Columbus', 'iupuc.edu', 'http://www.iupuc.edu/'),
(494, 1, 'Indiana University/Purdue University at Fort Wayne', 'ipfw.edu', 'http://www.ipfw.edu/'),
(495, 1, 'Indiana University/Purdue University at Indianapolis', 'iupui.edu', 'http://www.iupui.edu/'),
(496, 1, 'Indiana University Southeast', 'ius.edu', 'http://www.ius.edu/'),
(497, 1, 'Indiana Wesleyan University, Marion', 'indwes.edu', 'http://www.indwes.edu/'),
(498, 1, 'Institute for Advanced Study', 'ias.edu', 'http://www.ias.edu/'),
(499, 1, 'Institute for World Politics', 'iwp.edu', 'http://www.iwp.edu/'),
(500, 1, 'Iona College', 'iona.edu', 'http://www.iona.edu/'),
(501, 1, 'Iowa State University', 'iastate.edu', 'http://www.iastate.edu/'),
(502, 1, 'Irvine Valley College', 'ivc.edu', 'http://www.ivc.edu/'),
(503, 1, 'Ithaca College', 'ithaca.edu', 'http://www.ithaca.edu/'),
(504, 1, 'Jackson State University', 'jsums.edu', 'http://www.jsums.edu/'),
(505, 1, 'Jacksonville State University', 'jsu.edu', 'http://www.jsu.edu/'),
(506, 1, 'Jacksonville University', 'ju.edu', 'http://www.ju.edu/'),
(507, 1, 'James Madison University', 'jmu.edu', 'http://www.jmu.edu/'),
(508, 1, 'John Brown University', 'jbu.edu', 'http://www.jbu.edu/'),
(509, 1, 'John F. Kennedy University', 'jfku.edu', 'http://www.jfku.edu/'),
(510, 1, 'Johns Hopkins University', 'jh.edu', 'http://www.jhu.edu/'),
(511, 1, 'Johns Hopkins University Applied Physics Laboratory', 'jhuapl.edu', 'http://www.jhuapl.edu/'),
(512, 1, 'Johnson & Wales University', 'jwu.edu', 'http://www.jwu.edu/'),
(513, 1, 'Johnson Bible College', 'jbc.edu', 'http://www.jbc.edu/'),
(514, 1, 'Johnson C. Smith University', 'jcsu.edu', 'http://www.jcsu.edu/'),
(515, 1, 'Jones College', 'jones.edu', 'http://www.jones.edu/'),
(516, 1, 'Judson College', 'judson.edu', 'http://www.judson.edu/'),
(517, 1, 'Juniata College', 'juniata.edu', 'http://www.juniata.edu/'),
(518, 1, 'Kalamazoo College', 'kzoo.edu', 'http://www.kzoo.edu/'),
(519, 1, 'Kansas State University', 'ksu.edu', 'https://www.k-state.edu/'),
(520, 1, 'Kansas Wesleyan University', 'kwu.edu', 'http://www.kwu.edu/'),
(521, 1, 'Kaplan University', 'kaplan.edu', 'http://www.kaplan.edu/'),
(522, 1, 'Kean College', 'kean.edu', 'http://www.kean.edu/'),
(523, 1, 'Keene State College', 'keene.edu', 'http://www.keene.edu/'),
(524, 1, 'Kennesaw State University', 'kennesaw.edu', 'http://www.kennesaw.edu/'),
(525, 1, 'Kent State University', 'kent.edu', 'http://www.kent.edu/'),
(526, 1, 'Kentucky Community & Technical College System', 'kctcs.edu', 'http://www.kctcs.edu/'),
(527, 1, 'Kenyon College', 'kenyon.edu', 'http://www.kenyon.edu/'),
(528, 1, 'Kettering University', 'kettering.edu', 'http://www.kettering.edu/'),
(529, 1, 'King\'s College', 'kings.edu', 'http://www.kings.edu/'),
(530, 1, 'Knox College', 'knox.edu', 'http://www.knox.edu/'),
(531, 1, 'Kutztown University of Pennsylvania', 'kutztown.edu', 'http://www.kutztown.edu/'),
(532, 1, 'Lafayette College', 'lafayette.edu', 'http://www.lafayette.edu/'),
(533, 1, 'LaGrange College', 'lagrange.edu', 'http://www.lagrange.edu/'),
(534, 1, 'Lake Forest College', 'lfc.edu', 'http://www.lfc.edu/'),
(535, 1, 'Lake Superior College', 'lsc.edu', 'http://www.lsc.edu/'),
(536, 1, 'Lake Superior State University', 'lssu.edu', 'http://www.lssu.edu/'),
(537, 1, 'Lamar University', 'lamar.edu', 'http://www.lamar.edu/'),
(538, 1, 'Langston University', 'langston.edu', 'http://www.langston.edu/'),
(539, 1, 'LaSalle University', 'lasalle.edu', 'http://www.lasalle.edu/'),
(540, 1, 'La Sierra University', 'lasierra.edu', 'http://www.lasierra.edu/'),
(541, 1, 'Lawrence Technological University', 'ltu.edu', 'http://www.ltu.edu/'),
(542, 1, 'Lawrence University', 'lawrence.edu', 'http://www.lawrence.edu/'),
(543, 1, 'Lebanon Valley College', 'lvc.edu', 'http://www.lvc.edu/'),
(544, 1, 'Lehigh University', 'lehigh.edu', 'http://www.lehigh.edu/'),
(545, 1, 'Le Moyne College', 'lemoyne.edu', 'http://www.lemoyne.edu/'),
(546, 1, 'Lenoir Community College', 'lenoircc.edu', 'http://www.lenoircc.edu/'),
(547, 1, 'Lenoir-Rhyne College', 'lrc.edu', 'http://www.lrc.edu/'),
(548, 1, 'LeTourneau University', 'letu.edu', 'http://www.letu.edu/'),
(549, 1, 'Lewis & Clark College', 'lclark.edu', 'http://www.lclark.edu/'),
(550, 1, 'Lewis-Clark State College', 'lcsc.edu', 'http://www.lcsc.edu/'),
(551, 1, 'Lewis University', 'lewisu.edu', 'http://www.lewisu.edu/'),
(552, 1, 'Liberty University', 'liberty.edu', 'http://www.liberty.edu/'),
(553, 1, 'Lincoln University', 'lincoln.edu', 'http://www.lincoln.edu/'),
(554, 1, 'Linfield College', 'linfield.edu', 'http://www.linfield.edu/'),
(555, 1, 'Lock Haven University', 'lhup.edu', 'https://lockhaven.edu/'),
(556, 1, 'Loma Linda University', 'llu.edu', 'http://www.llu.edu/'),
(557, 1, 'Long Island University', 'liunet.edu', 'http://www.liu.edu/'),
(558, 1, 'Longwood University', 'longwood.edu', 'http://www.longwood.edu/'),
(559, 1, 'Loras College', 'loras.edu', 'http://www.loras.edu/'),
(560, 1, 'Los Angeles Community College District', 'laccd.edu', 'http://www.laccd.edu/'),
(561, 1, 'Louisiana College', 'lacollege.edu', 'http://www.lacollege.edu/'),
(562, 1, 'Louisiana State University', 'lsu.edu', 'http://www.lsu.edu/'),
(563, 1, 'Louisiana State University at Alexandria', 'lsua.edu', 'http://www.lsua.edu/'),
(564, 1, 'Louisiana Tech University', 'latech.edu', 'http://www.latech.edu/'),
(565, 1, 'Loyola College', 'loyola.edu', 'http://www.loyola.edu/'),
(566, 1, 'Loyola Marymount University', 'lmu.edu', 'http://www.lmu.edu/'),
(567, 1, 'Loyola University Chicago', 'luc.edu', 'http://www.luc.edu/'),
(568, 1, 'Luther College', 'luther.edu', 'http://www.luther.edu/'),
(569, 1, 'Luther Seminary', 'luthersem.edu', 'http://www.luthersem.edu/'),
(570, 1, 'Lycoming College', 'lycoming.edu', 'http://www.lycoming.edu/'),
(571, 1, 'Lynchburg College', 'lynchburg.edu', 'http://www.lynchburg.edu/'),
(572, 1, 'Lyndon State College', 'lyndonstate.edu', 'http://www.lyndonstate.edu/'),
(573, 1, 'Lyon College', 'lyon.edu', 'http://www.lyon.edu/'),
(574, 1, 'Macalester College', 'macalester.edu', 'http://www.macalester.edu/'),
(575, 1, 'Maharishi University of Management', 'mum.edu', 'http://www.mum.edu/'),
(576, 1, 'Malone College', 'malone.edu', 'http://www.malone.edu/'),
(577, 1, 'Manhattan College', 'manhattan.edu', 'http://www.manhattan.edu/'),
(578, 1, 'Mansfield University of Pennsylvania', 'mansfield.edu', 'http://www.mansfield.edu/'),
(579, 1, 'Marietta College', 'marietta.edu', 'http://www.marietta.edu/'),
(580, 1, 'Marist College', 'marist.edu', 'http://www.marist.edu/'),
(581, 1, 'Marlboro College', 'marlboro.edu', 'http://www.marlboro.edu/'),
(582, 1, 'Marquette University', 'marquette.edu', 'http://www.marquette.edu/'),
(583, 1, 'Marshall University', 'marshall.edu', 'http://www.marshall.edu/'),
(584, 1, 'Mary Baldwin College', 'mbc.edu', 'http://www.mbc.edu/'),
(585, 1, 'Marymount Manhattan College', 'mmm.edu', 'http://www.mmm.edu/'),
(586, 1, 'Marymount University', 'marymount.edu', 'http://www.marymount.edu/'),
(587, 1, 'Mary Washington College', 'mwc.edu', 'http://www.mwc.edu/'),
(588, 1, 'Massachusetts Institute of Technology', 'mit.edu', 'http://web.mit.edu/'),
(589, 1, 'McDaniel College', 'mcdaniel.edu', 'http://www.mcdaniel.edu/'),
(590, 1, 'McMurry University', 'mcm.edu', 'http://www2.mcm.edu/'),
(591, 1, 'McNeese State University', 'mcneese.edu', 'http://www.mcneese.edu/'),
(592, 1, 'Medical College of Georgia', 'mcg.edu', 'http://www.mcg.edu/'),
(593, 1, 'Medical College of Wisconsin', 'mcw.edu', 'http://www.mcw.edu/'),
(594, 1, 'Mercer County Community College', 'mccc.edu', 'http://www.mccc.edu/'),
(595, 1, 'Mercer University', 'mercer.edu', 'http://www.mercer.edu/'),
(596, 1, 'Mercy College', 'mercymavericks.edu', 'http://www.mercy.edu/'),
(597, 1, 'Mercyhurst University', 'mercyhurst.edu', 'https://mercyhurst.edu/'),
(598, 1, 'Meredith College', 'meredith.edu', 'http://www.meredith.edu/'),
(599, 1, 'Messiah College', 'messiah.edu', 'http://www.messiah.edu/'),
(600, 1, 'Metropolitan Community College (MO)', 'mcckc.edu', 'http://www.mcckc.edu/'),
(601, 1, 'Metropolitan Community College (NE)', 'mccneb.edu', 'http://www.mccneb.edu/'),
(602, 1, 'Metropolitan State College of Denver', 'msudenver.edu', 'http://www.msudenver.edu/'),
(603, 1, 'Denver College of Nursing', 'denvercollegeofnursing.edu', 'https://www.denvercollegeofnursing.edu/'),
(604, 1, 'Metropolitan State University', 'metrostate.edu', 'http://www.metrostate.edu/'),
(605, 1, 'Miami University of Ohio', 'miamioh.edu', 'http://www.miamioh.edu/'),
(606, 1, 'Michigan State University', 'msu.edu', 'http://www.msu.edu/'),
(607, 1, 'Michigan Technological University', 'mtu.edu', 'http://www.mtu.edu/'),
(608, 1, 'Mid-America Nazarene College', 'manc.edu', 'http://www.manc.edu/'),
(609, 1, 'Middlebury College', 'middlebury.edu', 'http://www.middlebury.edu/'),
(610, 1, 'Middle Georgia State College', 'mga.edu', 'http://www.mga.edu/'),
(611, 1, 'Middle Tennessee State University', 'mtsu.edu', 'http://www.mtsu.edu/'),
(612, 1, 'Midwestern State University', 'mwsu.edu', 'http://www.mwsu.edu/'),
(613, 1, 'Millersville University of Pennsylvania', 'millersville.edu', 'http://www.millersville.edu/'),
(614, 1, 'Milligan College', 'milligan.edu', 'http://www.milligan.edu/'),
(615, 1, 'Millikin University', 'millikin.edu', 'http://www.millikin.edu/'),
(616, 1, 'Millsaps College', 'millsaps.edu', 'http://www.millsaps.edu/'),
(617, 1, 'Milwaukee School of Engineering', 'msoe.edu', 'http://www.msoe.edu/'),
(618, 1, 'Minneapolis College of Art and Design', 'mcad.edu', 'http://www.mcad.edu/'),
(619, 1, 'Minnesota State University, Mankato', 'mnsu.edu', 'http://www.mnsu.edu/'),
(620, 1, 'Minnesota State University Moorhead', 'mnstate.edu', 'http://www.mnstate.edu/'),
(621, 1, 'Minot State University', 'minotstateu.edu', 'http://www.minotstateu.edu/'),
(622, 1, 'Mississippi College', 'mc.edu', 'http://www.mc.edu/'),
(623, 1, 'Mississippi State University', 'msstate.edu', 'http://www.msstate.edu/'),
(624, 1, 'Mississippi University for Women', 'muw.edu', 'http://www.muw.edu/'),
(625, 1, 'Missouri Southern State College', 'mssc.edu', 'http://www.mssc.edu/'),
(626, 1, 'Missouri University of Science and Technology', 'mst.edu', 'http://www.mst.edu/'),
(627, 1, 'Missouri Western State College', 'mwsc.edu', 'http://www.mwsc.edu/'),
(628, 1, 'Molloy College', 'molloy.edu', 'http://www.molloy.edu/'),
(629, 1, 'Monmouth College', 'monmouthcollege.edu', 'http://www.monmouthcollege.edu/'),
(630, 1, 'Monmouth University', 'monmouth.edu', 'http://www.monmouth.edu/'),
(631, 1, 'Montana State University - Billings', 'msubillings.edu', 'http://www.msubillings.edu/'),
(632, 1, 'Montana State University - Bozeman', 'montana.edu', 'http://www.montana.edu/'),
(633, 1, 'Montana State University - Northern', 'msun.edu', 'http://www.msun.edu/'),
(634, 1, 'Montana Tech', 'mtech.edu', 'http://www.mtech.edu/'),
(635, 1, 'Montclair State University', 'montclair.edu', 'http://www.montclair.edu/'),
(636, 1, 'Montgomery College', 'montgomerycollege.edu', 'http://www.montgomerycollege.edu/'),
(637, 1, 'Montreat College', 'montreat.edu', 'http://www.montreat.edu/'),
(638, 1, 'Moravian College', 'moravian.edu', 'http://www.moravian.edu/'),
(639, 1, 'Morgan State University', 'morgan.edu', 'http://www.morgan.edu/'),
(640, 1, 'Mott Community College', 'mcc.edu', 'http://www.mcc.edu/'),
(641, 1, 'Mount Holyoke College', 'mtholyoke.edu', 'http://www.mtholyoke.edu/'),
(642, 1, 'Mount Saint Joseph College', 'msj.edu', 'http://www.msj.edu/'),
(643, 1, 'Mount Saint Mary College', 'msmc.edu', 'http://www.msmc.edu/'),
(644, 1, 'Mount Senario College', 'mscfs.edu', 'http://www.mscfs.edu/'),
(645, 1, 'Mount Union College', 'muc.edu', 'http://www.muc.edu/'),
(646, 1, 'Murray State University', 'mursuky.edu', 'http://www.mursuky.edu/'),
(647, 1, 'Muskingum College', 'muskingum.edu', 'http://www.muskingum.edu/'),
(648, 1, 'Nashville State Community College', 'nscc.edu', 'http://www.nscc.edu/'),
(649, 1, 'National Defense University', 'ndu.edu', 'http://www.ndu.edu/'),
(650, 1, 'National-Louis University', 'nl.edu', 'http://www.nl.edu/'),
(651, 1, 'National Radio Astronomy Observatory', 'nrao.edu', 'http://www.nrao.edu/'),
(652, 1, 'National University', 'nu.edu', 'http://www.nu.edu/'),
(653, 1, 'Naval Postgraduate School', 'nps.edu', 'http://www.nps.edu/'),
(654, 1, 'Nazareth College', 'naz.edu', 'http://www2.naz.edu/'),
(655, 1, 'Nevada System of Higher Education', 'nevada.edu', 'http://system.nevada.edu/'),
(656, 1, 'Newberry College', 'newberry.edu', 'http://www.newberry.edu/');
INSERT INTO `universities` (`university_id`, `country_id`, `university_name`, `external_api_id`, `website_url`) VALUES
(657, 1, 'New College of California', 'newcollege.edu', 'http://www.newcollege.edu/'),
(658, 1, 'New England Institute of Technology', 'neit.edu', 'http://www.neit.edu/'),
(659, 1, 'New Hampshire College', 'nhc.edu', 'http://www.nhc.edu/'),
(660, 1, 'New Jersey Institute of Technology', 'njit.edu', 'http://www.njit.edu/'),
(661, 1, 'New Mexico Highlands University', 'nmhu.edu', 'http://www.nmhu.edu/'),
(662, 1, 'New Mexico Institute of Mining & Technology', 'nmt.edu', 'http://www.nmt.edu/'),
(663, 1, 'New Mexico State University', 'nmsu.edu', 'http://www.nmsu.edu/'),
(664, 1, 'New York Institute of Technology', 'nyit.edu', 'http://www.nyit.edu/'),
(665, 1, 'New York University', 'nyu.edu', 'http://www.nyu.edu/'),
(666, 1, 'Niagara University', 'niagara.edu', 'http://www.niagara.edu/'),
(667, 1, 'Nicholls State University', 'nicholls.edu', 'http://www.nicholls.edu/'),
(668, 1, 'Norfolk State University', 'nsu.edu', 'http://www.nsu.edu/'),
(669, 1, 'North American University', 'na.edu', 'http://www.na.edu/'),
(670, 1, 'Northampton Community College', 'northampton.edu', 'http://www.northampton.edu/'),
(671, 1, 'North Carolina A&T State University', 'ncat.edu', 'http://www.ncat.edu/'),
(672, 1, 'North Carolina Central University', 'nccu.edu', 'http://www.nccu.edu/'),
(673, 1, 'North Carolina State University', 'ncsu.edu', 'http://www.ncsu.edu/'),
(674, 1, 'North Carolina Wesleyan College', 'ncwc.edu', 'http://www.ncwc.edu/'),
(675, 1, 'North Central Bible College', 'ncbc.edu', 'http://www.ncbc.edu/'),
(676, 1, 'North Dakota State University', 'ndsu.edu', 'http://www.ndsu.edu/'),
(677, 1, 'Northeastern Louisiana University', 'nlu.edu', 'http://www.nlu.edu/'),
(678, 1, 'Northeastern State University', 'nsuok.edu', 'http://www.nsuok.edu/'),
(679, 1, 'Northeastern University', 'neu.edu', 'http://www.northeastern.edu/'),
(680, 1, 'Northern Arizona University', 'nau.edu', 'http://www.nau.edu/'),
(681, 1, 'Northern Illinois University', 'niu.edu', 'http://www.niu.edu/'),
(682, 1, 'Northern Kentucky University', 'nku.edu', 'http://www.nku.edu/'),
(683, 1, 'Northern Michigan University', 'nmu.edu', 'http://www.nmu.edu/'),
(684, 1, 'Northern State University', 'northern.edu', 'http://www.northern.edu/'),
(685, 1, 'Northland College', 'northland.edu', 'http://www.northland.edu/'),
(686, 1, 'North Park College and Theological Seminary', 'npcts.edu', 'http://www.npcts.edu/'),
(687, 1, 'Northwestern College of Iowa', 'nwciowa.edu', 'http://www.nwciowa.edu/'),
(688, 1, 'Northwestern State University', 'nsula.edu', 'http://www.nsula.edu/'),
(689, 1, 'Northwestern University', 'northwestern.edu', 'http://www.northwestern.edu/'),
(690, 1, 'Northwest Missouri State University', 'nwmissouri.edu', 'http://www.nwmissouri.edu/'),
(691, 1, 'Northwest Nazarene College', 'nnc.edu', 'http://www.nnc.edu/'),
(692, 1, 'Norwich University', 'norwich.edu', 'http://www.norwich.edu/'),
(693, 1, 'Nova Southeastern University', 'nova.edu', 'http://www.nova.edu/'),
(694, 1, 'Oakland University', 'oakland.edu', 'http://www.oakland.edu/'),
(695, 1, 'Oakwood University', 'oakwood.edu', 'http://www.oakwood.edu/'),
(696, 1, 'Oberlin College', 'oberlin.edu', 'http://www.oberlin.edu/'),
(697, 1, 'Occidental College', 'oxy.edu', 'http://www.oxy.edu/'),
(698, 1, 'Ohio Dominican College', 'odc.edu', 'http://www.odc.edu/'),
(699, 1, 'Ohio Northern University', 'onu.edu', 'http://www.onu.edu/'),
(700, 1, 'Ohio State University - Columbus', 'osu.edu', 'https://www.osu.edu/'),
(701, 1, 'Ohio University', 'ohio.edu', 'http://www.ohio.edu/'),
(702, 1, 'Ohio Wesleyan University', 'owu.edu', 'http://www.owu.edu/'),
(703, 1, 'Oklahoma Baptist University', 'okbu.edu', 'http://www.okbu.edu/'),
(704, 1, 'Oklahoma City University', 'okcu.edu', 'http://www.okcu.edu/'),
(705, 1, 'Oklahoma State University', 'okstate.edu', 'http://www.okstate.edu/'),
(706, 1, 'Old Dominion University', 'odu.edu', 'http://www.odu.edu/'),
(707, 1, 'Olivet Nazarene University', 'olivet.edu', 'http://www.olivet.edu/'),
(708, 1, 'Oral Roberts University', 'oru.edu', 'http://www.oru.edu/'),
(709, 1, 'Oregon Graduate Institute of Science and Technology', 'ogi.edu', 'http://www.ogi.edu/'),
(710, 1, 'Oregon Health Sciences University', 'ohsu.edu', 'http://www.ohsu.edu/'),
(711, 1, 'Oregon Institute of Technology', 'oit.edu', 'http://www.oit.edu/'),
(712, 1, 'Oregon State University', 'oregonstate.edu', 'http://www.oregonstate.edu/'),
(713, 1, 'Otterbein College', 'otterbein.edu', 'http://www.otterbein.edu/'),
(714, 1, 'Our Lady of the Lake University', 'ollusa.edu', 'http://www.ollusa.edu/'),
(715, 1, 'Pace University', 'pace.edu', 'http://www.pace.edu/'),
(716, 1, 'Pacific Lutheran University', 'plu.edu', 'http://www.plu.edu/'),
(717, 1, 'Pacific Union College', 'puc.edu', 'http://www.puc.edu/'),
(718, 1, 'Pacific University', 'pacificu.edu', 'http://www.pacificu.edu/'),
(719, 1, 'Pacific Western University', 'pwu.com', 'http://www.pwu.com/'),
(720, 1, 'Palm Beach Atlantic College', 'pbac.edu', 'http://www.pbac.edu/'),
(721, 1, 'Palm Beach State College', 'palmbeachstate.edu', 'http://www.palmbeachstate.edu/'),
(722, 1, 'Peace College', 'peace.edu', 'http://www.peace.edu/'),
(723, 1, 'Pembroke State University', 'pembroke.edu', 'http://www.pembroke.edu/'),
(724, 1, 'Pennsylvania College of Technology', 'pct.edu', 'http://www.pct.edu/'),
(725, 1, 'Pennsylvania State University', 'psu.edu', 'http://www.psu.edu/'),
(726, 1, 'Pennsylvania State University - Schuylkill Campus', 'sl.psu.edu', 'http://www.sl.psu.edu/'),
(727, 1, 'Pensacola Christian College', 'pcci.edu', 'http://www.pcci.edu/'),
(728, 1, 'Pensacola State College', 'pensacolastate.edu', 'http://www.pensacolastate.edu/'),
(729, 1, 'Pepperdine University', 'pepperdine.edu', 'http://www.pepperdine.edu/'),
(730, 1, 'Peru State College', 'peru.edu', 'http://www.peru.edu/'),
(731, 1, 'Purdue University Fort Wayne', 'pfw.edu', 'https://www.pdfw.edu/'),
(732, 1, 'Philadelphia University', 'philau.edu', 'http://www.philau.edu/'),
(733, 1, 'Phillips University', 'phillips.edu', 'http://www.phillips.edu/'),
(734, 1, 'Pittsburg State University', 'pittstate.edu', 'http://www.pittstate.edu/'),
(735, 1, 'Pitzer College', 'pitzer.edu', 'http://www.pitzer.edu/'),
(736, 1, 'Platt College', 'platt.edu', 'http://www.platt.edu/'),
(737, 1, 'Plymouth State University', 'plymouth.edu', 'http://www.plymouth.edu/'),
(738, 1, 'Polytechnic University of New York', 'poly.edu', 'http://www.poly.edu/'),
(739, 1, 'Polytechnic University of Puerto Rico', 'pupr.edu', 'http://www.pupr.edu/'),
(740, 1, 'Pomona College', 'pomona.edu', 'http://www.pomona.edu/'),
(741, 1, 'Portland Community College', 'pcc.edu', 'http://www.pcc.edu/'),
(742, 1, 'Portland State University', 'pdx.edu', 'http://www.ee.pdx.edu/'),
(743, 1, 'Prairie View A&M University', 'pvamu.edu', 'http://www.pvamu.edu/'),
(744, 1, 'Pratt Institute', 'pratt.edu', 'http://www.pratt.edu/'),
(745, 1, 'Presbyterian College', 'presby.edu', 'http://www.presby.edu/'),
(746, 1, 'Prescott College', 'prescott.edu', 'http://www.prescott.edu/'),
(747, 1, 'Princeton University', 'princeton.edu', 'http://www.princeton.edu/'),
(748, 1, 'Providence College', 'providence.edu', 'http://www.providence.edu/'),
(749, 1, 'Purdue Global University', 'purdueglobal.edu', 'http://www.purdueglobal.edu/'),
(750, 1, 'Purdue Global University (Student email)', 'student.purdueglobal.edu', 'http://www.purdueglobal.edu/'),
(751, 1, 'Purdue University', 'purdue.edu', 'http://www.purdue.edu/'),
(752, 1, 'Purdue University Calumet', 'purduecal.edu', 'http://webs.purduecal.edu/'),
(753, 1, 'Purdue University North Central', 'pnc.edu', 'http://www.pnc.edu/'),
(754, 1, 'Quincy University', 'quincy.edu', 'http://www.quincy.edu/'),
(755, 1, 'Quinnipiac College', 'quinnipiac.edu', 'http://www.quinnipiac.edu/'),
(756, 1, 'Radford University', 'radford.edu', 'http://www.radford.edu/'),
(757, 1, 'Ramapo College', 'ramapo.edu', 'http://www.ramapo.edu/'),
(758, 1, 'Randolph-Macon College', 'rmc.edu', 'http://www.rmc.edu/'),
(759, 1, 'Randolph-Macon Woman\'s College', 'rmwc.edu', 'http://www.rmwc.edu/'),
(760, 1, 'Reed College', 'reed.edu', 'http://www.reed.edu/'),
(761, 1, 'Regent University', 'regent.edu', 'http://www.regent.edu/'),
(762, 1, 'Regis University', 'regis.edu', 'http://www.regis.edu/'),
(763, 1, 'Rensselaer Polytechnic Institute', 'rpi.edu', 'http://www.rpi.edu/'),
(764, 1, 'Rhode Island College', 'ric.edu', 'http://www.ric.edu/'),
(765, 1, 'Rhodes College', 'rhodes.edu', 'http://www.rhodes.edu/'),
(766, 1, 'Rice University', 'rice.edu', 'http://www.rice.edu/'),
(767, 1, 'Richard Stockton College of New Jersey', 'stockton.edu', 'http://www.stockton.edu/'),
(768, 1, 'Rider University', 'rider.edu', 'http://www.rider.edu/'),
(769, 1, 'Ripon College', 'ripon.edu', 'http://www.ripon.edu/'),
(770, 1, 'Rivier College', 'riv.edu', 'http://www.riv.edu/'),
(771, 1, 'Roanoke College', 'roanoke.edu', 'http://www.roanoke.edu/'),
(772, 1, 'Robert Morris University', 'rmu.edu', 'http://www.rmu.edu/'),
(773, 1, 'Rochester Institute of Technology', 'rit.edu', 'http://www.rit.edu/'),
(774, 1, 'Rockefeller University', 'rockefeller.edu', 'http://www.rockefeller.edu/'),
(775, 1, 'Rockford College', 'rockford.edu', 'http://www.rockford.edu/'),
(776, 1, 'Rockhurst College', 'rockhurst.edu', 'http://www.rockhurst.edu/'),
(777, 1, 'Rocky Mountain College', 'rocky.edu', 'http://www.rocky.edu/'),
(778, 1, 'Roger Williams University', 'rwu.edu', 'http://www.rwu.edu/'),
(779, 1, 'Rollins College', 'rollins.edu', 'http://www.rollins.edu/'),
(780, 1, 'Rosary College', 'rosary.edu', 'http://www.rosary.edu/'),
(781, 1, 'Rose-Hulman Institute of Technology', 'rose-hulman.edu', 'http://www.rose-hulman.edu/'),
(782, 1, 'Rowan College', 'rowan.edu', 'http://www.rowan.edu/'),
(783, 1, 'Rutgers University', 'rutgers.edu', 'http://www.rutgers.edu/'),
(784, 1, 'Sacred Heart University', 'sacredheart.edu', 'http://www.sacredheart.edu/'),
(785, 1, 'Sage Colleges', 'sage.edu', 'http://www.sage.edu/'),
(786, 1, 'Saginaw Valley State University', 'svsu.edu', 'http://www.svsu.edu/'),
(787, 1, 'Saint Anselm College', 'anselm.edu', 'http://www.anselm.edu/'),
(788, 1, 'Saint Cloud State University', 'stcloudstate.edu', 'http://www.stcloudstate.edu/'),
(789, 1, 'Saint Edward\'s University', 'stedwards.edu', 'http://www.stedwards.edu/'),
(790, 1, 'St. Francis College', 'sfc.edu', 'https://www.sfc.edu/'),
(791, 1, 'Saint John\'s University (NY)', 'stjohns.edu', 'http://www.stjohns.edu/'),
(792, 1, 'Saint Joseph\'s College (IN)', 'saintjoe.edu', 'http://www.saintjoe.edu/'),
(793, 1, 'Saint Joseph\'s University', 'sju.edu', 'http://www.sju.edu/'),
(794, 1, 'Saint Leo University', 'saintleo.edu', 'http://www.saintleo.edu/'),
(795, 1, 'Saint Louis University', 'slu.edu', 'http://www.slu.edu/'),
(796, 1, 'Saint Mary College', 'smcks.edu', 'http://www.smcks.edu/'),
(797, 1, 'Saint Mary\'s College (IN)', 'saintmarys.edu', 'http://www.saintmarys.edu/'),
(798, 1, 'Saint Mary\'s College of California', 'stmarys-ca.edu', 'http://www.stmarys-ca.edu/'),
(799, 1, 'Saint Mary\'s University of Minnesota', 'smumn.edu', 'http://www.smumn.edu/'),
(800, 1, 'Saint Michael\'s College', 'smcvt.edu', 'http://www.smcvt.edu/'),
(801, 1, 'Saint Olaf College', 'stolaf.edu', 'http://www.stolaf.edu/'),
(802, 1, 'Saint Vincent College', 'stvincent.edu', 'http://www.stvincent.edu/'),
(803, 1, 'Saint Xavier University', 'sxu.edu', 'http://www.sxu.edu/'),
(804, 1, 'Salisbury University', 'salisbury.edu', 'http://www.salisbury.edu/'),
(805, 1, 'Salish Kootenai College', 'skc.edu', 'http://www.skc.edu/'),
(806, 1, 'Samford University', 'samford.edu', 'http://www.samford.edu/'),
(807, 1, 'Sam Houston State University', 'shsu.edu', 'http://www.shsu.edu/'),
(808, 1, 'San Diego State University', 'sdsu.edu', 'http://www.sdsu.edu/'),
(809, 1, 'San Francisco State University', 'sfsu.edu', 'http://www.sfsu.edu/'),
(810, 1, 'San Jose State University', 'sjsu.edu', 'http://www.sjsu.edu/'),
(811, 1, 'Santa Clara University', 'scu.edu', 'http://www.scu.edu/'),
(812, 1, 'Sarah Lawrence College', 'slc.edu', 'http://www.slc.edu/'),
(813, 1, 'School of the Art Institute of Chicago', 'saic.edu', 'http://www.saic.edu/'),
(814, 1, 'Seattle Central College', 'seattlecentral.edu', 'http://seattlecentral.edu/'),
(815, 1, 'Seattle Pacific University', 'spu.edu', 'http://www.spu.edu/'),
(816, 1, 'Seattle University', 'seattleu.edu', 'http://www.seattleu.edu/'),
(817, 1, 'Seton Hall University', 'shu.edu', 'http://www.shu.edu/'),
(818, 1, 'Sewanee, University of the South', 'sewanee.edu', 'http://www.sewanee.edu/'),
(819, 1, 'Shawnee State University', 'shawnee.edu', 'http://www.shawnee.edu/'),
(820, 1, 'Shenandoah University', 'su.edu', 'http://www.su.edu/'),
(821, 1, 'Shippensburg University of Pennsylvania', 'ship.edu', 'http://www.ship.edu/'),
(822, 1, 'Shorter College', 'shorter.edu', 'http://www.shorter.edu/'),
(823, 1, 'Simmons College', 'simmons.edu', 'http://www.simmons.edu/'),
(824, 1, 'Simon\'s Rock College', 'simons-rock.edu', 'http://www.simons-rock.edu/'),
(825, 1, 'Simpson College', 'simpson.edu', 'http://www.simpson.edu/'),
(826, 1, 'Sinclair Community College', 'sinclair.edu', 'http://www.sinclair.edu/'),
(827, 1, 'Skidmore College', 'skidmore.edu', 'http://www.skidmore.edu/'),
(828, 1, 'Slippery Rock University of Pennsylvania', 'sru.edu', 'http://www.sru.edu/'),
(829, 1, 'Smith College', 'smith.edu', 'http://www.smith.edu/'),
(830, 1, 'Sonoma State University', 'sonoma.edu', 'http://www.sonoma.edu/'),
(831, 1, 'South Dakota School of Mines and Technology', 'sdsmt.edu', 'http://www.sdsmt.edu/'),
(832, 1, 'South Dakota State University', 'sdstate.edu', 'http://www.sdstate.edu/'),
(833, 1, 'Southeastern Louisiana University', 'selu.edu', 'http://www.selu.edu/'),
(834, 1, 'Southeast Missouri State University', 'semo.edu', 'http://www.semo.edu/'),
(835, 1, 'Southern College', 'southern.edu', 'http://www.southern.edu/'),
(836, 1, 'Southern College of Technology', 'sct.edu', 'http://www.sct.edu/'),
(837, 1, 'Southern Connecticut State University', 'southernct.edu', 'http://www.southernct.edu/'),
(838, 1, 'Southern Illinois University-Carbondale', 'siu.edu', 'http://www.siu.edu/'),
(839, 1, 'Southern Illinois University-Edwardsville', 'siue.edu', 'http://www.siue.edu/'),
(840, 1, 'Southern Methodist University', 'smu.edu', 'http://www.smu.edu/'),
(841, 1, 'Southern Nazarene University', 'snu.edu', 'http://www.snu.edu/'),
(842, 1, 'Southern New Hampshire University', 'snhu.edu', 'http://www.snhu.edu/'),
(843, 1, 'Southern Oregon State College', 'sou.edu', 'http://www.sou.edu/'),
(844, 1, 'Southern University and A&M College', 'subr.edu', 'http://www.subr.edu/'),
(845, 1, 'Southern Utah University', 'suu.edu', 'http://www.suu.edu/'),
(846, 1, 'South Texas College of Law', 'stcl.edu', 'http://www.stcl.edu/'),
(847, 1, 'Southwest Baptist University', 'sbuniv.edu', 'http://www.sbuniv.edu/'),
(848, 1, 'Southwestern Adventist College', 'swac.edu', 'http://www.swac.edu/'),
(849, 1, 'Southwestern Assemblies of God University', 'sagu.edu', 'http://www.sagu.edu/'),
(850, 1, 'Southwestern College (KS)', 'sckans.edu', 'http://www.sckans.edu/'),
(851, 1, 'Southwestern University', 'southwestern.edu', 'http://www.southwestern.edu/'),
(852, 1, 'Southwest Minnesota State University', 'smsu.edu', 'http://www.smsu.edu/'),
(853, 1, 'Southwest Texas State University', 'swt.edu', 'http://www.swt.edu/'),
(854, 1, 'Spelman College', 'auc.edu', 'http://www.auc.edu/'),
(855, 1, 'Spring Arbor College', 'arbor.edu', 'http://www.arbor.edu/'),
(856, 1, 'Spring Hill College', 'shc.edu', 'http://www.shc.edu/'),
(857, 1, 'St. Ambrose University', 'sau.edu', 'http://www.sau.edu/'),
(858, 1, 'St. Andrews Presbyterian College', 'sapc.edu', 'http://www.sapc.edu/'),
(859, 1, 'Stanford University', 'stanford.edu', 'http://www.stanford.edu/'),
(860, 1, 'State University of New York at Albany', 'albany.edu', 'http://www.albany.edu/'),
(861, 1, 'State University of New York at Binghamton', 'binghamton.edu', 'http://www.binghamton.edu/'),
(862, 1, 'State University of New York at Buffalo', 'buffalo.edu', 'http://www.buffalo.edu/'),
(863, 1, 'State University of New York at Farmingdale', 'farmingdale.edu', 'http://www.farmingdale.edu/'),
(864, 1, 'State University of New York at Fredonia', 'fredonia.edu', 'http://home.fredonia.edu/'),
(865, 1, 'State University of New York at Oswego', 'oswego.edu', 'http://www.oswego.edu/'),
(866, 1, 'State University of New York at Plattsburgh', 'plattsburgh.edu', 'http://www.plattsburgh.edu/'),
(867, 1, 'State University of New York at Stony Brook', 'stonybrook.edu', 'http://www.stonybrook.edu/'),
(868, 1, 'Academic medical center at State University of New York at Stony Brook', 'stonybrookmedicine.edu', 'http://www.stonybrookmedicine.edu/'),
(869, 1, 'State University of New York College at Brockport', 'brockport.edu', 'http://www.brockport.edu/'),
(870, 1, 'State University of New York College at Buffalo', 'buffalostate.edu', 'http://suny.buffalostate.edu/'),
(871, 1, 'State University of New York College at Cortland', 'cortland.edu', 'http://www.cortland.edu/'),
(872, 1, 'State University of New York College at Geneseo', 'geneseo.edu', 'http://www.geneseo.edu/'),
(873, 1, 'State University of New York College at New Paltz', 'newpaltz.edu', 'http://www.newpaltz.edu/'),
(874, 1, 'State University of New York College at Potsdam', 'potsdam.edu', 'http://www.potsdam.edu/'),
(875, 1, 'State University of New York College of Agriculture and Technology at Cobleskill', 'cobleskill.edu', 'http://www.cobleskill.edu/'),
(876, 1, 'State University of New York College of Environmental Science and Forestry', 'esf.edu', 'http://www.esf.edu/'),
(877, 1, 'State University of New York College of Technology at Alfred', 'alfredtech.edu', 'http://www.alfredtech.edu/'),
(878, 1, 'State University of New York Polytechnic Institute', 'sunyit.edu', 'http://www.sunypoly.edu/'),
(879, 1, 'State University of New York System', 'sunycentral.edu', 'http://www.sunycentral.edu/'),
(880, 1, 'St. Bonaventure University', 'sbu.edu', 'http://www.sbu.edu/'),
(881, 1, 'Stephen F. Austin State University', 'sfasu.edu', 'http://www.sfasu.edu/'),
(882, 1, 'Stephens College', 'stephens.edu', 'http://www.stephens.edu/'),
(883, 1, 'Stetson University', 'stetson.edu', 'http://www.stetson.edu/'),
(884, 1, 'Stevens Institute of Technology', 'stevens.edu', 'http://www.stevens.edu/'),
(885, 1, 'St. John\'s College - Annapolis', 'sjca.edu', 'http://www.sjca.edu/'),
(886, 1, 'St. John\'s College - Santa Fe', 'sjcsf.edu', 'http://www.sjcsf.edu/'),
(887, 1, 'St. Joseph College (CT)', 'sjc.edu', 'http://www.sjc.edu/'),
(888, 1, 'St. Joseph\'s College (ME)', 'sjcme.edu', 'http://www.sjcme.edu/'),
(889, 1, 'St. Lawrence University', 'stlawu.edu', 'http://www.stlawu.edu/'),
(890, 1, 'St. Louis College of Pharmacy', 'stlcop.edu', 'http://www.stlcop.edu/'),
(891, 1, 'St. Martin\'s College', 'stmartin.edu', 'http://www.stmartin.edu/'),
(892, 1, 'St. Mary\'s College of Maryland', 'smcm.edu', 'http://www.smcm.edu/'),
(893, 1, 'Strayer College', 'strayer.edu', 'http://www.strayer.edu/'),
(894, 1, 'St. Thomas University (FL)', 'stu.edu', 'http://www.stu.edu/'),
(895, 1, 'Suffolk University', 'suffolk.edu', 'http://www.suffolk.edu/'),
(896, 1, 'Sul Ross State University', 'sulross.edu', 'http://www.sulross.edu/'),
(897, 1, 'Summit University of Louisiana', 'summitunivofla.edu', 'http://www.summitunivofla.edu/'),
(898, 1, 'Susquehanna University', 'susqu.edu', 'http://www.susqu.edu/'),
(899, 1, 'Swarthmore College', 'swarthmore.edu', 'http://www.swarthmore.edu/'),
(900, 1, 'Sweet Briar College', 'sbc.edu', 'http://www.sbc.edu/'),
(901, 1, 'Syracuse University', 'syr.edu', 'http://www.syr.edu/'),
(902, 1, 'Tabor College', 'tabor.edu', 'http://www.tabor.edu/'),
(903, 1, 'Tarleton State University', 'tarleton.edu', 'http://www.tarleton.edu/'),
(904, 1, 'Taylor University', 'tayloru.edu', 'http://www.tayloru.edu/'),
(905, 1, 'Temple University', 'temple.edu', 'http://www.temple.edu/'),
(906, 1, 'Tennessee State University', 'tnstate.edu', 'http://www.tnstate.edu/'),
(907, 1, 'Tennessee Technological University', 'tntech.edu', 'http://www.tntech.edu/'),
(908, 1, 'Tarrant County College', 'tccd.edu', 'http://www.tccd.edu/'),
(909, 1, 'Texas A&M International University', 'tamiu.edu', 'http://www.tamiu.edu/'),
(910, 1, 'Texas A&M University - College Station', 'tamu.edu', 'http://www.tamu.edu/'),
(911, 1, 'Texas A&M University - Commerce', 'tamuc.edu', 'http://www.tamuc.edu/'),
(912, 1, 'Texas A&M University - Corpus Christi', 'tamucc.edu', 'http://www.tamucc.edu/'),
(913, 1, 'Texas A&M University - Kingsville', 'tamuk.edu', 'http://www.tamuk.edu/'),
(914, 1, 'Texas Christian University', 'tcu.edu', 'http://www.tcu.edu/'),
(915, 1, 'Texas Southern University', 'tsu.edu', 'http://www.tsu.edu/'),
(916, 1, 'Texas State University', 'txstate.edu', 'http://www.txstate.edu/'),
(917, 1, 'Texas Tech University', 'ttu.edu', 'http://www.ttu.edu/'),
(918, 1, 'Texas Tech University-Health Sciences Center', 'ttuhsc.edu', 'http://www.ttuhsc.edu/'),
(919, 1, 'Texas Woman\'s University', 'twu.edu', 'http://www.twu.edu/'),
(920, 1, 'The Citadel', 'citadel.edu', 'http://www.citadel.edu/'),
(921, 1, 'The Jewish Theological Seminary', 'jtsa.edu', 'http://www.jtsa.edu/'),
(922, 1, 'Thomas College', 'thomas.edu', 'http://www.thomas.edu/'),
(923, 1, 'Thomas Edison State University', 'tesc.edu', 'http://www.tesc.edu/'),
(924, 1, 'Thomas Jefferson University', 'jefferson.edu', 'http://www.jefferson.edu/'),
(925, 1, 'Thomas More College', 'thomasmore.edu', 'http://www.thomasmore.edu/'),
(926, 1, 'Thunderbird School of Global Management', 'thunderbird.edu', 'http://www.thunderbird.edu/'),
(927, 1, 'Towson University', 'towson.edu', 'http://www.towson.edu/'),
(928, 1, 'Transylvania University', 'transy.edu', 'http://www.transy.edu/'),
(929, 1, 'Trenton State College', 'trenton.edu', 'http://www.trenton.edu/'),
(930, 1, 'Trine University', 'trine.edu', 'http://www.trine.edu/'),
(931, 1, 'Trinity College (CT)', 'trincoll.edu', 'http://www.trincoll.edu/'),
(932, 1, 'Trinity College (DC)', 'trinitydc.edu', 'http://www.trinitydc.edu/'),
(933, 1, 'Trinity University', 'trinity.edu', 'http://www.trinity.edu/'),
(934, 1, 'Troy State University', 'tsufl.edu', 'http://www.tsufl.edu/'),
(935, 1, 'Truman State University', 'truman.edu', 'http://www.truman.edu/'),
(936, 1, 'Tucson University', 'tucsonu.edu', 'http://www.tucsonu.edu/'),
(937, 1, 'Tufts University', 'tufts.edu', 'http://www.tufts.edu/'),
(938, 1, 'Tulane University', 'tulane.edu', 'http://www.tulane.edu/'),
(939, 1, 'Tuskegee University', 'tuskegee.edu', 'http://www.tuskegee.edu/'),
(940, 1, 'Uniformed Services University of the Health Sciences', 'usuhs.mil', 'http://www.usuhs.mil/'),
(941, 1, 'Union College', 'union.edu', 'http://www.union.edu/'),
(942, 1, 'Union Institute', 'tui.edu', 'http://www.tui.edu/'),
(943, 1, 'Union University', 'uu.edu', 'http://www.uu.edu/'),
(944, 1, 'United States Air Force Academy', 'usafa.af.mil', 'http://www.usafa.af.mil/'),
(945, 1, 'United States International University', 'usiu.edu', 'http://www.usiu.edu/'),
(946, 1, 'United States Merchant Marine Academy', 'usmma.edu', 'http://www.usmma.edu/'),
(947, 1, 'United States Military Academy', 'usma.edu', 'http://www.usma.edu/'),
(948, 1, 'United States Naval Academy', 'usna.edu', 'http://www.usna.edu/'),
(949, 1, 'University of Advancing Technology', 'uat.edu', 'http://www.uat.edu/'),
(950, 1, 'University of Akron', 'uakron.edu', 'http://www.uakron.edu/'),
(951, 1, 'University of Alabama at Birmingham', 'uab.edu', 'http://www.uab.edu/'),
(952, 1, 'University of Alabama at Huntsville', 'uah.edu', 'http://www.uah.edu/'),
(953, 1, 'University of Alaska', 'alaska.edu', 'http://www.alaska.edu/'),
(954, 1, 'University of Alaska - Anchorage', 'uaa.alaska.edu', 'http://www.uaa.alaska.edu/'),
(955, 1, 'University of Alaska - Fairbanks', 'uaf.edu', 'http://www.uaf.edu/'),
(956, 1, 'University of Alaska - Southeast', 'uas.alaska.edu', 'http://www.uas.alaska.edu/'),
(957, 1, 'University of Arizona', 'arizona.edu', 'http://www.arizona.edu/'),
(958, 1, 'University of Arkansas - Fayetteville', 'uark.edu', 'http://www.uark.edu/'),
(959, 1, 'University of Arkansas - Fort Smith', 'uafs.edu', 'http://www.uafs.edu/'),
(960, 1, 'University of Arkansas for Medical Sciences', 'uams.edu', 'http://www.uams.edu/'),
(961, 1, 'University of Arkansas - Little Rock', 'ualr.edu', 'http://www.ualr.edu/'),
(962, 1, 'University of Arkansas - Monticello', 'uamont.edu', 'http://www.uamont.edu/'),
(963, 1, 'University of Baltimore', 'ubalt.edu', 'http://www.ubalt.edu/'),
(964, 1, 'University of Bridgeport', 'bridgeport.edu', 'http://www.bridgeport.edu/'),
(965, 1, 'University of California, Berkeley', 'berkeley.edu', 'http://www.berkeley.edu/'),
(966, 1, 'University of California, Davis', 'ucdavis.edu', 'http://www.ucdavis.edu/'),
(967, 1, 'University of California, Irvine', 'uci.edu', 'http://www.uci.edu/'),
(968, 1, 'University of California, Los Angeles', 'ucla.edu', 'http://www.ucla.edu/'),
(969, 1, 'University of California, Merced', 'ucmerced.edu', 'http://www.ucmerced.edu/'),
(970, 1, 'University of California, Office of the President', 'ucop.edu', 'https://www.ucop.edu/'),
(971, 1, 'University of California, Riverside', 'ucr.edu', 'http://www.ucr.edu/'),
(972, 1, 'University of California, San Diego', 'ucsd.edu', 'http://www.ucsd.edu/'),
(973, 1, 'University of California, San Francisco', 'ucsf.edu', 'http://www.ucsf.edu/'),
(974, 1, 'University of California, Santa Barbara', 'ucsb.edu', 'http://www.ucsb.edu/'),
(975, 1, 'University of California, Santa Cruz', 'ucsc.edu', 'http://www.ucsc.edu/'),
(976, 1, 'University of Central Arkansas', 'uca.edu', 'http://www.uca.edu/'),
(977, 1, 'University of Central Florida', 'ucf.edu', 'http://www.ucf.edu/'),
(978, 1, 'University of Central Missouri', 'ucmo.edu', 'http://www.ucmo.edu/'),
(979, 1, 'UC Hastings College of the Law', 'uchastings.edu', 'http://www.uchastings.edu/'),
(980, 1, 'University of Charleston', 'uchaswv.edu', 'http://www.uchaswv.edu/'),
(981, 1, 'University of Chicago', 'uchicago.edu', 'http://www.uchicago.edu/'),
(982, 1, 'University of Cincinnati', 'uc.edu', 'http://www.uc.edu/'),
(983, 1, 'University of Colorado at Boulder', 'colorado.edu', 'http://www.colorado.edu/'),
(984, 1, 'University of Colorado at Colorado Springs', 'uccs.edu', 'http://www.uccs.edu/'),
(985, 1, 'University of Colorado at Denver', 'ucdenver.edu', 'http://www.ucdenver.edu/'),
(986, 1, 'University of Colorado Health Sciences Center', 'hsc.colorado.edu', 'http://www.hsc.colorado.edu/'),
(987, 1, 'University of Connecticut', 'uconn.edu', 'http://www.uconn.edu/'),
(988, 1, 'University of Dallas', 'udallas.edu', 'http://www.udallas.edu/'),
(989, 1, 'University of Dayton', 'udayton.edu', 'http://www.udayton.edu/'),
(990, 1, 'University of Delaware', 'udel.edu', 'http://www.udel.edu/'),
(991, 1, 'University of Denver', 'du.edu', 'http://www.du.edu/'),
(992, 1, 'University of Detroit Mercy', 'udmercy.edu', 'http://www.udmercy.edu/'),
(993, 1, 'University of Dubuque', 'dbq.edu', 'http://www.dbq.edu/'),
(994, 1, 'University of Evansville', 'evansville.edu', 'http://www.evansville.edu/'),
(995, 1, 'University of Florida', 'ufl.edu', 'http://www.ufl.edu/'),
(996, 1, 'University of Georgia', 'uga.edu', 'http://www.uga.edu/'),
(997, 1, 'University of Great Falls', 'ugf.edu', 'http://www.ugf.edu/'),
(998, 1, 'University of Hartford', 'hartford.edu', 'http://www.hartford.edu/'),
(999, 1, 'University of Hawaii at Hilo', 'hilo.hawaii.edu', 'http://hilo.hawaii.edu/'),
(1000, 1, 'University of Hawaii at Manoa', 'manoa.hawaii.edu', 'http://manoa.hawaii.edu/'),
(1001, 1, 'University of Hawaii System', 'hawaii.edu', 'http://www.hawaii.edu/'),
(1002, 1, 'University of Houston', 'uh.edu', 'http://www.uh.edu/'),
(1003, 1, 'University of Idaho', 'uidaho.edu', 'http://www.uidaho.edu/'),
(1004, 1, 'University of Illinois Chicago', 'uic.edu', 'http://www.uic.edu/'),
(1005, 1, 'University of Illinois Springfield', 'uis.edu', 'http://www.uis.edu/'),
(1006, 1, 'University of Illinois Urbana-Champaign', 'uiuc.edu', 'https://illinois.edu/'),
(1007, 1, 'University of Indianapolis', 'uindy.edu', 'http://www.uindy.edu/'),
(1008, 1, 'University of Iowa', 'uiowa.edu', 'http://www.uiowa.edu/'),
(1009, 1, 'University of Jamestown', 'uj.edu', 'http://www.uj.edu/'),
(1010, 1, 'University of Kansas', 'ku.edu', 'http://www.ku.edu/'),
(1011, 1, 'University of Kansas School of Medicine', 'kumc.edu', 'http://www.kumc.edu/'),
(1012, 1, 'University of Kentucky', 'uky.edu', 'http://www.uky.edu/'),
(1013, 1, 'University of Louisiana at Lafeyette', 'louisiana.edu', 'http://www.louisiana.edu/'),
(1014, 1, 'University of Louisiana at Monroe', 'ulm.edu', 'http://www.ulm.edu/'),
(1015, 1, 'University of Louisville', 'louisville.edu', 'http://www.louisville.edu/'),
(1016, 1, 'University of Maine', 'umaine.edu', 'http://www.umaine.edu/'),
(1017, 1, 'University of Maine at Farmington', 'umf.maine.edu', 'http://www.umf.maine.edu/'),
(1018, 1, 'University of Maine at Fort Kent', 'umfk.maine.edu', 'http://www.umfk.maine.edu/'),
(1019, 1, 'University of Maine at Machias', 'umm.maine.edu', 'http://www.umm.maine.edu/'),
(1020, 1, 'University of Maine at Presque Island', 'umpi.maine.edu', 'http://www.umpi.maine.edu/'),
(1021, 1, 'University of Maine System', 'maine.edu', 'http://www.maine.edu/'),
(1022, 1, 'University of Maryland, Baltimore', 'umaryland.edu', 'http://www.umaryland.edu/'),
(1023, 1, 'Mayo Clinic', 'mayo.edu', 'https://www.mayo.edu/'),
(1024, 1, 'University of Maryland, Baltimore County', 'umbc.edu', 'http://www.umbc.edu/'),
(1025, 1, 'University of Maryland, College Park', 'umd.edu', 'http://www.umd.edu/'),
(1026, 1, 'University of Maryland Eastern Shore', 'umes.edu', 'http://www.umes.edu/'),
(1027, 1, 'University of Maryland - University College', 'umuc.edu', 'http://www.umuc.edu/'),
(1028, 1, 'University of Massachusetts at Amherst', 'umass.edu', 'http://www.umass.edu/'),
(1029, 1, 'University of Massachusetts at Dartmouth', 'umassd.edu', 'http://www.umassd.edu/'),
(1030, 1, 'University of Massachusetts at Lowell', 'uml.edu', 'http://www.uml.edu/'),
(1031, 1, 'University of Memphis', 'memphis.edu', 'http://www.memphis.edu/'),
(1032, 1, 'University of Miami', 'miami.edu', 'http://welcome.miami.edu/'),
(1033, 1, 'University of Michigan - Ann Arbor', 'umich.edu', 'http://www.umich.edu/'),
(1034, 1, 'University of Michigan - Dearborn', 'umdearborn.edu', 'http://www.umdearborn.edu/'),
(1035, 1, 'University of Minnesota', 'umn.edu', 'http://www.umn.edu/'),
(1036, 1, 'University of Minnesota - Crookston', 'crk.umn.edu', 'http://www.crk.umn.edu/'),
(1037, 1, 'University of Minnesota - Duluth', 'd.umn.edu', 'http://www.d.umn.edu/'),
(1038, 1, 'University of Minnesota - Morris', 'mrs.umn.edu', 'http://www.mrs.umn.edu/'),
(1039, 1, 'University of Mississippi', 'olemiss.edu', 'http://www.olemiss.edu/'),
(1040, 1, 'University of Missouri', 'missouri.edu', 'http://www.missouri.edu/'),
(1041, 1, 'University of Missouri - Kansas City', 'umkc.edu', 'http://www.umkc.edu/'),
(1042, 1, 'University of Missouri - Rolla', 'umr.edu', 'http://www.umr.edu/'),
(1043, 1, 'University of Missouri - Saint Louis', 'umsl.edu', 'http://www.umsl.edu/'),
(1044, 1, 'University of Montana', 'umt.edu', 'http://www.umt.edu/'),
(1045, 1, 'University of Nebraska, Kearney', 'unk.edu', 'http://www.unk.edu/'),
(1046, 1, 'University of Nebraska, Lincoln', 'unl.edu', 'http://www.unl.edu/'),
(1047, 1, 'University of Nebraska, Omaha', 'unomaha.edu', 'http://www.unomaha.edu/'),
(1048, 1, 'University of Nevada, Las Vegas', 'unlv.edu', 'http://www.unlv.edu/'),
(1049, 1, 'University of Nevada, Reno', 'unr.edu', 'http://www.unr.edu/'),
(1050, 1, 'University of New England', 'une.edu', 'http://www.une.edu/'),
(1051, 1, 'University of New Hampshire', 'unh.edu', 'https://www.unh.edu/'),
(1052, 1, 'University of New Haven', 'newhaven.edu', 'http://www.newhaven.edu/'),
(1053, 1, 'University of New Mexico', 'unm.edu', 'http://www.unm.edu/'),
(1054, 1, 'University of New Orleans', 'uno.edu', 'http://www.uno.edu/'),
(1055, 1, 'University of North Carolina at Asheville', 'unca.edu', 'http://www.unca.edu/'),
(1056, 1, 'University of North Carolina at Chapel Hill', 'unc.edu', 'http://www.unc.edu/'),
(1057, 1, 'University of North Carolina at Charlotte', 'uncc.edu', 'http://www.uncc.edu/'),
(1058, 1, 'The University of North Carolina at Greensboro', 'uncg.edu', 'https://www.uncg.edu/'),
(1059, 1, 'University of North Carolina at Wilmington', 'uncw.edu', 'http://uncw.edu/'),
(1060, 1, 'University of North Dakota', 'und.edu', 'http://und.edu/'),
(1061, 1, 'University of Northern Colorado', 'unco.edu', 'http://www.unco.edu/'),
(1062, 1, 'University of Northern Iowa', 'uni.edu', 'http://www.uni.edu/'),
(1063, 1, 'University of North Florida', 'unf.edu', 'http://www.unf.edu/'),
(1064, 1, 'University of North Texas', 'unt.edu', 'http://www.unt.edu/'),
(1065, 1, 'University of North Texas Health Science Center', 'hsc.unt.edu', 'http://www.hsc.unt.edu/'),
(1066, 1, 'University of Notre Dame', 'nd.edu', 'http://www.nd.edu/'),
(1067, 1, 'University of Oklahoma', 'ou.edu', 'http://www.ou.edu/'),
(1068, 1, 'University of Oregon', 'uoregon.edu', 'http://www.uoregon.edu/'),
(1069, 1, 'University of Pennsylvania', 'upenn.edu', 'http://www.upenn.edu/'),
(1070, 1, 'University of Phoenix', 'phoenix.edu', 'http://www.phoenix.edu/'),
(1071, 1, 'University of Pittsburgh', 'pitt.edu', 'http://www.pitt.edu/'),
(1072, 1, 'University of Pittsburgh at Johnstown', 'upj.pitt.edu', 'http://www.upj.pitt.edu/'),
(1073, 1, 'University of Pittsburgh at Bradford', 'upb.pitt.edu', 'https://www.upb.pitt.edu/'),
(1074, 1, 'University of Portland', 'up.edu', 'http://www.up.edu/'),
(1075, 1, 'University of Puerto Rico', 'upr.edu', 'http://www.upr.edu/'),
(1076, 1, 'University of Puget Sound', 'ups.edu', 'http://www.ups.edu/'),
(1077, 1, 'University of Redlands', 'uor.edu', 'http://www.uor.edu/'),
(1078, 1, 'University of Rhode Island', 'uri.edu', 'http://www.uri.edu/'),
(1079, 1, 'University of Richmond', 'urich.edu', 'http://www.urich.edu/'),
(1080, 1, 'University of Rochester', 'rochester.edu', 'http://www.rochester.edu/'),
(1081, 1, 'University of Saint Thomas (MN)', 'stthomas.edu', 'http://www.stthomas.edu/'),
(1082, 1, 'University of Saint Thomas (TX)', 'stthom.edu', 'http://www.stthom.edu/'),
(1083, 1, 'University of San Diego', 'sandiego.edu', 'http://www.sandiego.edu/'),
(1084, 1, 'University of San Francisco', 'usfca.edu', 'http://www.usfca.edu/'),
(1085, 1, 'University of Science & Arts of Oklahoma', 'usao.edu', 'http://usao.edu/'),
(1086, 1, 'University of Scranton', 'scranton.edu', 'http://www.scranton.edu/'),
(1087, 1, 'University of Sioux Falls', 'usouixfalls.edu', 'http://www.usouixfalls.edu/'),
(1088, 1, 'University of South Alabama', 'southalabama.edu', 'http://www.southalabama.edu/'),
(1089, 1, 'University of South Carolina', 'sc.edu', 'http://www.sc.edu/'),
(1090, 1, 'Anderson University', 'andersonuniversity.edu', 'https://andersonuniversity.edu/'),
(1091, 1, 'University of South Carolina - Aiken', 'usca.edu', 'http://www.usca.edu/'),
(1092, 1, 'University of South Dakota', 'usd.edu', 'http://www.usd.edu/'),
(1093, 1, 'University of Southern California', 'usc.edu', 'http://www.usc.edu/'),
(1094, 1, 'University of Southern Indiana', 'usi.edu', 'http://www.usi.edu/'),
(1095, 1, 'University of Southern Maine', 'usm.maine.edu', 'http://www.usm.maine.edu/'),
(1096, 1, 'University of Southern Mississippi', 'usm.edu', 'http://www.usm.edu/'),
(1097, 1, 'University of South Florida', 'usf.edu', 'http://www.usf.edu/'),
(1098, 1, 'University of Southwestern Louisiana', 'usl.edu', 'http://www.usl.edu/'),
(1099, 1, 'University of Tampa', 'ut.edu', 'http://www.ut.edu/'),
(1100, 1, 'University of Tennessee at Chattanooga', 'utc.edu', 'http://www.utc.edu/'),
(1101, 1, 'University of Tennessee, Knoxville', 'utk.edu', 'http://www.utk.edu/'),
(1102, 1, 'University of Tennessee, Martin', 'utm.edu', 'http://www.utm.edu/'),
(1103, 1, 'University of Texas at Arlington', 'uta.edu', 'http://www.uta.edu/'),
(1104, 1, 'The University of Texas at Austin', 'utexas.edu', 'https://www.utexas.edu/'),
(1105, 1, 'University of Texas at Brownsville', 'utb.edu', 'http://www.utb.edu/'),
(1106, 1, 'University of Texas at Dallas', 'utd.edu', 'http://www.utdallas.edu/'),
(1107, 1, 'University of Texas at El Paso', 'utep.edu', 'http://www.utep.edu/'),
(1108, 1, 'The University of Texas at San Antonio', 'utsa.edu', 'https://www.utsa.edu/'),
(1109, 1, 'University of Texas at Tyler', 'uttyler.edu', 'http://www.uttyler.edu/'),
(1110, 1, 'University of Texas Medical Branch', 'utmb.edu', 'http://www.utmb.edu/'),
(1111, 1, 'University of Texas - Pan American', 'panam.edu', 'http://www.panam.edu/'),
(1112, 1, 'University of Texas Southwestern Medical Center', 'swmed.edu', 'http://www.swmed.edu/'),
(1113, 1, 'University of Texas Permian Basin', 'utpb.edu', 'http://www.utpb.edu/'),
(1114, 1, 'University of the District of Columbia', 'udc.edu', 'http://www.udc.edu/'),
(1115, 1, 'University of the Incarnate Word', 'uiw.edu', 'http://www.uiw.edu/'),
(1116, 1, 'University of the Ozarks', 'ozarks.edu', 'http://www.ozarks.edu/'),
(1117, 1, 'University of the Pacific', 'uop.edu', 'http://www.uop.edu/'),
(1118, 1, 'University of Toledo', 'utoledo.edu', 'http://www.utoledo.edu/'),
(1119, 1, 'University of Tulsa', 'utulsa.edu', 'http://utulsa.edu/'),
(1120, 1, 'University of Utah', 'utah.edu', 'http://www.utah.edu/'),
(1121, 1, 'University of Vermont', 'uvm.edu', 'http://www.uvm.edu/'),
(1122, 1, 'University of Virginia, Charlottesville', 'virginia.edu', 'http://www.virginia.edu/'),
(1123, 1, 'University of Washington', 'uw.edu', 'http://www.washington.edu/'),
(1124, 1, 'University of West Alabama', 'westal.edu', 'http://www.westal.edu/'),
(1125, 1, 'University of West Florida', 'uwf.edu', 'http://www.uwf.edu/'),
(1126, 1, 'University of Wisconsin - Eau Claire', 'uwec.edu', 'http://www.uwec.edu/'),
(1127, 1, 'University of Wisconsin - Green Bay', 'uwgb.edu', 'http://www.uwgb.edu/'),
(1128, 1, 'University of Wisconsin - LaCrosse', 'uwlax.edu', 'http://www.uwlax.edu/'),
(1129, 1, 'University of Wisconsin - Madison', 'wisc.edu', 'http://www.wisc.edu/'),
(1130, 1, 'University of Wisconsin - Milwaukee', 'uwm.edu', 'http://www.uwm.edu/'),
(1131, 1, 'University of Wisconsin - Oshkosh', 'uwosh.edu', 'http://www.uwosh.edu/'),
(1132, 1, 'University of Wisconsin - Parkside', 'uwp.edu', 'http://www.uwp.edu/'),
(1133, 1, 'University of Wisconsin - Platteville', 'uwplatt.edu', 'http://www.uwplatt.edu/'),
(1134, 1, 'University of Wisconsin - River Falls', 'uwrf.edu', 'http://www.uwrf.edu/'),
(1135, 1, 'University of Wisconsin - Stevens Point', 'uwsp.edu', 'http://www.uwsp.edu/'),
(1136, 1, 'University of Wisconsin - Stout', 'uwstout.edu', 'http://www.uwstout.edu/'),
(1137, 1, 'University of Wisconsin - Superior', 'uwsuper.edu', 'http://www.uwsuper.edu/'),
(1138, 1, 'University of Wisconsin System', 'uwsa.edu', 'http://www.uwsa.edu/'),
(1139, 1, 'University of Wisconsin - Whitewater', 'uww.edu', 'http://www.uww.edu/'),
(1140, 1, 'University of Wyoming', 'uwyo.edu', 'http://www.uwyo.edu/'),
(1141, 1, 'Upper Iowa University', 'uiu.edu', 'http://www.uiu.edu/'),
(1142, 1, 'Ursinus College', 'ursinus.edu', 'http://www.ursinus.edu/'),
(1143, 1, 'Utah State University', 'usu.edu', 'http://www.usu.edu/'),
(1144, 1, 'Utah Valley State College', 'uvsc.edu', 'http://www.uvsc.edu/'),
(1145, 1, 'Valdosta State University', 'valdosta.edu', 'http://www.valdosta.edu/'),
(1146, 1, 'Valley City State University', 'vcsu.edu', 'https://www.vcsu.edu/'),
(1147, 1, 'Valparaiso University', 'valpo.edu', 'http://www.valpo.edu/'),
(1148, 1, 'Vance-Granville Community College', 'vgcc.edu', 'http://www.vgcc.edu/'),
(1149, 1, 'Vanderbilt University', 'vanderbilt.edu', 'http://www.vanderbilt.edu/'),
(1150, 1, 'Vassar College', 'vassar.edu', 'http://www.vassar.edu/'),
(1151, 1, 'Vermont Technical College', 'vtc.edu', 'http://www.vtc.edu/'),
(1152, 1, 'Villa Julie College', 'vjc.edu', 'http://www.vjc.edu/'),
(1153, 1, 'Villanova University', 'villanova.edu', 'http://www.villanova.edu/'),
(1154, 1, 'Virginia Commonwealth University', 'vcu.edu', 'http://vcu.vcu.edu/'),
(1155, 1, 'Virginia Community College System', 'vccs.edu', 'http://www.vccs.edu/'),
(1156, 1, 'Virginia Intermont College', 'vic.edu', 'http://www.vic.edu/'),
(1157, 1, 'Virginia Military Institute', 'vmi.edu', 'http://www.vmi.edu/'),
(1158, 1, 'Virginia Tech', 'vt.edu', 'https://www.vt.edu/'),
(1159, 1, 'Virginia State University', 'vsu.edu', 'http://www.vsu.edu/'),
(1160, 1, 'Virginia Wesleyan College', 'vwc.edu', 'http://www.vwc.edu/'),
(1161, 1, 'Wabash College', 'wabash.edu', 'http://www.wabash.edu/'),
(1162, 1, 'Wake Forest University', 'wfu.edu', 'http://www.wfu.edu/'),
(1163, 1, 'Walden University', 'waldenu.edu', 'http://www.waldenu.edu/'),
(1164, 1, 'Walla Walla University', 'wallawalla.edu', 'http://www.wallawalla.edu/'),
(1165, 1, 'Walsh College', 'walshcollege.edu', 'http://www.walshcollege.edu/'),
(1166, 1, 'Warren Wilson College', 'warren-wilson.edu', 'http://www.warren-wilson.edu/'),
(1167, 1, 'Wartburg College', 'wartburg.edu', 'http://www.wartburg.edu/'),
(1168, 1, 'Washburn University', 'wuacc.edu', 'http://www.wuacc.edu/'),
(1169, 1, 'Washington & Lee University', 'wlu.edu', 'http://www.wlu.edu/'),
(1170, 1, 'Washington Bible College/Capital Bible Seminary', 'bible.edu', 'http://www.bible.edu/'),
(1171, 1, 'Washington College', 'washcoll.edu', 'http://www.washcoll.edu/'),
(1172, 1, 'Washington State University', 'wsu.edu', 'http://www.wsu.edu/'),
(1173, 1, 'Washington State University at Vancouver', 'vancouver.wsu.edu', 'http://www.vancouver.wsu.edu/'),
(1174, 1, 'Washington University, Saint Louis', 'wustl.edu', 'http://www.wustl.edu/'),
(1175, 1, 'Waubonsee Community College', 'waubonsee.edu', 'http://www.waubonsee.edu/'),
(1176, 1, 'Waynesburg College', 'waynesburg.edu', 'http://waynesburg.edu/'),
(1177, 1, 'Wayne State University', 'wayne.edu', 'http://www.wayne.edu/'),
(1178, 1, 'Weber State University', 'weber.edu', 'http://www.weber.edu/'),
(1179, 1, 'Webster University', 'webster.edu', 'http://www.webster.edu/'),
(1180, 1, 'Wellesley College', 'wellesley.edu', 'http://www.wellesley.edu/'),
(1181, 1, 'Wells College', 'wells.edu', 'http://www.wells.edu/'),
(1182, 1, 'Wentworth Institute of Technology', 'wit.edu', 'http://www.wit.edu/'),
(1183, 1, 'Wesleyan University', 'wesleyan.edu', 'http://www.wesleyan.edu/'),
(1184, 1, 'Wesley College', 'wesley.edu', 'http://www.wesley.edu/'),
(1185, 1, 'West Chester University of Pennsylvania', 'wcupa.edu', 'http://www.wcupa.edu/'),
(1186, 1, 'West Coast University', 'westcoastuniversity.edu', 'http://westcoastuniversity.edu/'),
(1187, 1, 'Western Carolina University', 'wcu.edu', 'http://www.wcu.edu/'),
(1188, 1, 'Western Connecticut State University', 'wcsu.edu', 'http://www.wcsu.edu/'),
(1189, 1, 'Western Governors University', 'wgu.edu', 'http://www.wgu.edu/'),
(1190, 1, 'Western Illinois University', 'wiu.edu', 'http://www.wiu.edu/'),
(1191, 1, 'Western Kentucky University', 'wku.edu', 'http://www.wku.edu/'),
(1192, 1, 'Western Michigan University', 'wmich.edu', 'http://www.wmich.edu/'),
(1193, 1, 'Western Montana College', 'wmc.edu', 'http://www.wmc.edu/'),
(1194, 1, 'Western New England College', 'wnec.edu', 'http://www.wnec.edu/'),
(1195, 1, 'Western New Mexico University', 'wnmu.edu', 'http://www.wnmu.edu/'),
(1196, 1, 'Western State Colorado University', 'western.edu', 'http://www.western.edu/'),
(1197, 1, 'Western Washington University', 'wwu.edu', 'http://www.wwu.edu/'),
(1198, 1, 'Westfield State College', 'westfield.mass.edu', 'http://www.westfield.mass.edu/'),
(1199, 1, 'University of West Georgia', 'westga.edu', 'http://www.westga.edu/'),
(1200, 1, 'West Liberty State College', 'wlsc.wvnet.edu', 'http://www.wlsc.wvnet.edu/'),
(1201, 1, 'Westminster College of New Wilmington', 'westminster.edu', 'http://www.westminster.edu/'),
(1202, 1, 'Westminster College of Fulton', 'westminster-mo.edu', 'http://www.westminster-mo.edu/'),
(1203, 1, 'Westminster College of Salt Lake City', 'wcslc.edu', 'http://www.wcslc.edu/'),
(1204, 1, 'Westminster Theological Seminary', 'wts.edu', 'http://www.wts.edu/'),
(1205, 1, 'Westmont College', 'westmont.edu', 'http://www.westmont.edu/'),
(1206, 1, 'West Texas A&M University', 'wtamu.edu', 'http://www.wtamu.edu/'),
(1207, 1, 'West Virginia University', 'wvu.edu', 'http://www.wvu.edu/'),
(1208, 1, 'West Virginia University at Parkersburg', 'westliberty.edu', 'http://www.westliberty.edu/'),
(1209, 1, 'Wheaton College', 'wheaton.edu', 'http://www.wheaton.edu/'),
(1210, 1, 'Wheaton College, Norton MA', 'wheatonma.edu', 'http://www.wheatonma.edu/'),
(1211, 1, 'Wheeling Jesuit College', 'wjc.edu', 'http://www.wjc.edu/'),
(1212, 1, 'Whitman College', 'whitman.edu', 'http://www.whitman.edu/'),
(1213, 1, 'Whittier College', 'whittier.edu', 'http://www.whittier.edu/'),
(1214, 1, 'Whitworth College', 'whitworth.edu', 'http://www.whitworth.edu/'),
(1215, 1, 'Wichita State University', 'wichita.edu', 'http://www.wichita.edu/'),
(1216, 1, 'Widener University', 'widener.edu', 'http://www.widener.edu/'),
(1217, 1, 'Wilberforce University', 'wilberforce.edu', 'http://www.wilberforce.edu/'),
(1218, 1, 'Wilkes University', 'wilkes.edu', 'http://www.wilkes.edu/'),
(1219, 1, 'Willamette University', 'willamette.edu', 'http://www.willamette.edu/'),
(1220, 1, 'William Howard Taft University', 'taftu.edu', 'http://www.taftu.edu/'),
(1221, 1, 'William Jewell College', 'jewell.edu', 'http://www.jewell.edu/'),
(1222, 1, 'William Mitchell College of Law', 'wmitchell.edu', 'http://www.wmitchell.edu/'),
(1223, 1, 'William Paterson University', 'wpunj.edu', 'http://www.wpunj.edu/'),
(1224, 1, 'William Penn College', 'wmpenn.edu', 'http://www.wmpenn.edu/'),
(1225, 1, 'Williams College', 'williams.edu', 'http://www.williams.edu/'),
(1226, 1, 'William Woods University', 'wmwoods.edu', 'http://www.wmwoods.edu/'),
(1227, 1, 'Wilmington College', 'wilmington.edu', 'http://www.wilmington.edu/'),
(1228, 1, 'Winona State University', 'winona.edu', 'https://www.winona.edu/'),
(1229, 1, 'Winthrop University', 'winthrop.edu', 'http://www.winthrop.edu/'),
(1230, 1, 'Wittenberg University', 'wittenberg.edu', 'http://www.wittenberg.edu/'),
(1231, 1, 'Wofford College', 'wofford.edu', 'http://www.wofford.edu/'),
(1232, 1, 'Woodbury University', 'woodbury.edu', 'http://www.woodbury.edu/'),
(1233, 1, 'Worcester Polytechnic Institute', 'wpi.edu', 'http://www.wpi.edu/'),
(1234, 1, 'Wright State University', 'wright.edu', 'http://www.wright.edu/'),
(1235, 1, 'Xavier University of Louisiana', 'xula.edu', 'http://www.xula.edu/'),
(1236, 1, 'Yale University', 'yale.edu', 'http://www.yale.edu/'),
(1237, 1, 'Yeshiva University', 'yu.edu', 'http://www.yu.edu/'),
(1238, 1, 'York College of Pennsylvania', 'ycp.edu', 'http://www.ycp.edu/'),
(1239, 1, 'Youngstown State University', 'ysu.edu', 'http://www.ysu.edu/'),
(1240, 1, 'Houston Baptist University', 'hbu.edu', 'https://www.hbu.edu/'),
(1241, 1, 'Brookings Institution', 'brookings.edu', 'https://www.brookings.edu/'),
(1242, 1, 'Woods Hole Oceanographic Institution', 'whoi.edu', 'https://www.whoi.edu/'),
(1243, 1, 'Alabama Southern Community College', 'ascc.edu', 'http://www.ascc.edu/'),
(1244, 1, 'Bevill State Community College', 'bscc.edu', 'http://www.bscc.edu/'),
(1245, 1, 'Bishop State Community College', 'bishop.edu', 'http://www.bishop.edu/'),
(1246, 1, 'Central Alabama Community College', 'cacc.edu', 'http://www.cacc.edu/'),
(1247, 1, 'Chattahoochee Valley Community College', 'cv.edu', 'http://www.cv.edu/'),
(1248, 1, 'Duke University', 'duke.edu', 'http://www.duke.edu/'),
(1249, 1, 'Enterprise State Community College', 'escc.edu', 'http://www.escc.edu/'),
(1250, 1, 'Gadsden State Community College', 'gadsdenstate.edu', 'http://www.gadsdenstate.edu/'),
(1251, 1, 'George C Wallace State Community College-Dothan', 'wallace.edu', 'http://www.wallace.edu/'),
(1252, 1, 'George C Wallace State Community College-Hanceville', 'wallacestate.edu', 'http://www.wallacestate.edu/'),
(1253, 1, 'George C Wallace State Community College-Selma', 'wccs.edu', 'http://www.wccs.edu/'),
(1254, 1, 'H Councill Trenholm State Technical College', 'trenholmstate.edu', 'http://www.trenholmstate.edu/'),
(1255, 1, 'James H Faulkner State Community College', 'faulknerstate.edu', 'http://www.faulknerstate.edu/'),
(1256, 1, 'Jefferson Davis Community College', 'jdcc.edu', 'http://www.jdcc.edu/'),
(1257, 1, 'Jefferson State Community College', 'jeffstateonline.com', 'http://www.jeffstateonline.com/'),
(1258, 1, 'J F Drake State Community and Technical College', 'drakestate.edu', 'http://www.drakestate.edu/'),
(1259, 1, 'Calhoun Community College', 'calhoun.edu', 'http://www.calhoun.edu/'),
(1260, 1, 'Lurleen B Wallace Community College', 'lbwcc.edu', 'http://www.lbwcc.edu/'),
(1261, 1, 'Marion Military Institute', 'marionmilitary.edu', 'http://www.marionmilitary.edu/'),
(1262, 1, 'Northeast Alabama Community College', 'nacc.edu', 'http://www.nacc.edu/'),
(1263, 1, 'Northwest-Shoals Community College', 'nwscc.edu', 'http://www.nwscc.edu/'),
(1264, 1, 'Shelton State Community College', 'sheltonstate.edu', 'http://www.sheltonstate.edu/'),
(1265, 1, 'Snead State Community College', 'snead.edu', 'http://www.snead.edu/'),
(1266, 1, 'Southern Union State Community College', 'suscc.edu', 'http://www.suscc.edu/'),
(1267, 1, 'Ilisagvik College', 'ilisagvik.edu', 'http://www.ilisagvik.edu/'),
(1268, 1, 'Prince William Sound College', 'pwsc.alaska.edu', 'http://pwsc.alaska.edu/'),
(1269, 1, 'Central Arizona College', 'centralaz.edu', 'http://www.centralaz.edu/'),
(1270, 1, 'Chandler-Gilbert Community College', 'cgc.maricopa.edu', 'http://www.cgc.maricopa.edu/'),
(1271, 1, 'Cochise College', 'cochise.edu', 'http://www.cochise.edu/'),
(1272, 1, 'Coconino Community College', 'coconino.edu', 'https://www.coconino.edu/'),
(1273, 1, 'Eastern Arizona College', 'eac.edu', 'http://www.eac.edu/'),
(1274, 1, 'GateWay Community College', 'gwcc.commnet.edu', 'http://www.gwcc.commnet.edu/'),
(1275, 1, 'Glendale Community College', 'glendale.edu', 'http://www.glendale.edu/'),
(1276, 1, 'Minerva University', 'minerva.edu', 'https://www.minerva.edu/'),
(1277, 1, 'Mesa Community College', 'mesacc.edu', 'http://www.mesacc.edu/'),
(1278, 1, 'Mohave Community College', 'mohave.edu', 'http://www.mohave.edu/'),
(1279, 1, 'Northland Pioneer College', 'npc.edu', 'http://www.npc.edu/'),
(1280, 1, 'Paradise Valley Community College', 'pvc.maricopa.edu', 'http://www.pvc.maricopa.edu/'),
(1281, 1, 'Phoenix College', 'phoenixcollege.edu', 'http://www.phoenixcollege.edu/'),
(1282, 1, 'Pima Community College', 'pima.edu', 'http://www.pima.edu/'),
(1283, 1, 'Rio Salado College', 'rio.maricopa.edu', 'http://www.rio.maricopa.edu/');
INSERT INTO `universities` (`university_id`, `country_id`, `university_name`, `external_api_id`, `website_url`) VALUES
(1284, 1, 'Scottsdale Community College', 'scottsdalecc.edu', 'http://www.scottsdalecc.edu/'),
(1285, 1, 'South Mountain Community College', 'southmountaincc.edu', 'http://www.southmountaincc.edu/'),
(1286, 1, 'Tohono O\'Odham Community College', 'tocc.edu', 'http://www.tocc.edu/'),
(1287, 1, 'Yavapai College', 'yc.edu', 'http://www.YC.EDU/'),
(1288, 1, 'Arkansas Northeastern College', 'anc.edu', 'http://www.anc.edu/'),
(1289, 1, 'Arkansas State University-Beebe', 'asub.edu', 'http://www.asub.edu/'),
(1290, 1, 'Arkansas State University-Mountain Home', 'asumh.edu', 'http://www.asumh.edu/'),
(1291, 1, 'Arkansas State University-Newport', 'asun.edu', 'http://www.asun.edu/'),
(1292, 1, 'Black River Technical College', 'blackrivertech.edu', 'http://www.blackrivertech.edu/'),
(1293, 1, 'College of the Ouachitas', 'coto.edu', 'http://www.coto.edu/'),
(1294, 1, 'Cossatot Community College of the University of Arkansas', 'cccua.edu', 'http://www.cccua.edu/'),
(1295, 1, 'East Arkansas Community College', 'www.eacc.edu', 'http://WWW.EACC.EDU/'),
(1296, 1, 'Mid-South Community College', 'midsouthcc.edu', 'http://www.midsouthcc.edu/'),
(1297, 1, 'National Park Community College', 'npcc.edu', 'http://www.npcc.edu/'),
(1298, 1, 'North Arkansas College', 'northark.edu', 'http://www.northark.edu/'),
(1299, 1, 'NorthWest Arkansas Community College', 'nwacc.edu', 'http://www.nwacc.edu/'),
(1300, 1, 'Ozarka College', 'ozarka.edu', 'http://www.ozarka.edu/'),
(1301, 1, 'Phillips Community College of the University of Arkansas', 'pccua.edu', 'http://www.pccua.edu/'),
(1302, 1, 'Pulaski Technical College', 'pulaskitech.edu', 'http://www.pulaskitech.edu/'),
(1303, 1, 'Rich Mountain Community College', 'rmcc.edu', 'http://www.rmcc.edu/'),
(1304, 1, 'South Arkansas Community College', 'southark.edu', 'http://www.southark.edu/'),
(1305, 1, 'Southeast Arkansas College', 'seark.edu', 'http://www.seark.edu/'),
(1306, 1, 'Southern Arkansas University Tech', 'sautech.edu', 'http://www.sautech.edu/'),
(1307, 1, 'University of Arkansas Community College-Batesville', 'uaccb.edu', 'http://www.uaccb.edu/'),
(1308, 1, 'University of Arkansas Community College-Hope', 'uacch.edu', 'http://www.uacch.edu/'),
(1309, 1, 'University of Arkansas Community College-Morrilton', 'uaccm.edu', 'http://www.uaccm.edu/'),
(1310, 1, 'Allan Hancock College', 'hancockcollege.edu', 'http://www.hancockcollege.edu/'),
(1311, 1, 'American River College', 'arc.losrios.edu', 'http://www.arc.losrios.edu/'),
(1312, 1, 'Antelope Valley College', 'avc.edu', 'http://www.avc.edu/'),
(1313, 1, 'Bakersfield College', 'bakersfieldcollege.edu', 'http://www.bakersfieldcollege.edu/'),
(1314, 1, 'Barstow Community College', 'barstow.edu', 'http://www.barstow.edu/'),
(1315, 1, 'Berkeley City College', 'berkeleycitycollege.edu', 'http://www.berkeleycitycollege.edu/'),
(1316, 1, 'Butte College', 'butte.edu', 'http://www.butte.edu/'),
(1317, 1, 'Cabrillo College', 'cabrillo.edu', 'http://www.cabrillo.edu/'),
(1318, 1, 'Canada College', 'canadacollege.edu', 'http://canadacollege.edu/'),
(1319, 1, 'Carrington College California-Sacramento', 'carrington.edu', 'http://www.carrington.edu/'),
(1320, 1, 'Cerritos College', 'cerritos.edu', 'http://www.cerritos.edu/'),
(1321, 1, 'Cerro Coso Community College', 'cerrocoso.edu', 'http://cerrocoso.edu/'),
(1322, 1, 'Chabot College', 'chabotcollege.edu', 'http://www.chabotcollege.edu/'),
(1323, 1, 'Chaffey College', 'chaffey.edu', 'http://www.chaffey.edu/'),
(1324, 1, 'Citrus College', 'citruscollege.edu', 'http://www.citruscollege.edu/'),
(1325, 1, 'City College of San Francisco', 'ccsf.edu', 'http://www.ccsf.edu/'),
(1326, 1, 'Coastline Community College', 'coastline.edu', 'http://www.coastline.edu/'),
(1327, 1, 'College of Alameda', 'peralta.edu', 'http://www.peralta.edu/'),
(1328, 1, 'College of Marin', 'marin.edu', 'http://www.marin.edu/'),
(1329, 1, 'College of San Mateo', 'collegeofsanmateo.edu', 'http://www.collegeofsanmateo.edu/'),
(1330, 1, 'College of the Canyons', 'canyons.edu', 'http://www.canyons.edu/'),
(1331, 1, 'College of the Desert', 'collegeofthedesert.edu', 'http://collegeofthedesert.edu/'),
(1332, 1, 'College of the Redwoods', 'redwoods.edu', 'http://www.redwoods.edu/'),
(1333, 1, 'College of the Sequoias', 'cos.edu', 'http://www.cos.edu/'),
(1334, 1, 'College of the Siskiyous', 'siskiyous.edu', 'http://www.siskiyous.edu/'),
(1335, 1, 'Columbia College (MO)', 'ccis.edu', 'http://www.ccis.edu/'),
(1336, 1, 'Columbia College (CA)', 'gocolumbia.edu', 'http://www.gocolumbia.edu/'),
(1337, 1, 'Contra Costa College', 'contracosta.edu', 'http://www.contracosta.edu/'),
(1338, 1, 'Copper Mountain Community College', 'cmccd.edu', 'http://www.cmccd.edu/'),
(1339, 1, 'Cosumnes River College', 'crc.losrios.edu', 'http://www.crc.losrios.edu/'),
(1340, 1, 'Crafton Hills College', 'craftonhills.edu', 'http://www.craftonhills.edu/'),
(1341, 1, 'Cuesta College', 'www.cuesta.edu', 'http://WWW.CUESTA.EDU/'),
(1342, 1, 'Cuyamaca College', 'cuyamaca.edu', 'http://www.cuyamaca.edu/'),
(1343, 1, 'Cypress College', 'cypresscollege.edu', 'http://www.cypresscollege.edu/'),
(1344, 1, 'De Anza College', 'deanza.edu', 'http://www.deanza.edu/'),
(1345, 1, 'Diablo Valley College', 'dvc.edu', 'http://www.dvc.edu/'),
(1346, 1, 'East Los Angeles College', 'elac.edu', 'http://www.elac.edu/'),
(1347, 1, 'El Camino College-Compton Center', 'compton.edu', 'http://www.compton.edu/'),
(1348, 1, 'El Camino Community College District', 'elcamino.edu', 'http://www.elcamino.edu/'),
(1349, 1, 'Evergreen Valley College', 'evc.edu', 'http://www.evc.edu/'),
(1350, 1, 'Feather River Community College District', 'frc.edu', 'http://www.frc.edu/'),
(1351, 1, 'Folsom Lake College', 'flc.losrios.edu', 'http://www.flc.losrios.edu/'),
(1352, 1, 'Foothill College', 'foothill.edu', 'http://www.foothill.edu/'),
(1353, 1, 'Fresno City College', 'fresnocitycollege.edu', 'http://www.fresnocitycollege.edu/'),
(1354, 1, 'Fullerton College', 'fullcoll.edu', 'http://www.fullcoll.edu/'),
(1355, 1, 'Gavilan College', 'gavilan.edu', 'http://www.gavilan.edu/'),
(1357, 1, 'Golden West College', 'goldenwestcollege.edu', 'http://www.goldenwestcollege.edu/'),
(1358, 1, 'Grossmont College', 'grossmont.edu', 'http://www.grossmont.edu/'),
(1359, 1, 'Hartnell College', 'hartnell.edu', 'http://www.hartnell.edu/'),
(1360, 1, 'Imperial Valley College', 'imperial.edu', 'http://www.imperial.edu/'),
(1361, 1, 'Lake Tahoe Community College', 'ltcc.edu', 'http://www.ltcc.edu/'),
(1362, 1, 'Laney College', 'laney.edu', 'http://www.laney.edu/'),
(1363, 1, 'Las Positas College', 'laspositascollege.edu', 'http://www.laspositascollege.edu/'),
(1364, 1, 'Lassen Community College', 'lassencollege.edu', 'http://www.lassencollege.edu/'),
(1365, 1, 'Long Beach City College', 'lbcc.edu', 'http://www.lbcc.edu/'),
(1366, 1, 'Los Angeles City College', 'lacitycollege.edu', 'http://www.lacitycollege.edu/'),
(1367, 1, 'Los Angeles County College of Nursing and Allied Health', 'lacounty.org', 'https://dhs.lacounty.gov/'),
(1368, 1, 'Los Angeles Harbor College', 'lahc.edu', 'http://www.lahc.edu/'),
(1369, 1, 'Los Angeles Mission College', 'lamission.edu', 'http://www.lamission.edu/'),
(1370, 1, 'Los Angeles Pierce College', 'piercecollege.edu', 'http://www.piercecollege.edu/'),
(1371, 1, 'Los Angeles Southwest College', 'lasc.edu', 'http://www.lasc.edu/'),
(1372, 1, 'Los Angeles Trade Technical College', 'lattc.edu', 'http://www.lattc.edu/'),
(1373, 1, 'Los Angeles Valley College', 'lavc.edu', 'http://www.lavc.edu/'),
(1374, 1, 'Los Medanos College', 'losmedanos.edu', 'http://www.losmedanos.edu/'),
(1375, 1, 'Mendocino College', 'mendocino.edu', 'http://www.mendocino.edu/'),
(1376, 1, 'Merced College', 'mccd.edu', 'http://www.mccd.edu/'),
(1377, 1, 'Merritt College', 'merritt.edu', 'http://www.merritt.edu/'),
(1378, 1, 'MiraCosta College', 'miracosta.edu', 'http://www.miracosta.edu/'),
(1379, 1, 'Mission College', 'missioncollege.edu', 'http://www.missioncollege.edu/'),
(1380, 1, 'Modesto Junior College', 'mjc.edu', 'http://mjc.edu/'),
(1381, 1, 'Monterey Peninsula College', 'mpc.edu', 'http://www.mpc.edu/'),
(1382, 1, 'Moorpark College', 'moorparkcollege.edu', 'http://www.moorparkcollege.edu/'),
(1383, 1, 'Moreno Valley College', 'mvc.edu', 'http://www.mvc.edu/'),
(1384, 1, 'MTI College', 'sacramento.mticollege.edu', 'http://sacramento.mticollege.edu/'),
(1385, 1, 'Mt. San Antonio College', 'mtsac.edu', 'http://www.mtsac.edu/'),
(1386, 1, 'Mt. San Jacinto Community College District', 'msjc.edu', 'http://www.msjc.edu/'),
(1387, 1, 'Napa Valley College', 'napavalley.edu', 'http://www.napavalley.edu/'),
(1388, 1, 'Ohlone College', 'ohlone.edu', 'http://www.ohlone.edu/'),
(1389, 1, 'Orange Coast College', 'orangecoastcollege.edu', 'http://www.orangecoastcollege.edu/'),
(1390, 1, 'Oxnard College', 'oxnardcollege.edu', 'http://www.oxnardcollege.edu/'),
(1391, 1, 'Palomar College', 'palomar.edu', 'http://www.palomar.edu/'),
(1392, 1, 'Palo Verde College', 'paloverde.edu', 'http://www.paloverde.edu/'),
(1393, 1, 'Pasadena City College', 'pasadena.edu', 'http://www.pasadena.edu/'),
(1394, 1, 'Porterville College', 'portervillecollege.edu', 'http://www.portervillecollege.edu/'),
(1395, 1, 'Reedley College', 'reedleycollege.edu', 'http://www.reedleycollege.edu/'),
(1396, 1, 'Rio Hondo College', 'riohondo.edu', 'http://www.riohondo.edu/'),
(1397, 1, 'Riverside City College', 'rcc.edu', 'http://www.rcc.edu/'),
(1398, 1, 'Sacramento City College', 'scc.losrios.edu', 'http://www.scc.losrios.edu/'),
(1399, 1, 'Saddleback College', 'saddleback.edu', 'http://www.saddleback.edu/'),
(1400, 1, 'San Bernardino Valley College', 'valleycollege.edu', 'http://www.valleycollege.edu/'),
(1401, 1, 'San Diego City College', 'sdcity.edu', 'http://www.sdcity.edu/'),
(1402, 1, 'San Diego Mesa College', 'sdmesa.edu', 'http://www.sdmesa.edu/'),
(1403, 1, 'San Diego Miramar College', 'sdmiramar.edu', 'http://www.sdmiramar.edu/'),
(1404, 1, 'San Joaquin Delta College', 'deltacollege.edu', 'http://www.deltacollege.edu/'),
(1405, 1, 'San Joaquin Valley College-Visalia', 'sjvc.edu', 'http://www.sjvc.edu/'),
(1406, 1, 'San Jose City College', 'sjcc.edu', 'http://www.sjcc.edu/'),
(1407, 1, 'Santa Ana College', 'sac.edu', 'http://www.sac.edu/'),
(1408, 1, 'Santa Barbara City College', 'sbcc.edu', 'http://www.sbcc.edu/'),
(1409, 1, 'Santa Monica College', 'smc.edu', 'http://www.smc.edu/'),
(1410, 1, 'Santa Rosa Junior College', 'santarosa.edu', 'http://www.santarosa.edu/'),
(1411, 1, 'Santiago Canyon College', 'sccollege.edu', 'http://www.sccollege.edu/'),
(1412, 1, 'Shasta College', 'shastacollege.edu', 'http://www.shastacollege.edu/'),
(1413, 1, 'Sierra College', 'sierracollege.edu', 'http://www.sierracollege.edu/'),
(1414, 1, 'Skyline College', 'skylinecollege.edu', 'http://skylinecollege.edu/'),
(1415, 1, 'Solano Community College', 'solano.edu', 'http://www.solano.edu/'),
(1416, 1, 'Southwestern College (CA)', 'swccd.edu', 'http://www.swccd.edu/'),
(1417, 1, 'Taft College', 'taftcollege.edu', 'http://www.taftcollege.edu/'),
(1418, 1, 'Ventura College', 'venturacollege.edu', 'http://www.venturacollege.edu/'),
(1419, 1, 'Victor Valley College', 'vvc.edu', 'http://www.vvc.edu/'),
(1420, 1, 'West Hills College-Coalinga', 'westhillscollege.com', 'http://www.westhillscollege.com/'),
(1421, 1, 'West Los Angeles College', 'wlac.edu', 'http://www.wlac.edu/'),
(1422, 1, 'West Valley College', 'westvalley.edu', 'http://www.westvalley.edu/'),
(1423, 1, 'Woodland Community College', 'wcc.yccd.edu', 'http://wcc.yccd.edu/'),
(1424, 1, 'Yuba College', 'yc.yccd.edu', 'http://yc.yccd.edu/'),
(1425, 1, 'Aims Community College', 'aims.edu', 'http://www.aims.edu/'),
(1426, 1, 'Arapahoe Community College', 'arapahoe.edu', 'http://www.arapahoe.edu/'),
(1427, 1, 'Colorado Northwestern Community College', 'cncc.edu', 'http://www.cncc.edu/'),
(1428, 1, 'Community College of Aurora', 'ccaurora.edu', 'http://www.ccaurora.edu/'),
(1429, 1, 'Community College of Denver', 'ccd.edu', 'http://www.ccd.edu/'),
(1430, 1, 'Front Range Community College', 'frontrange.edu', 'http://www.frontrange.edu/'),
(1431, 1, 'Lamar Community College', 'lamarcc.edu', 'http://www.lamarcc.edu/'),
(1432, 1, 'Morgan Community College', 'morgancc.edu', 'http://www.morgancc.edu/'),
(1433, 1, 'Northeastern Junior College', 'njc.edu', 'http://www.njc.edu/'),
(1434, 1, 'Otero Junior College', 'www.ojc.edu', 'http://WWW.OJC.EDU/'),
(1435, 1, 'Pikes Peak Community College', 'ppcc.edu', 'http://www.ppcc.edu/'),
(1436, 1, 'Pueblo Community College', 'pueblocc.edu', 'http://www.pueblocc.edu/'),
(1437, 1, 'Red Rocks Community College', 'rrcc.edu', 'http://www.rrcc.edu/'),
(1438, 1, 'Trinidad State Junior College', 'trinidadstate.edu', 'http://www.trinidadstate.edu/'),
(1439, 1, 'Asnuntuck Community College', 'asnuntuck.edu', 'http://www.Asnuntuck.edu/'),
(1440, 1, 'Capital Community College', 'ccc.commnet.edu', 'http://www.ccc.commnet.edu/'),
(1442, 1, 'Housatonic Community College', 'hcc.commnet.edu', 'http://www.hcc.commnet.edu/'),
(1443, 1, 'Manchester Community College', 'mccnh.edu', 'http://www.mccnh.edu/'),
(1444, 1, 'Middlesex Community College', 'middlesex.mass.edu', 'http://www.middlesex.mass.edu/'),
(1445, 1, 'Naugatuck Valley Community College', 'nv.edu', 'http://www.nv.edu/'),
(1446, 1, 'Northwestern Connecticut Community College', 'nwcc.commnet.edu', 'http://www.nwcc.commnet.edu/'),
(1447, 1, 'Norwalk Community College', 'ncc.commnet.edu', 'http://www.ncc.commnet.edu/'),
(1448, 1, 'Quinebaug Valley Community College', 'qvcc.edu', 'http://www.qvcc.edu/'),
(1449, 1, 'Three Rivers Community College', 'trcc.edu', 'http://www.trcc.edu/'),
(1450, 1, 'Tunxis Community College', 'tunxis.edu', 'http://www.tunxis.edu/'),
(1451, 1, 'Delaware College of Art and Design', 'dcad.edu', 'http://www.dcad.edu/'),
(1452, 1, 'Delaware Technical Community College', 'dtcc.edu', 'https://www.dtcc.edu/'),
(1453, 1, 'Florida Keys Community College', 'fkcc.edu', 'http://www.fkcc.edu/'),
(1454, 1, 'Hillsborough Community College', 'hccfl.edu', 'http://www.hccfl.edu/'),
(1455, 1, 'North Florida Community College', 'nfcc.edu', 'http://www.nfcc.edu/'),
(1456, 1, 'Pasco-Hernando Community College', 'phcc.edu', 'http://www.phcc.edu/'),
(1457, 1, 'Tallahassee Community College', 'tcc.fl.edu', 'https://www.tcc.fl.edu/'),
(1458, 1, 'Albany Technical College', 'albanytech.edu', 'http://www.albanytech.edu/'),
(1459, 1, 'Andrew College', 'andrewcollege.edu', 'http://www.andrewcollege.edu/'),
(1460, 1, 'Athens Technical College', 'athenstech.edu', 'http://www.athenstech.edu/'),
(1461, 1, 'Atlanta Technical College', 'atlantatech.edu', 'http://www.atlantatech.edu/'),
(1462, 1, 'Augusta Technical College', 'augustatech.edu', 'http://www.augustatech.edu/'),
(1463, 1, 'Bainbridge State College', 'bainbridge.edu', 'http://www.bainbridge.edu/'),
(1464, 1, 'Central Georgia Technical College', 'centralgatech.edu', 'http://www.centralgatech.edu/'),
(1465, 1, 'Chattahoochee Technical College', 'chattahoocheetech.edu', 'http://www.chattahoocheetech.edu/'),
(1466, 1, 'Columbus Technical College', 'columbustech.edu', 'http://www.columbustech.edu/'),
(1467, 1, 'Darton State College', 'darton.edu', 'http://www.darton.edu/'),
(1468, 1, 'Georgia Highlands College', 'highlands.edu', 'http://www.highlands.edu/'),
(1469, 1, 'Georgia Military College', 'gmc.cc.ga.us', 'http://www.gmc.cc.ga.us/'),
(1470, 1, 'Georgia Northwestern Technical College', 'gntc.edu', 'http://www.gntc.edu/'),
(1471, 1, 'Georgia Perimeter College', 'gpc.edu', 'http://www.gpc.edu/'),
(1472, 1, 'Georgia Piedmont Technical College', 'gptc.edu', 'http://www.gptc.edu/'),
(1473, 1, 'Gwinnett Technical College', 'gwinnetttech.edu', 'http://www.GwinnettTech.edu/'),
(1474, 1, 'Lanier Technical College', 'laniertech.edu', 'http://www.laniertech.edu/'),
(1475, 1, 'Moultrie Technical College', 'moultrietech.edu', 'http://www.moultrietech.edu/'),
(1476, 1, 'North Georgia Technical College', 'northgatech.edu', 'http://www.northgatech.edu/'),
(1477, 1, 'Ogeechee Technical College', 'ogeecheetech.edu', 'http://www.ogeecheetech.edu/'),
(1478, 1, 'Coastal Pines Technical College', 'coastalpines.edu', 'http://www.coastalpines.edu/'),
(1479, 1, 'Savannah Technical College', 'savannahtech.edu', 'http://www.savannahtech.edu/'),
(1480, 1, 'Southeastern Technical College', 'southeasterntech.edu', 'http://www.southeasterntech.edu/'),
(1481, 1, 'Southern Crescent Technical College', 'sctech.edu', 'http://www.sctech.edu/'),
(1482, 1, 'South Georgia Technical College', 'southgatech.edu', 'http://www.southgatech.edu/'),
(1483, 1, 'Southwest Georgia Technical College', 'southwestgatech.edu', 'http://www.southwestgatech.edu/'),
(1484, 1, 'West Georgia Technical College', 'westgatech.edu', 'http://www.westgatech.edu/'),
(1485, 1, 'Wiregrass Georgia Technical College', 'wiregrass.edu', 'http://www.wiregrass.edu/'),
(1486, 1, 'Hawaii Community College', 'hawaii.hawaii.edu', 'http://hawaii.hawaii.edu/'),
(1487, 1, 'Honolulu Community College', 'honolulu.hawaii.edu', 'http://www.honolulu.hawaii.edu/'),
(1488, 1, 'Kapiolani Community College', 'kapiolani.hawaii.edu', 'http://kapiolani.hawaii.edu/'),
(1489, 1, 'Kauai Community College', 'kauai.hawaii.edu', 'http://kauai.hawaii.edu/'),
(1490, 1, 'Leeward Community College', 'leeward.hawaii.edu', 'http://www.leeward.hawaii.edu/'),
(1491, 1, 'Windward Community College', 'windward.hawaii.edu', 'http://windward.hawaii.edu/'),
(1492, 1, 'College of Southern Idaho', 'csi.edu', 'http://www.csi.edu/'),
(1493, 1, 'College of Western Idaho', 'cwidaho.cc', 'http://cwidaho.cc/'),
(1494, 1, 'Eastern Idaho Technical College', 'eitc.edu', 'http://www.eitc.edu/'),
(1495, 1, 'North Idaho College', 'nic.edu', 'http://www.nic.edu/'),
(1496, 1, 'Black Hawk College', 'bhc.edu', 'http://www.bhc.edu/'),
(1497, 1, 'Carl Sandburg College', 'sandburg.edu', 'http://www.sandburg.edu/'),
(1498, 1, 'City Colleges of Chicago', 'ccc.edu', 'http://www.ccc.edu/'),
(1499, 1, 'College of DuPage', 'cod.edu', 'http://www.cod.edu/'),
(1500, 1, 'College of Lake County', 'www.clcillinois.edu', 'http://WWW.CLCILLINOIS.EDU/'),
(1501, 1, 'Danville Area Community College', 'dacc.edu', 'http://www.dacc.edu/'),
(1502, 1, 'Elgin Community College', 'elgin.edu', 'http://www.elgin.edu/'),
(1503, 1, 'Fox College', 'foxcollege.edu', 'http://www.foxcollege.edu/'),
(1504, 1, 'Harper College', 'harpercollege.edu', 'http://www.harpercollege.edu/'),
(1505, 1, 'Heartland Community College', 'heartland.edu', 'http://www.heartland.edu/'),
(1506, 1, 'Highland Community College', 'highlandcc.edu', 'http://www.highlandcc.edu/'),
(1507, 1, 'Illinois Central College', 'icc.edu', 'http://www.icc.edu/'),
(1508, 1, 'Illinois Valley Community College', 'ivcc.edu', 'http://www.ivcc.edu/'),
(1509, 1, 'John A Logan College', 'jalc.edu', 'http://www.jalc.edu/'),
(1510, 1, 'John Wood Community College', 'jwcc.edu', 'http://www.jwcc.edu/'),
(1511, 1, 'Joliet Junior College', 'jjc.edu', 'http://www.jjc.edu/'),
(1512, 1, 'Kankakee Community College', 'kcc.edu', 'http://www.kcc.edu/'),
(1513, 1, 'Kaskaskia College', 'kaskaskia.edu', 'http://www.kaskaskia.edu/'),
(1514, 1, 'Kishwaukee College', 'kishwaukeecollege.edu', 'http://www.kishwaukeecollege.edu/'),
(1515, 1, 'Lake Land College', 'lakeland.cc.il.us', 'http://www.lakeland.cc.il.us/'),
(1516, 1, 'Lewis and Clark Community College', 'lc.edu', 'http://www.lc.edu/'),
(1517, 1, 'Lincoln Land Community College', 'llcc.edu', 'http://www.llcc.edu/'),
(1518, 1, 'MacCormac College', 'maccormac.edu', 'http://www.maccormac.edu/'),
(1519, 1, 'McHenry County College', 'mchenry.edu', 'http://www.mchenry.edu/'),
(1520, 1, 'Moraine Valley Community College', 'morainevalley.edu', 'http://www.morainevalley.edu/'),
(1521, 1, 'Morton College', 'morton.edu', 'http://www.morton.edu/'),
(1522, 1, 'Northwestern College-Chicago Campus', 'northwesterncollege.edu', 'http://www.NorthwesternCollege.edu/'),
(1523, 1, 'Oakton Community College', 'oakton.edu', 'http://www.oakton.edu/'),
(1524, 1, 'Parkland College', 'parkland.edu', 'http://www.parkland.edu/'),
(1525, 1, 'Prairie State College', 'prairiestate.edu', 'http://www.prairiestate.edu/'),
(1526, 1, 'Rend Lake College', 'rlc.edu', 'http://www.rlc.edu/'),
(1527, 1, 'Richland Community College', 'richland.edu', 'http://www.richland.edu/'),
(1528, 1, 'Rock Valley College', 'rockvalleycollege.edu', 'http://www.rockvalleycollege.edu/'),
(1529, 1, 'Sauk Valley Community College', 'svcc.edu', 'http://www.svcc.edu/'),
(1530, 1, 'Shawnee Community College', 'shawneecc.edu', 'http://www.shawneecc.edu/'),
(1531, 1, 'Southeastern Illinois College', 'sic.edu', 'http://www.sic.edu/'),
(1532, 1, 'South Suburban College', 'ssc.edu', 'http://www.ssc.edu/'),
(1533, 1, 'Southwestern Illinois College', 'swic.edu', 'http://www.swic.edu/'),
(1534, 1, 'Spoon River College', 'src.edu', 'http://www.src.edu/'),
(1535, 1, 'Triton College', 'triton.edu', 'http://www.triton.edu/'),
(1536, 1, 'Ancilla College', 'ancilla.edu', 'http://www.ancilla.edu/'),
(1537, 1, 'Ivy Tech Community College', 'ivytech.edu', 'http://www.ivytech.edu/'),
(1538, 1, 'Des Moines Area Community College', 'dmacc.edu', 'http://www.dmacc.edu/'),
(1539, 1, 'Eastern Iowa Community College District', 'eicc.edu', 'http://www.eicc.edu/'),
(1540, 1, 'Hawkeye Community College', 'hawkeyecollege.edu', 'http://www.hawkeyecollege.edu/'),
(1541, 1, 'Indian Hills Community College', 'indianhills.edu', 'http://www.indianhills.edu/'),
(1542, 1, 'Iowa Central Community College', 'iowacentral.edu', 'http://www.iowacentral.edu/'),
(1543, 1, 'Iowa Lakes Community College', 'iowalakes.edu', 'http://www.iowalakes.edu/'),
(1544, 1, 'Iowa Western Community College', 'iwcc.edu', 'http://www.iwcc.edu/'),
(1545, 1, 'Kirkwood Community College', 'kirkwood.edu', 'http://www.kirkwood.edu/'),
(1546, 1, 'Marshalltown Community College', 'iavalley.edu', 'http://www.iavalley.edu/'),
(1547, 1, 'Northeast Iowa Community College', 'nicc.edu', 'http://www.nicc.edu/'),
(1548, 1, 'North Iowa Area Community College', 'niacc.edu', 'http://www.niacc.edu/'),
(1549, 1, 'Northwest Iowa Community College', 'nwicc.edu', 'http://www.nwicc.edu/'),
(1550, 1, 'Southeastern Community College', 'sccnc.edu', 'http://www.sccnc.edu/'),
(1551, 1, 'Southwestern Community College', 'southwesterncc.edu', 'http://www.southwesterncc.edu/'),
(1552, 1, 'Western Iowa Tech Community College', 'witcc.edu', 'http://www.witcc.edu/'),
(1553, 1, 'Allen County Community College', 'allencc.edu', 'http://www.allencc.edu/'),
(1554, 1, 'Barton County Community College', 'bartonccc.edu', 'http://www.bartonccc.edu/'),
(1555, 1, 'Butler Community College', 'butlercc.edu', 'http://www.butlercc.edu/'),
(1556, 1, 'Cloud County Community College', 'cloud.edu', 'http://www.cloud.edu/'),
(1557, 1, 'Coffeyville Community College', 'coffeyville.edu', 'http://www.coffeyville.edu/'),
(1558, 1, 'Colby Community College', 'colbycc.edu', 'http://www.colbycc.edu/'),
(1559, 1, 'Cowley County Community College', 'cowley.edu', 'http://www.cowley.edu/'),
(1560, 1, 'Dodge City Community College', 'dc3.edu', 'http://www.dc3.edu/'),
(1561, 1, 'Flint Hills Technical College', 'fhtc.edu', 'http://www.fhtc.edu/'),
(1562, 1, 'Fort Scott Community College', 'fortscott.edu', 'http://www.fortscott.edu/'),
(1563, 1, 'Garden City Community College', 'gcccks.edu', 'http://www.gcccks.edu/'),
(1565, 1, 'Hutchinson Community College', 'hutchcc.edu', 'http://www.hutchcc.edu/'),
(1566, 1, 'Independence Community College', 'indycc.edu', 'http://www.indycc.edu/'),
(1567, 1, 'Johnson County Community College', 'jccc.edu', 'http://www.jccc.edu/'),
(1568, 1, 'Kansas City Kansas Community College', 'kckcc.edu', 'http://www.kckcc.edu/'),
(1569, 1, 'Labette Community College', 'labette.edu', 'http://www.labette.edu/'),
(1570, 1, 'Manhattan Area Technical College', 'manhattantech.edu', 'http://www.manhattantech.edu/'),
(1571, 1, 'Neosho County Community College', 'neosho.edu', 'http://www.neosho.edu/'),
(1572, 1, 'North Central Kansas Technical College', 'ncktc.edu', 'http://www.ncktc.edu/'),
(1573, 1, 'Northwest Kansas Technical College', 'nwktc.edu', 'http://www.nwktc.edu/'),
(1574, 1, 'Pratt Community College', 'prattcc.edu', 'http://www.prattcc.edu/'),
(1575, 1, 'Seward County Community College and Area Technical School', 'sccc.edu', 'http://www.sccc.edu/'),
(1576, 1, 'Wichita Area Technical College', 'watc.edu', 'http://www.watc.edu/'),
(1577, 1, 'Ashland Community and Technical College', 'ashland.kctcs.edu', 'http://www.ashland.kctcs.edu/'),
(1578, 1, 'Big Sandy Community and Technical College', 'bigsandy.kctcs.edu', 'http://www.bigsandy.kctcs.edu/'),
(1579, 1, 'Bluegrass Community and Technical College', 'bluegrass.kctcs.edu', 'http://www.bluegrass.kctcs.edu/'),
(1580, 1, 'Elizabethtown Community and Technical College', 'elizabethtown.kctcs.edu', 'http://www.elizabethtown.kctcs.edu/'),
(1581, 1, 'Galen College of Nursing-Louisville', 'galencollege.edu', 'http://www.galencollege.edu/'),
(1582, 1, 'Gateway Community and Technical College', 'gateway.kctcs.edu', 'http://www.gateway.kctcs.edu/'),
(1583, 1, 'Hazard Community and Technical College', 'hazard.kctcs.edu', 'http://www.hazard.kctcs.edu/'),
(1584, 1, 'Henderson Community College', 'hencc.kctcs.edu', 'http://www.hencc.kctcs.edu/'),
(1585, 1, 'Hopkinsville Community College', 'hopkinsville.kctcs.edu', 'http://hopkinsville.kctcs.edu/'),
(1586, 1, 'Jefferson Community and Technical College', 'jefferson.kctcs.edu', 'http://www.jefferson.kctcs.edu/'),
(1587, 1, 'Madisonville Community College', 'madisonville.kctcs.edu', 'http://www.madisonville.kctcs.edu/'),
(1588, 1, 'Maysville Community and Technical College', 'maysville.kctcs.edu', 'http://maysville.kctcs.edu/'),
(1589, 1, 'Owensboro Community and Technical College', 'owensboro.kctcs.edu', 'http://www.owensboro.kctcs.edu/'),
(1590, 1, 'Somerset Community College', 'somerset.kctcs.edu', 'http://www.somerset.kctcs.edu/'),
(1591, 1, 'Southcentral Kentucky Community and Technical College', 'bowlinggreen.kctcs.edu', 'http://www.bowlinggreen.kctcs.edu/'),
(1592, 1, 'Southeast Kentucky Community and Technical College', 'southeast.kctcs.edu', 'http://www.southeast.kctcs.edu/'),
(1593, 1, 'West Kentucky Community and Technical College', 'westkentucky.kctcs.edu', 'http://www.westkentucky.kctcs.edu/'),
(1594, 1, 'Baton Rouge Community College', 'mybrcc.edu', 'http://www.mybrcc.edu/'),
(1595, 1, 'Bossier Parish Community College', 'bpcc.edu', 'http://www.bpcc.edu/'),
(1596, 1, 'Delgado Community College', 'dcc.edu', 'http://WWW.DCC.EDU/'),
(1597, 1, 'L E Fletcher Technical Community College', 'fletcher.edu', 'http://www.fletcher.edu/'),
(1598, 1, 'Louisiana Delta Community College', 'ladelta.edu', 'http://www.ladelta.edu/'),
(1599, 1, 'Louisiana State University-Eunice', 'lsue.edu', 'http://www.lsue.edu/'),
(1600, 1, 'Nunez Community College', 'nunez.edu', 'http://www.nunez.edu/'),
(1601, 1, 'River Parishes Community College', 'rpcc.edu', 'http://www.rpcc.edu/'),
(1602, 1, 'Southern University at Shreveport', 'susla.edu', 'http://www.susla.edu/'),
(1603, 1, 'South Louisiana Community College', 'solacc.edu', 'http://www.solacc.edu/'),
(1604, 1, 'SOWELA Technical Community College', 'sowela.edu', 'http://www.sowela.edu/'),
(1605, 1, 'Central Maine Community College', 'cmcc.edu', 'http://www.cmcc.edu/'),
(1606, 1, 'Central Maine Medical Center College of Nursing and Health Professions', 'cmmccollege.edu', 'http://www.cmmccollege.edu/'),
(1607, 1, 'Eastern Maine Community College', 'emcc.edu', 'http://www.emcc.edu/'),
(1608, 1, 'Kennebec Valley Community College', 'kvcc.me.edu', 'http://www.kvcc.me.edu/'),
(1609, 1, 'Northern Maine Community College', 'nmcc.edu', 'http://www.nmcc.edu/'),
(1610, 1, 'Southern Maine Community College', 'smccme.edu', 'http://www.smccME.edu/'),
(1611, 1, 'Washington County Community College', 'wccc.me.edu', 'http://www.wccc.me.edu/'),
(1612, 1, 'York County Community College', 'yccc.edu', 'http://www.yccc.edu/'),
(1613, 1, 'Allegany College of Maryland', 'allegany.edu', 'http://www.allegany.edu/'),
(1614, 1, 'Baltimore City Community College', 'bccc.edu', 'http://www.bccc.edu/'),
(1615, 1, 'Carroll Community College', 'carrollcc.edu', 'http://www.carrollcc.edu/'),
(1616, 1, 'Cecil College', 'cecil.edu', 'http://www.cecil.edu/'),
(1617, 1, 'College of Southern Maryland', 'csmd.edu', 'http://www.csmd.edu/'),
(1618, 1, 'Garrett College', 'garrettcollege.edu', 'http://www.garrettcollege.edu/'),
(1619, 1, 'Prince George\'s Community College', 'pgcc.edu', 'http://www.pgcc.edu/'),
(1620, 1, 'Wor-Wic Community College', 'worwic.edu', 'http://www.worwic.edu/'),
(1621, 1, 'Berkshire Community College', 'berkshirecc.edu', 'http://www.berkshirecc.edu/'),
(1622, 1, 'Bristol Community College', 'bristolcc.edu', 'http://bristolcc.edu/'),
(1623, 1, 'Bunker Hill Community College', 'bhcc.mass.edu', 'http://www.bhcc.mass.edu/'),
(1624, 1, 'Cape Cod Community College', 'capecod.edu', 'http://www.capecod.edu/'),
(1625, 1, 'Greenfield Community College', 'gcc.mass.edu', 'http://www.gcc.mass.edu/'),
(1626, 1, 'Holyoke Community College', 'hcc.edu', 'http://www.hcc.edu/'),
(1627, 1, 'Massachusetts Bay Community College', 'massbay.edu', 'http://www.massbay.edu/'),
(1628, 1, 'Massasoit Community College', 'massasoit.mass.edu', 'http://www.massasoit.mass.edu/'),
(1630, 1, 'Mount Wachusett Community College', 'mwcc.edu', 'http://MWCC.EDU/'),
(1631, 1, 'Northern Essex Community College', 'necc.edu', 'http://www.necc.mass.edu/'),
(1632, 1, 'North Shore Community College', 'northshore.edu', 'http://www.northshore.edu/'),
(1633, 1, 'Quincy College', 'quincycollege.edu', 'http://www.quincycollege.edu/'),
(1634, 1, 'Quinsigamond Community College', 'qcc.edu', 'http://www.qcc.edu/'),
(1635, 1, 'Roxbury Community College', 'rcc.mass.edu', 'http://www.rcc.mass.edu/'),
(1636, 1, 'Springfield Technical Community College', 'stcc.edu', 'http://www.stcc.edu/'),
(1637, 1, 'Urban College of Boston', 'urbancollege.edu', 'http://www.urbancollege.edu/'),
(1638, 1, 'Alpena Community College', 'alpenacc.edu', 'http://www.alpenacc.edu/'),
(1639, 1, 'Bay de Noc Community College', 'baycollege.edu', 'http://www.baycollege.edu/'),
(1640, 1, 'Bay Mills Community College', 'bmcc.edu', 'http://www.bmcc.edu/'),
(1641, 1, 'Delta College', 'delta.edu', 'http://www.delta.edu/'),
(1642, 1, 'Glen Oaks Community College', 'glenoaks.edu', 'https://www.glenoaks.edu/'),
(1643, 1, 'Gogebic Community College', 'gogebic.edu', 'http://www.gogebic.edu/'),
(1644, 1, 'Grand Rapids Community College', 'grcc.edu', 'http://www.grcc.edu/'),
(1645, 1, 'Henry Ford College', 'hfcc.edu', 'http://www.hfcc.edu/'),
(1646, 1, 'Jackson College', 'jccmi.edu', 'http://www.jccmi.edu/'),
(1647, 1, 'Kalamazoo Valley Community College', 'kvcc.edu', 'http://www.kvcc.edu/'),
(1648, 1, 'Kellogg Community College', 'kellogg.edu', 'http://www.kellogg.edu/'),
(1649, 1, 'Keweenaw Bay Ojibwa Community College', 'kbocc.org', 'http://www.kbocc.org/'),
(1650, 1, 'Kirtland Community College', 'kirtland.edu', 'http://www.kirtland.edu/'),
(1651, 1, 'Lake Michigan College', 'lakemichigancollege.edu', 'http://www.lakemichigancollege.edu/'),
(1652, 1, 'Lansing Community College', 'lcc.edu', 'http://www.lcc.edu/'),
(1653, 1, 'Macomb Community College', 'macomb.edu', 'http://www.macomb.edu/'),
(1654, 1, 'Mid Michigan Community College', 'midmich.edu', 'http://www.midmich.edu/'),
(1655, 1, 'Monroe County Community College', 'monroeccc.edu', 'http://www.monroeccc.edu/'),
(1656, 1, 'Montcalm Community College', 'montcalm.edu', 'http://www.montcalm.edu/'),
(1657, 1, 'Muskegon Community College', 'muskegoncc.edu', 'http://www.muskegoncc.edu/'),
(1658, 1, 'North Central Michigan College', 'ncmich.edu', 'http://www.ncmich.edu/'),
(1659, 1, 'Oakland Community College', 'oaklandcc.edu', 'http://www.oaklandcc.edu/'),
(1660, 1, 'Saginaw Chippewa Tribal College', 'sagchip.edu', 'http://www.sagchip.edu/'),
(1661, 1, 'Schoolcraft College', 'schoolcraft.edu', 'http://www.schoolcraft.edu/'),
(1662, 1, 'Southwestern Michigan College', 'swmich.edu', 'http://www.swmich.edu/'),
(1663, 1, 'St. Clair County Community College', 'sc4.edu', 'http://www.sc4.edu/'),
(1664, 1, 'Washtenaw Community College', 'wccnet.edu', 'http://www.wccnet.edu/'),
(1665, 1, 'Wayne County Community College District', 'wcccd.edu', 'http://www.wcccd.edu/'),
(1666, 1, 'West Shore Community College', 'westshore.edu', 'http://www.westshore.edu/'),
(1667, 1, 'Alexandria Technical & Community College', 'alextech.edu', 'http://www.alextech.edu/'),
(1668, 1, 'Anoka-Ramsey Community College', 'anokaramsey.edu', 'http://www.anokaramsey.edu/'),
(1669, 1, 'Anoka Technical College', 'anokatech.edu', 'http://www.anokatech.edu/'),
(1670, 1, 'Central Lakes College-Brainerd', 'www.clcmn.edu', 'http://WWW.CLCMN.EDU/'),
(1671, 1, 'Century College', 'century.edu', 'http://www.century.edu/'),
(1672, 1, 'Dakota County Technical College', 'dctc.edu', 'http://www.dctc.edu/'),
(1673, 1, 'Fond du Lac Tribal and Community College', 'fdltcc.edu', 'http://www.fdltcc.edu/'),
(1674, 1, 'Hennepin Technical College', 'hennepintech.edu', 'http://www.hennepintech.edu/'),
(1675, 1, 'Hibbing Community College', 'hibbing.edu', 'http://www.hibbing.edu/'),
(1676, 1, 'Inver Hills Community College', 'inverhills.edu', 'http://www.inverhills.edu/'),
(1677, 1, 'Itasca Community College', 'itascacc.edu', 'http://www.itascacc.edu/'),
(1678, 1, 'Leech Lake Tribal College', 'lltc.edu', 'http://www.lltc.edu/'),
(1679, 1, 'Mesabi Range Community and Technical College', 'mesabirange.edu', 'http://www.mesabirange.edu/'),
(1680, 1, 'Minneapolis Community and Technical College', 'minneapolis.edu', 'http://www.minneapolis.edu/'),
(1681, 1, 'Minnesota State College-Southeast Technical', 'southeastmn.edu', 'http://www.southeastmn.edu/'),
(1682, 1, 'Minnesota State Community and Technical College', 'minnesota.edu', 'http://www.minnesota.edu/'),
(1683, 1, 'Minnesota West Community and Technical College', 'mnwest.edu', 'http://www.mnwest.edu/'),
(1684, 1, 'Normandale Community College', 'normandale.edu', 'http://www.normandale.edu/'),
(1685, 1, 'North Hennepin Community College', 'nhcc.edu', 'http://www.nhcc.edu/'),
(1686, 1, 'Northland Community and Technical College', 'northlandcollege.edu', 'http://www.northlandcollege.edu/'),
(1687, 1, 'Northwest Technical College', 'ntcmn.edu', 'http://www.ntcmn.edu/'),
(1688, 1, 'Pine Technical College', 'pinetech.edu', 'http://www.pinetech.edu/'),
(1689, 1, 'Rainy River Community College', 'rrcc.mnscu.edu', 'http://www.rrcc.mnscu.edu/'),
(1690, 1, 'Ridgewater College', 'ridgewater.edu', 'http://www.ridgewater.edu/'),
(1691, 1, 'Riverland Community College', 'riverland.edu', 'http://www.riverland.edu/'),
(1692, 1, 'Rochester Community and Technical College', 'rctc.edu', 'http://www.rctc.edu/'),
(1693, 1, 'Saint Paul College', 'saintpaul.edu', 'http://www.saintpaul.edu/'),
(1694, 1, 'South Central College', 'southcentral.edu', 'http://www.southcentral.edu/'),
(1695, 1, 'St Cloud Technical and Community College', 'sctcc.edu', 'http://www.sctcc.edu/'),
(1696, 1, 'Vermilion Community College', 'vcc.edu', 'http://www.vcc.edu/'),
(1697, 1, 'White Earth Tribal and Community College', 'wetcc.edu', 'http://www.wetcc.edu/'),
(1698, 1, 'Coahoma Community College', 'coahomacc.edu', 'http://www.coahomacc.edu/'),
(1699, 1, 'Copiah-Lincoln Community College', 'colin.edu', 'http://www.colin.edu/'),
(1700, 1, 'Olin College of Engineering', 'students.olin.edu', 'http://www.students.olin.edu/'),
(1701, 1, 'East Central Community College', 'eccc.edu', 'http://www.eccc.edu/'),
(1702, 1, 'East Mississippi Community College', 'eastms.edu', 'http://www.eastms.edu/'),
(1703, 1, 'Hinds Community College', 'hindscc.edu', 'http://www.hindscc.edu/'),
(1704, 1, 'Holmes Community College', 'holmescc.edu', 'http://www.holmescc.edu/'),
(1705, 1, 'Itawamba Community College', 'iccms.edu', 'https://www.iccms.edu/'),
(1706, 1, 'Jones County Junior College', 'jcjc.edu', 'http://www.jcjc.edu/'),
(1707, 1, 'Meridian Community College', 'meridiancc.edu', 'http://www.meridiancc.edu/'),
(1708, 1, 'Mississippi Delta Community College', 'msdelta.edu', 'http://www.msdelta.edu/'),
(1709, 1, 'Mississippi Gulf Coast Community College', 'mgccc.edu', 'https://www.mgccc.edu/'),
(1710, 1, 'Northeast Mississippi Community College', 'nemcc.edu', 'http://www.nemcc.edu/'),
(1711, 1, 'Northwest Mississippi Community College', 'northwestms.edu', 'http://www.northwestms.edu/'),
(1712, 1, 'Pearl River Community College', 'prcc.edu', 'http://www.prcc.edu/'),
(1713, 1, 'Southwest Mississippi Community College', 'smcc.edu', 'http://www.smcc.edu/'),
(1714, 1, 'Crowder College', 'crowder.edu', 'http://www.crowder.edu/'),
(1715, 1, 'East Central College', 'eastcentral.edu', 'http://www.eastcentral.edu/'),
(1716, 1, 'Jefferson College', 'jeffco.edu', 'http://www.jeffco.edu/'),
(1717, 1, 'Linn State Technical College', 'linnstate.edu', 'http://www.linnstate.edu/'),
(1718, 1, 'Mineral Area College', 'mineralarea.edu', 'http://www.mineralarea.edu/'),
(1719, 1, 'Missouri State University', 'missouristate.edu', 'http://www.missouristate.edu/'),
(1720, 1, 'Missouri State University-West Plains', 'wp.missouristate.edu', 'http://www.wp.missouristate.edu/'),
(1721, 1, 'Moberly Area Community College', 'macc.edu', 'http://www.macc.edu/'),
(1722, 1, 'North Central Missouri College', 'ncmissouri.edu', 'http://www.ncmissouri.edu/'),
(1723, 1, 'Ozarks Technical Community College', 'otc.edu', 'http://www.otc.edu/'),
(1724, 1, 'Southeast Missouri Hospital College of Nursing and Health Sciences', 'southeastmissourihospitalcollege.edu', 'http://www.southeastmissourihospitalcollege.edu/'),
(1725, 1, 'State Fair Community College', 'sfccmo.edu', 'http://www.sfccmo.edu/'),
(1726, 1, 'St Charles Community College', 'stchas.edu', 'http://www.stchas.edu/'),
(1728, 1, 'Wentworth Military Academy & Junior College', 'wma.edu', 'http://www.wma.edu/'),
(1729, 1, 'Aaniiih Nakoda College', 'ancollege.edu', 'http://www.ancollege.edu/'),
(1730, 1, 'Blackfeet Community College', 'bfcc.edu', 'http://bfcc.edu/'),
(1731, 1, 'Chief Dull Knife College', 'cdkc.edu', 'http://cdkc.edu/'),
(1732, 1, 'Dawson Community College', 'dawson.edu', 'http://www.dawson.edu/'),
(1733, 1, 'Flathead Valley Community College', 'fvcc.edu', 'http://www.fvcc.edu/'),
(1734, 1, 'Fort Peck Community College', 'fpcc.edu', 'http://www.fpcc.edu/'),
(1735, 1, 'Great Falls College Montana State University', 'gfcmsu.edu', 'http://www.gfcmsu.edu/'),
(1736, 1, 'Helena College University of Montana', 'umhelena.edu', 'http://www.umhelena.edu/'),
(1737, 1, 'Little Big Horn College', 'lbhc.edu', 'http://www.lbhc.edu/'),
(1738, 1, 'Miles Community College', 'milescc.edu', 'http://milescc.edu/'),
(1739, 1, 'Stone Child College', 'stonechild.edu', 'http://www.stonechild.edu/'),
(1740, 1, 'Central Community College', 'cccneb.edu', 'http://www.cccneb.edu/'),
(1741, 1, 'Little Priest Tribal College', 'littlepriest.edu', 'http://www.littlepriest.edu/'),
(1742, 1, 'Mid-Plains Community College', 'mpcc.edu', 'http://www.mpcc.edu/'),
(1743, 1, 'Nebraska College of Technical Agriculture', 'ncta.unl.edu', 'http://NCTA.UNL.EDU/'),
(1744, 1, 'Nebraska Indian Community College', 'thenicc.edu', 'http://www.thenicc.edu/'),
(1745, 1, 'Northeast Community College', 'northeast.edu', 'http://www.northeast.edu/'),
(1746, 1, 'Southeast Community College Area', 'southeast.edu', 'http://www.southeast.edu/'),
(1747, 1, 'Western Nebraska Community College', 'wncc.edu', 'http://www.wncc.edu/'),
(1748, 1, 'Truckee Meadows Community College', 'tmcc.edu', 'http://www.tmcc.edu/'),
(1749, 1, 'Great Bay Community College', 'greatbay.edu', 'http://www.greatbay.edu/'),
(1750, 1, 'Lakes Region Community College', 'lrcc.edu', 'http://www.lrcc.edu/'),
(1752, 1, 'Nashua Community College', 'nashuacc.edu', 'http://www.nashuacc.edu/'),
(1753, 1, 'NHTI-Concord\'s Community College', 'nhti.edu', 'http://www.nhti.edu/'),
(1754, 1, 'River Valley Community College', 'rivervalley.edu', 'http://www.rivervalley.edu/'),
(1755, 1, 'White Mountains Community College', 'wmcc.edu', 'http://www.wmcc.edu/'),
(1756, 1, 'Assumption College for Sisters', 'acs350.org', 'http://www.acs350.org/'),
(1757, 1, 'Atlantic Cape Community College', 'atlantic.edu', 'http://www.atlantic.edu/'),
(1758, 1, 'Bergen Community College', 'bergen.edu', 'http://www.bergen.edu/'),
(1759, 1, 'Brookdale Community College', 'brookdalecc.edu', 'http://www.brookdalecc.edu/'),
(1760, 1, 'Camden County College', 'camdencc.edu', 'http://www.camdencc.edu/'),
(1761, 1, 'County College of Morris', 'ccm.edu', 'https://www.ccm.edu/'),
(1762, 1, 'Cumberland County College', 'cccnj.edu', 'http://www.cccnj.edu/'),
(1763, 1, 'Essex County College', 'essex.edu', 'http://www.essex.edu/'),
(1764, 1, 'Gloucester County College', 'gccnj.edu', 'http://www.gccnj.edu/'),
(1765, 1, 'Hudson County Community College', 'hccc.edu', 'http://www.hccc.edu/'),
(1766, 1, 'Middlesex County College', 'middlesexcc.edu', 'http://www.middlesexcc.edu/'),
(1767, 1, 'Ocean County College', 'ocean.edu', 'http://www.ocean.edu/'),
(1768, 1, 'Passaic County Community College', 'pccc.edu', 'http://www.pccc.edu/'),
(1769, 1, 'Raritan Valley Community College', 'raritanval.edu', 'http://www.raritanval.edu/'),
(1770, 1, 'Salem Community College', 'salemcc.edu', 'http://www.salemcc.edu/'),
(1771, 1, 'Sussex County Community College', 'sussex.edu', 'http://www.sussex.edu/'),
(1772, 1, 'Union County College', 'ucc.edu', 'http://www.ucc.edu/'),
(1773, 1, 'Warren County Community College', 'warren.edu', 'http://www.warren.edu/'),
(1774, 1, 'Central New Mexico Community College', 'cnm.edu', 'http://www.cnm.edu/'),
(1775, 1, 'Clovis Community College', 'clovis.edu', 'http://www.clovis.edu/'),
(1776, 1, 'Eastern New Mexico University-Roswell Campus', 'roswell.enmu.edu', 'http://www.roswell.enmu.edu/'),
(1777, 1, 'Luna Community College', 'luna.edu', 'http://www.luna.edu/'),
(1778, 1, 'Mesalands Community College', 'mesalands.edu', 'http://www.mesalands.edu/'),
(1779, 1, 'New Mexico Junior College', 'nmjc.edu', 'http://www.nmjc.edu/'),
(1780, 1, 'New Mexico Military Institute', 'nmmi.edu', 'http://www.nmmi.edu/'),
(1781, 1, 'New Mexico State University-Alamogordo', 'nmsua.edu', 'http://nmsua.edu/'),
(1782, 1, 'New Mexico State University-Carlsbad', 'cavern.nmsu.edu', 'http://www.cavern.nmsu.edu/'),
(1783, 1, 'New Mexico State University-Dona Ana', 'dabcc.nmsu.edu', 'http://dabcc.nmsu.edu/'),
(1784, 1, 'San Juan College', 'sanjuancollege.edu', 'http://www.sanjuancollege.edu/'),
(1785, 1, 'Santa Fe Community College', 'sfcc.edu', 'http://www.sfcc.edu/'),
(1786, 1, 'Southwestern Indian Polytechnic Institute', 'sipi.edu', 'http://www.sipi.edu/'),
(1787, 1, 'Adirondack Community College', 'www.sunyacc.edu', 'http://WWW.SUNYACC.EDU/'),
(1788, 1, 'American Academy of Dramatic Arts-New York', 'aada.edu', 'http://www.aada.edu/'),
(1789, 1, 'ASA College', 'asa.edu', 'http://www.asa.edu/'),
(1790, 1, 'Cayuga County Community College', 'cayuga-cc.edu', 'http://www.cayuga-cc.edu/'),
(1791, 1, 'Clinton Community College', 'clinton.edu', 'http://www.clinton.edu/'),
(1792, 1, 'Columbia-Greene Community College', 'sunycgcc.edu', 'http://www.sunycgcc.edu/'),
(1793, 1, 'CUNY Borough of Manhattan Community College', 'bmcc.cuny.edu', 'http://www.bmcc.cuny.edu/'),
(1794, 1, 'CUNY Bronx Community College', 'bcc.cuny.edu', 'http://www.bcc.cuny.edu/'),
(1795, 1, 'CUNY Hostos Community College', 'hostos.cuny.edu', 'http://www.hostos.cuny.edu/'),
(1796, 1, 'CUNY Kingsborough Community College', 'kbcc.cuny.edu', 'http://www.kbcc.cuny.edu/'),
(1797, 1, 'CUNY LaGuardia Community College', 'lagcc.cuny.edu', 'http://www.lagcc.cuny.edu/'),
(1798, 1, 'CUNY Queensborough Community College', 'qcc.cuny.edu', 'http://www.qcc.cuny.edu/'),
(1799, 1, 'CUNY Baruch College', 'baruch.cuny.edu', 'https://www.baruch.cuny.edu/'),
(1800, 1, 'CUNY Queens College', 'qc.cuny.edu', 'https://www.qc.cuny.edu/'),
(1801, 1, 'CUNY City Tech', 'citytech.cuny.edu', 'https://www.citytech.cuny.edu/'),
(1802, 1, 'CUNY City College of NY', 'ccny.cuny.edu', 'https://www.ccny.cuny.edu/'),
(1803, 1, 'CUNY Brooklyn College', 'brooklyn.cuny.edu', 'http://www.brooklyn.cuny.edu/'),
(1804, 1, 'CUNY Medgar Evers College', 'mec.cuny.edu', 'https://www.mec.cuny.edu/'),
(1805, 1, 'CUNY College of Staten Island', 'csi.cuny.edu', 'https://www.csi.cuny.edu/'),
(1806, 1, 'CUNY Macauly Honors College', 'macauly.cuny.edu', 'https://macaulay.cuny.edu/'),
(1807, 1, 'Dutchess Community College', 'sunydutchess.edu', 'http://www.sunydutchess.edu/'),
(1808, 1, 'Finger Lakes Community College', 'flcc.edu', 'http://www.flcc.edu/'),
(1809, 1, 'Fulton-Montgomery Community College', 'fmcc.edu', 'http://fmcc.edu/'),
(1810, 1, 'Genesee Community College', 'genesee.edu', 'http://www.genesee.edu/'),
(1811, 1, 'Herkimer County Community College', 'herkimer.edu', 'http://www.herkimer.edu/'),
(1812, 1, 'Hudson Valley Community College', 'hvcc.edu', 'http://www.hvcc.edu/'),
(1813, 1, 'Jamestown Community College', 'sunyjcc.edu', 'http://www.sunyjcc.edu/'),
(1814, 1, 'Jefferson Community College', 'sunyjefferson.edu', 'http://www.sunyjefferson.edu/'),
(1815, 1, 'Mohawk Valley Community College', 'mvcc.edu', 'http://www.mvcc.edu/'),
(1816, 1, 'Monroe Community College', 'monroecc.edu', 'http://www.monroecc.edu/'),
(1817, 1, 'Nassau Community College', 'ncc.edu', 'http://www.ncc.edu/'),
(1818, 1, 'Niagara County Community College', 'niagaracc.suny.edu', 'http://www.niagaracc.suny.edu/'),
(1819, 1, 'North Country Community College', 'nccc.edu', 'http://www.nccc.edu/'),
(1820, 1, 'Onondaga Community College', 'sunyocc.edu', 'http://www.sunyocc.edu/'),
(1821, 1, 'Orange County Community College', 'sunyorange.edu', 'http://www.sunyorange.edu/'),
(1822, 1, 'Rockland Community College', 'sunyrockland.edu', 'http://www.sunyrockland.edu/'),
(1823, 1, 'Saint Elizabeth College of Nursing', 'secon.edu', 'http://www.secon.edu/'),
(1824, 1, 'Schenectady County Community College', 'sunysccc.edu', 'http://www.sunysccc.edu/'),
(1825, 1, 'Suffolk County Community College', 'www3.sunysuffolk.edu', 'http://www3.sunysuffolk.edu/'),
(1826, 1, 'Sullivan County Community College', 'sunysullivan.edu', 'http://www.sunysullivan.edu/'),
(1827, 1, 'SUNY Broome Community College', 'sunybroome.edu', 'https://sunybroome.edu/'),
(1828, 1, 'SUNY Westchester Community College', 'sunywcc.edu', 'http://www.sunywcc.edu/'),
(1829, 1, 'Technical Career Institutes', 'tcicollege.edu', 'http://www.tcicollege.edu/'),
(1830, 1, 'Tompkins Cortland Community College', 'tc3.edu', 'http://www.TC3.edu/'),
(1831, 1, 'Ulster County Community College', 'www.sunyulster.edu', 'http://WWW.SUNYULSTER.EDU/'),
(1832, 1, 'Alamance Community College', 'alamancecc.edu', 'http://www.alamancecc.edu/'),
(1833, 1, 'Asheville-Buncombe Technical Community College', 'abtech.edu', 'http://www.abtech.edu/'),
(1834, 1, 'Beaufort County Community College', 'beaufortccc.edu', 'http://www.beaufortccc.edu/'),
(1835, 1, 'Bladen Community College', 'bladencc.edu', 'http://www.bladencc.edu/'),
(1836, 1, 'Blue Ridge Community College', 'brcc.edu', 'http://www.brcc.edu/'),
(1837, 1, 'Brunswick Community College', 'brunswickcc.edu', 'http://www.brunswickcc.edu/'),
(1838, 1, 'Caldwell Community College and Technical Institute', 'cccti.edu', 'http://www.cccti.edu/'),
(1839, 1, 'Cape Fear Community College', 'cfcc.edu', 'http://www.cfcc.edu/'),
(1840, 1, 'Carolinas College of Health Sciences', 'carolinascollege.edu', 'http://www.carolinascollege.edu/'),
(1841, 1, 'Carteret Community College', 'carteret.edu', 'http://www.carteret.edu/'),
(1842, 1, 'Catawba Valley Community College', 'cvcc.edu', 'http://www.cvcc.edu/'),
(1843, 1, 'Central Carolina Community College', 'cccc.edu', 'http://www.cccc.edu/'),
(1844, 1, 'Central Piedmont Community College', 'cpcc.edu', 'http://www.cpcc.edu/'),
(1845, 1, 'Cleveland Community College', 'clevelandcc.edu', 'http://www.clevelandcc.edu/'),
(1846, 1, 'Coastal Carolina Community College', 'coastalcarolina.edu', 'http://www.coastalcarolina.edu/'),
(1847, 1, 'College of the Albemarle', 'albemarle.edu', 'http://www.albemarle.edu/'),
(1848, 1, 'Craven Community College', 'cravencc.edu', 'http://www.cravencc.edu/'),
(1849, 1, 'Davidson County Community College', 'davidsonccc.edu', 'http://www.davidsonccc.edu/'),
(1850, 1, 'Durham Technical Community College', 'durhamtech.edu', 'http://www.durhamtech.edu/'),
(1851, 1, 'Edgecombe Community College', 'edgecombe.edu', 'http://www.edgecombe.edu/'),
(1852, 1, 'Fayetteville Technical Community College', 'faytechcc.edu', 'http://www.faytechcc.edu/'),
(1853, 1, 'Forsyth Technical Community College', 'forsythtech.edu', 'http://www.forsythtech.edu/'),
(1854, 1, 'Gaston College', 'gaston.edu', 'http://www.gaston.edu/'),
(1855, 1, 'Guilford Technical Community College', 'gtcc.edu', 'http://www.gtcc.edu/'),
(1856, 1, 'Halifax Community College', 'halifaxcc.edu', 'http://www.halifaxcc.edu/'),
(1857, 1, 'Haywood Community College', 'haywood.edu', 'http://www.haywood.edu/'),
(1858, 1, 'Isothermal Community College', 'isothermal.edu', 'http://www.isothermal.edu/'),
(1859, 1, 'James Sprunt Community College', 'jamessprunt.edu', 'http://www.jamessprunt.edu/'),
(1860, 1, 'Johnston Community College', 'johnstoncc.edu', 'http://www.johnstoncc.edu/'),
(1861, 1, 'Louisburg College', 'louisburg.edu', 'http://www.louisburg.edu/'),
(1862, 1, 'Martin Community College', 'martincc.edu', 'http://www.martincc.edu/'),
(1863, 1, 'Mayland Community College', 'mayland.edu', 'http://www.mayland.edu/'),
(1864, 1, 'McDowell Technical Community College', 'mcdowelltech.edu', 'http://www.mcdowelltech.edu/'),
(1865, 1, 'Mitchell Community College', 'mitchellcc.edu', 'http://www.mitchellcc.edu/'),
(1866, 1, 'Montgomery Community College', 'montgomery.edu', 'http://www.montgomery.edu/'),
(1867, 1, 'Nash Community College', 'nashcc.edu', 'http://www.nashcc.edu/'),
(1868, 1, 'Pamlico Community College', 'pamlicocc.edu', 'http://www.pamlicocc.edu/'),
(1869, 1, 'Piedmont Community College', 'piedmontcc.edu', 'http://www.piedmontcc.edu/'),
(1870, 1, 'Pitt Community College', 'pittcc.edu', 'http://www.pittcc.edu/'),
(1871, 1, 'Randolph Community College', 'randolph.edu', 'http://www.randolph.edu/'),
(1872, 1, 'Richmond Community College', 'richmondcc.edu', 'http://www.richmondcc.edu/'),
(1873, 1, 'Roanoke-Chowan Community College', 'roanokechowan.edu', 'http://www.roanokechowan.edu/'),
(1874, 1, 'Robeson Community College', 'robeson.edu', 'http://www.robeson.edu/'),
(1875, 1, 'Rockingham Community College', 'rockinghamcc.edu', 'http://www.rockinghamcc.edu/'),
(1876, 1, 'Rowan-Cabarrus Community College', 'rccc.edu', 'http://www.rccc.edu/'),
(1877, 1, 'Sampson Community College', 'sampsoncc.edu', 'http://www.sampsoncc.edu/'),
(1878, 1, 'Sandhills Community College', 'sandhills.edu', 'http://www.sandhills.edu/'),
(1880, 1, 'South Piedmont Community College', 'spcc.edu', 'http://www.spcc.edu/');
INSERT INTO `universities` (`university_id`, `country_id`, `university_name`, `external_api_id`, `website_url`) VALUES
(1882, 1, 'Stanly Community College', 'stanly.edu', 'http://www.stanly.edu/'),
(1883, 1, 'Surry Community College', 'surry.edu', 'http://www.surry.edu/'),
(1884, 1, 'Tri-County Community College', 'tricountycc.edu', 'http://www.tricountycc.edu/'),
(1885, 1, 'Wake Technical Community College', 'waketech.edu', 'http://www.waketech.edu/'),
(1886, 1, 'Wayne Community College', 'waynecc.edu', 'http://www.waynecc.edu/'),
(1887, 1, 'Western Piedmont Community College', 'wpcc.edu', 'http://www.wpcc.edu/'),
(1888, 1, 'Wilkes Community College', 'wilkescc.edu', 'http://www.wilkescc.edu/'),
(1889, 1, 'Wilson Community College', 'wilsoncc.edu', 'http://www.wilsoncc.edu/'),
(1890, 1, 'Cankdeska Cikana Community College', 'littlehoop.edu', 'http://www.littlehoop.edu/'),
(1891, 1, 'Dakota College at Bottineau', 'dakotacollege.edu', 'http://www.dakotacollege.edu/'),
(1892, 1, 'Lake Region State College', 'lrsc.edu', 'http://www.lrsc.edu/'),
(1893, 1, 'North Dakota State College of Science', 'ndscs.edu', 'http://www.ndscs.edu/'),
(1894, 1, 'Williston State College', 'willistonstate.edu', 'http://www.willistonstate.edu/'),
(1895, 1, 'Belmont College', 'belmontcollege.edu', 'http://www.belmontcollege.edu/'),
(1896, 1, 'Central Ohio Technical College', 'cotc.edu', 'http://www.cotc.edu/'),
(1897, 1, 'Chatfield College', 'chatfield.edu', 'http://www.chatfield.edu/'),
(1898, 1, 'Cincinnati State Technical and Community College', 'cincinnatistate.edu', 'http://www.cincinnatistate.edu/'),
(1899, 1, 'Clark State Community College', 'clarkstate.edu', 'http://www.clarkstate.edu/'),
(1900, 1, 'Columbus State Community College', 'cscc.edu', 'http://www.cscc.edu/'),
(1901, 1, 'Cuyahoga Community College District', 'tri-c.edu', 'http://www.tri-c.edu/'),
(1902, 1, 'Davis College', 'daviscollege.edu', 'http://www.daviscollege.edu/'),
(1903, 1, 'Eastern Gateway Community College', 'egcc.edu', 'http://www.egcc.edu/'),
(1904, 1, 'Edison State Community College', 'edisonohio.edu', 'http://www.edisonOHIO.edu/'),
(1905, 1, 'Hocking College', 'hocking.edu', 'http://www.hocking.edu/'),
(1906, 1, 'James A Rhodes State College', 'rhodesstate.edu', 'http://www.rhodesstate.edu/'),
(1907, 1, 'Lakeland Community College', 'lakelandcc.edu', 'http://www.lakelandcc.edu/'),
(1908, 1, 'Lorain County Community College', 'lorainccc.edu', 'http://www.lorainccc.edu/'),
(1909, 1, 'Marion Technical College', 'mtc.edu', 'http://www.mtc.edu/'),
(1910, 1, 'North Central State College', 'ncstatecollege.edu', 'http://www.ncstatecollege.edu/'),
(1911, 1, 'Northwest State Community College', 'northweststate.edu', 'http://www.northweststate.edu/'),
(1912, 1, 'Ohio State University Agricultural Technical Institute', 'ati.osu.edu', 'http://www.ati.osu.edu/'),
(1913, 1, 'Owens Community College', 'owens.edu', 'https://www.owens.edu/'),
(1914, 1, 'Southern State Community College', 'sscc.edu', 'http://www.sscc.edu/'),
(1915, 1, 'Stark State College', 'starkstate.edu', 'http://www.starkstate.edu/'),
(1916, 1, 'Terra State Community College', 'terra.edu', 'http://www.terra.edu/'),
(1917, 1, 'University of Akron Wayne College', 'wayne.uakron.edu', 'http://www.wayne.uakron.edu/'),
(1918, 1, 'Washington State Community College', 'wscc.edu', 'http://www.wscc.edu/'),
(1919, 1, 'Zane State College', 'zanestate.edu', 'http://www.zanestate.edu/'),
(1920, 1, 'Carl Albert State College', 'carlalbert.edu', 'http://www.carlalbert.edu/'),
(1921, 1, 'Connors State College', 'connorsstate.edu', 'http://www.connorsstate.edu/'),
(1922, 1, 'Eastern Oklahoma State College', 'eosc.edu', 'http://www.eosc.edu/'),
(1923, 1, 'Murray State College', 'mscok.edu', 'http://www.mscok.edu/'),
(1924, 1, 'Northeastern Oklahoma A&M College', 'neo.edu', 'http://www.neo.edu/'),
(1925, 1, 'Northern Oklahoma College', 'noc.edu', 'http://www.noc.edu/'),
(1926, 1, 'Oklahoma City Community College', 'occc.edu', 'http://www.occc.edu/'),
(1927, 1, 'Redlands Community College', 'redlandscc.edu', 'http://www.redlandscc.edu/'),
(1928, 1, 'Rose State College', 'rose.edu', 'http://www.rose.edu/'),
(1929, 1, 'Seminole State College', 'sscok.edu', 'http://www.sscok.edu/'),
(1930, 1, 'Tulsa Community College', 'tulsacc.edu', 'http://www.tulsacc.edu/'),
(1931, 1, 'Western Oklahoma State College', 'wosc.edu', 'http://www.wosc.edu/'),
(1932, 1, 'Blue Mountain Community College', 'bluecc.edu', 'http://www.bluecc.edu/'),
(1933, 1, 'Central Oregon Community College', 'cocc.edu', 'http://www.cocc.edu/'),
(1934, 1, 'Chemeketa Community College', 'chemeketa.edu', 'http://www.chemeketa.edu/'),
(1935, 1, 'Clackamas Community College', 'clackamas.edu', 'http://www.clackamas.edu/'),
(1936, 1, 'Clatsop Community College', 'clatsopcc.edu', 'http://www.clatsopcc.edu/'),
(1937, 1, 'Columbia Gorge Community College', 'cgcc.cc.or.us', 'http://www.cgcc.cc.or.us/'),
(1938, 1, 'Klamath Community College', 'klamathcc.edu', 'https://www.klamathcc.edu/'),
(1939, 1, 'Lane Community College', 'lanecc.edu', 'http://www.Lanecc.edu/'),
(1940, 1, 'Linn-Benton Community College', 'linnbenton.edu', 'http://www.linnbenton.edu/'),
(1941, 1, 'Mt. Hood Community College', 'mhcc.edu', 'http://www.mhcc.edu/'),
(1942, 1, 'Rogue Community College', 'roguecc.edu', 'http://www.roguecc.edu/'),
(1943, 1, 'Southwestern Oregon Community College', 'socc.edu', 'http://www.socc.edu/'),
(1944, 1, 'Tillamook Bay Community College', 'tbcc.cc.or.us', 'http://www.tbcc.cc.or.us/'),
(1945, 1, 'Treasure Valley Community College', 'tvcc.cc', 'http://www.tvcc.cc/'),
(1946, 1, 'Umpqua Community College', 'umpqua.edu', 'http://www.umpqua.edu/'),
(1947, 1, 'Bucks County Community College', 'bucks.edu', 'http://www.bucks.edu/'),
(1948, 1, 'Butler County Community College', 'bc3.edu', 'http://www.bc3.edu/'),
(1949, 1, 'Community College of Allegheny County', 'ccac.edu', 'http://www.ccac.edu/'),
(1950, 1, 'Community College of Beaver County', 'ccbc.edu', 'http://www.ccbc.edu/'),
(1951, 1, 'Community College of Philadelphia', 'ccp.edu', 'http://www.ccp.edu/'),
(1952, 1, 'Delaware County Community College', 'dccc.edu', 'http://www.dccc.edu/'),
(1953, 1, 'Harcum College', 'harcum.edu', 'http://www.harcum.edu/'),
(1954, 1, 'Harrisburg Area Community College-Harrisburg', 'hacc.edu', 'http://www.hacc.edu/'),
(1955, 1, 'Lackawanna College', 'lackawanna.edu', 'http://www.lackawanna.edu/'),
(1956, 1, 'Lehigh Carbon Community College', 'lccc.edu', 'http://www.lccc.edu/'),
(1957, 1, 'Luzerne County Community College', 'luzerne.edu', 'http://www.luzerne.edu/'),
(1958, 1, 'Manor College', 'manor.edu', 'http://www.manor.edu/'),
(1959, 1, 'Montgomery County Community College', 'mc3.edu', 'http://www.mc3.edu/'),
(1960, 1, 'Pennsylvania Highlands Community College', 'pennhighlands.edu', 'http://www.pennhighlands.edu/'),
(1961, 1, 'Pennsylvania Institute of Technology', 'pit.edu', 'http://www.pit.edu/'),
(1962, 1, 'Pittsburgh Technical Institute', 'pti.edu', 'http://www.pti.edu/'),
(1963, 1, 'Reading Area Community College', 'racc.edu', 'http://www.racc.edu/'),
(1964, 1, 'Thaddeus Stevens College of Technology', 'stevenscollege.edu', 'http://www.stevenscollege.edu/'),
(1965, 1, 'University of Pittsburgh-Titusville', 'upt.pitt.edu', 'http://www.upt.pitt.edu/'),
(1966, 1, 'Valley Forge Military Academy and College', 'vfmac.edu', 'http://www.vfmac.edu/'),
(1967, 1, 'Westmoreland County Community College', 'wccc.edu', 'http://wccc.edu/'),
(1968, 1, 'Community College of Rhode Island', 'ccri.edu', 'http://www.ccri.edu/'),
(1969, 1, 'Central Carolina Technical College', 'cctech.edu', 'http://www.cctech.edu/'),
(1970, 1, 'Denmark Technical College', 'denmarktech.edu', 'http://www.denmarktech.edu/'),
(1971, 1, 'Florence-Darlington Technical College', 'www.fdtc.edu', 'http://WWW.FDTC.EDU/'),
(1972, 1, 'Greenville Technical College', 'gvltec.edu', 'http://www.gvltec.edu/'),
(1973, 1, 'Horry-Georgetown Technical College', 'hgtc.edu', 'http://www.hgtc.edu/'),
(1974, 1, 'Midlands Technical College', 'midlandstech.edu', 'http://www.midlandstech.edu/'),
(1975, 1, 'Northeastern Technical College', 'netc.edu', 'http://www.netc.edu/'),
(1976, 1, 'Orangeburg Calhoun Technical College', 'octech.edu', 'http://www.octech.edu/'),
(1977, 1, 'Piedmont Technical College', 'ptc.edu', 'http://www.ptc.edu/'),
(1978, 1, 'Spartanburg Community College', 'sccsc.edu', 'http://www.sccsc.edu/'),
(1979, 1, 'Spartanburg Methodist College', 'smcsc.edu', 'http://www.smcsc.edu/'),
(1980, 1, 'Technical College of the Lowcountry', 'tcl.edu', 'http://www.tcl.edu/'),
(1981, 1, 'Tri-County Technical College', 'tctc.edu', 'http://www.tctc.edu/'),
(1982, 1, 'Trident Technical College', 'tridenttech.edu', 'http://www.tridenttech.edu/'),
(1983, 1, 'Williamsburg Technical College', 'wiltech.edu', 'http://www.wiltech.edu/'),
(1984, 1, 'York Technical College', 'yorktech.edu', 'http://www.yorktech.edu/'),
(1985, 1, 'Kilian Community College', 'kilian.edu', 'http://www.kilian.edu/'),
(1986, 1, 'Lake Area Technical Institute', 'lakeareatech.edu', 'http://www.lakeareatech.edu/'),
(1987, 1, 'Mitchell Technical Institute', 'mitchelltech.edu', 'http://www.mitchelltech.edu/'),
(1988, 1, 'Sisseton Wahpeton College', 'swc.tc', 'http://www.swc.tc/'),
(1989, 1, 'Southeast Technical Institute', 'southeasttech.edu', 'http://www.southeasttech.edu/'),
(1990, 1, 'Western Dakota Technical Institute', 'wdt.edu', 'https://www.wdt.edu/'),
(1991, 1, 'Chattanooga State Community College', 'chattanoogastate.edu', 'http://www.chattanoogastate.edu/'),
(1992, 1, 'Cleveland State Community College', 'clevelandstatecc.edu', 'http://www.clevelandstatecc.edu/'),
(1993, 1, 'Columbia State Community College', 'columbiastate.edu', 'http://www.columbiastate.edu/'),
(1994, 1, 'Dyersburg State Community College', 'dscc.edu', 'http://www.dscc.edu/'),
(1995, 1, 'Jackson State Community College', 'jscc.edu', 'http://www.jscc.edu/'),
(1996, 1, 'John A Gupton College', 'guptoncollege.edu', 'http://www.guptoncollege.edu/'),
(1997, 1, 'Motlow State Community College', 'mscc.edu', 'http://www.mscc.edu/'),
(1998, 1, 'Northeast State Community College', 'northeaststate.edu', 'http://www.NortheastState.edu/'),
(1999, 1, 'Pellissippi State Community College', 'pstcc.edu', 'http://www.pstcc.edu/'),
(2000, 1, 'Roane State Community College', 'roanestate.edu', 'http://www.roanestate.edu/'),
(2001, 1, 'Southwest Tennessee Community College', 'southwest.tn.edu', 'http://www.southwest.tn.edu/'),
(2002, 1, 'Volunteer State Community College', 'volstate.edu', 'http://www.volstate.edu/'),
(2003, 1, 'Walters State Community College', 'ws.edu', 'http://www.ws.edu/'),
(2004, 1, 'Alvin Community College', 'alvincollege.edu', 'http://www.alvincollege.edu/'),
(2005, 1, 'Amarillo College', 'actx.edu', 'http://www.actx.edu/'),
(2006, 1, 'Angelina College', 'angelina.edu', 'http://www.angelina.edu/'),
(2007, 1, 'Blinn College', 'blinn.edu', 'http://www.blinn.edu/'),
(2008, 1, 'Brookhaven College', 'brookhavencollege.edu', 'http://www.brookhavencollege.edu/'),
(2009, 1, 'Cedar Valley College', 'cedarvalleycollege.edu', 'http://www.cedarvalleycollege.edu/'),
(2010, 1, 'Central Texas College', 'ctcd.edu', 'http://www.ctcd.edu/'),
(2011, 1, 'Schreiner University', 'schreiner.edu', 'https://schreiner.edu/'),
(2012, 1, 'Cisco College', 'cisco.edu', 'http://www.cisco.edu/'),
(2013, 1, 'Clarendon College', 'clarendoncollege.edu', 'http://www.clarendoncollege.edu/'),
(2014, 1, 'Coastal Bend College', 'coastalbend.edu', 'http://www.coastalbend.edu/'),
(2015, 1, 'College of the Mainland', 'com.edu', 'http://www.com.edu/'),
(2016, 1, 'Collin County Community College District', 'collin.edu', 'http://www.collin.edu/'),
(2017, 1, 'Del Mar College', 'delmar.edu', 'http://www.delmar.edu/'),
(2018, 1, 'Eastfield College', 'eastfieldcollege.edu', 'http://www.eastfieldcollege.edu/'),
(2019, 1, 'El Centro College', 'elcentrocollege.edu', 'http://www.elcentrocollege.edu/'),
(2020, 1, 'El Paso Community College', 'epcc.edu', 'http://www.epcc.edu/'),
(2021, 1, 'Frank Phillips College', 'fpctx.edu', 'http://www.fpctx.edu/'),
(2022, 1, 'Galveston College', 'gc.edu', 'http://www.gc.edu/'),
(2023, 1, 'Grayson College', 'grayson.edu', 'http://www.grayson.edu/'),
(2024, 1, 'Hill College', 'hillcollege.edu', 'http://www.hillcollege.edu/'),
(2025, 1, 'Houston Community College', 'hccs.edu', 'http://www.hccs.edu/'),
(2026, 1, 'Howard College', 'howardcollege.edu', 'http://www.howardcollege.edu/'),
(2027, 1, 'Jacksonville College-Main Campus', 'jacksonville-college.edu', 'http://www.jacksonville-college.edu/'),
(2028, 1, 'Kilgore College', 'kilgore.edu', 'http://www.kilgore.edu/'),
(2029, 1, 'Lamar Institute of Technology', 'lit.edu', 'http://www.lit.edu/'),
(2030, 1, 'Lamar State College-Orange', 'lsco.edu', 'http://www.lsco.edu/'),
(2031, 1, 'Lamar State College-Port Arthur', 'lamarpa.edu', 'http://www.lamarpa.edu/'),
(2032, 1, 'Laredo Community College', 'laredo.edu', 'http://www.laredo.edu/'),
(2033, 1, 'Lee College', 'lee.edu', 'http://www.lee.edu/'),
(2034, 1, 'Lone Star College System', 'lonestar.edu', 'http://www.lonestar.edu/'),
(2035, 1, 'McLennan Community College', 'mclennan.edu', 'http://www.mclennan.edu/'),
(2036, 1, 'Navarro College', 'navarrocollege.edu', 'http://www.navarrocollege.edu/'),
(2037, 1, 'North Central Texas College', 'nctc.edu', 'http://www.nctc.edu/'),
(2038, 1, 'Northeast Texas Community College', 'ntcc.edu', 'http://www.ntcc.edu/'),
(2039, 1, 'Odessa College', 'odessa.edu', 'http://www.odessa.edu/'),
(2040, 1, 'Alamo Colleges District', 'alamo.edu', 'http://www.alamo.edu/'),
(2041, 1, 'Panola College', 'panola.edu', 'http://www.panola.edu/'),
(2042, 1, 'Paris Junior College', 'parisjc.edu', 'http://www.parisjc.edu/'),
(2043, 1, 'Ranger College', 'rangercollege.edu', 'http://www.rangercollege.edu/'),
(2044, 1, 'Richland College', 'richlandcollege.edu', 'http://www.richlandcollege.edu/'),
(2045, 1, 'South Plains College', 'southplainscollege.edu', 'http://www.southplainscollege.edu/'),
(2046, 1, 'Southwest Texas Junior College', 'swtjc.net', 'http://www.swtjc.net/'),
(2047, 1, 'Temple College', 'templejc.edu', 'http://www.templejc.edu/'),
(2048, 1, 'Texarkana College', 'texarkanacollege.edu', 'http://www.texarkanacollege.edu/'),
(2049, 1, 'Texas State Technical College-Harlingen', 'harlingen.tstc.edu', 'http://www.harlingen.tstc.edu/'),
(2050, 1, 'Texas State Technical College-Marshall', 'marshall.tstc.edu', 'http://www.marshall.tstc.edu/'),
(2051, 1, 'Texas State Technical College-Waco', 'waco.tstc.edu', 'http://www.waco.tstc.edu/'),
(2052, 1, 'Texas State Technical College-West Texas', 'westtexas.tstc.edu', 'http://www.westtexas.tstc.edu/'),
(2053, 1, 'Trinity Valley Community College', 'tvcc.edu', 'http://www.tvcc.edu/'),
(2054, 1, 'Tyler Junior College', 'www.tjc.edu', 'http://WWW.TJC.EDU/'),
(2055, 1, 'Vernon College', 'vernoncollege.edu', 'http://www.vernoncollege.edu/'),
(2056, 1, 'Victoria College', 'victoriacollege.edu', 'http://www.victoriacollege.edu/'),
(2057, 1, 'Weatherford College', 'wc.edu', 'http://www.wc.edu/'),
(2058, 1, 'Western Texas College', 'wtc.edu', 'http://www.wtc.edu/'),
(2059, 1, 'Wharton County Junior College', 'wcjc.edu', 'http://www.wcjc.edu/'),
(2060, 1, 'Latter-day Saints Business College', 'ldsbc.edu', 'http://www.ldsbc.edu/'),
(2061, 1, 'Salt Lake Community College', 'slcc.edu', 'http://www.slcc.edu/'),
(2062, 1, 'Community College of Vermont', 'ccv.edu', 'http://www.ccv.edu/'),
(2064, 1, 'Central Virginia Community College', 'cvcc.vccs.edu', 'http://www.cvcc.vccs.edu/'),
(2065, 1, 'Dabney S Lancaster Community College', 'dslcc.edu', 'http://www.dslcc.edu/'),
(2066, 1, 'Danville Community College', 'dcc.vccs.edu', 'http://www.dcc.vccs.edu/'),
(2067, 1, 'Eastern Shore Community College', 'es.vccs.edu', 'http://www.es.vccs.edu/'),
(2068, 1, 'Germanna Community College', 'germanna.edu', 'http://www.germanna.edu/'),
(2069, 1, 'John Tyler Community College', 'jtcc.edu', 'http://www.jtcc.edu/'),
(2070, 1, 'J Sargeant Reynolds Community College', 'reynolds.edu', 'http://www.reynolds.edu/'),
(2071, 1, 'Lord Fairfax Community College', 'lfcc.edu', 'http://www.lfcc.edu/'),
(2072, 1, 'Mountain Empire Community College', 'mecc.edu', 'http://www.mecc.edu/'),
(2073, 1, 'New River Community College', 'nr.edu', 'http://www.nr.edu/'),
(2074, 1, 'Northern Virginia Community College', 'nvcc.edu', 'http://www.nvcc.edu/'),
(2075, 1, 'Patrick Henry Community College', 'patrickhenry.edu', 'http://www.patrickhenry.edu/'),
(2076, 1, 'Paul D Camp Community College', 'pdc.edu', 'http://www.pdc.edu/'),
(2077, 1, 'Piedmont Virginia Community College', 'pvcc.edu', 'http://www.pvcc.edu/'),
(2078, 1, 'Rappahannock Community College', 'rappahannock.edu', 'http://www.rappahannock.edu/'),
(2079, 1, 'Richard Bland College of the College of William and Mary', 'rbc.edu', 'http://www.rbc.edu/'),
(2080, 1, 'Southside Virginia Community College', 'southside.edu', 'http://www.southside.edu/'),
(2081, 1, 'Southwest Virginia Community College', 'sw.edu', 'http://www.sw.edu/'),
(2082, 1, 'Thomas Nelson Community College', 'tncc.edu', 'http://www.tncc.edu/'),
(2083, 1, 'Tidewater Community College', 'tcc.edu', 'http://www.tcc.edu/'),
(2084, 1, 'Virginia Highlands Community College', 'vhcc.edu', 'http://www.vhcc.edu/'),
(2085, 1, 'Virginia Western Community College', 'virginiawestern.edu', 'http://virginiawestern.edu/'),
(2086, 1, 'Wytheville Community College', 'wcc.vccs.edu', 'http://www.wcc.vccs.edu/'),
(2087, 1, 'Bates Technical College', 'bates.ctc.edu', 'http://www.bates.ctc.edu/'),
(2088, 1, 'Bellingham Technical College', 'btc.ctc.edu', 'http://www.btc.ctc.edu/'),
(2089, 1, 'Big Bend Community College', 'bigbend.edu', 'http://www.bigbend.edu/'),
(2090, 1, 'Cascadia Community College', 'cascadia.edu', 'http://www.cascadia.edu/'),
(2091, 1, 'Clark College', 'clark.edu', 'http://www.clark.edu/'),
(2092, 1, 'Clover Park Technical College', 'cptc.edu', 'http://www.cptc.edu/'),
(2093, 1, 'Edmonds Community College', 'edcc.edu', 'http://www.edcc.edu/'),
(2094, 1, 'Everett Community College', 'everettcc.edu', 'http://www.everettcc.edu/'),
(2095, 1, 'Grays Harbor College', 'ghc.edu', 'http://www.ghc.edu/'),
(2096, 1, 'Green River Community College', 'greenriver.edu', 'http://www.greenriver.edu/'),
(2097, 1, 'Highline Community College', 'highline.edu', 'http://www.highline.edu/'),
(2098, 1, 'Lower Columbia College', 'lowercolumbia.edu', 'http://lowercolumbia.edu/'),
(2099, 1, 'Pierce College at Puyallup', 'pierce.ctc.edu', 'http://www.pierce.ctc.edu/'),
(2100, 1, 'Renton Technical College', 'rtc.edu', 'http://www.rtc.edu/'),
(2101, 1, 'Shoreline Community College', 'shoreline.edu', 'http://www.shoreline.edu/'),
(2102, 1, 'Skagit Valley College', 'skagit.edu', 'http://www.skagit.edu/'),
(2103, 1, 'South Puget Sound Community College', 'spscc.ctc.edu', 'http://www.spscc.ctc.edu/'),
(2104, 1, 'Spokane Community College', 'scc.spokane.edu', 'http://www.scc.spokane.edu/'),
(2105, 1, 'Spokane Falls Community College', 'spokanefalls.edu', 'http://www.spokanefalls.edu/'),
(2106, 1, 'Tacoma Community College', 'tacomacc.edu', 'http://www.tacomacc.edu/'),
(2107, 1, 'Walla Walla Community College', 'wwcc.edu', 'http://www.wwcc.edu/'),
(2108, 1, 'Wenatchee Valley College', 'wvc.edu', 'http://www.wvc.edu/'),
(2109, 1, 'Whatcom Community College', 'whatcom.ctc.edu', 'http://www.whatcom.ctc.edu/'),
(2110, 1, 'Yakima Valley Community College', 'yvcc.edu', 'http://www.yvcc.edu/'),
(2111, 1, 'Blue Ridge Community and Technical College', 'blueridgectc.edu', 'http://www.blueridgectc.edu/'),
(2112, 1, 'Bridgemont Community and Technical College', 'bridgemont.edu', 'http://www.bridgemont.edu/'),
(2113, 1, 'Eastern West Virginia Community and Technical College', 'eastern.wvnet.edu', 'http://www.Eastern.wvnet.edu/'),
(2114, 1, 'Huntington Junior College', 'huntingtonjuniorcollege.edu', 'http://www.huntingtonjuniorcollege.edu/'),
(2115, 1, 'Kanawha Valley Community and Technical College', 'kvctc.edu', 'http://www.kvctc.edu/'),
(2116, 1, 'Mountwest Community and Technical College', 'mctc.edu', 'http://www.mctc.edu/'),
(2117, 1, 'New River Community and Technical College', 'newriver.edu', 'http://www.newriver.edu/'),
(2118, 1, 'Pierpont Community and Technical College', 'pierpont.edu', 'http://www.pierpont.edu/'),
(2119, 1, 'Southern West Virginia Community and Technical College', 'southernwv.edu', 'http://www.southernwv.edu/'),
(2120, 1, 'West Virginia Northern Community College', 'wvncc.edu', 'http://www.wvncc.edu/'),
(2121, 1, 'Blackhawk Technical College', 'blackhawk.edu', 'http://www.blackhawk.edu/'),
(2122, 1, 'Chippewa Valley Technical College', 'cvtc.edu', 'http://www.cvtc.edu/'),
(2123, 1, 'Fox Valley Technical College', 'fvtc.edu', 'http://www.fvtc.edu/'),
(2124, 1, 'Gateway Technical College', 'gtc.edu', 'http://www.gtc.edu/'),
(2125, 1, 'Lac Courte Oreilles Ojibwa Community College', 'lco.edu', 'http://www.lco.edu/'),
(2126, 1, 'Lakeshore Technical College', 'gotoltc.edu', 'http://www.gotoltc.edu/'),
(2127, 1, 'Madison Area Technical College', 'madisoncollege.edu', 'http://madisoncollege.edu/'),
(2128, 1, 'Mid-State Technical College', 'mstc.edu', 'http://www.mstc.edu/'),
(2129, 1, 'Milwaukee Area Technical College', 'matc.edu', 'http://matc.edu/'),
(2130, 1, 'Moraine Park Technical College', 'morainepark.edu', 'http://www.morainepark.edu/'),
(2131, 1, 'Nicolet Area Technical College', 'nicoletcollege.edu', 'http://www.nicoletcollege.edu/'),
(2132, 1, 'Northcentral Technical College', 'ntc.edu', 'http://www.ntc.edu/'),
(2133, 1, 'Northeast Wisconsin Technical College', 'nwtc.edu', 'http://www.nwtc.edu/'),
(2134, 1, 'Southwest Wisconsin Technical College', 'swtc.edu', 'http://www.swtc.edu/'),
(2135, 1, 'University of Wisconsin Colleges', 'uwc.edu', 'http://www.uwc.edu/'),
(2136, 1, 'Waukesha County Technical College', 'wctc.edu', 'http://www.wctc.edu/'),
(2137, 1, 'Western Technical College', 'westerntc.edu', 'http://www.westerntc.edu/'),
(2138, 1, 'Wisconsin Indianhead Technical College', 'witc.edu', 'http://www.witc.edu/'),
(2139, 1, 'Casper College', 'caspercollege.edu', 'http://www.caspercollege.edu/'),
(2140, 1, 'Central Wyoming College', 'cwc.edu', 'http://www.cwc.edu/'),
(2141, 1, 'Eastern Wyoming College', 'ewc.wy.edu', 'http://ewc.wy.edu/'),
(2142, 1, 'Laramie County Community College', 'lccc.wy.edu', 'http://www.lccc.wy.edu/'),
(2143, 1, 'Northwest College', 'northwestcollege.edu', 'http://www.northwestcollege.edu/'),
(2144, 1, 'Sheridan College', 'sheridan.edu', 'http://www.sheridan.edu/'),
(2145, 1, 'Western Wyoming Community College', 'wwcc.wy.edu', 'http://www.wwcc.wy.edu/'),
(2146, 1, 'Trinity Bible College & Graduate School', 'trinitybiblecollege.edu', 'https://trinitybiblecollege.edu/'),
(2147, 1, 'University of Michigan-Flint', 'umflint.edu', 'http://www.umflint.edu/'),
(2148, 1, 'Kenai Peninsula College', 'kpc.alaska.edu', 'http://www.kpc.alaska.edu/'),
(2149, 1, 'Mat-Su College', 'matsu.alaska.edu', 'http://matsu.alaska.edu/'),
(2150, 1, 'Kodiak College', 'koc.alaska.edu', 'http://koc.alaska.edu/'),
(2151, 1, 'Alaska Pacific University', 'alaskapacific.edu', 'http://www.alaskapacific.edu/'),
(2152, 1, 'Wayland Baptist University', 'wbu.edu', 'http://www.wbu.edu/'),
(2153, 1, 'Polk State College', 'polk.edu', 'https://www.polk.edu/'),
(2154, 1, 'Brescia University', 'brescia.edu', 'https://www.brescia.edu/'),
(2155, 1, 'Rogers State University', 'rsu.edu', 'https://www.rsu.edu/'),
(2156, 1, 'Neumann University', 'neumann.edu', 'https://www.neumann.edu/'),
(2157, 1, 'Savannah College of Art and Design', 'scad.edu', 'http://www.scad.edu/'),
(2158, 1, 'Ashford University', 'ashford.edu', 'https://www.ashford.edu/'),
(2159, 1, 'McPherson College', 'mcpherson.edu', 'https://www.mcpherson.edu/'),
(2160, 1, 'Community College System of New Hampshire', 'ccsnh.edu', 'https://www.ccsnh.edu/'),
(2161, 1, 'Defiance College', 'defiance.edu', 'http://www.defiance.edu/'),
(2162, 1, 'Medical University of South Carolina', 'musc.edu', 'http://www.musc.edu/'),
(2163, 1, 'Gulf Coast State College', 'gulfcoast.edu', 'https://www.gulfcoast.edu/'),
(2164, 1, 'Academy of Art University', 'academyart.edu', 'https://www.academyart.edu/'),
(2165, 1, 'Lenoir-Rhyne University', 'lr.edu', 'https://www.lr.edu/'),
(2166, 1, 'Point Park University', 'pointpark.edu', 'https://pointpark.edu/'),
(2167, 1, 'Northwood University', 'northwood.edu', 'https://northwood.edu/'),
(2168, 1, 'Clark Atlanta University', 'cau.edu', 'https://www.cau.edu/'),
(2169, 1, 'Morehouse', 'morehouse.edu', 'https://morehouse.edu/'),
(2170, 1, 'University of St. Augustine for Health Sciences', 'usa.edu', 'https://www.usa.edu/'),
(2171, 1, 'Gwynedd Mercy University', 'gmercyu.edu', 'https://www.gmercyu.edu/'),
(2172, 1, 'California Institute of the Arts', 'calarts.edu', 'https://calarts.edu/'),
(2173, 1, 'Des Moines University', 'dmu.edu', 'https://www.dmu.edu/'),
(2174, 1, 'Utah Tech University', 'utahtech.edu', 'https://utahtech.edu/'),
(2175, 1, 'Midwestern University', 'midwestern.edu', 'https://midwestern.edu/'),
(2176, 1, 'Illinois Wesleyan University', 'iwu.edu', 'https://www.iwu.edu/'),
(2177, 1, 'Maryville College', 'maryvillecollege.edu', 'https://www.maryvillecollege.edu/'),
(2178, 1, 'Endicott College', 'endicott.edu', 'https://www.endicott.edu/'),
(2179, 1, 'The University of Alabama', 'ua.edu', 'https://www.ua.edu/'),
(2180, 1, 'Great Basin College', 'gbcnv.edu', 'https://www.gbcnv.edu/'),
(2181, 1, 'Einsteinmed', 'einsteinmed.edu', 'https://www.einsteinmed.edu/'),
(2182, 1, 'Miami Dade College', 'mdc.edu', 'https://mdc.edu/'),
(2183, 1, 'Florida SouthWestern State College', 'fsw.edu', 'https://www.fsw.edu/'),
(2184, 1, 'Bishop McNamara High School', 'bmhs.org', 'https://www.bmhs.org/'),
(2185, 1, 'Chaminade University of Honolulu', 'chaminade.edu', 'https://chaminade.edu/'),
(2186, 1, 'Dalton State College', 'daltonstate.edu', 'https://www.daltonstate.edu/'),
(2187, 1, 'Ojai Unified School District', 'ojaiusd.org', 'https://www.ojaiusd.org/'),
(2188, 1, 'Bismark State College', 'bismarckstate.edu', 'https://bismarckstate.edu/'),
(2189, 1, 'Quadrat Academy', 'quadratacademy.com', 'https://www.quadratacademy.com/'),
(2190, 1, 'University of North Alabama', 'una.edu', 'https://www.una.edu/'),
(2191, 1, 'Bellevue College', 'bellevuecollege.edu', 'https://bellevuecollege.edu/'),
(2192, 1, 'CUNY Lehman College', 'lehman.cuny.edu', 'https://www.lehman.cuny.edu/'),
(2193, 1, 'CUNY John Jay College of Criminal Justice', 'jjay.cuny.edu', 'https://www.jjay.cuny.edu/'),
(2194, 1, 'Hunter College CUNY', 'hunter.cuny.edu', 'https://hunter.cuny.edu/'),
(2195, 1, 'CUNY York College', 'york.cuny.edu', 'https://www.york.cuny.edu/'),
(2196, 1, 'Pennsylvania State University - Harrisburg', 'harrisburg.psu.edu', 'https://harrisburg.psu.edu/'),
(2197, 1, 'Alcorn State University', 'alcorn.edu', 'https://www.alcorn.edu/'),
(2198, 1, 'Allen University', 'allenuniversity.edu', 'https://allenuniversity.edu/'),
(2199, 1, 'American Baptist College', 'abcnash.edu', 'https://abcnash.edu/'),
(2200, 1, 'Arkansas at Pine Bluff, University of', 'uapb.edu', 'http://www.uapb.edu/'),
(2201, 1, 'Arkansas Baptist College', 'arkansasbaptist.edu', 'https://www.arkansasbaptist.edu/'),
(2202, 1, 'Barber-Scotia College', 'b-sc.edu', 'https://b-sc.edu/'),
(2203, 1, 'Benedict College', 'benedict.edu', 'https://www.benedict.edu/'),
(2204, 1, 'Bennett College', 'bennet.edu', 'https://www.bennett.edu/'),
(2205, 1, 'Bethune-Cookman University', 'cookman.edu', 'https://www.cookman.edu/'),
(2206, 1, 'Bluefield State College', 'bluefieldstate.edu', 'https://bluefieldstate.edu/'),
(2207, 1, 'Carver College', 'carver.edu', 'https://www.carver.edu/'),
(2208, 1, 'Central State University', 'centralstate.edu', 'https://www.centralstate.edu/'),
(2209, 1, 'Claflin University', 'claflin.edu', 'https://www.claflin.edu/'),
(2210, 1, 'Clinton College', 'clintoncollege.edu', 'https://www.clintoncollege.edu/'),
(2211, 1, 'Edward Waters University', 'ewc.edu', 'http://www.ewc.edu/'),
(2212, 1, 'Florida Memorial University', 'fmuniv.edu', 'https://www.fmuniv.edu/'),
(2213, 1, 'Fort Valley State University', 'fvsu.edu', 'https://www.fvsu.edu/'),
(2214, 1, 'Gasden State Community College', 'gadsenstate.edu', 'https://www.gadsdenstate.edu/'),
(2215, 1, 'Grambling State University', 'gram.edu', 'https://www.gram.edu/'),
(2216, 1, 'Harris-Stowe State University', 'hssu.edu', 'https://www.hssu.edu/'),
(2217, 1, 'Hood Theological', 'hoodseminary.edu', 'https://www.hoodseminary.edu/'),
(2218, 1, 'Huston-Tillotson University', 'htu.edu', 'https://htu.edu/'),
(2219, 1, 'Interdenominational Theological Center', 'itc.edu', 'https://www.itc.edu/'),
(2220, 1, 'Jarvis Christian College', 'jarvis.edu', 'http://www.jarvis.edu/'),
(2221, 1, 'Johnson C Smith Theological Seminary *', 'smithseminary.org', 'https://www.smithseminary.org/'),
(2222, 1, 'Kentucky State University', 'kysu.edu', 'https://www.kysu.edu/'),
(2223, 1, 'Knoxville College', 'knoxvillecollege.edu', 'https://www.knoxvillecollege.edu/'),
(2224, 1, 'Lane College', 'lanecollege.edu', 'https://www.lanecollege.edu/'),
(2225, 1, 'Lawson State Community College', 'lawsonstate.edu', 'http://www.lawsonstate.edu/'),
(2226, 1, 'LeMoyne-Owen College', 'loc.edu', 'https://www.loc.edu/'),
(2227, 1, 'Livingstone College', 'livingstone.edu', 'http://livingstone.edu/'),
(2228, 1, 'Meharry Medical College', 'mmc.edu', 'https://home.mmc.edu/'),
(2229, 1, 'Miles College', 'miles.edu', 'https://www.miles.edu/'),
(2230, 1, 'Miles School of Law', 'mlaw.edu', 'https://mlaw.edu/'),
(2231, 1, 'Morehouse School of Medicine', 'msm.edu', 'https://www.msm.edu/'),
(2232, 1, 'Morris Brown College', 'morrisbrown.edu', 'https://morrisbrown.edu/'),
(2233, 1, 'Morris College', 'morris.edu', 'https://www.morris.edu/'),
(2234, 1, 'Paine College', 'paine.edu', 'https://www.paine.edu/'),
(2235, 1, 'Paul Quinn College', 'paulquinn.edu', 'https://paulquinn.edu/'),
(2236, 1, 'Philander Smith College', 'philander.edu', 'https://www.philander.edu/'),
(2237, 1, 'Rust College', 'rustcollege.edu', 'https://www.rustcollege.edu/'),
(2238, 1, 'Savannah State University', 'savannahstate.edu', 'https://www.savannahstate.edu/'),
(2239, 1, 'Selma University', 'selmauniversity.edu', 'https://www.selmauniversity.edu/'),
(2240, 1, 'Shaw University', 'shawu.edu', 'https://www.shawu.edu/'),
(2241, 1, 'Simmons College of Kentucky', 'simmonscollegeky.edu', 'https://simmonscollegeky.edu/'),
(2242, 1, 'South Carolina State University', 'scsu.edu', 'https://scsu.edu/'),
(2243, 1, 'Southern University at New Orleans', 'suno.edu', 'https://www.suno.edu/'),
(2244, 1, 'Southwestern Christian College', 'swcc.edu', 'https://www.swcc.edu/'),
(2245, 1, 'St. Augustine\'s University', 'st-aug.edu', 'https://www.st-aug.edu/'),
(2246, 1, 'Stillman College', 'stillman.edu', 'https://stillman.edu/'),
(2247, 1, 'Talladega College', 'talladega.edu', 'https://www.talladega.edu/'),
(2248, 1, 'Texas College', 'texascollege.edu', 'https://www.texascollege.edu/'),
(2249, 1, 'Tougaloo College', 'tougaloo.edu', 'https://www.tougaloo.edu/'),
(2250, 1, 'Virginia Union University', 'vuu.edu', 'https://www.vuu.edu/'),
(2251, 1, 'Virginia University of Lynchburg', 'vul.edu', 'https://www.vul.edu/'),
(2252, 1, 'Voorhees University', 'voorhees.edu', 'https://www.voorhees.edu/'),
(2253, 1, 'West Virginia State University', 'wvstate.edu', 'https://www.wvstateu.edu/'),
(2254, 1, 'Wiley College', 'wileyc.edu', 'https://www.wileyc.edu/'),
(2255, 1, 'Winston-Salem State University', 'wssu.edu', 'https://www.wssu.edu/'),
(2256, 1, 'Unity Environmental College', 'unity.edu', 'https://unity.edu/'),
(2257, 1, 'Catawba College', 'catawba.edu', 'https://catawba.edu/'),
(2258, 1, 'Texas A&M University-Texarkana', 'ace.tamut.edu', 'https://tamut.edu/'),
(2259, 1, 'Belhaven University', 'belhaven.edu', 'https://belhaven.edu/'),
(2260, 1, 'Berry College', 'berry.edu', 'https://berry.edu/'),
(2261, 1, 'Bloomfield College', 'bloomfield.edu', 'https://bloomfield.edu/'),
(2262, 1, 'Bridgewater State University', 'bridgew.edu', 'https://bridgew.edu/'),
(2263, 1, 'Cabrini University', 'cabrini.edu', 'https://cabrini.edu/'),
(2264, 1, 'Caldwell University', 'caldwell.edu', 'https://caldwell.edu/'),
(2266, 1, 'Covenant College', 'covenant.edu', 'https://covenant.edu/'),
(2267, 1, 'Chicago State University', 'csu.edu', 'https://csu.edu/'),
(2268, 1, 'California State University', 'csueastbay.edu', 'https://csueastbay.edu/'),
(2269, 1, 'Colorado State University-Pueblo', 'csupueblo.edu', 'https://csupueblo.edu/'),
(2270, 1, 'Bay Atlantic University', 'bau.edu', 'https://bau.edu/'),
(2271, 1, 'Siena College', 'siena.edu', 'https://www.siena.edu/'),
(2272, 1, 'Texas Wesleyan University', 'txwes.edu', 'https://txwes.edu/'),
(2273, 1, 'Island Drafting & Technical Institute', 'idti.edu', 'https://www.idti.edu/'),
(2274, 1, 'Bay Path University', 'baypath.edu', 'https://www.baypath.edu/'),
(2275, 1, 'Snow College', 'snow.edu', 'https://www.snow.edu/'),
(2276, 1, 'State Center Community College District', 'scccd.edu', 'https://www.scccd.edu/'),
(2277, 1, 'Davidson-Davie Community College', 'davidsondavie.edu', 'https://www.davidsondavie.edu/'),
(2278, 1, 'Berkeley College', 'berkeleycollege.edu', 'https://berkeleycollege.edu/'),
(2279, 1, 'Schiller International University', 'schiller.edu', 'https://schiller.edu/'),
(2280, 1, 'Greensboro College', 'greensboro.edu', 'https://www.greensboro.edu/'),
(2281, 1, 'Verde Valley School', 'vvsaz.org', 'https://www.vvsaz.org/'),
(2282, 1, 'Oglethorpe University', 'oglethorpe.edu', 'https://oglethorpe.edu/'),
(2283, 1, 'Detroit School of Technology', 'dsdt.edu', 'https://dsdt.edu/'),
(2284, 1, 'North Central College', 'northcentralcollege.edu', 'https://www.northcentralcollege.edu/'),
(2285, 1, 'The University of Montana Western', 'umwestern.edu', 'https://www.umwestern.edu/'),
(2286, 1, 'Queens University of Charlotte', 'queens.edu', 'https://www.queens.edu/'),
(2287, 1, 'Lincoln Memorial University', 'lmunet.edu', 'https://www.lmunet.edu/'),
(2288, 1, 'Greenville University', 'greenville.edu', 'https://www.greenville.edu/'),
(2289, 1, 'State University of New York at Oneonta', 'suny.oneonta.edu', 'https://suny.oneonta.edu/'),
(2290, 1, 'Northwestern Michigan College', 'nmc.edu', 'https://www.nmc.edu/'),
(2291, 1, 'Adrian College', 'adrian.edu', 'https://adrian.edu/'),
(2292, 1, 'Concordia University Wisconsin', 'cuw.edu', 'https://cuw.edu/'),
(2293, 1, 'Delaware Valley University', 'delval.edu', 'https://delval.edu/'),
(2295, 1, 'Eckerd College', 'eckerd.edu', 'https://eckerd.edu/'),
(2296, 1, 'University of South Carolina Upstate', 'email.uscupstate.edu', 'https://uscupstate.edu/'),
(2297, 1, 'Fairfield University', 'fairfield.edu', 'https://fairfield.edu/'),
(2298, 1, 'Foothill-De Anza Community College District', 'fhda.edu', 'https://fhda.edu/'),
(2299, 1, 'Francis Marion University', 'g.fmarion.edu', 'https://fmarion.edu/'),
(2300, 1, 'George Fox University', 'georgefox.edu', 'https://georgefox.edu/'),
(2301, 1, 'Grand View University', 'grandview.edu', 'https://grandview.edu/'),
(2302, 1, 'Abraham Baldwin Agricultural College', 'abac.edu', 'https://www.abac.edu/'),
(2303, 1, 'Capital University', 'capital.edu', 'https://www.capital.edu/'),
(2304, 1, 'State University of New York College at Oneonta', 'oneonta.edu', 'https://suny.oneonta.edu/'),
(2305, 1, 'University of Mount Olive', 'umo.edu', 'https://umo.edu/'),
(2306, 1, 'The University of Olivet', 'olivetcollege.edu', 'https://www.uolivet.edu/'),
(2307, 1, 'Westminster University', 'westminsteru.edu', 'https://westminsteru.edu/'),
(2308, 1, 'Dominican University', 'dom.edu', 'https://www.dom.edu/'),
(2309, 1, 'Claremont Colleges', 'claremont.edu', 'http://www.claremont.edu/'),
(2310, 1, 'Rowan College at Burlington County', 'rcbc.edu', 'http://www.rcbc.edu/'),
(2312, 1, 'Aspen University', 'aspen.edu', 'https://www.aspen.edu/'),
(2313, 1, 'California University of Science and Medicine', 'cusm.edu', 'https://www.cusm.edu/'),
(2314, 1, 'CUNY School of Law', 'law.cuny.edu', 'https://www.law.cuny.edu/'),
(2315, 1, 'Doane University', 'doane.edu', 'https://www.doane.edu/'),
(2316, 1, 'Eastern Virginia Medical School', 'evms.edu', 'https://www.evms.edu/'),
(2317, 1, 'Elms College', 'elms.edu', 'https://www.elms.edu/'),
(2318, 1, 'Estrella Mountain Community College', 'estrellamountain.edu', 'https://www.estrellamountain.edu/'),
(2319, 1, 'Florida Southern College', 'flsouthern.edu', 'https://www.flsouthern.edu/'),
(2320, 1, 'Franklin Pierce University', 'franklinpierce.edu', 'https://franklinpierce.edu/'),
(2321, 1, 'Kansas City University', 'kansascity.edu', 'https://www.kansascity.edu/'),
(2322, 1, 'Loyola University New Orleans', 'loyno.edu', 'https://www.loyno.edu/'),
(2323, 1, 'Maryland Institute College of Arts', 'mica.edu', 'https://www.mica.edu/'),
(2324, 1, 'Merrimack College', 'merrimack.edu', 'https://www.merrimack.edu/'),
(2325, 1, 'Nebraska Wesleyan University', 'nebrwesleyan.edu', 'https://www.nebrwesleyan.edu/'),
(2326, 1, 'New York Medical College', 'nymc.edu', 'https://www.nymc.edu/'),
(2327, 1, 'Pacific Northwest University of Health Sciences', 'pnwu.edu', 'https://www.pnwu.edu/'),
(2328, 1, 'Rowan College of South Jersey', 'rcsj.edu', 'https://rcsj.edu/'),
(2329, 1, 'Sofia University', 'sofia.edu', 'https://www.sofia.edu/'),
(2330, 1, 'SUNY Downstate Health Sciences University', 'downstate.edu', 'https://www.downstate.edu/'),
(2331, 1, 'University of South Carolina, Beaufort', 'uscb.edu', 'https://www.uscb.edu/'),
(2332, 1, 'Vermont Law School', 'vermontlaw.edu', 'https://www.vermontlaw.edu/'),
(2333, 1, 'Western Nevada College', 'wnc.edu', 'https://wnc.edu/'),
(2334, 1, 'Western University of Health Sciences', 'westernu.edu', 'https://www.westernu.edu/'),
(2335, 1, 'St. Mary\'s University', 'stmarytx.edu', 'https://www.stmarytx.edu/'),
(2336, 1, 'South Florida State College', 'southflorida.edu', 'https://www.southflorida.edu/'),
(2337, 1, 'Alvernia University', 'alvernia.edu', 'https://www.alvernia.edu/'),
(2338, 1, 'Hellenic American University', 'hauniv.edu', 'https://www.hauniv.edu/'),
(2339, 1, 'University of Holy Cross', 'uhcno.edu', 'https://uhcno.edu/'),
(2340, 1, 'University of Pikeville', 'upike.edu', 'https://www.upike.edu/'),
(2341, 1, 'Stonehill College', 'stonehill.edu', 'https://www.stonehill.edu/'),
(2342, 1, 'Southern Virginia University', 'svu.edu', 'https://svu.edu/'),
(2343, 1, 'Louisiana State University - Shreveport', 'lsus.edu', 'https://www.lsus.edu/'),
(2344, 1, 'Maricopa Community Colleges', 'maricopa.edu', 'https://www.maricopa.edu/'),
(2345, 1, 'Wingate University', 'wingate.edu', 'https://www.wingate.edu/'),
(2346, 1, 'California College of the Arts', 'cca.edu', 'https://cca.edu/'),
(2347, 1, 'Dallas College', 'dallascollege.edu', 'https://www.dallascollege.edu/'),
(2348, 1, 'University of North Texas at Dallas', 'untdallas.edu', 'https://www.untdallas.edu/'),
(2349, 1, 'Spokane Colleges', 'spokane.edu', 'https://spokane.edu/'),
(2350, 1, 'Life Chiropractic College West', 'lifewest.edu', 'https://lifewest.edu/'),
(2351, 1, 'Palmer College of Chiropractic', 'palmer.edu', 'https://www.palmer.edu/'),
(2352, 1, 'Parker University', 'parker.edu', 'https://www.parker.edu/'),
(2353, 1, 'Sherman College of Chiropractic', 'sherman.edu', 'https://www.sherman.edu/');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `user_id` bigint(20) UNSIGNED NOT NULL,
  `role_id` tinyint(3) UNSIGNED NOT NULL,
  `full_name` varchar(120) NOT NULL,
  `email` varchar(190) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `email_verified_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`user_id`, `role_id`, `full_name`, `email`, `password_hash`, `is_active`, `email_verified_at`, `created_at`, `updated_at`) VALUES
(1, 2, 'Sumaiya Tabassom', 'mentor@gmail.com', '$2b$12$mIlHhqv8fWMegff/3HOvUu69Bq3aVuhflb/7hBaY1XIvGF2uEiQSi', 1, NULL, '2026-11-03 11:04:34', '2026-11-03 11:04:34'),
(2, 1, 'Adib Abrar', 'abrar@gmail.com', '$2b$12$ApLoUuoVFIgEgAkMYsi/EOpwW7ObAQVehNRr/9J7SDh.lOWskMAcm', 1, NULL, '2026-11-03 11:19:38', '2026-11-03 11:19:38'),
(3, 1, 'Rafia Jannat', 'rafia@gmail.com', '$2b$12$/U0pkAUY.hK5RsutSpAw3.9PcRWefdRcNd70oxLKRJiadNZzfGBZm', 1, NULL, '2026-11-05 17:17:35', '2026-11-05 17:17:35'),
(4, 2, 'Sanzida', 'sanzida19@gmail.com', '$2b$12$cVjhxSzcRU6g5NcybF/K1.efudfITy1iez61xpJPLDHfB2/k2nEOK', 1, NULL, '2026-11-05 17:19:22', '2026-11-05 17:19:22');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `bookings`
--
ALTER TABLE `bookings`
  ADD PRIMARY KEY (`booking_id`),
  ADD KEY `fk_booking_plan` (`plan_id`),
  ADD KEY `idx_booking_student_date` (`student_user_id`,`scheduled_at`),
  ADD KEY `idx_booking_mentor_date` (`mentor_id`,`scheduled_at`);

--
-- Indexes for table `countries`
--
ALTER TABLE `countries`
  ADD PRIMARY KEY (`country_id`),
  ADD UNIQUE KEY `country_name` (`country_name`),
  ADD UNIQUE KEY `slug` (`slug`);

--
-- Indexes for table `faqs`
--
ALTER TABLE `faqs`
  ADD PRIMARY KEY (`faq_id`);

--
-- Indexes for table `group_sessions`
--
ALTER TABLE `group_sessions`
  ADD PRIMARY KEY (`session_id`),
  ADD KEY `fk_session_category` (`category_id`),
  ADD KEY `fk_session_mentor` (`mentor_id`),
  ADD KEY `idx_sessions_start` (`starts_at`,`status`);

--
-- Indexes for table `mentor_countries`
--
ALTER TABLE `mentor_countries`
  ADD PRIMARY KEY (`mentor_id`,`country_id`),
  ADD KEY `fk_mc_country` (`country_id`);

--
-- Indexes for table `mentor_plans`
--
ALTER TABLE `mentor_plans`
  ADD PRIMARY KEY (`plan_id`),
  ADD UNIQUE KEY `uq_mentor_duration` (`mentor_id`,`duration_minutes`);

--
-- Indexes for table `mentor_profiles`
--
ALTER TABLE `mentor_profiles`
  ADD PRIMARY KEY (`mentor_id`),
  ADD UNIQUE KEY `user_id` (`user_id`);

--
-- Indexes for table `mentor_programs`
--
ALTER TABLE `mentor_programs`
  ADD PRIMARY KEY (`mentor_id`,`program_id`),
  ADD KEY `fk_mp_program` (`program_id`);

--
-- Indexes for table `mentor_scholarships`
--
ALTER TABLE `mentor_scholarships`
  ADD PRIMARY KEY (`mentor_id`,`scholarship_id`),
  ADD KEY `fk_ms_scholarship` (`scholarship_id`);

--
-- Indexes for table `mentor_services`
--
ALTER TABLE `mentor_services`
  ADD PRIMARY KEY (`mentor_id`,`service_id`),
  ADD KEY `fk_mserv_service` (`service_id`);

--
-- Indexes for table `mentor_universities`
--
ALTER TABLE `mentor_universities`
  ADD PRIMARY KEY (`mentor_id`,`university_id`),
  ADD KEY `fk_mu_university` (`university_id`);

--
-- Indexes for table `programs`
--
ALTER TABLE `programs`
  ADD PRIMARY KEY (`program_id`),
  ADD UNIQUE KEY `program_name` (`program_name`);

--
-- Indexes for table `reviews`
--
ALTER TABLE `reviews`
  ADD PRIMARY KEY (`review_id`),
  ADD UNIQUE KEY `booking_id` (`booking_id`),
  ADD KEY `fk_review_student` (`student_user_id`),
  ADD KEY `fk_review_mentor` (`mentor_id`);

--
-- Indexes for table `roles`
--
ALTER TABLE `roles`
  ADD PRIMARY KEY (`role_id`),
  ADD UNIQUE KEY `role_name` (`role_name`);

--
-- Indexes for table `scholarships`
--
ALTER TABLE `scholarships`
  ADD PRIMARY KEY (`scholarship_id`),
  ADD KEY `idx_scholarships_country` (`country_id`);

--
-- Indexes for table `services`
--
ALTER TABLE `services`
  ADD PRIMARY KEY (`service_id`),
  ADD UNIQUE KEY `service_name` (`service_name`);

--
-- Indexes for table `session_categories`
--
ALTER TABLE `session_categories`
  ADD PRIMARY KEY (`category_id`),
  ADD UNIQUE KEY `category_name` (`category_name`);

--
-- Indexes for table `session_registrations`
--
ALTER TABLE `session_registrations`
  ADD PRIMARY KEY (`registration_id`),
  ADD UNIQUE KEY `uq_session_student` (`session_id`,`student_user_id`),
  ADD KEY `fk_registration_student` (`student_user_id`);

--
-- Indexes for table `universities`
--
ALTER TABLE `universities`
  ADD PRIMARY KEY (`university_id`),
  ADD UNIQUE KEY `uq_university_country_name` (`country_id`,`university_name`),
  ADD KEY `idx_universities_country` (`country_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`user_id`),
  ADD UNIQUE KEY `email` (`email`),
  ADD KEY `fk_users_role` (`role_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `bookings`
--
ALTER TABLE `bookings`
  MODIFY `booking_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `countries`
--
ALTER TABLE `countries`
  MODIFY `country_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `faqs`
--
ALTER TABLE `faqs`
  MODIFY `faq_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `group_sessions`
--
ALTER TABLE `group_sessions`
  MODIFY `session_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `mentor_plans`
--
ALTER TABLE `mentor_plans`
  MODIFY `plan_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `mentor_profiles`
--
ALTER TABLE `mentor_profiles`
  MODIFY `mentor_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `programs`
--
ALTER TABLE `programs`
  MODIFY `program_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=25;

--
-- AUTO_INCREMENT for table `reviews`
--
ALTER TABLE `reviews`
  MODIFY `review_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `roles`
--
ALTER TABLE `roles`
  MODIFY `role_id` tinyint(3) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `scholarships`
--
ALTER TABLE `scholarships`
  MODIFY `scholarship_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `services`
--
ALTER TABLE `services`
  MODIFY `service_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `session_categories`
--
ALTER TABLE `session_categories`
  MODIFY `category_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `session_registrations`
--
ALTER TABLE `session_registrations`
  MODIFY `registration_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `universities`
--
ALTER TABLE `universities`
  MODIFY `university_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2354;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `user_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `bookings`
--
ALTER TABLE `bookings`
  ADD CONSTRAINT `fk_booking_mentor` FOREIGN KEY (`mentor_id`) REFERENCES `mentor_profiles` (`mentor_id`),
  ADD CONSTRAINT `fk_booking_plan` FOREIGN KEY (`plan_id`) REFERENCES `mentor_plans` (`plan_id`),
  ADD CONSTRAINT `fk_booking_student` FOREIGN KEY (`student_user_id`) REFERENCES `users` (`user_id`);

--
-- Constraints for table `group_sessions`
--
ALTER TABLE `group_sessions`
  ADD CONSTRAINT `fk_session_category` FOREIGN KEY (`category_id`) REFERENCES `session_categories` (`category_id`),
  ADD CONSTRAINT `fk_session_mentor` FOREIGN KEY (`mentor_id`) REFERENCES `mentor_profiles` (`mentor_id`);

--
-- Constraints for table `mentor_countries`
--
ALTER TABLE `mentor_countries`
  ADD CONSTRAINT `fk_mc_country` FOREIGN KEY (`country_id`) REFERENCES `countries` (`country_id`),
  ADD CONSTRAINT `fk_mc_mentor` FOREIGN KEY (`mentor_id`) REFERENCES `mentor_profiles` (`mentor_id`) ON DELETE CASCADE;

--
-- Constraints for table `mentor_plans`
--
ALTER TABLE `mentor_plans`
  ADD CONSTRAINT `fk_plans_mentor` FOREIGN KEY (`mentor_id`) REFERENCES `mentor_profiles` (`mentor_id`) ON DELETE CASCADE;

--
-- Constraints for table `mentor_profiles`
--
ALTER TABLE `mentor_profiles`
  ADD CONSTRAINT `fk_mentor_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`);

--
-- Constraints for table `mentor_programs`
--
ALTER TABLE `mentor_programs`
  ADD CONSTRAINT `fk_mp_mentor` FOREIGN KEY (`mentor_id`) REFERENCES `mentor_profiles` (`mentor_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_mp_program` FOREIGN KEY (`program_id`) REFERENCES `programs` (`program_id`);

--
-- Constraints for table `mentor_scholarships`
--
ALTER TABLE `mentor_scholarships`
  ADD CONSTRAINT `fk_ms_mentor` FOREIGN KEY (`mentor_id`) REFERENCES `mentor_profiles` (`mentor_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_ms_scholarship` FOREIGN KEY (`scholarship_id`) REFERENCES `scholarships` (`scholarship_id`);

--
-- Constraints for table `mentor_services`
--
ALTER TABLE `mentor_services`
  ADD CONSTRAINT `fk_mserv_mentor` FOREIGN KEY (`mentor_id`) REFERENCES `mentor_profiles` (`mentor_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_mserv_service` FOREIGN KEY (`service_id`) REFERENCES `services` (`service_id`);

--
-- Constraints for table `mentor_universities`
--
ALTER TABLE `mentor_universities`
  ADD CONSTRAINT `fk_mu_mentor` FOREIGN KEY (`mentor_id`) REFERENCES `mentor_profiles` (`mentor_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_mu_university` FOREIGN KEY (`university_id`) REFERENCES `universities` (`university_id`);

--
-- Constraints for table `reviews`
--
ALTER TABLE `reviews`
  ADD CONSTRAINT `fk_review_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`booking_id`),
  ADD CONSTRAINT `fk_review_mentor` FOREIGN KEY (`mentor_id`) REFERENCES `mentor_profiles` (`mentor_id`),
  ADD CONSTRAINT `fk_review_student` FOREIGN KEY (`student_user_id`) REFERENCES `users` (`user_id`);

--
-- Constraints for table `scholarships`
--
ALTER TABLE `scholarships`
  ADD CONSTRAINT `fk_scholarships_country` FOREIGN KEY (`country_id`) REFERENCES `countries` (`country_id`);

--
-- Constraints for table `session_registrations`
--
ALTER TABLE `session_registrations`
  ADD CONSTRAINT `fk_registration_session` FOREIGN KEY (`session_id`) REFERENCES `group_sessions` (`session_id`),
  ADD CONSTRAINT `fk_registration_student` FOREIGN KEY (`student_user_id`) REFERENCES `users` (`user_id`);

--
-- Constraints for table `universities`
--
ALTER TABLE `universities`
  ADD CONSTRAINT `fk_universities_country` FOREIGN KEY (`country_id`) REFERENCES `countries` (`country_id`);

--
-- Constraints for table `users`
--
ALTER TABLE `users`
  ADD CONSTRAINT `fk_users_role` FOREIGN KEY (`role_id`) REFERENCES `roles` (`role_id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

DELIMITER //

CREATE PROCEDURE sp_get_programs()
BEGIN
    SELECT
        program_id,
        program_name,
        degree_level
    FROM programs
    WHERE is_active = 1
    ORDER BY program_name;
END //

CREATE PROCEDURE sp_get_services()
BEGIN
    SELECT
        service_id,
        service_name
    FROM services
    WHERE is_active = 1
    ORDER BY service_name;
END //

CREATE PROCEDURE sp_get_scholarships(IN p_country_id INT)
BEGIN
    SELECT
        scholarship_id,
        country_id,
        scholarship_name,
        provider_name
    FROM scholarships
    WHERE is_active = 1
      AND (p_country_id IS NULL OR country_id = p_country_id)
    ORDER BY scholarship_name;
END //

DELIMITER ;
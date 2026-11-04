USE abroadmates_db;
DROP PROCEDURE IF EXISTS sp_get_role_by_name;
DROP PROCEDURE IF EXISTS sp_get_user_by_email;
DELIMITER $$
CREATE PROCEDURE sp_get_role_by_name(IN p_role_name VARCHAR(30))
BEGIN
  SELECT role_id,role_name FROM roles WHERE role_name=p_role_name LIMIT 1;
END$$
CREATE PROCEDURE sp_get_user_by_email(IN p_email VARCHAR(190))
BEGIN
  SELECT u.user_id,u.full_name,u.email,u.password_hash,u.is_active,r.role_name
  FROM users u JOIN roles r ON r.role_id=u.role_id
  WHERE u.email=p_email LIMIT 1;
END$$
DELIMITER ;

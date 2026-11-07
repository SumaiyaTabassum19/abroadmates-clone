const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const pool = require('../config/database');

async function register(req, res) {
  const { fullName, email, password, role } = req.body || {};
  if (!fullName || !email || !password || !role) {
    return res.status(400).json({ message: 'Full name, email, password and role are required.' });
  }
  if (!['Student', 'Mentor'].includes(role)) {
    return res.status(400).json({ message: 'Role must be Student or Mentor.' });
  }
  if (String(fullName).trim().length < 2 || String(fullName).trim().length > 120) {
    return res.status(400).json({ message: 'Full name must be between 2 and 120 characters.' });
  }
  const normalizedEmail = String(email).trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
    return res.status(400).json({ message: 'Please enter a valid email address.' });
  }
  if (String(password).length < 8) {
    return res.status(400).json({ message: 'Password must be at least 8 characters.' });
  }

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    const [roleSets] = await conn.query('CALL sp_get_role_by_name(?)', [role]);
    const roleRow = roleSets[0]?.[0];
    if (!roleRow) {
      await conn.rollback();
      return res.status(400).json({ message: 'Role is not configured in the database. Check the roles table.' });
    }

    const passwordHash = await bcrypt.hash(String(password), 12);
    const [userResult] = await conn.execute(
      'INSERT INTO users (role_id, full_name, email, password_hash) VALUES (?, ?, ?, ?)',
      [roleRow.role_id, String(fullName).trim(), normalizedEmail, passwordHash]
    );

    // Every Mentor account gets a published master mentor profile automatically.
    if (role === 'Mentor') {
      await conn.execute(
        `INSERT INTO mentor_profiles (user_id, is_published)
     VALUES (?, 1)`,
        [userResult.insertId]
      );
    }

    await conn.commit();
    return res.status(201).json({
      message: role === 'Mentor'
        ? 'Mentor account and mentor profile created successfully. Please log in.'
        : 'Student account created successfully. Please log in.',
      user: {
        userId: userResult.insertId,
        fullName: String(fullName).trim(),
        email: normalizedEmail,
        role
      }
    });
  } catch (error) {
    await conn.rollback();
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ message: 'This email address is already registered.' });
    }
    throw error;
  } finally {
    conn.release();
  }
}

async function login(req, res) {
  const { email, password } = req.body || {};
  if (!email || !password) {
    return res.status(400).json({ message: 'Email and password are required.' });
  }

  const [sets] = await pool.query('CALL sp_get_user_by_email(?)', [
    String(email).trim().toLowerCase()
  ]);
  const user = sets[0]?.[0];

  if (!user || !user.is_active || !(await bcrypt.compare(String(password), user.password_hash))) {
    return res.status(401).json({ message: 'Invalid email or password.' });
  }

  const token = jwt.sign(
    { userId: user.user_id, role: user.role_name, email: user.email },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '1d' }
  );

  return res.json({
    message: 'Login successful.',
    token,
    user: {
      userId: user.user_id,
      fullName: user.full_name,
      email: user.email,
      role: user.role_name
    }
  });
}

async function getMe(req, res) {
  const [sets] = await pool.query('CALL sp_get_auth_user_by_id(?)', [req.user.userId]);
  const user = sets[0]?.[0];
  if (!user || !user.is_active) {
    return res.status(404).json({ message: 'Account not found or inactive.' });
  }

  let mentorProfile = null;
  if (user.role_name === 'Mentor') {
    const [profileSets] = await pool.query(
      'CALL sp_get_mentor_profile_by_user_id(?)',
      [req.user.userId]
    );
    mentorProfile = profileSets[0]?.[0] || null;
  }

  return res.json({
    user: {
      userId: user.user_id,
      fullName: user.full_name,
      email: user.email,
      role: user.role_name
    },
    mentorProfile
  });
}

module.exports = { register, login, getMe };

const pool = require('../config/database');

const getCountries = async (req, res, next) => {
  try {
    const [sets] = await pool.query('CALL sp_get_countries()');
    res.json({ success: true, data: sets[0] || [] });
  } catch (error) { next(error); }
};

const getUniversitiesByCountry = async (req, res, next) => {
  try {
    const countryId = Number(req.params.countryId);
    if (!Number.isInteger(countryId) || countryId < 1) {
      return res.status(400).json({ success: false, message: 'Invalid country ID.' });
    }
    const [sets] = await pool.query('CALL sp_get_universities_by_country(?)', [countryId]);
    res.json({ success: true, data: sets[0] || [] });
  } catch (error) { next(error); }
};

const getMentors = async (req, res, next) => {
  try {
    const toNullableNumber = (v) => v === undefined || v === '' ? null : Number(v);
    const countryId = toNullableNumber(req.query.countryId);
    const programId = toNullableNumber(req.query.programId);
    const serviceId = toNullableNumber(req.query.serviceId);
    const scholarshipId = toNullableNumber(req.query.scholarshipId);
    for (const id of [countryId, programId, serviceId, scholarshipId]) {
      if (id !== null && (!Number.isInteger(id) || id < 1)) {
        return res.status(400).json({ success: false, message: 'Filter IDs must be positive integers.' });
      }
    }
    const search = typeof req.query.search === 'string' ? req.query.search.trim().slice(0, 150) : null;
    const allowedSorts = ['top_rated', 'most_sessions', 'price_low'];
    const sort = allowedSorts.includes(req.query.sort) ? req.query.sort : null;
    const [sets] = await pool.query(
      'CALL sp_get_mentor_list(?, ?, ?, ?, ?, ?)',
      [countryId, programId, serviceId, scholarshipId, search, sort]
    );
    res.json({ success: true, data: sets[0] || [] });
  } catch (error) { next(error); }
};

const getMentorById = async (req, res, next) => {
  try {
    const mentorId = Number(req.params.mentorId);

    if (!Number.isInteger(mentorId) || mentorId < 1) {
      return res.status(400).json({
        success: false,
        message: 'Invalid mentor ID.'
      });
    }

    const [sets] = await pool.query(
      'CALL sp_get_mentor_by_id(?)',
      [mentorId]
    );

    const profile = sets[0]?.[0] || null;

    if (!profile) {
      return res.status(404).json({
        success: false,
        message: 'Mentor not found.'
      });
    }

    res.json({
      success: true,
      data: {
        profile,
        plans: sets[1] || [],
        countries: sets[2] || [],
        universities: sets[3] || [],
        programs: sets[4] || [],
        services: sets[5] || [],
        scholarships: sets[6] || []
      }
    });

  } catch (error) {
    next(error);
  }
};

module.exports = { getCountries, getUniversitiesByCountry, getMentors, getMentorById };

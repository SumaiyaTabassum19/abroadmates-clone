const pool = require('../config/database');

const UNIVERSITY_API = 'http://universities.hipolabs.com/search';

const getUniversitiesFromExternalApi = async (req, res, next) => {
  try {
    const countryId = Number(req.params.countryId);
    if (!Number.isInteger(countryId) || countryId < 1) {
      return res.status(400).json({ success: false, message: 'Invalid country ID.' });
    }

    const [countrySets] = await pool.query('CALL sp_get_countries()');
    const country = (countrySets[0] || []).find(item => item.country_id === countryId);
    if (!country) {
      return res.status(404).json({ success: false, message: 'Country not found.' });
    }

    const url = new URL(UNIVERSITY_API);
    url.searchParams.set('country', country.country_name);

    const response = await fetch(url, {
      headers: { Accept: 'application/json' },
      signal: AbortSignal.timeout(12000)
    });

    if (!response.ok) {
      return res.status(502).json({
        success: false,
        message: 'The university data provider is temporarily unavailable.'
      });
    }

    const universities = await response.json();
    if (!Array.isArray(universities)) {
      return res.status(502).json({ success: false, message: 'Unexpected university API response.' });
    }

    const data = universities
      .map(item => ({
        university_name: item.name || '',
        website_url: Array.isArray(item.web_pages) ? (item.web_pages[0] || null) : null,
        external_api_id: item.domains?.[0] || item.name || null,
        country: item.country || country.country_name,
        alpha_two_code: item.alpha_two_code || null
      }))
      .filter(item => item.university_name)
      .sort((a, b) => a.university_name.localeCompare(b.university_name));

    res.json({
      success: true,
      source: 'Hipolabs Universities API',
      country: country.country_name,
      count: data.length,
      data
    });
  } catch (error) {
    if (error.name === 'TimeoutError' || error.name === 'AbortError') {
      return res.status(504).json({ success: false, message: 'University API request timed out. Please try again.' });
    }
    next(error);
  }
};

const syncUniversitiesToDatabase = async (req, res, next) => {
  let connection;
  try {
    const countryId = Number(req.params.countryId);
    if (!Number.isInteger(countryId) || countryId < 1) {
      return res.status(400).json({ success: false, message: 'Invalid country ID.' });
    }

    const [countrySets] = await pool.query('CALL sp_get_countries()');
    const country = (countrySets[0] || []).find(item => item.country_id === countryId);
    if (!country) return res.status(404).json({ success: false, message: 'Country not found.' });

    const url = new URL(UNIVERSITY_API);
    url.searchParams.set('country', country.country_name);
    const response = await fetch(url, { headers: { Accept: 'application/json' }, signal: AbortSignal.timeout(12000) });
    if (!response.ok) return res.status(502).json({ success: false, message: 'University data provider is unavailable.' });

    const items = await response.json();
    if (!Array.isArray(items)) return res.status(502).json({ success: false, message: 'Unexpected university API response.' });

    connection = await pool.getConnection();
    await connection.beginTransaction();
    let saved = 0;

    for (const item of items) {
      if (!item.name) continue;
      const website = Array.isArray(item.web_pages) ? (item.web_pages[0] || null) : null;
      const externalId = item.domains?.[0] || item.name;
      await connection.execute(
        `INSERT INTO universities (country_id, university_name, external_api_id, website_url)
         VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
           external_api_id = VALUES(external_api_id),
           website_url = VALUES(website_url)`,
        [countryId, item.name.slice(0, 180), String(externalId).slice(0, 255), website]
      );
      saved++;
    }

    await connection.commit();
    res.json({ success: true, message: 'University list synced to the database.', country: country.country_name, saved });
  } catch (error) {
    if (connection) await connection.rollback();
    if (error.name === 'TimeoutError' || error.name === 'AbortError') {
      return res.status(504).json({ success: false, message: 'University API request timed out.' });
    }
    next(error);
  } finally {
    if (connection) connection.release();
  }
};

module.exports = { getUniversitiesFromExternalApi, syncUniversitiesToDatabase };

const express = require('express');
const router = express.Router();
const {
  getUniversitiesFromExternalApi,
  syncUniversitiesToDatabase
} = require('../controllers/universityController');

// Fetch live results without saving them.
router.get('/countries/:countryId/universities/live', getUniversitiesFromExternalApi);

// Admin-only protection will be added when the admin role is introduced.
// Keep this route local during development; do not expose it publicly in production.
router.post('/countries/:countryId/universities/sync', syncUniversitiesToDatabase);

module.exports = router;

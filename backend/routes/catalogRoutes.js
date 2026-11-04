
const express = require('express');
const router = express.Router();

const catalogController = require('../controllers/catalogController');

router.get('/countries', catalogController.getCountries);

router.get(
  '/countries/:countryId/universities',
  catalogController.getUniversitiesByCountry
);

router.get('/mentors', catalogController.getMentors);

router.get('/mentors/:mentorId', catalogController.getMentorById);

module.exports = router;

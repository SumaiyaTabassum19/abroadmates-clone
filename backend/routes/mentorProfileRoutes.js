const express = require('express');
const router = express.Router();

const {
    getMyProfile,
    updateMyProfile
} = require('../controllers/mentorProfileController');

const {
    authenticateToken,
    authorizeRoles
} = require('../middleware/authMiddleware');

const asyncHandler = require('../utils/asyncHandler');

router.use(authenticateToken, authorizeRoles('Mentor'));

router.get(
    '/me',
    asyncHandler(getMyProfile)
);

router.put(
    '/me',
    asyncHandler(updateMyProfile)
);

module.exports = router;
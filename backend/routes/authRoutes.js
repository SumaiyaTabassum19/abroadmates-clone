const router = require('express').Router();
const { register, login, getMe } = require('../controllers/authController');
const { authenticateToken } = require('../middleware/authMiddleware');
const asyncHandler = require('../utils/asyncHandler');

router.post('/register', asyncHandler(register));
router.post('/login', asyncHandler(login));
router.get('/me', authenticateToken, asyncHandler(getMe));

module.exports = router;

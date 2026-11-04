const express = require("express");
const router = express.Router();

const {
    getMyBookings
} = require("../controllers/studentBookingController");

const {
    authenticateToken,
    authorizeRoles
} = require("../middleware/authMiddleware");

const asyncHandler = require("../utils/asyncHandler");

router.use(authenticateToken, authorizeRoles("Student"));

router.get("/my", asyncHandler(getMyBookings));

module.exports = router;
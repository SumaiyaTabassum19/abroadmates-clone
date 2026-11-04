const express = require("express");
const router = express.Router();

const {
    createBooking,
    getMyBookings
} = require("../controllers/bookingController");

const {
    authenticateToken,
    authorizeRoles
} = require("../middleware/authMiddleware");

router.use(authenticateToken);

router.post(
    "/",
    authorizeRoles("Student"),
    createBooking
);

router.get(
    "/my",
    authorizeRoles("Student"),
    getMyBookings
);

module.exports = router;
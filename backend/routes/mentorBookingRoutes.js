
const express = require("express");
const router = express.Router();

const {
    getMyBookings,
    confirmBooking,
    completeBooking,
    cancelBooking,
    getMentorAnalytics
} = require("../controllers/mentorBookingController");

const {
    authenticateToken,
    authorizeRoles
} = require("../middleware/authMiddleware");


// All routes require Mentor authentication.
router.use(authenticateToken);
router.use(authorizeRoles("Mentor"));

// Get mentor bookings.
router.get("/my", getMyBookings);

// Confirm booking.
router.patch("/:bookingId/confirm", confirmBooking);

// Complete booking.
router.patch("/:bookingId/complete", completeBooking);

// Cancel booking.
router.patch("/:bookingId/cancel", cancelBooking);

// Get mentor dashboard analytics.
router.get("/analytics", getMentorAnalytics);

module.exports = router;

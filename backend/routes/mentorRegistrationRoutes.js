const express = require("express");
const router = express.Router();

const {
    getSessionRegistrations,
    markAttendance
} = require("../controllers/mentorRegistrationController");

const {
    authenticateToken,
    authorizeRoles
} = require("../middleware/authMiddleware");

const asyncHandler = require("../utils/asyncHandler");

router.use(authenticateToken, authorizeRoles("Mentor"));

router.get(
    "/sessions/:sessionId/registrations",
    asyncHandler(getSessionRegistrations)
);

router.patch(
    "/registrations/:registrationId/attended",
    asyncHandler(markAttendance)
);

module.exports = router;
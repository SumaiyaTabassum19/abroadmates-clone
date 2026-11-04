const express = require("express");
const router = express.Router();

const {
    registerForSession,
    cancelRegistration,
    getMyRegistrations
} = require("../controllers/studentGroupRegistrationController");

const {
    authenticateToken,
    authorizeRoles
} = require("../middleware/authMiddleware");

const asyncHandler = require("../utils/asyncHandler");

router.use(authenticateToken, authorizeRoles("Student"));

router.get("/my", asyncHandler(getMyRegistrations));

router.post(
    "/:sessionId/register",
    asyncHandler(registerForSession)
);

router.patch(
    "/registrations/:registrationId/cancel",
    asyncHandler(cancelRegistration)
);

module.exports = router;
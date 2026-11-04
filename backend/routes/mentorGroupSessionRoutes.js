const express = require("express");
const router = express.Router();

const {
    getMySessions,
    createSession,
    updateSession,
    cancelSession
} = require("../controllers/mentorGroupSessionController");

const {
    authenticateToken,
    authorizeRoles
} = require("../middleware/authMiddleware");

const asyncHandler = require("../utils/asyncHandler");

router.use(authenticateToken, authorizeRoles("Mentor"));

router.get(
    "/",
    asyncHandler(getMySessions)
);

router.post(
    "/",
    asyncHandler(createSession)
);

router.put(
    "/:sessionId",
    asyncHandler(updateSession)
);

router.patch(
    "/:sessionId/cancel",
    asyncHandler(cancelSession)
);

module.exports = router;
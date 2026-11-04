const express = require("express");
const router = express.Router();

const {
    getCategories,
    getSessions,
    registerForSession
} = require("../controllers/groupSessionController");

const {
    authenticateToken,
    authorizeRoles
} = require("../middleware/authMiddleware");

const asyncHandler = require("../utils/asyncHandler");

// Public browsing
router.get("/categories", asyncHandler(getCategories));
router.get("/", asyncHandler(getSessions));

// Only logged-in Students can register
router.post(
    "/:sessionId/register",
    authenticateToken,
    authorizeRoles("Student"),
    asyncHandler(registerForSession)
);

module.exports = router;
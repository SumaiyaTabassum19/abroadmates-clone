const express = require("express");
const router = express.Router();

const {
    createReview
} = require("../controllers/studentReviewController");

const {
    authenticateToken,
    authorizeRoles
} = require("../middleware/authMiddleware");

const asyncHandler = require("../utils/asyncHandler");

router.use(authenticateToken, authorizeRoles("Student"));

router.post("/", asyncHandler(createReview));

module.exports = router;
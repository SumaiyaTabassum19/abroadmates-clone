const express = require("express");
const router = express.Router();

const {
    getPublicMentorReviews
} = require("../controllers/publicReviewController");

const asyncHandler = require("../utils/asyncHandler");

router.get("/:mentorId/reviews", asyncHandler(getPublicMentorReviews));

module.exports = router;
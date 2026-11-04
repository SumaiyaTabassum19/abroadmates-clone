const express = require("express");
const router = express.Router();

const {
    getPublicMentorDetails
} = require("../controllers/publicMentorController");

router.get("/:mentorId", getPublicMentorDetails);

module.exports = router;
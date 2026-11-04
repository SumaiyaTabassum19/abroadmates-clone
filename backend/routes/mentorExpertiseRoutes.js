const express = require("express");
const router = express.Router();

const {
    getMyExpertise,
    saveMyExpertise
} = require("../controllers/mentorExpertiseController");

const {
    authenticateToken,
    authorizeRoles
} = require("../middleware/authMiddleware");

router.use(authenticateToken, authorizeRoles("Mentor"));

router.get("/me", getMyExpertise);
router.put("/me", saveMyExpertise);

module.exports = router;
const express = require("express");
const router = express.Router();

const { getEarningsReport } =
    require("../controllers/mentorReportController");

const {
    authenticateToken,
    authorizeRoles
} = require("../middleware/authMiddleware");

router.use(authenticateToken);
router.use(authorizeRoles("Mentor"));

router.get("/earnings", getEarningsReport);

module.exports = router;
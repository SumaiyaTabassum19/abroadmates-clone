const express = require("express");
const router = express.Router();

const controller = require("../controllers/catalogFilterController");

router.get("/programs", controller.getPrograms);
router.get("/services", controller.getServices);
router.get("/scholarships", controller.getScholarships);

module.exports = router;
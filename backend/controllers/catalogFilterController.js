const pool = require("../config/database");

const getPrograms = async (req, res) => {
    try {
        const [results] = await pool.query(
            "CALL sp_get_programs()"
        );

        res.json({
            success: true,
            data: results[0]
        });
    } catch (error) {
        console.error("Get programs error:", error);
        res.status(500).json({
            success: false,
            message: "Could not load programs"
        });
    }
};

const getServices = async (req, res) => {
    try {
        const [results] = await pool.query(
            "CALL sp_get_services()"
        );

        res.json({
            success: true,
            data: results[0]
        });
    } catch (error) {
        console.error("Get services error:", error);
        res.status(500).json({
            success: false,
            message: "Could not load services"
        });
    }
};

const getScholarships = async (req, res) => {
    try {
        const countryId = req.query.countryId
            ? Number(req.query.countryId)
            : null;

        if (
            countryId !== null &&
            (!Number.isInteger(countryId) || countryId <= 0)
        ) {
            return res.status(400).json({
                success: false,
                message: "Invalid countryId"
            });
        }

        const [results] = await pool.query(
            "CALL sp_get_scholarships(?)",
            [countryId]
        );

        res.json({
            success: true,
            data: results[0]
        });
    } catch (error) {
        console.error("Get scholarships error:", error);
        res.status(500).json({
            success: false,
            message: "Could not load scholarships"
        });
    }
};

module.exports = {
    getPrograms,
    getServices,
    getScholarships
};
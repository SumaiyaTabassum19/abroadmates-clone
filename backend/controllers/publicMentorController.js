const pool = require("../config/database");

const getPublicMentorDetails = async (req, res) => {
    try {
        const mentorId = Number(req.params.mentorId);

        if (!Number.isInteger(mentorId) || mentorId <= 0) {
            return res.status(400).json({
                success: false,
                message: "Invalid mentor ID"
            });
        }

        const [results] = await pool.query(
            "CALL sp_get_public_mentor_details(?)",
            [mentorId]
        );

        const profile = results[0]?.[0];

        if (!profile) {
            return res.status(404).json({
                success: false,
                message: "Mentor not found or profile is unpublished"
            });
        }

        res.json({
            success: true,
            data: {
                profile,
                plans: results[1] || [],
                countries: results[2] || [],
                universities: results[3] || [],
                programs: results[4] || [],
                services: results[5] || [],
                scholarships: results[6] || []
            }
        });

    } catch (error) {
        console.error("Public mentor details error:", error);

        res.status(500).json({
            success: false,
            message: "Could not load mentor details"
        });
    }
};

module.exports = { getPublicMentorDetails };
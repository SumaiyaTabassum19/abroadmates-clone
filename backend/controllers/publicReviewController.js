const pool = require("../config/database");

const getPublicMentorReviews = async (req, res) => {
    const mentorId = Number(req.params.mentorId);

    if (!Number.isInteger(mentorId) || mentorId <= 0) {
        return res.status(400).json({
            success: false,
            message: "Invalid mentor ID."
        });
    }

    const [results] = await pool.query(
        "CALL sp_get_public_mentor_reviews(?)",
        [mentorId]
    );

    const summary = results[0]?.[0];

    if (!summary) {
        return res.status(404).json({
            success: false,
            message: "Published mentor not found."
        });
    }

    res.json({
        success: true,
        data: {
            summary,
            reviews: results[1] || []
        }
    });
};

module.exports = { getPublicMentorReviews };
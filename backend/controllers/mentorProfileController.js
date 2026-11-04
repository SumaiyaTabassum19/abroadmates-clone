const db = require("../config/database");

// Get logged-in mentor's profile
const getMyProfile = async (req, res) => {
    const userId = req.user.userId;

    const [results] = await db.query(
        "CALL sp_get_my_mentor_profile(?)",
        [userId]
    );

    res.json({
        success: true,
        profile: results[0]?.[0] || null,
        plans: results[1] || [],
        countries: results[2] || [],
        universities: results[3] || []
    });
};

// Update logged-in mentor's profile
const updateMyProfile = async (req, res) => {
    const userId = req.user.userId;

    const {
        headline,
        bio,
        years_experience
    } = req.body;

    // Validate headline
    if (typeof headline !== "string" || headline.length > 180) {
        return res.status(400).json({
            success: false,
            message: "Headline must be 180 characters or fewer."
        });
    }

    // Validate bio
    if (typeof bio !== "string" || bio.length > 5000) {
        return res.status(400).json({
            success: false,
            message: "About Me must be 5000 characters or fewer."
        });
    }

    // Validate experience
    const experience = Number(years_experience);

    if (
        !Number.isInteger(experience) ||
        experience < 0 ||
        experience > 60
    ) {
        return res.status(400).json({
            success: false,
            message: "Years of experience must be between 0 and 60."
        });
    }

    const [results] = await db.query(
        "CALL sp_update_my_mentor_profile(?, ?, ?, ?)",
        [
            userId,
            headline.trim(),
            bio.trim(),
            experience
        ]
    );

    res.json({
        success: true,
        message:
            results[0]?.[0]?.message ||
            "Mentor profile updated successfully."
    });
};

module.exports = {
    getMyProfile,
    updateMyProfile
};

const db = require("../config/database");

// Get logged-in mentor's expertise and consultation plans
const getMyExpertise = async (req, res, next) => {
    try {
        const userId = req.user.userId;

        const [results] = await db.query(
            "CALL sp_get_my_mentor_expertise(?)",
            [userId]
        );

        res.json({
            success: true,
            countries: results[0] || [],
            universities: results[1] || [],
            plans: results[2] || []
        });

    } catch (error) {
        next(error);
    }
};

// Save mentor's countries, universities and consultation plans
const saveMyExpertise = async (req, res, next) => {
    try {
        const userId = req.user.userId;

        const {
            countryIds = [],
            universityIds = [],
            plans = []
        } = req.body;

        // Validate request arrays
        if (
            !Array.isArray(countryIds) ||
            !Array.isArray(universityIds) ||
            !Array.isArray(plans)
        ) {
            return res.status(400).json({
                success: false,
                message: "Countries, universities and plans must be arrays."
            });
        }

        // Convert IDs to positive integers and remove duplicates
        const cleanIds = (ids) => {
            const converted = ids.map(Number);

            if (
                converted.some(
                    id => !Number.isInteger(id) || id <= 0
                )
            ) {
                return null;
            }

            return [...new Set(converted)];
        };

        const cleanCountryIds = cleanIds(countryIds);
        const cleanUniversityIds = cleanIds(universityIds);

        if (!cleanCountryIds || !cleanUniversityIds) {
            return res.status(400).json({
                success: false,
                message: "Country and university IDs must be valid positive integers."
            });
        }

        // Validate and normalize consultation plans
        const cleanPlans = [];

        for (const plan of plans) {
            const duration = Number(
                plan.duration_minutes ?? plan.durationMinutes
            );

            const price = Number(plan.price);
            const currency = String(plan.currency || "BDT").toUpperCase();

            if (
                ![20, 40].includes(duration) ||
                !Number.isFinite(price) ||
                price < 0 ||
                !/^[A-Z]{3}$/.test(currency)
            ) {
                return res.status(400).json({
                    success: false,
                    message: "Each plan must have a valid 20 or 40 minute duration, non-negative price and three-letter currency."
                });
            }

            if (cleanPlans.some(p => p.duration_minutes === duration)) {
                return res.status(400).json({
                    success: false,
                    message: "You cannot add the same consultation duration more than once."
                });
            }

            cleanPlans.push({
                duration_minutes: duration,
                price,
                currency
            });
        }

        // Save everything through the stored procedure
        const [results] = await db.query(
            "CALL sp_save_my_mentor_expertise(?, ?, ?, ?)",
            [
                userId,
                JSON.stringify(cleanCountryIds),
                JSON.stringify(cleanUniversityIds),
                JSON.stringify(cleanPlans)
            ]
        );

        res.json({
            success: true,
            message:
                results[0]?.[0]?.message ||
                "Mentor expertise and consultation plans saved successfully."
        });

    } catch (error) {
        next(error);
    }
};

module.exports = {
    getMyExpertise,
    saveMyExpertise
};

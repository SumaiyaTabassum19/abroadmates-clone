const db = require("../config/database");

exports.getEarningsReport = async (req, res) => {
    try {
        const { startDate = null, endDate = null, status = "all" } = req.query;

        // Validate date format before sending values to MySQL.
        const isValidDate = value =>
            value === null ||
            /^\d{4}-\d{2}-\d{2}$/.test(value) &&
            !Number.isNaN(Date.parse(`${value}T00:00:00`));

        if (!isValidDate(startDate) || !isValidDate(endDate)) {
            return res.status(400).json({
                success: false,
                message: "Dates must use YYYY-MM-DD format."
            });
        }

        if (startDate && endDate && startDate > endDate) {
            return res.status(400).json({
                success: false,
                message: "Start date cannot be after end date."
            });
        }

        const allowedStatuses = [
            "all",
            "pending",
            "confirmed",
            "completed",
            "cancelled"
        ];

        const normalizedStatus = String(status).toLowerCase();

        if (!allowedStatuses.includes(normalizedStatus)) {
            return res.status(400).json({
                success: false,
                message: "Invalid booking status."
            });
        }

        const [results] = await db.query(
            "CALL sp_get_mentor_earnings_report(?, ?, ?, ?)",
            [
                req.user.userId,
                startDate || null,
                endDate || null,
                normalizedStatus
            ]
        );

        res.status(200).json({
            success: true,
            data: {
                summary: results[0]?.[0] || {},
                monthlyEarnings: results[1] || [],
                bookings: results[2] || []
            }
        });

    } catch (error) {
        console.error("Mentor earnings report error:", error);

        const isMissingProfile =
            error.sqlMessage === "Mentor profile not found";

        res.status(isMissingProfile ? 404 : 500).json({
            success: false,
            message: isMissingProfile
                ? "Mentor profile not found."
                : "Could not load the earnings report."
        });
    }
};
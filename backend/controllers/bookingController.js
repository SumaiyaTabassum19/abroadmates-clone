const pool = require("../config/database");

// Create a new booking
const createBooking = async (req, res) => {
    const { mentorId, planId, scheduledAt, studentNote } = req.body;
    const studentUserId = req.user.userId;

    if (!mentorId || !planId || !scheduledAt) {
        return res.status(400).json({
            success: false,
            message: "Mentor, plan, and scheduled date are required."
        });
    }

    try {
        const formattedDate = scheduledAt.replace("T", " ");

        const [resultSets] = await pool.query(
            "CALL sp_create_booking(?,?,?,?,?)",
            [
                studentUserId,
                mentorId,
                planId,
                formattedDate,
                studentNote || null
            ]
        );

        const booking = resultSets[0]?.[0] || null;

        return res.status(201).json({
            success: true,
            message: "Booking created successfully.",
            data: booking
        });

    } catch (error) {
        console.error("Create booking error:", error);

        return res.status(400).json({
            success: false,
            message: error.sqlMessage || error.message
        });
    }
};


// Get bookings for the logged-in student
const getMyBookings = async (req, res) => {
    try {
        const studentUserId = req.user.userId;

        const [resultSets] = await pool.query(
            "CALL sp_get_my_bookings(?)",
            [studentUserId]
        );

        const bookings = resultSets[0] || [];

        return res.json({
            success: true,
            data: bookings
        });

    } catch (error) {
        console.error("Get my bookings error:", error);

        return res.status(500).json({
            success: false,
            message: "Unable to retrieve your bookings."
        });
    }
};


module.exports = {
    createBooking,
    getMyBookings
};
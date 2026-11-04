const pool = require("../config/database");

const getMyBookings = async (req, res) => {
    const studentUserId = req.user.userId;

    const [results] = await pool.query(
        "CALL sp_get_my_bookings_detailed(?)",
        [studentUserId]
    );

    const bookings = results[0] || [];

    res.json({
        success: true,
        count: bookings.length,
        data: bookings
    });
};

module.exports = { getMyBookings };
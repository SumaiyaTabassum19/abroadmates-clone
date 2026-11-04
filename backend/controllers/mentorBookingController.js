
const db = require("../config/database");

// Get bookings for the logged-in mentor.
exports.getMyBookings = async (req, res) => {
    try {
        const mentorUserId = req.user.userId;

        const [results] = await db.query(
            "CALL sp_get_my_mentor_bookings(?)",
            [mentorUserId]
        );

        res.status(200).json({
            success: true,
            data: results[0] || []
        });

    } catch (error) {
        console.error("Get mentor bookings error:", error);

        res.status(500).json({
            success: false,
            message: "Could not load mentor bookings."
        });
    }
};


// Confirm a booking.
exports.confirmBooking = async (req, res) => {
    try {
        const mentorUserId = req.user.userId;
        const { bookingId } = req.params;
        const { meetingLink } = req.body;

        const [results] = await db.query(
            "CALL sp_confirm_mentor_booking(?, ?, ?)",
            [
                mentorUserId,
                bookingId,
                meetingLink || null
            ]
        );

        res.status(200).json({
            success: true,
            message: "Booking confirmed successfully."
        });

    } catch (error) {
        console.error("Confirm booking error:", error);

        res.status(400).json({
            success: false,
            message: error.sqlMessage || "Could not confirm booking."
        });
    }
};


// Complete a booking.
exports.completeBooking = async (req, res) => {
    try {
        const mentorUserId = req.user.userId;
        const { bookingId } = req.params;

        await db.query(
            "CALL sp_complete_mentor_booking(?, ?)",
            [mentorUserId, bookingId]
        );

        res.status(200).json({
            success: true,
            message: "Booking completed successfully."
        });

    } catch (error) {
        console.error("Complete booking error:", error);

        res.status(400).json({
            success: false,
            message: error.sqlMessage || "Could not complete booking."
        });
    }
};


// Cancel a booking.
exports.cancelBooking = async (req, res) => {
    try {
        const mentorUserId = req.user.userId;
        const { bookingId } = req.params;

        await db.query(
            "CALL sp_cancel_mentor_booking(?, ?)",
            [mentorUserId, bookingId]
        );

        res.status(200).json({
            success: true,
            message: "Booking cancelled successfully."
        });

    } catch (error) {
        console.error("Cancel booking error:", error);

        res.status(400).json({
            success: false,
            message: error.sqlMessage || "Could not cancel booking."
        });
    }
};

// Get dashboard analytics for the logged-in mentor.
exports.getMentorAnalytics = async (req, res) => {
    try {
        const mentorUserId = req.user.userId;

        // Find the mentor profile belonging to this user.
        const [mentorRows] = await db.query(
            `SELECT mentor_id
             FROM mentor_profiles
             WHERE user_id = ?`,
            [mentorUserId]
        );

        if (mentorRows.length === 0) {
            return res.status(404).json({
                success: false,
                message: "Mentor profile not found."
            });
        }

        const mentorId = mentorRows[0].mentor_id;

        // Booking counts and completed-booking earnings.
        const [bookingStats] = await db.query(
            `SELECT
                COUNT(*) AS totalBookings,
                SUM(status = 'Pending') AS pendingBookings,
                SUM(status = 'Confirmed') AS confirmedBookings,
                SUM(status = 'Completed') AS completedBookings,
                SUM(status = 'Cancelled') AS cancelledBookings,
                COALESCE(
                    SUM(
                        CASE
                            WHEN b.status = 'Completed'
                            THEN mp.price
                            ELSE 0
                        END
                    ), 0
                ) AS totalEarnings,
                COALESCE(MAX(mp.currency), 'BDT') AS currency
             FROM bookings b
             LEFT JOIN mentor_plans mp
                ON b.plan_id = mp.plan_id
             WHERE b.mentor_id = ?`,
            [mentorId]
        );

        // Average student rating and total reviews.
        const [reviewStats] = await db.query(
            `SELECT
                COALESCE(ROUND(AVG(rating), 1), 0) AS averageRating,
                COUNT(*) AS totalReviews
             FROM reviews
             WHERE mentor_id = ?`,
            [mentorId]
        );

        // Latest 5 bookings with student names.
        const [recentBookings] = await db.query(
            `SELECT
                b.booking_id,
                u.full_name AS studentName,
                mp.duration_minutes AS durationMinutes,
                mp.price,
                mp.currency,
                b.scheduled_at AS scheduledAt,
                b.status,
                b.created_at AS createdAt
             FROM bookings b
             INNER JOIN users u
                ON b.student_user_id = u.user_id
             LEFT JOIN mentor_plans mp
                ON b.plan_id = mp.plan_id
             WHERE b.mentor_id = ?
             ORDER BY b.created_at DESC
             LIMIT 5`,
            [mentorId]
        );

        res.status(200).json({
            success: true,
            data: {
                bookings: bookingStats[0],
                reviews: reviewStats[0],
                recentBookings
            }
        });

    } catch (error) {
        console.error("Get mentor analytics error:", error);

        res.status(500).json({
            success: false,
            message: "Could not load mentor analytics."
        });
    }
};

const pool = require("../config/database");

const createReview = async (req, res) => {
    const studentUserId = req.user.userId;
    const { bookingId, rating, reviewText } = req.body;

    if (!bookingId || !Number.isInteger(Number(bookingId))) {
        return res.status(400).json({
            success: false,
            message: "A valid booking ID is required."
        });
    }

    const numericRating = Number(rating);

    if (!Number.isInteger(numericRating) ||
        numericRating < 1 ||
        numericRating > 5) {
        return res.status(400).json({
            success: false,
            message: "Rating must be a whole number from 1 to 5."
        });
    }

    if (reviewText && String(reviewText).length > 2000) {
        return res.status(400).json({
            success: false,
            message: "Review must be 2,000 characters or fewer."
        });
    }

    try {
        const [results] = await pool.query(
            "CALL sp_create_student_review(?,?,?,?)",
            [
                studentUserId,
                Number(bookingId),
                numericRating,
                reviewText || null
            ]
        );

        const reviewId = results[0]?.[0]?.review_id;

        return res.status(201).json({
            success: true,
            message: "Your review was submitted successfully.",
            data: { reviewId }
        });

    } catch (error) {
        if (error.sqlState === "45000") {
            return res.status(400).json({
                success: false,
                message: error.sqlMessage || "Unable to submit this review."
            });
        }

        throw error;
    }
};

module.exports = { createReview };
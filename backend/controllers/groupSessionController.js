const pool = require("../config/database");

// Get session categories
const getCategories = async (req, res) => {
    const [resultSets] = await pool.query(
        "CALL sp_get_session_categories()"
    );

    res.json({
        success: true,
        data: resultSets[0] || []
    });
};


// Get upcoming or past sessions
const getSessions = async (req, res) => {
    const view = String(req.query.view || "upcoming").toLowerCase();

    if (!["upcoming", "past"].includes(view)) {
        return res.status(400).json({
            success: false,
            message: "View must be upcoming or past."
        });
    }

    const categoryId = req.query.categoryId
        ? Number(req.query.categoryId)
        : null;

    if (
        categoryId !== null &&
        (!Number.isInteger(categoryId) || categoryId <= 0)
    ) {
        return res.status(400).json({
            success: false,
            message: "Invalid category ID."
        });
    }

    // Public visitors can browse sessions without being logged in.
    // A logged-in user can also see their registration status.
    const studentUserId = req.user?.userId || null;

    const [resultSets] = await pool.query(
        "CALL sp_get_public_group_sessions(?,?,?)",
        [view, categoryId, studentUserId]
    );

    res.json({
        success: true,
        data: resultSets[0] || []
    });
};


// Register a student
const registerForSession = async (req, res) => {
    const sessionId = Number(req.params.sessionId);
    const studentUserId = req.user.userId;

    if (!Number.isInteger(sessionId) || sessionId <= 0) {
        return res.status(400).json({
            success: false,
            message: "Invalid session ID."
        });
    }

    try {
        const [resultSets] = await pool.query(
            "CALL sp_register_for_group_session(?,?)",
            [sessionId, studentUserId]
        );

        res.status(201).json({
            success: true,
            data: resultSets[0]?.[0] || null
        });

    } catch (error) {
        if (error.sqlState === "45000" || error.errno === 1644) {
            return res.status(400).json({
                success: false,
                message: error.sqlMessage || error.message
            });
        }

        throw error;
    }
};


module.exports = {
    getCategories,
    getSessions,
    registerForSession
};
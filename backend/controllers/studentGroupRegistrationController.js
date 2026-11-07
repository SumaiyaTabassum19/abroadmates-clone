const pool = require("../config/database");

const registerForSession = async (req, res) => {
    const sessionId = Number(req.params.sessionId);

    if (!Number.isInteger(sessionId) || sessionId <= 0) {
        return res.status(400).json({
            success: false,
            message: "Invalid session ID."
        });
    }

    try {
        const [results] = await pool.query(
            "CALL sp_register_for_group_session(?, ?)",
            [sessionId, req.user.userId]
        );

        return res.status(201).json({
            success: true,
            message: "You are registered for this group session.",
            data: results[0]?.[0] || {}
        });

    } catch (error) {
        console.error("Group session registration error:", error);

        return res.status(400).json({
            success: false,
            message: error.sqlMessage || "Registration failed."
        });
    }
};

const cancelRegistration = async (req, res) => {
    const registrationId = Number(req.params.registrationId);

    if (!Number.isInteger(registrationId) || registrationId <= 0) {
        return res.status(400).json({
            success: false,
            message: "Invalid registration ID."
        });
    }

    const [results] = await pool.query(
        "CALL sp_cancel_group_registration(?,?)",
        [req.user.userId, registrationId]
    );

    return res.json({
        success: true,
        message: "Your registration has been cancelled.",
        data: results[0]?.[0] || {}
    });
};

const getMyRegistrations = async (req, res) => {
    const [results] = await pool.query(
        "CALL sp_get_my_group_registrations(?)",
        [req.user.userId]
    );

    return res.json({
        success: true,
        count: (results[0] || []).length,
        data: results[0] || []
    });
};

module.exports = {
    registerForSession,
    cancelRegistration,
    getMyRegistrations
};
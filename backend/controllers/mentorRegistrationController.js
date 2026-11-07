const pool = require("../config/database");

// Get registrations for one of the mentor's sessions
const getSessionRegistrations = async (req, res) => {
    const sessionId = Number(req.params.sessionId);

    if (!Number.isInteger(sessionId) || sessionId <= 0) {
        return res.status(400).json({
            success: false,
            message: "Invalid session ID."
        });
    }
    
    const [resultSets] = await pool.query(
    "CALL sp_get_my_session_registrations(?)",
    [req.user.userId, sessionId]
);
    
    const registrations = resultSets[0] || [];

    // An empty list may mean the session has no registrations.
    // Verify ownership separately through the session-list procedure.
    const [sessionSets] = await pool.query(
        "CALL sp_get_my_group_sessions(?)",
        [req.user.userId]
    );

    const ownedSession = (sessionSets[0] || []).find(
        session => Number(session.session_id) === sessionId
    );

    if (!ownedSession) {
        return res.status(404).json({
            success: false,
            message: "Session not found or you do not have access."
        });
    }

    res.json({
        success: true,
        session: {
            session_id: ownedSession.session_id,
            title: ownedSession.title,
            starts_at: ownedSession.starts_at,
            ends_at: ownedSession.ends_at,
            status: ownedSession.status
        },
        data: registrations
    });
};


// Mark a student as attended
const markAttendance = async (req, res) => {
    const registrationId = Number(req.params.registrationId);

    if (!Number.isInteger(registrationId) || registrationId <= 0) {
        return res.status(400).json({
            success: false,
            message: "Invalid registration ID."
        });
    }

    try {
        const [resultSets] = await pool.query(
            "CALL sp_mark_my_session_attendance(?,?)",
            [req.user.userId, registrationId]
        );

        res.json({
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
    getSessionRegistrations,
    markAttendance
};
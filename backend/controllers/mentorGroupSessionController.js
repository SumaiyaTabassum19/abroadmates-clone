const pool = require("../config/database");

function toMySQLDateTime(value) {
    if (typeof value !== "string") return null;

    // Accepts datetime-local values: YYYY-MM-DDTHH:mm
    const normalized = value.replace("T", " ");

    if (!/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?$/.test(normalized)) {
        return null;
    }

    return normalized.length === 16
        ? `${normalized}:00`
        : normalized;
}

function validateSession(body) {
    const {
        categoryId,
        title,
        description,
        startsAt,
        endsAt,
        capacity,
        meetingLink
    } = body;

    const start = toMySQLDateTime(startsAt);
    const end = toMySQLDateTime(endsAt);
    const parsedCapacity = Number(capacity);
    const parsedCategory = Number(categoryId);

    if (!Number.isInteger(parsedCategory) || parsedCategory <= 0) {
        return { error: "Please select a valid session category." };
    }

    if (typeof title !== "string" || !title.trim() || title.trim().length > 180) {
        return { error: "Title is required and must be 180 characters or fewer." };
    }

    if (!start || !end || end <= start) {
        return { error: "Please provide valid start and end dates. The end must be after the start." };
    }

    if (!Number.isInteger(parsedCapacity) || parsedCapacity < 1) {
        return { error: "Capacity must be a whole number of at least one." };
    }

    const cleanLink = meetingLink ? String(meetingLink).trim() : null;

    if (cleanLink) {
        try {
            const parsedUrl = new URL(cleanLink);
            if (parsedUrl.protocol !== "https:") {
                return { error: "Meeting links must use HTTPS." };
            }
        } catch {
            return { error: "Please enter a valid meeting URL." };
        }

        if (cleanLink.length > 500) {
            return { error: "Meeting link must be 500 characters or fewer." };
        }
    }

    return {
        values: [
            parsedCategory,
            title.trim(),
            description ? String(description).trim() : null,
            start,
            end,
            parsedCapacity,
            cleanLink
        ]
    };
}

function sendDatabaseError(error, res) {
    if (error.sqlState === "45000" || error.errno === 1644) {
        return res.status(400).json({
            success: false,
            message: error.sqlMessage || error.message
        });
    }

    if (error.code === "ER_NO_REFERENCED_ROW_2") {
        return res.status(400).json({
            success: false,
            message: "The selected category does not exist."
        });
    }

    throw error;
}


// GET mentor's own sessions
const getMySessions = async (req, res) => {
    const [resultSets] = await pool.query(
        "CALL sp_get_my_group_sessions(?)",
        [req.user.userId]
    );

    res.json({
        success: true,
        data: resultSets[0] || []
    });
};


// CREATE session
const createSession = async (req, res) => {
    const validation = validateSession(req.body);

    if (validation.error) {
        return res.status(400).json({
            success: false,
            message: validation.error
        });
    }

    try {
        const [resultSets] = await pool.query(
            "CALL sp_create_group_session(?,?,?,?,?,?,?,?)",
            [req.user.userId, ...validation.values]
        );

        res.status(201).json({
            success: true,
            message: "Group session created successfully.",
            data: resultSets[0]?.[0] || null
        });
    } catch (error) {
        sendDatabaseError(error, res);
    }
};


// UPDATE session
const updateSession = async (req, res) => {
    const sessionId = Number(req.params.sessionId);

    if (!Number.isInteger(sessionId) || sessionId <= 0) {
        return res.status(400).json({
            success: false,
            message: "Invalid session ID."
        });
    }

    const validation = validateSession(req.body);

    if (validation.error) {
        return res.status(400).json({
            success: false,
            message: validation.error
        });
    }

    try {
        await pool.query(
            "CALL sp_update_my_group_session(?,?,?,?,?,?,?,?,?)",
            [req.user.userId, sessionId, ...validation.values]
        );

        res.json({
            success: true,
            message: "Group session updated successfully."
        });
    } catch (error) {
        sendDatabaseError(error, res);
    }
};


// CANCEL session
const cancelSession = async (req, res) => {
    const sessionId = Number(req.params.sessionId);

    if (!Number.isInteger(sessionId) || sessionId <= 0) {
        return res.status(400).json({
            success: false,
            message: "Invalid session ID."
        });
    }

    try {
        await pool.query(
            "CALL sp_cancel_my_group_session(?,?)",
            [req.user.userId, sessionId]
        );

        res.json({
            success: true,
            message: "Group session cancelled successfully."
        });
    } catch (error) {
        sendDatabaseError(error, res);
    }
};


module.exports = {
    getMySessions,
    createSession,
    updateSession,
    cancelSession
};
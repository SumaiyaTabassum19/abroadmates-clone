const pool = require("../config/database");
const fs = require("fs/promises");
const path = require("path");

const {
    photoDirectory,
    cvDirectory
} = require("../middleware/mentorUpload");

async function getMentorFilePaths(userId) {
    const [resultSets] = await pool.query(
        "CALL sp_get_my_mentor_file_paths(?)",
        [userId]
    );

    return resultSets[0]?.[0] || null;
}

async function removeOldFile(filePath, allowedDirectory) {
    if (!filePath) return;

    const absolutePath = path.resolve(
        __dirname,
        "..",
        filePath
    );

    const safeDirectory = path.resolve(allowedDirectory);

    if (!absolutePath.startsWith(safeDirectory + path.sep)) {
        return;
    }

    try {
        await fs.unlink(absolutePath);
    } catch (error) {
        if (error.code !== "ENOENT") {
            console.error("Could not remove old upload:", error);
        }
    }
}

const uploadProfilePhoto = async (req, res) => {
    if (!req.file) {
        return res.status(400).json({
            success: false,
            message: "Please choose a profile photo."
        });
    }

    const userId = req.user.userId;
    const relativePath = path.join(
        "uploads",
        "mentor-photos",
        req.file.filename
    ).replace(/\\/g, "/");

    try {
        const oldFiles = await getMentorFilePaths(userId);

        const [result] = await pool.execute(
            `UPDATE mentor_profiles
             SET profile_photo_path = ?
             WHERE user_id = ?`,
            [relativePath, userId]
        );

        if (result.affectedRows === 0) {
            throw new Error("Mentor profile not found.");
        }

        if (oldFiles?.profile_photo_path) {
            await removeOldFile(
                oldFiles.profile_photo_path,
                photoDirectory
            );
        }

        res.json({
            success: true,
            message: "Profile photo uploaded successfully.",
            photoUrl: `http://localhost:5000/${relativePath}`
        });

    } catch (error) {
        await fs.unlink(req.file.path).catch(() => {});

        console.error("Photo upload error:", error);

        res.status(500).json({
            success: false,
            message: "Could not save the profile photo."
        });
    }
};

const uploadCv = async (req, res) => {
    if (!req.file) {
        return res.status(400).json({
            success: false,
            message: "Please choose a CV PDF."
        });
    }

    const userId = req.user.userId;
    const relativePath = path.join(
        "uploads",
        "mentor-cvs",
        req.file.filename
    ).replace(/\\/g, "/");

    try {
        const oldFiles = await getMentorFilePaths(userId);

        const [result] = await pool.execute(
            `UPDATE mentor_profiles
             SET cv_file_path = ?
             WHERE user_id = ?`,
            [relativePath, userId]
        );

        if (result.affectedRows === 0) {
            throw new Error("Mentor profile not found.");
        }

        if (oldFiles?.cv_file_path) {
            await removeOldFile(
                oldFiles.cv_file_path,
                cvDirectory
            );
        }

        res.json({
            success: true,
            message: "CV uploaded successfully."
        });

    } catch (error) {
        await fs.unlink(req.file.path).catch(() => {});

        console.error("CV upload error:", error);

        res.status(500).json({
            success: false,
            message: "Could not save the CV."
        });
    }
};

const downloadMyCv = async (req, res) => {
    try {
        const files = await getMentorFilePaths(req.user.userId);

        if (!files?.cv_file_path) {
            return res.status(404).json({
                success: false,
                message: "No CV has been uploaded yet."
            });
        }

        const absolutePath = path.resolve(
            __dirname,
            "..",
            files.cv_file_path
        );

        const safeDirectory = path.resolve(cvDirectory);

        if (!absolutePath.startsWith(safeDirectory + path.sep)) {
            return res.status(400).json({
                success: false,
                message: "Invalid CV file path."
            });
        }

        res.download(absolutePath, "mentor-cv.pdf", error => {
            if (error && !res.headersSent) {
                res.status(404).json({
                    success: false,
                    message: "CV file could not be found."
                });
            }
        });

    } catch (error) {
        console.error("CV download error:", error);

        res.status(500).json({
            success: false,
            message: "Could not download the CV."
        });
    }
};

module.exports = {
    uploadProfilePhoto,
    uploadCv,
    downloadMyCv
};
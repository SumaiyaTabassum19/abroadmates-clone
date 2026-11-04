const express = require("express");
const router = express.Router();

const {
    uploadProfilePhoto,
    uploadCv,
    downloadMyCv
} = require("../controllers/mentorFileController");

const {
    authenticateToken,
    authorizeRoles
} = require("../middleware/authMiddleware");

const {
    photoUpload,
    cvUpload
} = require("../middleware/mentorUpload");

const asyncHandler = require("../utils/asyncHandler");

function handleUpload(uploadMiddleware) {
    return (req, res, next) => {
        uploadMiddleware.single(
            uploadMiddleware === photoUpload ? "profilePhoto" : "cv"
        )(req, res, error => {
            if (error) {
                return res.status(400).json({
                    success: false,
                    message: error.message
                });
            }

            next();
        });
    };
}

router.use(authenticateToken, authorizeRoles("Mentor"));

router.post(
    "/photo",
    handleUpload(photoUpload),
    asyncHandler(uploadProfilePhoto)
);

router.post(
    "/cv",
    handleUpload(cvUpload),
    asyncHandler(uploadCv)
);

router.get(
    "/cv/download",
    asyncHandler(downloadMyCv)
);

module.exports = router;
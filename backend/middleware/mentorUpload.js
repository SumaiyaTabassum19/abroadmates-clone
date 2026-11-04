const multer = require("multer");
const path = require("path");
const fs = require("fs");

const uploadRoot = path.join(__dirname, "..", "uploads");
const photoDirectory = path.join(uploadRoot, "mentor-photos");
const cvDirectory = path.join(uploadRoot, "mentor-cvs");

fs.mkdirSync(photoDirectory, { recursive: true });
fs.mkdirSync(cvDirectory, { recursive: true });

const createStorage = destination => multer.diskStorage({
    destination: (req, file, cb) => cb(null, destination),

    filename: (req, file, cb) => {
        const extension = path.extname(file.originalname).toLowerCase();
        const safeName = `${Date.now()}-${require("crypto").randomUUID()}${extension}`;
        cb(null, safeName);
    }
});

const photoUpload = multer({
    storage: createStorage(photoDirectory),
    limits: { fileSize: 5 * 1024 * 1024 },
    fileFilter: (req, file, cb) => {
        const allowed = ["image/jpeg", "image/png", "image/webp"];

        if (!allowed.includes(file.mimetype)) {
            return cb(new Error("Please upload a JPG, PNG or WEBP image."));
        }

        cb(null, true);
    }
});

const cvUpload = multer({
    storage: createStorage(cvDirectory),
    limits: { fileSize: 10 * 1024 * 1024 },
    fileFilter: (req, file, cb) => {
        const extension = path.extname(file.originalname).toLowerCase();

        if (file.mimetype !== "application/pdf" || extension !== ".pdf") {
            return cb(new Error("Please upload a PDF file."));
        }

        cb(null, true);
    }
});

module.exports = {
    photoUpload,
    cvUpload,
    photoDirectory,
    cvDirectory
};
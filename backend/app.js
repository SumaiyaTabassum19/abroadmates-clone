require('dotenv').config();

const express = require('express');
const cors = require('cors');

const app = express();

// Middleware must come before API routes
app.use(cors());

app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true }));

// Import routes
const catalogRoutes = require('./routes/catalogRoutes');
const universityRoutes = require('./routes/universityRoutes');
const healthRoutes = require('./routes/healthRoutes');
const authRoutes = require('./routes/authRoutes');

const mentorProfileRoutes = require('./routes/mentorProfileRoutes');

app.use('/api/mentor/profile',mentorProfileRoutes);

const mentorExpertiseRoutes = require("./routes/mentorExpertiseRoutes");
app.use("/api/mentor/expertise", mentorExpertiseRoutes);

const mentorFileRoutes = require("./routes/mentorFileRoutes");
const path = require("path");
// Public profile photos only. CV files are NOT served publicly.
app.use(
    "/uploads/mentor-photos",
    express.static(path.join(__dirname, "uploads", "mentor-photos"))
);

app.use("/api/mentor/files", mentorFileRoutes);

const catalogFilterRoutes = require("./routes/catalogFilterRoutes");
app.use("/api/catalog", catalogFilterRoutes);

const publicMentorRoutes = require("./routes/publicMentorRoutes");
const bookingRoutes = require("./routes/bookingRoutes");
const groupSessionRoutes = require("./routes/groupSessionRoutes");
const mentorGroupSessionRoutes =
    require("./routes/mentorGroupSessionRoutes");
const mentorRegistrationRoutes =
    require("./routes/mentorRegistrationRoutes");
const studentBookingRoutes =
    require("./routes/studentBookingRoutes");

app.use("/api/public/mentors", publicMentorRoutes);
app.use("/api/bookings", bookingRoutes);
app.use("/api/group-sessions", groupSessionRoutes);
app.use(
    "/api/mentor/group-sessions",
    mentorGroupSessionRoutes
);
app.use(
    "/api/mentor/registrations",
    mentorRegistrationRoutes
);
app.use("/api/student/bookings", studentBookingRoutes);

const studentReviewRoutes =
    require("./routes/studentReviewRoutes");

app.use("/api/student/reviews", studentReviewRoutes);

const publicReviewRoutes =
    require("./routes/publicReviewRoutes");

app.use("/api/public/mentors", publicReviewRoutes);

const studentGroupRegistrationRoutes =
    require("./routes/studentGroupRegistrationRoutes");

app.use(
    "/api/student/group-sessions",
    studentGroupRegistrationRoutes
);

const mentorBookingRoutes = require("./routes/mentorBookingRoutes");

app.use("/api/mentor/bookings", mentorBookingRoutes);

const mentorReportRoutes = require("./routes/mentorReportRoutes");
app.use("/api/mentor/reports", mentorReportRoutes);

// Main routes
app.get('/', (_req, res) => {
  res.json({
    name: 'AbroadMates API',
    version: '1.0.0'
  });
});

app.use('/api/health', healthRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/catalog', catalogRoutes);
app.use('/api/universities', universityRoutes);

// 404 handler
app.use((_req, res) => {
  res.status(404).json({ message: 'Route not found' });
});

// Error handler
app.use((err, _req, res, _next) => {
  console.error(err);

  res.status(500).json({
    message: process.env.NODE_ENV === 'production'
      ? 'Internal server error.'
      : err.message
  });
});

module.exports = app;

const API = "http://localhost:5000/api";

const token = localStorage.getItem("abroadmates_token");

if (!token) {
  window.location.replace("auth.html");
}

const logout = () => {
  localStorage.removeItem("abroadmates_token");
  localStorage.removeItem("abroadmates_user");
  window.location.replace("auth.html");
};

document.getElementById("logoutButton").addEventListener("click", logout);


// Load mentor analytics.
async function loadMentorAnalytics() {
  const analyticsSection = document.getElementById("mentorAnalytics");
  const analyticsMessage = document.getElementById("analyticsMessage");
  const analyticsCards = document.getElementById("analyticsCards");

  analyticsSection.hidden = false;
  analyticsMessage.textContent = "Loading your analytics...";

  try {
    const response = await fetch(`${API}/mentor/bookings/analytics`, {
      headers: {
        Authorization: `Bearer ${token}`
      }
    });

    const result = await response.json();

    if (!response.ok || !result.success) {
      throw new Error(result.message || "Could not load analytics.");
    }

    const { bookings, reviews, recentBookings } = result.data;

    // Booking statistics.
    document.getElementById("totalBookings").textContent =
      Number(bookings.totalBookings || 0);

    document.getElementById("pendingBookings").textContent =
      Number(bookings.pendingBookings || 0);

    document.getElementById("confirmedBookings").textContent =
      Number(bookings.confirmedBookings || 0);

    document.getElementById("completedBookings").textContent =
      Number(bookings.completedBookings || 0);

    document.getElementById("cancelledBookings").textContent =
      Number(bookings.cancelledBookings || 0);

    // Earnings.
    const currency = bookings.currency || "BDT";

    const earnings = Number(bookings.totalEarnings || 0);

    document.getElementById("totalEarnings").textContent =
      new Intl.NumberFormat("en-BD", {
        style: "currency",
        currency: currency,
        maximumFractionDigits: 2
      }).format(earnings);

    // Reviews.
    document.getElementById("averageRating").textContent =
      `${Number(reviews.averageRating || 0).toFixed(1)} / 5`;

    const reviewCount = Number(reviews.totalReviews || 0);

    document.getElementById("totalReviews").textContent =
      `${reviewCount} student ${reviewCount === 1 ? "review" : "reviews"}`;

    // Recent bookings.
    renderRecentBookings(recentBookings || []);

    analyticsMessage.textContent = "Your analytics are up to date.";
    analyticsCards.hidden = false;

  } catch (error) {
    console.error("Mentor analytics error:", error);
    analyticsMessage.textContent =
      error.message || "Could not load mentor analytics.";
    analyticsMessage.classList.add("analytics-error");
  }
}


// Render recent booking rows.
function renderRecentBookings(bookings) {
  const tbody = document.getElementById("recentBookingsBody");

  tbody.innerHTML = "";

  if (!bookings.length) {
    const row = document.createElement("tr");
    const cell = document.createElement("td");

    cell.colSpan = 5;
    cell.className = "empty-bookings";
    cell.textContent = "No bookings found yet.";

    row.appendChild(cell);
    tbody.appendChild(row);

    return;
  }

  bookings.forEach(booking => {
    const row = document.createElement("tr");

    const studentCell = document.createElement("td");
    studentCell.textContent = booking.studentName || "Student";

    const planCell = document.createElement("td");
    planCell.textContent =
      `${booking.durationMinutes || 0} minutes`;

    const priceCell = document.createElement("td");
    const price = Number(booking.price || 0);

    priceCell.textContent =
      new Intl.NumberFormat("en-BD", {
        style: "currency",
        currency: booking.currency || "BDT",
        maximumFractionDigits: 2
      }).format(price);

    const dateCell = document.createElement("td");

    const scheduledDate = new Date(booking.scheduledAt);

    dateCell.textContent = Number.isNaN(scheduledDate.getTime())
      ? "Not scheduled"
      : scheduledDate.toLocaleString();

    const statusCell = document.createElement("td");

    const statusBadge = document.createElement("span");
    const status = String(booking.status || "pending").toLowerCase();

    statusBadge.className = `booking-status status-${status}`;
    statusBadge.textContent =
      status.charAt(0).toUpperCase() + status.slice(1);

    statusCell.appendChild(statusBadge);

    row.append(
      studentCell,
      planCell,
      priceCell,
      dateCell,
      statusCell
    );

    tbody.appendChild(row);
  });
}


// Load account information.
(async () => {
  try {
    const response = await fetch(`${API}/auth/me`, {
      headers: {
        Authorization: `Bearer ${token}`
      }
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.message || "Could not load account.");
    }

    const user = data.user;

    document.getElementById("welcomeTitle").textContent =
      `Welcome, ${user.fullName.split(" ")[0]}!`;

    document.getElementById("welcomeCopy").textContent =
      user.role === "Mentor"
        ? "Manage your mentorship activity and track your progress."
        : "Your student account is ready. Explore mentors and manage your bookings.";

    document.getElementById("accountName").textContent = user.fullName;
    document.getElementById("accountEmail").textContent = user.email;
    document.getElementById("accountRole").textContent =
      `Account type: ${user.role}`;

    if (user.role === "Mentor") {
      const profile = document.getElementById("mentorProfileStatus");

      profile.hidden = false;

      profile.textContent = data.mentorProfile
        ? `Mentor profile created successfully (profile ID: ${data.mentorProfile.mentor_id}).`
        : "No mentor profile was found. Please check your mentor profile setup.";

      profile.classList.add(data.mentorProfile ? "success" : "error");

      await loadMentorAnalytics();
    }

  } catch (error) {
    console.error("Dashboard error:", error);
    alert(error.message);
    logout();
  }
})();

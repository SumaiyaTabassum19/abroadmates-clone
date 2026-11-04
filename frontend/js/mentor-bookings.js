const API_BASE_URL = "http://localhost:5000/api";

const bookingList = document.getElementById("bookingList");
const messageBox = document.getElementById("message");
const statusFilter = document.getElementById("statusFilter");

const totalBookings = document.getElementById("totalBookings");
const pendingBookings = document.getElementById("pendingBookings");
const confirmedBookings = document.getElementById("confirmedBookings");
const completedBookings = document.getElementById("completedBookings");

const refreshBtn = document.getElementById("refreshBtn");
const logoutBtn = document.getElementById("logoutBtn");

let allBookings = [];

function escapeHTML(value) {
    return String(value ?? "").replace(/[&<>"']/g, character => ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#039;"
    })[character]);
}

function formatDate(value) {
    if (!value) return "Not available";

    const date = new Date(String(value).replace(" ", "T"));

    if (Number.isNaN(date.getTime())) {
        return value;
    }

    return date.toLocaleString([], {
        dateStyle: "medium",
        timeStyle: "short"
    });
}

function showMessage(message, type = "success") {
    messageBox.textContent = message;
    messageBox.className = `message ${type}`;
}

function clearMessage() {
    messageBox.textContent = "";
    messageBox.className = "message";
}

function getToken() {
    return localStorage.getItem("abroadmates_token");
}

// Load all bookings belonging to the logged-in mentor.
async function loadBookings() {
    const token = getToken();

    if (!token) {
        window.location.href = "./auth.html";
        return;
    }

    bookingList.innerHTML =
        '<p class="loading">Loading bookings...</p>';

    clearMessage();

    try {
        const response = await fetch(
            `${API_BASE_URL}/mentor/bookings/my`,
            {
                headers: {
                    Authorization: `Bearer ${token}`
                }
            }
        );

        const result = await response.json();

        if (response.status === 401 || response.status === 403) {
            throw new Error(
                "Please log in using your Mentor account."
            );
        }

        if (!response.ok || !result.success) {
            throw new Error(
                result.message || "Could not load bookings."
            );
        }

        allBookings = result.data || [];

        updateSummary();
        renderBookings();

    } catch (error) {
        bookingList.innerHTML = "";
        showMessage(error.message, "error");
    }
}

// Update summary numbers.
function updateSummary() {
    totalBookings.textContent = allBookings.length;

    pendingBookings.textContent =
        allBookings.filter(b => b.status === "pending").length;

    confirmedBookings.textContent =
        allBookings.filter(b => b.status === "confirmed").length;

    completedBookings.textContent =
        allBookings.filter(b => b.status === "completed").length;
}

// Render booking cards.
function renderBookings() {
    const selectedStatus = statusFilter.value;

    const filteredBookings = selectedStatus === "all"
        ? allBookings
        : allBookings.filter(
            booking => booking.status === selectedStatus
        );

    if (!filteredBookings.length) {
        bookingList.innerHTML = `
            <div class="empty-state">
                <h3>No bookings found</h3>
                <p>There are no bookings in this category yet.</p>
            </div>
        `;
        return;
    }

    bookingList.innerHTML = filteredBookings.map(booking => {
        const status = String(booking.status || "").toLowerCase();

        let actionsHTML = "";

        if (status === "pending") {
            actionsHTML = `
                <input
                    type="url"
                    class="meeting-input"
                    id="meeting-${Number(booking.booking_id)}"
                    placeholder="Optional meeting link (https://...)"
                >

                <div class="booking-actions">
                    <button
                        type="button"
                        class="action-btn confirm-btn"
                        data-action="confirm"
                        data-id="${Number(booking.booking_id)}"
                    >
                        Confirm Booking
                    </button>

                    <button
                        type="button"
                        class="action-btn cancel-btn"
                        data-action="cancel"
                        data-id="${Number(booking.booking_id)}"
                    >
                        Cancel Booking
                    </button>
                </div>
            `;
        } else if (status === "confirmed") {
            actionsHTML = `
                <div class="booking-actions">
                    <button
                        type="button"
                        class="action-btn complete-btn"
                        data-action="complete"
                        data-id="${Number(booking.booking_id)}"
                    >
                        Mark as Completed
                    </button>

                    <button
                        type="button"
                        class="action-btn cancel-btn"
                        data-action="cancel"
                        data-id="${Number(booking.booking_id)}"
                    >
                        Cancel Booking
                    </button>
                </div>
            `;
        }

        const meetingLinkHTML = booking.meeting_link
            ? `
                <div class="meeting-link">
                    <strong>Meeting link:</strong>
                    <a
                        href="${escapeHTML(booking.meeting_link)}"
                        target="_blank"
                        rel="noopener noreferrer"
                    >
                        Open meeting link
                    </a>
                </div>
            `
            : "";

        return `
            <article class="booking-card">

                <div class="booking-top">
                    <h3>Booking #${Number(booking.booking_id)}</h3>

                    <span class="status ${escapeHTML(status)}">
                        ${escapeHTML(status)}
                    </span>
                </div>

                <div class="booking-details">

                    <div class="detail-item">
                        <span>Student</span>
                        <strong>${escapeHTML(booking.student_name)}</strong>
                    </div>

                    <div class="detail-item">
                        <span>Student Email</span>
                        <strong>${escapeHTML(booking.student_email)}</strong>
                    </div>

                    <div class="detail-item">
                        <span>Consultation Duration</span>
                        <strong>${Number(booking.duration_minutes)} minutes</strong>
                    </div>

                    <div class="detail-item">
                        <span>Price</span>
                        <strong>
                            ${escapeHTML(booking.currency)}
                            ${escapeHTML(booking.price)}
                        </strong>
                    </div>

                    <div class="detail-item">
                        <span>Scheduled Date</span>
                        <strong>${escapeHTML(formatDate(booking.scheduled_at))}</strong>
                    </div>

                    <div class="detail-item">
                        <span>Booking Created</span>
                        <strong>${escapeHTML(formatDate(booking.created_at))}</strong>
                    </div>

                </div>

                ${
                    booking.student_note
                        ? `
                            <div class="student-note">
                                <strong>Student Note:</strong>
                                <p>${escapeHTML(booking.student_note)}</p>
                            </div>
                        `
                        : ""
                }

                ${meetingLinkHTML}

                ${actionsHTML}

            </article>
        `;
    }).join("");
}

// Handle booking actions.
async function handleBookingAction(action, bookingId, button) {
    const token = getToken();

    if (!token) {
        window.location.href = "./auth.html";
        return;
    }

    let endpoint = "";
    let requestBody;

    if (action === "confirm") {
        endpoint = `${API_BASE_URL}/mentor/bookings/${bookingId}/confirm`;

        const meetingInput = document.getElementById(
            `meeting-${bookingId}`
        );

        const meetingLink = meetingInput.value.trim();

        if (meetingLink) {
            try {
                const parsedLink = new URL(meetingLink);

                if (parsedLink.protocol !== "https:") {
                    showMessage(
                        "Please enter a valid HTTPS meeting link.",
                        "error"
                    );
                    return;
                }
            } catch {
                showMessage(
                    "Please enter a valid meeting URL.",
                    "error"
                );
                return;
            }
        }

        requestBody = {
            meetingLink: meetingLink || null
        };

    } else if (action === "complete") {
        endpoint = `${API_BASE_URL}/mentor/bookings/${bookingId}/complete`;

        if (!confirm("Mark this booking as completed?")) {
            return;
        }

    } else if (action === "cancel") {
        endpoint = `${API_BASE_URL}/mentor/bookings/${bookingId}/cancel`;

        if (!confirm("Are you sure you want to cancel this booking?")) {
            return;
        }

    } else {
        return;
    }

    button.disabled = true;
    button.textContent = "Processing...";

    clearMessage();

    try {
        const response = await fetch(endpoint, {
            method: "PATCH",
            headers: {
                Authorization: `Bearer ${token}`,
                "Content-Type": "application/json"
            },
            ...(requestBody
                ? { body: JSON.stringify(requestBody) }
                : {})
        });

        const result = await response.json();

        if (!response.ok || !result.success) {
            throw new Error(
                result.message || "Could not update booking."
            );
        }

        showMessage(result.message || "Booking updated successfully.");

        await loadBookings();

    } catch (error) {
        showMessage(error.message, "error");

        button.disabled = false;

        if (action === "confirm") {
            button.textContent = "Confirm Booking";
        } else if (action === "complete") {
            button.textContent = "Mark as Completed";
        } else {
            button.textContent = "Cancel Booking";
        }
    }
}

// Use event delegation for booking buttons.
bookingList.addEventListener("click", event => {
    const button = event.target.closest("[data-action]");

    if (!button) return;

    const action = button.dataset.action;
    const bookingId = Number(button.dataset.id);

    if (!Number.isInteger(bookingId) || bookingId <= 0) {
        showMessage("Invalid booking ID.", "error");
        return;
    }

    handleBookingAction(action, bookingId, button);
});

// Filter bookings.
statusFilter.addEventListener("change", renderBookings);

// Refresh bookings.
refreshBtn.addEventListener("click", loadBookings);

// Logout.
logoutBtn.addEventListener("click", () => {
    localStorage.removeItem("abroadmates_token");
    localStorage.removeItem("abroadmates_user");

    window.location.href = "./auth.html";
});

// Initialize.
loadBookings();

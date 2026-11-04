const API_BASE = "http://localhost:5000/api";

const token = localStorage.getItem("abroadmates_token");

const bookingContainer =
    document.getElementById("bookingContainer");

const messageBox = document.getElementById("message");

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
    if (!value) return "Not scheduled";

    const date = new Date(value);

    if (Number.isNaN(date.getTime())) {
        return escapeHTML(value);
    }

    return date.toLocaleString([], {
        dateStyle: "medium",
        timeStyle: "short"
    });
}

function showMessage(text, isError = false) {
    messageBox.textContent = text;
    messageBox.style.color = isError ? "#a12c2c" : "#A14646";
}

function renderBookings(bookings) {
    if (!bookings.length) {
        bookingContainer.innerHTML = `
            <div class="empty-state">
                <h3>No bookings yet</h3>
                <p>Explore mentors and book your first consultation.</p>
                <a href="./find-mentor.html">Find a Mentor</a>
            </div>
        `;
        return;
    }

    bookingContainer.innerHTML = bookings.map(booking => {
        const status = String(booking.status || "").toLowerCase();

        const reviewSection =
    status === "completed"
        ? booking.review_id
            ? `
                <div class="meeting-area">
                    <strong>Review submitted</strong>
                    <p>Thank you for sharing your experience.</p>
                </div>
            `
            : `
                <form class="review-form"
                      data-booking-id="${escapeHTML(booking.booking_id)}">

                    <h3>Review your consultation</h3>

                    <label for="rating-${escapeHTML(booking.booking_id)}">
                        Your rating
                    </label>

                    <select
                        id="rating-${escapeHTML(booking.booking_id)}"
                        name="rating"
                        required
                    >
                        <option value="">Choose a rating</option>
                        <option value="5">5 - Excellent</option>
                        <option value="4">4 - Very good</option>
                        <option value="3">3 - Good</option>
                        <option value="2">2 - Fair</option>
                        <option value="1">1 - Poor</option>
                    </select>

                    <label for="review-${escapeHTML(booking.booking_id)}">
                        Your comments
                    </label>

                    <textarea
                        id="review-${escapeHTML(booking.booking_id)}"
                        name="reviewText"
                        maxlength="2000"
                        placeholder="Share your experience (optional)"
                    ></textarea>

                    <button type="submit">Submit Review</button>

                    <div class="review-message" aria-live="polite"></div>
                </form>
            `
        : "";

        const meetingLink =
            status === "confirmed" && booking.meeting_link
                ? `
                    <div class="meeting-area">
                        <strong>Meeting link</strong>
                        <p>
                            <a href="${escapeHTML(booking.meeting_link)}"
                               target="_blank"
                               rel="noopener noreferrer">
                                Open meeting link
                            </a>
                        </p>
                    </div>
                `
                : "";

        return `
            <article class="booking-card">
                <div class="booking-header">
                    <div>
                        <h2>${escapeHTML(booking.mentor_name)}</h2>
                        <div class="booking-id">
                            Booking #${escapeHTML(booking.booking_id)}
                        </div>
                    </div>

                    <span class="status ${escapeHTML(status)}">
                        ${escapeHTML(status)}
                    </span>
                </div>

                <div class="booking-details">
                    <div>
                        <div class="detail-label">Mentor headline</div>
                        <div class="detail-value">
                            ${escapeHTML(booking.mentor_headline || "Mentor")}
                        </div>
                    </div>

                    <div>
                        <div class="detail-label">Consultation duration</div>
                        <div class="detail-value">
                            ${escapeHTML(booking.duration_minutes)} minutes
                        </div>
                    </div>

                    <div>
                        <div class="detail-label">Price</div>
                        <div class="detail-value">
                            ${escapeHTML(booking.currency)}
                            ${escapeHTML(booking.price)}
                        </div>
                    </div>

                    <div>
                        <div class="detail-label">Scheduled date</div>
                        <div class="detail-value">
                            ${formatDate(booking.scheduled_at)}
                        </div>
                    </div>
                </div>

                ${meetingLink}
                ${reviewSection}
            </article>
        `;
    }).join("");
}

async function loadBookings() {
    if (!token) {
        window.location.href = "./auth.html";
        return;
    }

    try {
        const response = await fetch(
            `${API_BASE}/student/bookings/my`,
            {
                headers: {
                    "Authorization": `Bearer ${token}`
                }
            }
        );

        const result = await response.json();

        if (response.status === 401 || response.status === 403) {
            localStorage.removeItem("abroadmates_token");
            localStorage.removeItem("abroadmates_user");
            window.location.href = "./auth.html";
            return;
        }

        if (!response.ok || !result.success) {
            throw new Error(result.message || "Could not load bookings.");
        }

        renderBookings(result.data || []);

    } catch (error) {
        console.error(error);
        showMessage(error.message, true);

        bookingContainer.innerHTML = `
            <div class="empty-state">
                Unable to load your bookings. Please try again.
            </div>
        `;
    }
}

loadBookings();

bookingContainer.addEventListener("submit", async event => {
    const form = event.target.closest(".review-form");

    if (!form) return;

    event.preventDefault();

    const button = form.querySelector("button");
    const message = form.querySelector(".review-message");
    const bookingId = form.dataset.bookingId;
    const rating = form.querySelector('[name="rating"]').value;
    const reviewText = form.querySelector('[name="reviewText"]').value;

    button.disabled = true;
    message.textContent = "Submitting your review...";

    try {
        const response = await fetch(
            `${API_BASE}/student/reviews`,
            {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "Authorization": `Bearer ${token}`
                },
                body: JSON.stringify({
                    bookingId,
                    rating: Number(rating),
                    reviewText
                })
            }
        );

        const result = await response.json();

        if (!response.ok || !result.success) {
            throw new Error(result.message || "Review submission failed.");
        }

        message.textContent = "Review submitted successfully.";
        await loadBookings();

    } catch (error) {
        message.textContent = error.message;
        button.disabled = false;
    }
});
const reviewApiBase = "http://localhost:5000/api";

const reviewMentorId =
    new URLSearchParams(window.location.search).get("id");

const ratingSummaryElement =
    document.getElementById("ratingSummary");

const publicReviewsElement =
    document.getElementById("publicReviewsList");

function escapeReviewHTML(value) {
    return String(value ?? "").replace(/[&<>"']/g, character => ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#039;"
    })[character]);
}

function formatReviewDate(value) {
    if (!value) return "";

    const date = new Date(value);

    if (Number.isNaN(date.getTime())) {
        return "";
    }

    return date.toLocaleDateString([], {
        year: "numeric",
        month: "long",
        day: "numeric"
    });
}

async function loadPublicReviews() {
    if (!reviewMentorId || !/^\d+$/.test(reviewMentorId)) {
        ratingSummaryElement.textContent = "Invalid mentor.";
        publicReviewsElement.textContent = "";
        return;
    }

    try {
        const response = await fetch(
            `${reviewApiBase}/public/mentors/${reviewMentorId}/reviews`
        );

        const result = await response.json();

        if (!response.ok || !result.success) {
            throw new Error(result.message || "Unable to load reviews.");
        }

        const summary = result.data.summary;
        const reviews = result.data.reviews || [];

        const average = Number(summary.average_rating || 0);
        const total = Number(summary.total_reviews || 0);

        ratingSummaryElement.innerHTML = `
            <div class="review-stars">
                ${"★".repeat(Math.round(average))}
                ${"☆".repeat(5 - Math.round(average))}
            </div>
            <div>${average.toFixed(1)} / 5</div>
            <small>${total} review${total === 1 ? "" : "s"}</small>
        `;

        if (reviews.length === 0) {
            publicReviewsElement.innerHTML = `
                <div class="no-reviews">
                    <h3>No reviews yet</h3>
                    <p>Be the first student to share feedback after a completed consultation.</p>
                </div>
            `;
            return;
        }

        publicReviewsElement.innerHTML = reviews.map(review => {
            const rating = Math.max(
                1,
                Math.min(5, Number(review.rating) || 1)
            );

            return `
                <article class="review-card">
                    <h3>${escapeReviewHTML(review.student_name)}</h3>

                    <div class="review-stars">
                        ${"★".repeat(rating)}
                        ${"☆".repeat(5 - rating)}
                    </div>

                    <p class="review-text">
                        ${escapeReviewHTML(review.review_text || "No written comment.")}
                    </p>

                    <div class="review-date">
                        ${escapeReviewHTML(formatReviewDate(review.created_at))}
                    </div>
                </article>
            `;
        }).join("");

    } catch (error) {
        console.error("Review loading error:", error);
        ratingSummaryElement.textContent = "Ratings unavailable.";
        publicReviewsElement.textContent =
            "Unable to load reviews. Please try again later.";
    }
}

loadPublicReviews();
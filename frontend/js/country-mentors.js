
const API_BASE_URL = "http://localhost:5000/api";
const SERVER_BASE_URL = "http://localhost:5000";

const countryTitle = document.getElementById("countryTitle");
const countryDescription = document.getElementById("countryDescription");
const mentorHeading = document.getElementById("mentorHeading");
const mentorCount = document.getElementById("mentorCount");
const mentorList = document.getElementById("mentorList");
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

function showError(message) {
    messageBox.textContent = message;
    messageBox.className = "message error";
}

function getCountryId() {
    return new URLSearchParams(window.location.search).get("countryId");
}

function getPhotoUrl(path) {
    if (!path) return "";

    if (/^https?:\/\//i.test(path)) {
        return path;
    }

    const cleanPath = String(path).replace(/^\/+/, "");
    return `${SERVER_BASE_URL}/${cleanPath}`;
}

// Load country information and update SEO metadata.
async function loadCountry(countryId) {
    const response = await fetch(`${API_BASE_URL}/catalog/countries`);
    const result = await response.json();

    if (!response.ok || !result.success) {
        throw new Error(result.message || "Could not load countries.");
    }

    const country = result.data.find(
        item => Number(item.country_id) === Number(countryId)
    );

    if (!country) {
        throw new Error("Country not found.");
    }

    const title = country.page_title || `Study in ${country.country_name}`;
    const description = country.page_description ||
        `Find experienced study abroad mentors for ${country.country_name}.`;

    countryTitle.textContent = title;
    countryDescription.textContent = description;
    mentorHeading.textContent = `Mentors for ${country.country_name}`;

    document.title = `${title} | AbroadMates`;

    document.querySelector('meta[name="description"]')
        ?.setAttribute("content", description);

    return country;
}

// Load mentors for the selected country.
async function loadCountryMentors(countryId) {
    const params = new URLSearchParams({
        countryId: countryId
    });

    const response = await fetch(
        `${API_BASE_URL}/catalog/mentors?${params.toString()}`
    );

    const result = await response.json();

    if (!response.ok || !result.success) {
        throw new Error(result.message || "Could not load mentors.");
    }

    const mentors = result.data || [];

    mentorCount.textContent =
        `${mentors.length} mentor${mentors.length === 1 ? "" : "s"} found`;

    renderMentors(mentors);
}

// Render mentor cards.
function renderMentors(mentors) {
    if (!mentors.length) {
        mentorList.innerHTML = `
            <div class="empty-state">
                <h3>No mentors available yet</h3>
                <p>There are currently no published mentors for this destination.</p>
            </div>
        `;
        return;
    }

    mentorList.innerHTML = mentors.map(mentor => {
        const photoUrl = getPhotoUrl(mentor.profile_photo_path);

        const rating = Number(mentor.average_rating || 0);
        const reviewCount = Number(mentor.review_count || 0);
        const sessionCount = Number(mentor.session_count || 0);

        const price = mentor.min_price !== null &&
            mentor.min_price !== undefined
            ? `Starting from ${escapeHTML(mentor.min_price)}`
            : "Price not available";

        return `
            <article class="mentor-card">

                ${
                    photoUrl
                        ? `
                            <img
                                class="mentor-photo"
                                src="${escapeHTML(photoUrl)}"
                                alt="${escapeHTML(mentor.full_name)}"
                                onerror="this.style.display='none'"
                            >
                        `
                        : ""
                }

                <h3>${escapeHTML(mentor.full_name)}</h3>

                <p class="mentor-headline">
                    ${escapeHTML(mentor.headline || "Study abroad mentor")}
                </p>

                <p class="mentor-meta">
                    Experience: ${Number(mentor.years_experience || 0)} years
                </p>

                <p class="mentor-meta">
                    Rating: ${rating.toFixed(1)} / 5
                    (${reviewCount} reviews)
                </p>

                <p class="mentor-meta">
                    ${sessionCount} sessions
                </p>

                <p class="mentor-price">
                    ${price}
                </p>

                <a
                    class="view-profile-btn"
                    href="./mentor-details.html?id=${encodeURIComponent(mentor.mentor_id)}"
                >
                    View Mentor Profile
                </a>

            </article>
        `;
    }).join("");
}

// Initialize the page.
async function initializePage() {
    const countryId = getCountryId();

    if (!countryId || !/^\d+$/.test(countryId)) {
        mentorList.innerHTML = "";
        showError("Invalid country selection. Please select a country first.");
        mentorCount.textContent = "";
        return;
    }

    try {
        const country = await loadCountry(countryId);

        await loadCountryMentors(country.country_id);

    } catch (error) {
        mentorList.innerHTML = "";
        mentorCount.textContent = "";
        showError(error.message);
    }
}

initializePage();

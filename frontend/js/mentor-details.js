const API = "http://localhost:5000/api";
const SERVER = "http://localhost:5000";

const token = localStorage.getItem("abroadmates_token");

const params = new URLSearchParams(window.location.search);
const mentorId = Number(params.get("id"));

const loadingMessage = document.getElementById("loadingMessage");
const errorMessage = document.getElementById("errorMessage");
const mentorContent = document.getElementById("mentorContent");

const bookingForm = document.getElementById("bookingForm");
const planSelect = document.getElementById("planSelect");
const bookingDate = document.getElementById("bookingDate");
const studentNote = document.getElementById("studentNote");
const bookingMessage = document.getElementById("bookingMessage");
const bookingSubmit = document.getElementById("bookingSubmit");
const selectedPlanInfo = document.getElementById("selectedPlanInfo");

let mentorData = null;

if (!token) {
    window.location.href = "./auth.html";
}

function showError(message) {
    loadingMessage.hidden = true;
    mentorContent.hidden = true;
    errorMessage.hidden = false;
    errorMessage.textContent = message;
}

async function loadMentorDetails() {
    if (!Number.isInteger(mentorId) || mentorId <= 0) {
        showError("Invalid mentor profile link.");
        return;
    }

    try {
        const response = await fetch(
            `${API}/catalog/mentors/${mentorId}`
        );

        const result = await response.json();

        if (!response.ok || !result.success) {
            throw new Error(result.message || "Could not load mentor.");
        }

        mentorData = result.data;

        renderProfile(mentorData);
        loadingMessage.hidden = true;
        mentorContent.hidden = false;

    } catch (error) {
        console.error(error);
        showError(error.message);
    }
}

function renderProfile(data) {
    const profile = data.profile;

    document.getElementById("mentorName").textContent =
        profile.full_name;

    document.getElementById("mentorHeadline").textContent =
        profile.headline || "Study abroad mentor";

    document.getElementById("mentorExperience").textContent =
        `${profile.years_experience || 0} years of experience`;

    document.getElementById("mentorBio").textContent =
        profile.bio || "No biography provided yet.";

    const photo = document.getElementById("mentorPhoto");

    photo.src = profile.profile_photo_path
        ? `${SERVER}/${profile.profile_photo_path}`
        : "./images/default-mentor.png";

    photo.onerror = () => {
        photo.src = "./images/default-mentor.png";
    };

    renderTags("mentorCountries", data.countries, "country_name");

    renderUniversities(data.universities);

    renderTags("mentorPrograms", data.programs, "program_name");

    renderTags("mentorServices", data.services, "service_name");

    renderScholarships(data.scholarships);

    renderPlans(data.plans);
}

function renderTags(elementId, items, field) {
    const container = document.getElementById(elementId);
    container.innerHTML = "";

    if (!items || items.length === 0) {
        container.innerHTML = '<span class="md-empty">Not specified yet.</span>';
        return;
    }

    items.forEach(item => {
        const tag = document.createElement("span");
        tag.className = "md-tag";
        tag.textContent = item[field];
        container.appendChild(tag);
    });
}

function renderUniversities(universities) {
    const container = document.getElementById("mentorUniversities");
    container.innerHTML = "";

    if (!universities || universities.length === 0) {
        container.innerHTML = '<p class="md-empty">No universities added yet.</p>';
        return;
    }

    universities.forEach(university => {
        const item = document.createElement("div");
        item.className = "md-university";

        const name = document.createElement("strong");
        name.textContent = university.university_name;

        const country = document.createElement("span");
        country.textContent = university.country_name;

        item.append(name, country);
        container.appendChild(item);
    });
}

function renderScholarships(scholarships) {
    const container = document.getElementById("mentorScholarships");
    container.innerHTML = "";

    if (!scholarships || scholarships.length === 0) {
        container.innerHTML =
            '<p class="md-empty">No scholarships added yet.</p>';
        return;
    }

    scholarships.forEach(scholarship => {
        const item = document.createElement("div");
        item.className = "md-university";

        const name = document.createElement("strong");
        name.textContent = scholarship.scholarship_name;

        const provider = document.createElement("span");
        provider.textContent =
            `${scholarship.provider_name || "Provider not specified"} · ${scholarship.country_name || ""}`;

        item.append(name, provider);
        container.appendChild(item);
    });
}

function renderPlans(plans) {
    planSelect.innerHTML = '<option value="">Choose a plan</option>';

    if (!plans || plans.length === 0) {
        planSelect.disabled = true;
        bookingSubmit.disabled = true;
        selectedPlanInfo.textContent = "No active consultation plans available.";
        return;
    }

    plans.forEach(plan => {
        const option = document.createElement("option");

        option.value = plan.plan_id;
        option.textContent =
            `${plan.duration_minutes} minutes — ${plan.price} ${plan.currency}`;

        option.dataset.duration = plan.duration_minutes;
        option.dataset.price = plan.price;
        option.dataset.currency = plan.currency;

        planSelect.appendChild(option);
    });
}

planSelect.addEventListener("change", () => {
    const option = planSelect.selectedOptions[0];

    if (!option || !option.value) {
        selectedPlanInfo.textContent =
            "Select a consultation plan to see its price.";
        return;
    }

    selectedPlanInfo.textContent =
        `${option.dataset.duration} minutes · ${option.dataset.price} ${option.dataset.currency}`;
});

// Prevent selecting a date/time in the past.
function setMinimumBookingDate() {
    const now = new Date();
    now.setMinutes(now.getMinutes() - now.getTimezoneOffset());

    bookingDate.min = now.toISOString().slice(0, 16);
}

setMinimumBookingDate();

bookingForm.addEventListener("submit", async event => {
    event.preventDefault();

    bookingMessage.textContent = "";
    bookingMessage.className = "";

    if (!planSelect.value) {
        bookingMessage.textContent = "Please choose a consultation plan.";
        bookingMessage.className = "md-error-text";
        return;
    }

    if (!bookingDate.value) {
        bookingMessage.textContent = "Please select a date and time.";
        bookingMessage.className = "md-error-text";
        return;
    }

    const selectedDate = new Date(bookingDate.value);

    if (Number.isNaN(selectedDate.getTime()) || selectedDate <= new Date()) {
        bookingMessage.textContent =
            "Please choose a future date and time.";
        bookingMessage.className = "md-error-text";
        return;
    }

    bookingSubmit.disabled = true;
    bookingSubmit.textContent = "Submitting...";

    try {
        const response = await fetch(`${API}/bookings`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${token}`
            },
            body: JSON.stringify({
                mentorId,
                planId: Number(planSelect.value),
                scheduledAt: bookingDate.value,
                studentNote: studentNote.value.trim()
            })
        });

        const result = await response.json();

        if (!response.ok || !result.success) {
            throw new Error(result.message || "Booking failed.");
        }

        bookingMessage.textContent =
            `Booking request submitted successfully! Booking ID: ${result.data.booking_id}. Status: Pending.`;

        bookingMessage.className = "md-success";

        bookingForm.reset();

        selectedPlanInfo.textContent =
            "Select a consultation plan to see its price.";

    } catch (error) {
        console.error(error);

        bookingMessage.textContent = error.message;
        bookingMessage.className = "md-error-text";

    } finally {
        bookingSubmit.disabled = false;
        bookingSubmit.textContent = "Request Booking";
    }
});

document.getElementById("logoutBtn").addEventListener("click", () => {
    localStorage.removeItem("abroadmates_token");
    localStorage.removeItem("abroadmates_user");
    window.location.href = "./auth.html";
});

loadMentorDetails();
const API_URL = "http://localhost:5000/api";

// Get authentication token
const token = localStorage.getItem("abroadmates_token");

// HTML elements
const profileForm = document.getElementById("profileForm");
const messageBox = document.getElementById("messageBox");

const headlineInput = document.getElementById("headline");
const bioInput = document.getElementById("bio");
const experienceInput = document.getElementById("yearsExperience");

const saveButton = document.getElementById("saveButton");

const plansContainer = document.getElementById("plansContainer");
const countriesContainer = document.getElementById("countriesContainer");
const universitiesContainer = document.getElementById("universitiesContainer");


// -------------------------------------
// Authentication
// -------------------------------------

if (!token) {
    window.location.replace("auth.html");
}


// -------------------------------------
// Show messages
// -------------------------------------

function showMessage(message, type) {
    messageBox.textContent = message;
    messageBox.className = `message-box ${type}`;
}


// -------------------------------------
// Safe HTML output
// -------------------------------------

function escapeHTML(value) {
    return String(value ?? "").replace(/[&<>"']/g, character => {
        const entities = {
            "&": "&amp;",
            "<": "&lt;",
            ">": "&gt;",
            '"': "&quot;",
            "'": "&#039;"
        };

        return entities[character];
    });
}


// -------------------------------------
// API request helper
// -------------------------------------

async function apiRequest(url, options = {}) {

    const response = await fetch(url, {
        ...options,

        headers: {
            "Authorization": `Bearer ${token}`,
            ...(options.headers || {})
        }
    });

    const result = await response.json();

    if (response.status === 401 || response.status === 403) {
        localStorage.removeItem("token");
        window.location.replace("auth.html");

        throw new Error("Your session has expired. Please log in again.");
    }

    if (!response.ok || result.success === false) {
        throw new Error(
            result.message || "Something went wrong with the API request."
        );
    }

    return result;
}


// -------------------------------------
// Normalize stored procedure data
// -------------------------------------

function normalizeProfileResponse(result) {

    const data = result.data;

    // Expected format:
    // {
    //   profile: {...},
    //   plans: [...],
    //   countries: [...],
    //   universities: [...]
    // }

    if (data && !Array.isArray(data)) {
        return data;
    }

    // Some mysql2 CALL responses return result sets as arrays.
    // This supports a common format:
    // [ [profileRows], [planRows], [countryRows], [universityRows] ]

    if (Array.isArray(data) && Array.isArray(data[0])) {

        return {
            profile: data[0][0] || {},
            plans: data[1] || [],
            countries: data[2] || [],
            universities: data[3] || []
        };
    }

    // Another common API format:
    // { profile: [], plans: [], countries: [], universities: [] }

    if (Array.isArray(data)) {
        return {
            profile: data[0] || {},
            plans: [],
            countries: [],
            universities: []
        };
    }

    return {
        profile: {},
        plans: [],
        countries: [],
        universities: []
    };
}


// -------------------------------------
// Load mentor profile
// -------------------------------------

async function loadProfile() {

    if (!token) return;

    try {

        const result = await apiRequest(
            `${API_URL}/mentor/profile/me`
        );

        const profileData = normalizeProfileResponse(result);

        const profile = profileData.profile || {};

        headlineInput.value = profile.headline || "";
        bioInput.value = profile.bio || "";

        experienceInput.value =
            profile.years_experience ?? 0;

        renderPlans(profileData.plans || []);

        renderCountries(profileData.countries || []);

        renderUniversities(profileData.universities || []);

    } catch (error) {

        console.error("Profile loading error:", error);

        showMessage(error.message, "error");

        plansContainer.innerHTML =
            '<p class="muted">Unable to load plans.</p>';

        countriesContainer.innerHTML =
            '<p class="muted">Unable to load countries.</p>';

        universitiesContainer.innerHTML =
            '<p class="muted">Unable to load universities.</p>';
    }
}


// -------------------------------------
// Render consultation plans
// -------------------------------------

function renderPlans(plans) {

    if (!Array.isArray(plans) || plans.length === 0) {

        plansContainer.innerHTML =
            '<p class="muted">No consultation plans added yet.</p>';

        return;
    }

    plansContainer.innerHTML = plans.map(plan => {

        const duration = escapeHTML(plan.duration_minutes);
        const currency = escapeHTML(plan.currency || "");
        const price = escapeHTML(plan.price ?? "");

        return `
            <div class="plan-item">
                <strong>${duration}-minute session</strong>
                <span>${currency} ${price}</span>
            </div>
        `;

    }).join("");
}


// -------------------------------------
// Render countries
// -------------------------------------

function renderCountries(countries) {

    if (!Array.isArray(countries) || countries.length === 0) {

        countriesContainer.innerHTML =
            '<p class="muted">No countries selected yet.</p>';

        return;
    }

    countriesContainer.innerHTML = countries.map(country => {

        const name =
            country.country_name ||
            country.name ||
            "Country";

        return `
            <span class="tag-item">
                ${escapeHTML(name)}
            </span>
        `;

    }).join("");
}


// -------------------------------------
// Render universities
// -------------------------------------

function renderUniversities(universities) {

    if (!Array.isArray(universities) || universities.length === 0) {

        universitiesContainer.innerHTML =
            '<p class="muted">No universities selected yet.</p>';

        return;
    }

    universitiesContainer.innerHTML = universities.map(university => {

        const name =
            university.university_name ||
            university.name ||
            "University";

        return `
            <span class="tag-item">
                ${escapeHTML(name)}
            </span>
        `;

    }).join("");
}


// -------------------------------------
// Save mentor profile
// -------------------------------------

profileForm.addEventListener("submit", async function(event) {

    event.preventDefault();

    const yearsExperience = Number(experienceInput.value);

    if (
        !Number.isInteger(yearsExperience) ||
        yearsExperience < 0 ||
        yearsExperience > 60
    ) {

        showMessage(
            "Please enter a valid experience value between 0 and 60.",
            "error"
        );

        return;
    }

    const profileData = {
        headline: headlineInput.value.trim(),
        bio: bioInput.value.trim(),
        years_experience: yearsExperience
    };

    saveButton.disabled = true;
    saveButton.textContent = "Saving...";

    try {

        await apiRequest(
            `${API_URL}/mentor/profile/me`,
            {
                method: "PUT",

                headers: {
                    "Content-Type": "application/json"
                },

                body: JSON.stringify(profileData)
            }
        );

        showMessage(
            "Your mentor profile has been saved successfully!",
            "success"
        );

    } catch (error) {

        console.error("Profile saving error:", error);

        showMessage(error.message, "error");

    } finally {

        saveButton.disabled = false;
        saveButton.textContent = "Save Profile";
    }
});


// -------------------------------------
// Logout
// -------------------------------------

document.getElementById("logoutButton").addEventListener("click", function() {

    localStorage.removeItem("abroadmates_token");
    localStorage.removeItem("abroadmates_user");

    window.location.replace("auth.html");
});


// -------------------------------------
// Start page
// -------------------------------------

loadProfile();
const API_BASE = "http://localhost:5000/api";
const token = localStorage.getItem("abroadmates_token");

if (!token) {
    window.location.href = "./auth.html";
}

const countriesList = document.getElementById("countriesList");
const universitiesList = document.getElementById("universitiesList");
const expertiseForm = document.getElementById("expertiseForm");
const saveButton = document.getElementById("saveButton");
const statusMessage = document.getElementById("statusMessage");

let allCountries = [];
let selectedUniversityIds = new Set();

function getRows(response) {
    if (Array.isArray(response)) return response;
    if (Array.isArray(response?.data)) return response.data;
    return [];
}

async function apiRequest(url, options = {}) {
    const response = await fetch(`${API_BASE}${url}`, {
        ...options,
        headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
            ...(options.headers || {})
        }
    });

    const result = await response.json();

    if (!response.ok || result.success === false) {
        throw new Error(result.message || "Request failed.");
    }

    return result;
}

// Load countries from your existing catalog API
async function loadCountries() {
    try {
        const response = await apiRequest("/catalog/countries");
        allCountries = getRows(response);

        countriesList.innerHTML = "";

        if (allCountries.length === 0) {
            countriesList.textContent = "No active countries found.";
            return;
        }

        allCountries.forEach(country => {
            const id = Number(country.country_id);

            const label = document.createElement("label");
            label.className = "selection-item";

            const checkbox = document.createElement("input");
            checkbox.type = "checkbox";
            checkbox.className = "country-checkbox";
            checkbox.value = id;
            checkbox.dataset.countryName = country.country_name;

            checkbox.addEventListener("change", () => {
                loadUniversities();
            });

            const text = document.createElement("span");
            text.textContent = country.country_name;

            label.append(checkbox, text);
            countriesList.appendChild(label);
        });

    } catch (error) {
        countriesList.textContent = error.message;
    }
}

function getSelectedCountryIds() {
    return Array.from(
        document.querySelectorAll(".country-checkbox:checked")
    ).map(input => Number(input.value));
}

// Load universities for all selected countries
async function loadUniversities() {
    const countryIds = getSelectedCountryIds();

    universitiesList.innerHTML = "";
    selectedUniversityIds.clear();

    if (countryIds.length === 0) {
        universitiesList.innerHTML =
            '<p class="empty-message">Select a country first.</p>';
        return;
    }

    for (const countryId of countryIds) {
        const country = allCountries.find(
            item => Number(item.country_id) === countryId
        );

        const group = document.createElement("div");
        group.className = "country-university-group";

        const heading = document.createElement("h3");
        heading.textContent = country?.country_name || "Universities";

        const grid = document.createElement("div");
        grid.className = "university-grid";
        grid.textContent = "Loading universities...";

        group.append(heading, grid);
        universitiesList.appendChild(group);

        try {
            const response = await apiRequest(
                `/catalog/countries/${countryId}/universities`
            );

            const universities = getRows(response);
            grid.innerHTML = "";

            if (universities.length === 0) {
                grid.textContent = "No universities found for this country.";
                continue;
            }

            universities.forEach(university => {
                const universityId = Number(university.university_id);

                const label = document.createElement("label");
                label.className = "selection-item";

                const checkbox = document.createElement("input");
                checkbox.type = "checkbox";
                checkbox.className = "university-checkbox";
                checkbox.value = universityId;

                checkbox.addEventListener("change", () => {
                    if (checkbox.checked) {
                        selectedUniversityIds.add(universityId);
                    } else {
                        selectedUniversityIds.delete(universityId);
                    }
                });

                const text = document.createElement("span");
                text.textContent = university.university_name;

                label.append(checkbox, text);
                grid.appendChild(label);
            });

        } catch (error) {
            grid.textContent = error.message;
        }
    }
}

// Load previously saved expertise and consultation plans
async function loadSavedExpertise() {
    try {
        const response = await apiRequest("/mentor/expertise/me");
        const data = response.data || {};

        const savedCountryIds = (data.countries || []).map(
            item => Number(item.country_id)
        );

        selectedUniversityIds = new Set(
            (data.universities || []).map(
                item => Number(item.university_id)
            )
        );

        document.querySelectorAll(".country-checkbox").forEach(checkbox => {
            checkbox.checked = savedCountryIds.includes(
                Number(checkbox.value)
            );
        });

        await loadUniversities();

        document.querySelectorAll(".university-checkbox").forEach(checkbox => {
            checkbox.checked = selectedUniversityIds.has(
                Number(checkbox.value)
            );
        });

        const plans = data.plans || [];

        const plan20 = plans.find(
            plan => Number(plan.duration_minutes) === 20
        );

        const plan40 = plans.find(
            plan => Number(plan.duration_minutes) === 40
        );

        if (plan20) {
            document.getElementById("price20").value = plan20.price;
            document.getElementById("currency20").value = plan20.currency;
        }

        if (plan40) {
            document.getElementById("price40").value = plan40.price;
            document.getElementById("currency40").value = plan40.currency;
        }

    } catch (error) {
        statusMessage.textContent = error.message;
    }
}

function collectPlans() {
    const plans = [];

    const price20 = document.getElementById("price20").value.trim();
    const price40 = document.getElementById("price40").value.trim();

    if (price20 !== "") {
        plans.push({
            duration_minutes: 20,
            price: price20,
            currency: document.getElementById("currency20").value
        });
    }

    if (price40 !== "") {
        plans.push({
            duration_minutes: 40,
            price: price40,
            currency: document.getElementById("currency40").value
        });
    }

    return plans;
}

// Save everything without reloading the page
expertiseForm.addEventListener("submit", async event => {
    event.preventDefault();

    statusMessage.textContent = "";
    saveButton.disabled = true;
    saveButton.textContent = "Saving...";

    const countryIds = getSelectedCountryIds();

    const universityIds = Array.from(
        document.querySelectorAll(".university-checkbox:checked")
    ).map(input => Number(input.value));

    const plans = collectPlans();

    try {
        const result = await apiRequest("/mentor/expertise/me", {
            method: "PUT",
            body: JSON.stringify({
                countryIds,
                universityIds,
                plans
            })
        });

        statusMessage.textContent = result.message;
    } catch (error) {
        statusMessage.textContent = error.message;
    } finally {
        saveButton.disabled = false;
        saveButton.textContent = "Save my expertise";
    }
});

// Initial page loading
async function initializePage() {
    await loadCountries();
    await loadSavedExpertise();
}

initializePage();
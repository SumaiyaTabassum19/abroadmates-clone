const API_BASE_URL = "http://localhost:5000/api";

const sessionList = document.getElementById("sessionList");
const categoryFilter = document.getElementById("categoryFilter");
const messageBox = document.getElementById("message");
const sessionCount = document.getElementById("sessionCount");
const resultsTitle = document.getElementById("resultsTitle");

const resetFilter = document.getElementById("resetFilter");
const logoutBtn = document.getElementById("logoutBtn");

let currentView = "upcoming";

// Escape HTML to prevent unsafe content from being inserted into the page.
function escapeHTML(value) {
    return String(value ?? "").replace(/[&<>"']/g, character => ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#039;"
    })[character]);
}

// Format MySQL DATETIME values.
function formatDate(value) {
    if (!value) return "Not available";

    const normalized = String(value).replace(" ", "T");
    const date = new Date(normalized);

    if (Number.isNaN(date.getTime())) {
        return value;
    }

    return date.toLocaleString([], {
        dateStyle: "medium",
        timeStyle: "short"
    });
}

// Display success or error messages.
function showMessage(message, type = "success") {
    messageBox.textContent = message;
    messageBox.className = `message ${type}`;
}

function clearMessage() {
    messageBox.textContent = "";
    messageBox.className = "message";
}

// Load session categories.
async function loadCategories() {
    try {
        const response = await fetch(
            `${API_BASE_URL}/group-sessions/categories`
        );

        const result = await response.json();

        if (!response.ok || !result.success) {
            throw new Error(result.message || "Could not load categories.");
        }

        categoryFilter.innerHTML =
            '<option value="">All Categories</option>';

        result.data.forEach(category => {
            const option = document.createElement("option");

            option.value = category.category_id;
            option.textContent = category.category_name;

            categoryFilter.appendChild(option);
        });

    } catch (error) {
        showMessage(error.message, "error");
    }
}

// Render session cards.
function renderSessions(sessions) {
    sessionCount.textContent =
        `${sessions.length} session${sessions.length === 1 ? "" : "s"}`;

    if (!sessions.length) {
        sessionList.innerHTML = `
            <div class="empty-state">
                <h3>No sessions found</h3>
                <p>Try another category or check the other tab.</p>
            </div>
        `;
        return;
    }

    sessionList.innerHTML = sessions.map(session => {
        const capacity = Number(session.capacity || 0);
        const registered = Number(session.registered_count || 0);

        const remaining = Math.max(0, capacity - registered);

        const percentage = capacity > 0
            ? Math.min(100, (registered / capacity) * 100)
            : 0;

        const isFull = remaining <= 0;
        const isUpcoming = currentView === "upcoming";

        let actionHTML = "";

        if (isUpcoming && isFull) {
            actionHTML = `
                <span class="closed-label">
                    Session full
                </span>
            `;
        } else if (isUpcoming) {
            actionHTML = `
                <button
                    type="button"
                    class="register-btn"
                    data-session-id="${escapeHTML(session.session_id)}"
                    ${String(session.status) !== "scheduled" ? "disabled" : ""}
                >
                    Register
                </button>
            `;
        } else {
            actionHTML = `
                <span class="closed-label">
                    Registration closed
                </span>
            `;
        }

        return `
            <article class="session-card">

                <span class="category-label">
                    ${escapeHTML(session.category_name)}
                </span>

                <h3>${escapeHTML(session.title)}</h3>

                <p class="session-description">
                    ${escapeHTML(
                        session.description || "No description provided."
                    )}
                </p>

                <div class="session-info">

                    <div class="info-row">
                        <span>Mentor</span>
                        <strong>${escapeHTML(session.mentor_name)}</strong>
                    </div>

                    <div class="info-row">
                        <span>Starts</span>
                        <strong>${escapeHTML(formatDate(session.starts_at))}</strong>
                    </div>

                    <div class="info-row">
                        <span>Ends</span>
                        <strong>${escapeHTML(formatDate(session.ends_at))}</strong>
                    </div>

                    <div class="info-row">
                        <span>Participants</span>
                        <strong>${registered} / ${capacity}</strong>
                    </div>

                </div>

                <div class="capacity-track">
                    <div
                        class="capacity-fill"
                        style="width: ${percentage}%"
                    ></div>
                </div>

                <p class="capacity-text">
                    ${remaining} seat${remaining === 1 ? "" : "s"} remaining
                </p>

                ${actionHTML}

            </article>
        `;
    }).join("");

    // Attach one click handler to each Register button.
    sessionList.querySelectorAll(".register-btn").forEach(button => {
        button.addEventListener("click", () => {
            registerForSession(button.dataset.sessionId, button);
        });
    });
}

// Load upcoming or past sessions.
async function loadSessions() {
    clearMessage();

    resultsTitle.textContent =
        currentView === "upcoming"
            ? "Upcoming Sessions"
            : "Past Sessions";

    sessionList.innerHTML =
        '<p class="loading">Loading sessions...</p>';

    const categoryId = categoryFilter.value;

    const params = new URLSearchParams({
        view: currentView
    });

    if (categoryId) {
        params.set("categoryId", categoryId);
    }

    try {
        const response = await fetch(
            `${API_BASE_URL}/group-sessions?${params.toString()}`
        );

        const result = await response.json();

        if (!response.ok || !result.success) {
            throw new Error(result.message || "Could not load sessions.");
        }

        renderSessions(result.data || []);

    } catch (error) {
        sessionList.innerHTML = "";
        showMessage(error.message, "error");
    }
}

// Register a student for a group session.
async function registerForSession(sessionId, button) {
    const token = localStorage.getItem("abroadmates_token");

    if (!token) {
        window.location.href = "./auth.html";
        return;
    }

    button.disabled = true;
    button.textContent = "Registering...";

    clearMessage();

    try {
        const response = await fetch(
            `${API_BASE_URL}/student/group-sessions/${sessionId}/register`,
            {
                method: "POST",
                headers: {
                    Authorization: `Bearer ${token}`
                }
            }
        );

        const result = await response.json();

        if (response.status === 401 || response.status === 403) {
            throw new Error(
                "Please log in with a Student account to register."
            );
        }

        if (!response.ok || !result.success) {
            throw new Error(result.message || "Registration failed.");
        }

        showMessage(
            "You have successfully registered for this session."
        );

        // Refresh the session list after successful registration.
        await loadSessions();

    } catch (error) {
        showMessage(error.message, "error");

        button.disabled = false;
        button.textContent = "Register";
    }
}

// Upcoming / Past tabs.
document.querySelectorAll(".tab").forEach(tab => {
    tab.addEventListener("click", () => {
        document.querySelectorAll(".tab").forEach(item => {
            item.classList.remove("active");
        });

        tab.classList.add("active");

        currentView = tab.dataset.view;

        loadSessions();
    });
});

// Category filter.
categoryFilter.addEventListener("change", loadSessions);

// Reset filters.
resetFilter.addEventListener("click", () => {
    categoryFilter.value = "";
    loadSessions();
});

// Logout.
logoutBtn.addEventListener("click", () => {
    localStorage.removeItem("abroadmates_token");
    localStorage.removeItem("abroadmates_user");

    window.location.href = "./auth.html";
});

// Initialize page.
async function initializePage() {
    await loadCategories();
    await loadSessions();
}

initializePage();

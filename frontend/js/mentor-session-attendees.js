const API_BASE_URL = "http://localhost:5000/api";

const token = localStorage.getItem("abroadmates_token");

const attendeeList = document.getElementById("attendeeList");
const sessionTitle = document.getElementById("sessionTitle");
const sessionDate = document.getElementById("sessionDate");
const sessionStatus = document.getElementById("sessionStatus");
const messageBox = document.getElementById("message");

const refreshBtn = document.getElementById("refreshBtn");
const logoutBtn = document.getElementById("logoutBtn");

const params = new URLSearchParams(window.location.search);
const sessionId = Number(params.get("id"));

if (!token) {
    window.location.href = "./auth.html";
}

if (!Number.isInteger(sessionId) || sessionId <= 0) {
    sessionTitle.textContent = "Invalid session";
    attendeeList.innerHTML = `
        <p class="empty-state">Please open this page from your session management list.</p>
    `;
}

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

    if (Number.isNaN(date.getTime())) return value;

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

async function apiRequest(url, options = {}) {
    const response = await fetch(url, {
        ...options,
        headers: {
            Authorization: `Bearer ${token}`,
            ...(options.body ? { "Content-Type": "application/json" } : {}),
            ...options.headers
        }
    });

    const result = await response.json();

    if (response.status === 401 || response.status === 403) {
        localStorage.removeItem("abroadmates_token");
        localStorage.removeItem("abroadmates_user");
        window.location.href = "./auth.html";
        throw new Error("Your login session expired or you do not have Mentor access.");
    }

    if (!response.ok || result.success === false) {
        throw new Error(result.message || "Request failed.");
    }

    return result;
}

function renderAttendees(registrations, session) {
    const sessionHasEnded =
        new Date(String(session.ends_at).replace(" ", "T")) <= new Date();

    if (!registrations.length) {
        attendeeList.innerHTML = `
            <p class="empty-state">
                No students have registered for this session yet.
            </p>
        `;
        return;
    }

    attendeeList.innerHTML = registrations.map(student => {
        const status = String(student.registration_status || "registered");

        const canMarkAttended =
            sessionHasEnded && status === "registered";

        return `
            <article class="attendee-card">
                <div>
                    <div class="student-name">
                        ${escapeHTML(student.student_name)}
                    </div>

                    <div class="student-email">
                        ${escapeHTML(student.student_email)}
                    </div>

                    <div class="registered-date">
                        Registered: ${escapeHTML(formatDate(student.registered_at))}
                    </div>

                    <span class="attendee-status ${escapeHTML(status)}">
                        ${escapeHTML(status)}
                    </span>
                </div>

                <div>
                    ${canMarkAttended ? `
                        <button
                            class="attendance-btn"
                            data-registration-id="${escapeHTML(student.registration_id)}"
                        >
                            Mark Attended
                        </button>
                    ` : ""}
                </div>
            </article>
        `;
    }).join("");

    attendeeList.querySelectorAll(".attendance-btn").forEach(button => {
        button.addEventListener("click", () => {
            markAttended(button.dataset.registrationId, button);
        });
    });
}

async function loadRegistrations() {
    if (!Number.isInteger(sessionId) || sessionId <= 0) return;

    clearMessage();
    attendeeList.innerHTML =
        '<p class="loading">Loading registrations...</p>';

    try {
        const result = await apiRequest(
            `${API_BASE_URL}/mentor/registrations/sessions/${sessionId}/registrations`
        );

        const session = result.session;

        sessionTitle.textContent = session.title;
        sessionDate.textContent =
            `Starts: ${formatDate(session.starts_at)} | Ends: ${formatDate(session.ends_at)}`;

        sessionStatus.textContent =
            `Session status: ${session.status}`;

        renderAttendees(result.data || [], session);

    } catch (error) {
        attendeeList.innerHTML = "";
        showMessage(error.message, "error");
    }
}

async function markAttended(registrationId, button) {
    button.disabled = true;
    button.textContent = "Updating...";

    try {
        const result = await apiRequest(
            `${API_BASE_URL}/mentor/registrations/registrations/${registrationId}/attended`,
            { method: "PATCH" }
        );

        showMessage(
            result.data?.message || "Attendance recorded successfully."
        );

        await loadRegistrations();

    } catch (error) {
        showMessage(error.message, "error");
        button.disabled = false;
        button.textContent = "Mark Attended";
    }
}

refreshBtn.addEventListener("click", loadRegistrations);

logoutBtn.addEventListener("click", () => {
    localStorage.removeItem("abroadmates_token");
    localStorage.removeItem("abroadmates_user");
    window.location.href = "./auth.html";
});

loadRegistrations();
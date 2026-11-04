const API_BASE_URL = "http://localhost:5000/api";

const token = localStorage.getItem("abroadmates_token");

const sessionForm = document.getElementById("sessionForm");
const sessionList = document.getElementById("sessionList");
const categorySelect = document.getElementById("categoryId");
const messageBox = document.getElementById("message");

const sessionIdInput = document.getElementById("sessionId");
const titleInput = document.getElementById("title");
const descriptionInput = document.getElementById("description");
const startsAtInput = document.getElementById("startsAt");
const endsAtInput = document.getElementById("endsAt");
const capacityInput = document.getElementById("capacity");
const meetingLinkInput = document.getElementById("meetingLink");

const formTitle = document.getElementById("formTitle");
const saveBtn = document.getElementById("saveBtn");
const cancelEditBtn = document.getElementById("cancelEditBtn");
const resetFormBtn = document.getElementById("resetFormBtn");
const refreshBtn = document.getElementById("refreshBtn");
const logoutBtn = document.getElementById("logoutBtn");

if (!token) {
    window.location.href = "./auth.html";
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
        throw new Error("Your login session has expired or you do not have Mentor access.");
    }

    if (!response.ok || result.success === false) {
        throw new Error(result.message || "The request could not be completed.");
    }

    return result;
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

function toDateTimeLocal(value) {
    if (!value) return "";

    // MySQL DATETIME is returned as YYYY-MM-DD HH:mm:ss
    return String(value).replace(" ", "T").slice(0, 16);
}

async function loadCategories() {
    const result = await fetch(
        `${API_BASE_URL}/group-sessions/categories`
    );

    const data = await result.json();

    if (!result.ok || !data.success) {
        throw new Error(data.message || "Could not load categories.");
    }

    categorySelect.innerHTML =
        '<option value="">Select a category</option>';

    data.data.forEach(category => {
        const option = document.createElement("option");
        option.value = category.category_id;
        option.textContent = category.category_name;
        categorySelect.appendChild(option);
    });
}

function resetForm() {
    sessionForm.reset();
    sessionIdInput.value = "";
    capacityInput.value = 20;

    formTitle.textContent = "Create a Group Session";
    saveBtn.textContent = "Create Session";
    cancelEditBtn.classList.add("hidden");

    clearMessage();
}

function renderSessions(sessions) {
    if (!sessions.length) {
        sessionList.innerHTML = `
            <div class="empty-state">
                <h3>You haven't created any group sessions yet.</h3>
                <p>Use the form above to create your first session.</p>
            </div>
        `;
        return;
    }

    sessionList.innerHTML = sessions.map(session => {
        const registered = Number(session.registered_count || 0);
        const canManage =
            session.status === "scheduled" &&
            new Date(String(session.starts_at).replace(" ", "T")) > new Date();

        const meetingLink = session.meeting_link
            ? `<a class="meeting-link"
                  href="${escapeHTML(session.meeting_link)}"
                  target="_blank"
                  rel="noopener noreferrer">Open meeting link</a>`
            : "";

        return `
            <article class="session-card">
                <span class="category-label">
                    ${escapeHTML(session.category_name)}
                </span>

                <span class="session-status ${escapeHTML(session.status)}">
                    ${escapeHTML(session.status)}
                </span>

                <h3>${escapeHTML(session.title)}</h3>

                <p class="session-description">
                    ${escapeHTML(session.description || "No description provided.")}
                </p>

                <div class="session-details">
                    <div class="detail-item">
                        <span class="detail-label">Starts</span>
                        <span class="detail-value">
                            ${escapeHTML(formatDate(session.starts_at))}
                        </span>
                    </div>

                    <div class="detail-item">
                        <span class="detail-label">Ends</span>
                        <span class="detail-value">
                            ${escapeHTML(formatDate(session.ends_at))}
                        </span>
                    </div>

                    <div class="detail-item">
                        <span class="detail-label">Participants</span>
                        <span class="detail-value">
                            ${registered} / ${escapeHTML(session.capacity)}
                        </span>
                    </div>
                </div>

                ${meetingLink}

                ${canManage ? `
                    <div class="session-actions">
                        <button
                            class="edit-btn"
                            data-action="edit"
                            data-id="${escapeHTML(session.session_id)}"
                        >
                            Edit Session
                        </button>

                        <button
                            class="cancel-btn"
                            data-action="cancel"
                            data-id="${escapeHTML(session.session_id)}"
                        >
                            Cancel Session
                        </button>
                    </div>
                    ${`
    <div class="session-actions">
        <button
            class="edit-btn"
            data-action="edit"
            data-id="${escapeHTML(session.session_id)}"
            ${canManage ? "" : "disabled"}
        >
            Edit Session
        </button>

        <button
            class="cancel-btn"
            data-action="cancel"
            data-id="${escapeHTML(session.session_id)}"
            ${canManage ? "" : "disabled"}
        >
            Cancel Session
        </button>

        <button
            class="edit-btn"
            data-action="attendees"
            data-id="${escapeHTML(session.session_id)}"
        >
            View Attendees
        </button>
    </div>
`}
                ` : ""}
            </article>
        `;
    }).join("");

    sessionList.querySelectorAll("[data-action]").forEach(button => {
        button.addEventListener("click", () => {
            const session = sessions.find(
                item => Number(item.session_id) === Number(button.dataset.id)
            );

            if (!session) return;

            if (button.dataset.action === "edit") {
    editSession(session);
} else if (button.dataset.action === "cancel") {
    cancelSession(session.session_id);
} else if (button.dataset.action === "attendees") {
    window.location.href =
        `./mentor-session-attendees.html?id=${session.session_id}`;
}
        });
    });
}

async function loadSessions() {
    sessionList.innerHTML =
        '<p class="loading">Loading your sessions...</p>';

    try {
        const result = await apiRequest(
            `${API_BASE_URL}/mentor/group-sessions`
        );

        renderSessions(result.data || []);

    } catch (error) {
        sessionList.innerHTML = "";
        showMessage(error.message, "error");
    }
}

function editSession(session) {
    clearMessage();

    sessionIdInput.value = session.session_id;
    titleInput.value = session.title;
    descriptionInput.value = session.description || "";
    categorySelect.value = session.category_id;
    startsAtInput.value = toDateTimeLocal(session.starts_at);
    endsAtInput.value = toDateTimeLocal(session.ends_at);
    capacityInput.value = session.capacity;
    meetingLinkInput.value = session.meeting_link || "";

    formTitle.textContent = "Edit Group Session";
    saveBtn.textContent = "Save Changes";
    cancelEditBtn.classList.remove("hidden");

    window.scrollTo({
        top: 0,
        behavior: "smooth"
    });
}

async function cancelSession(sessionId) {
    const confirmed = window.confirm(
        "Are you sure you want to cancel this group session? Registered students will be marked as cancelled."
    );

    if (!confirmed) return;

    try {
        const result = await apiRequest(
            `${API_BASE_URL}/mentor/group-sessions/${sessionId}/cancel`,
            { method: "PATCH" }
        );

        showMessage(result.message || "Session cancelled successfully.");
        await loadSessions();

    } catch (error) {
        showMessage(error.message, "error");
    }
}

sessionForm.addEventListener("submit", async event => {
    event.preventDefault();
    clearMessage();

    const sessionId = sessionIdInput.value;

    const payload = {
        title: titleInput.value.trim(),
        description: descriptionInput.value.trim(),
        categoryId: categorySelect.value,
        startsAt: startsAtInput.value,
        endsAt: endsAtInput.value,
        capacity: capacityInput.value,
        meetingLink: meetingLinkInput.value.trim()
    };

    saveBtn.disabled = true;
    saveBtn.textContent = "Saving...";

    try {
        const url = sessionId
            ? `${API_BASE_URL}/mentor/group-sessions/${sessionId}`
            : `${API_BASE_URL}/mentor/group-sessions`;

        const result = await apiRequest(url, {
            method: sessionId ? "PUT" : "POST",
            body: JSON.stringify(payload)
        });

        showMessage(
            result.message ||
            (sessionId ? "Session updated." : "Session created.")
        );

        resetForm();
        await loadSessions();

    } catch (error) {
        showMessage(error.message, "error");
    } finally {
        saveBtn.disabled = false;
        saveBtn.textContent = sessionIdInput.value
            ? "Save Changes"
            : "Create Session";
    }
});

resetFormBtn.addEventListener("click", resetForm);
cancelEditBtn.addEventListener("click", resetForm);
refreshBtn.addEventListener("click", loadSessions);

logoutBtn.addEventListener("click", () => {
    localStorage.removeItem("abroadmates_token");
    localStorage.removeItem("abroadmates_user");
    window.location.href = "./auth.html";
});

async function initializePage() {
    try {
        await loadCategories();
        await loadSessions();
    } catch (error) {
        showMessage(error.message, "error");
    }
}

initializePage();
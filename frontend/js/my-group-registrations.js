const API_BASE = "http://localhost:5000/api";
const token = localStorage.getItem("abroadmates_token");

const registrationsElement = document.getElementById("registrations");
const messageElement = document.getElementById("message");

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
    const date = new Date(value);

    return Number.isNaN(date.getTime())
        ? "Date unavailable"
        : date.toLocaleString([], {
            dateStyle: "medium",
            timeStyle: "short"
        });
}

async function loadRegistrations() {
    if (!token) {
        window.location.href = "./auth.html";
        return;
    }

    try {
        const response = await fetch(
            `${API_BASE}/student/group-sessions/my`,
            {
                headers: {
                    Authorization: `Bearer ${token}`
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
            throw new Error(result.message || "Could not load registrations.");
        }

        renderRegistrations(result.data || []);

    } catch (error) {
        messageElement.textContent = error.message;
        registrationsElement.innerHTML = "";
    }
}

function renderRegistrations(registrations) {
    if (!registrations.length) {
        registrationsElement.innerHTML = `
            <div class="empty-state">
                <h3>No group session registrations yet</h3>
                <a href="./group-sessions.html">Browse group sessions</a>
            </div>
        `;
        return;
    }

    registrationsElement.innerHTML = registrations.map(item => {
        const status = String(item.registration_status || "").toLowerCase();

        const canCancel =
            status === "registered" &&
            item.session_status === "scheduled" &&
            new Date(item.starts_at).getTime() > Date.now();

        return `
            <article class="session-card">
                <h2>${escapeHTML(item.title)}</h2>

                <p>${escapeHTML(item.description || "")}</p>

                <div class="session-meta">
                    <div><strong>Mentor:</strong> ${escapeHTML(item.mentor_name)}</div>
                    <div><strong>Category:</strong> ${escapeHTML(item.category_name || "General")}</div>
                    <div><strong>Starts:</strong> ${escapeHTML(formatDate(item.starts_at))}</div>
                    <div><strong>Ends:</strong> ${escapeHTML(formatDate(item.ends_at))}</div>
                    <div><strong>Registered:</strong> ${escapeHTML(formatDate(item.registered_at))}</div>
                </div>

                <p>
                    <span class="status ${escapeHTML(status)}">
                        ${escapeHTML(status)}
                    </span>
                </p>

                ${
                    canCancel
                        ? `<button class="cancel-btn"
                                   data-registration-id="${escapeHTML(item.registration_id)}">
                               Cancel Registration
                           </button>`
                        : ""
                }
            </article>
        `;
    }).join("");
}

registrationsElement.addEventListener("click", async event => {
    const button = event.target.closest(".cancel-btn");

    if (!button) return;

    if (!confirm("Are you sure you want to cancel this registration?")) {
        return;
    }

    button.disabled = true;
    button.textContent = "Cancelling...";

    try {
        const response = await fetch(
            `${API_BASE}/student/group-sessions/registrations/${button.dataset.registrationId}/cancel`,
            {
                method: "PATCH",
                headers: {
                    Authorization: `Bearer ${token}`
                }
            }
        );

        const result = await response.json();

        if (!response.ok || !result.success) {
            throw new Error(result.message || "Cancellation failed.");
        }

        messageElement.textContent = "Registration cancelled successfully.";
        await loadRegistrations();

    } catch (error) {
        messageElement.textContent = error.message;
        button.disabled = false;
        button.textContent = "Cancel Registration";
    }
});

loadRegistrations();
const API_BASE_URL = "http://localhost:5000/api";

const token = localStorage.getItem("abroadmates_token");

const message = document.getElementById("message");
const bookingsBody = document.getElementById("bookingsBody");
const monthlyEarningsBody = document.getElementById("monthlyEarningsBody");

let currentBookings = [];

if (!token) {
    window.location.replace("./auth.html");
}

document.getElementById("logoutBtn").addEventListener("click", () => {
    localStorage.removeItem("abroadmates_token");
    localStorage.removeItem("abroadmates_user");
    window.location.replace("./auth.html");
});

function showMessage(text, type = "error") {
    message.textContent = text;
    message.className = `message ${type}`;
}

function clearMessage() {
    message.textContent = "";
    message.className = "message";
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

function formatMoney(value, currency = "BDT") {
    const amount = Number(value || 0);

    try {
        return new Intl.NumberFormat("en-BD", {
            style: "currency",
            currency,
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        }).format(amount);
    } catch {
        return `${currency} ${amount.toFixed(2)}`;
    }
}

function formatDate(value) {
    if (!value) return "Not available";

    const date = new Date(value);

    return Number.isNaN(date.getTime())
        ? String(value)
        : date.toLocaleString();
}

async function loadReport() {
    if (!token) return;

    clearMessage();

    bookingsBody.innerHTML =
        '<tr><td colspan="6">Loading bookings...</td></tr>';

    monthlyEarningsBody.innerHTML =
        '<tr><td colspan="3">Loading earnings...</td></tr>';

    const params = new URLSearchParams();

    const startDate = document.getElementById("startDate").value;
    const endDate = document.getElementById("endDate").value;
    const status = document.getElementById("statusFilter").value;

    if (startDate) params.set("startDate", startDate);
    if (endDate) params.set("endDate", endDate);

    params.set("status", status);

    try {
        const response = await fetch(
            `${API_BASE_URL}/mentor/reports/earnings?${params.toString()}`,
            {
                headers: {
                    Authorization: `Bearer ${token}`
                }
            }
        );

        const result = await response.json();

        if (response.status === 401 || response.status === 403) {
            throw new Error("Please log in using your Mentor account.");
        }

        if (!response.ok || !result.success) {
            throw new Error(result.message || "Could not load reports.");
        }

        const { summary, monthlyEarnings, bookings } = result.data;

        document.getElementById("totalBookings").textContent =
            Number(summary.totalBookings || 0);

        document.getElementById("pendingBookings").textContent =
            Number(summary.pendingBookings || 0);

        document.getElementById("confirmedBookings").textContent =
            Number(summary.confirmedBookings || 0);

        document.getElementById("completedBookings").textContent =
            Number(summary.completedBookings || 0);

        document.getElementById("cancelledBookings").textContent =
            Number(summary.cancelledBookings || 0);

        document.getElementById("totalEarnings").textContent =
            formatMoney(summary.totalEarnings, summary.currency || "BDT");

        currentBookings = bookings || [];

        renderMonthlyEarnings(monthlyEarnings || []);
        renderBookings(currentBookings);

        showMessage("Report updated successfully.", "success");

    } catch (error) {
        console.error("Report loading error:", error);

        bookingsBody.innerHTML =
            '<tr><td colspan="6">Could not load booking details.</td></tr>';

        monthlyEarningsBody.innerHTML =
            '<tr><td colspan="3">Could not load earnings.</td></tr>';

        showMessage(error.message);
    }
}

function renderMonthlyEarnings(rows) {
    monthlyEarningsBody.innerHTML = "";

    if (!rows.length) {
        monthlyEarningsBody.innerHTML =
            '<tr><td colspan="3">No completed earnings found for this period.</td></tr>';
        return;
    }

    rows.forEach(item => {
        const row = document.createElement("tr");

        const month = document.createElement("td");
        month.textContent = item.monthLabel || item.reportMonth;

        const count = document.createElement("td");
        count.textContent = Number(item.completedBookings || 0);

        const earnings = document.createElement("td");
        earnings.textContent = formatMoney(
            item.earnings,
            item.currency || "BDT"
        );

        row.append(month, count, earnings);
        monthlyEarningsBody.appendChild(row);
    });
}

function renderBookings(rows) {
    bookingsBody.innerHTML = "";

    if (!rows.length) {
        bookingsBody.innerHTML =
            '<tr><td colspan="6">No bookings found for these filters.</td></tr>';
        return;
    }

    rows.forEach(booking => {
        const row = document.createElement("tr");

        const values = [
            `#${booking.booking_id}`,
            `${booking.studentName || "Student"} (${booking.studentEmail || "No email"})`,
            `${Number(booking.durationMinutes || 0)} minutes`,
            formatMoney(booking.price, booking.currency || "BDT"),
            formatDate(booking.scheduledAt)
        ];

        values.forEach(value => {
            const cell = document.createElement("td");
            cell.textContent = value;
            row.appendChild(cell);
        });

        const statusCell = document.createElement("td");
        const badge = document.createElement("span");
        const status = String(booking.status || "").toLowerCase();

        badge.className = `status status-${status}`;
        badge.textContent = status
            ? status.charAt(0).toUpperCase() + status.slice(1)
            : "Unknown";

        statusCell.appendChild(badge);
        row.appendChild(statusCell);

        bookingsBody.appendChild(row);
    });
}

function exportCSV() {
    if (!currentBookings.length) {
        showMessage("There are no booking records to export.");
        return;
    }

    const headers = [
        "Booking ID",
        "Student",
        "Student Email",
        "Duration (minutes)",
        "Price",
        "Currency",
        "Scheduled At",
        "Status"
    ];

    const rows = currentBookings.map(booking => [
        booking.booking_id,
        booking.studentName,
        booking.studentEmail,
        booking.durationMinutes,
        booking.price,
        booking.currency,
        booking.scheduledAt,
        booking.status
    ]);

    // Escape CSV fields and guard against spreadsheet formula injection.
    const csvCell = value => {
        let text = String(value ?? "");

        if (/^[=+\-@\t\r]/.test(text)) {
            text = `'${text}`;
        }

        return `"${text.replace(/"/g, '""')}"`;
    };

    const csv = [headers, ...rows]
        .map(row => row.map(csvCell).join(","))
        .join("\r\n");

    const blob = new Blob(["\uFEFF" + csv], {
        type: "text/csv;charset=utf-8;"
    });

    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");

    link.href = url;
    link.download = "abroadmates-booking-report.csv";

    document.body.appendChild(link);
    link.click();
    link.remove();

    URL.revokeObjectURL(url);
}

document.getElementById("applyFiltersBtn")
    .addEventListener("click", loadReport);

document.getElementById("resetFiltersBtn")
    .addEventListener("click", () => {
        document.getElementById("startDate").value = "";
        document.getElementById("endDate").value = "";
        document.getElementById("statusFilter").value = "all";
        loadReport();
    });

document.getElementById("exportCsvBtn")
    .addEventListener("click", exportCSV);

loadReport();
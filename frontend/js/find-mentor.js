console.log("FIND MENTOR JS STARTED");

const API = "http://localhost:5000/api";
const token = localStorage.getItem("abroadmates_token");

const mentorList = document.getElementById("mentorList");
const resultCount = document.getElementById("resultCount");

const searchInput = document.getElementById("searchInput");
const searchBtn = document.getElementById("searchBtn");

const countryFilter = document.getElementById("countryFilter");
const programFilter = document.getElementById("programFilter");
const serviceFilter = document.getElementById("serviceFilter");
const scholarshipFilter = document.getElementById("scholarshipFilter");
const sortFilter = document.getElementById("sortFilter");

const resetFilters = document.getElementById("resetFilters");
const exportExcelBtn = document.getElementById("exportExcelBtn");
const exportPdfBtn = document.getElementById("exportPdfBtn");
const exportMessage = document.getElementById("exportMessage");

let currentMentors = [];

function showExportMessage(message, isError = false) {
    if (!exportMessage) return;

    exportMessage.textContent = message;
    exportMessage.style.color = isError ? "#b42318" : "#287a45";
}

if (!token) {
    window.location.href = "./auth.html";
}

async function apiGet(url) {
    const response = await fetch(`${API}${url}`, {
        headers: {
            Authorization: `Bearer ${token}`
        }
    });

    let result;

    try {
        result = await response.json();
    } catch {
        throw new Error("The server returned an invalid response.");
    }

    if (!response.ok) {
        throw new Error(result.message || "API request failed");
    }

    return result.data || [];
}

async function loadDropdown(selectElement, endpoint, idField, nameField) {
    try {
        const items = await apiGet(endpoint);

        items.forEach(item => {
            const option = document.createElement("option");
            option.value = item[idField];
            option.textContent = item[nameField];
            selectElement.appendChild(option);
        });
    } catch (error) {
        console.error(`Dropdown loading error: ${endpoint}`, error);
    }
}

async function loadFilters() {
    await Promise.all([
        loadDropdown(countryFilter, "/catalog/countries", "country_id", "country_name"),
        loadDropdown(programFilter, "/catalog/programs", "program_id", "program_name"),
        loadDropdown(serviceFilter, "/catalog/services", "service_id", "service_name"),
        loadDropdown(scholarshipFilter, "/catalog/scholarships", "scholarship_id", "scholarship_name")
    ]);
}

function buildMentorCard(mentor) {
    const photo = mentor.profile_photo_path
        ? `${API.replace("/api", "")}/${mentor.profile_photo_path}`
        : "./images/default-mentor.png";

    const card = document.createElement("article");
    card.className = "fm-card";

    const image = document.createElement("img");
    image.src = photo;
    image.alt = `${mentor.full_name || "Mentor"} profile photo`;

    image.onerror = () => {
        image.onerror = null;
        image.src = "./images/default-mentor.png";
    };

    const content = document.createElement("div");
    content.className = "fm-card-content";

    const name = document.createElement("h3");
    name.textContent = mentor.full_name || "Mentor";

    const headline = document.createElement("p");
    headline.className = "fm-headline";
    headline.textContent = mentor.headline || "Study abroad mentor";

    const stats = document.createElement("div");
    stats.className = "fm-stats";
    stats.textContent =
        `⭐ ${Number(mentor.average_rating || 0).toFixed(1)} (${mentor.review_count || 0} reviews)`;

    const sessions = document.createElement("p");
    sessions.className = "fm-headline";
    sessions.textContent = `${mentor.session_count || 0} completed sessions`;

    // const price = document.createElement("p");
    // price.className = "fm-price";
    // price.textContent = `From ${mentor.min_price || "N/A"} BDT`;
    const price = document.createElement("p");
    price.className = "fm-price";

    const startingPrice =
        mentor.minimum_price ??
        mentor.min_price ??
        null;

    const currency = mentor.currency || "BDT";

    price.textContent = startingPrice !== null
        ? `From ${Number(startingPrice).toLocaleString()} ${currency}`
        : "Price unavailable";

    const link = document.createElement("a");
    link.className = "fm-view-btn";
    link.href = `./mentor-details.html?id=${encodeURIComponent(mentor.mentor_id)}`;
    link.textContent = "View Profile";

    content.append(name, headline, stats, sessions, price, link);
    card.append(image, content);

    return card;
}

async function loadMentors() {
    mentorList.innerHTML = "<p>Loading mentors...</p>";
    resultCount.textContent = "Loading...";
    currentMentors = [];

    const params = new URLSearchParams();

    if (countryFilter.value) {
        params.set("countryId", countryFilter.value);
    }

    if (programFilter.value) {
        params.set("programId", programFilter.value);
    }

    if (serviceFilter.value) {
        params.set("serviceId", serviceFilter.value);
    }

    if (scholarshipFilter.value) {
        params.set("scholarshipId", scholarshipFilter.value);
    }

    if (searchInput.value.trim()) {
        params.set("search", searchInput.value.trim());
    }

    params.set("sort", sortFilter.value);

    try {
        const mentors = await apiGet(
            `/catalog/mentors?${params.toString()}`
        );

        currentMentors = Array.isArray(mentors) ? mentors : [];

        mentorList.innerHTML = "";
        resultCount.textContent =
            `${currentMentors.length} mentor(s) found`;

        if (currentMentors.length === 0) {
            mentorList.innerHTML = `
                <div class="fm-empty">
                    <h3>No mentors found</h3>
                    <p>Try changing your filters or search terms.</p>
                </div>
            `;
            return;
        }

        currentMentors.forEach(mentor => {
            mentorList.appendChild(buildMentorCard(mentor));
        });

    } catch (error) {
        console.error("Mentor loading error:", error);

        currentMentors = [];

        mentorList.innerHTML = `
            <div class="fm-empty">
                <h3>Could not load mentors</h3>
                <p>${error.message}</p>
            </div>
        `;

        resultCount.textContent = "Error loading mentors";
    }
}

// EXPORT TO EXCEL
function exportToExcel() {
    if (currentMentors.length === 0) {
        showExportMessage("There are no mentors to export.", true);
        return;
    }

    if (!window.XLSX) {
        showExportMessage("Excel library did not load.", true);
        return;
    }

    try {
        const rows = currentMentors.map(mentor => ({
            "Mentor ID": mentor.mentor_id ?? "",
            "Mentor Name": mentor.full_name || "",
            "Headline": mentor.headline || "",
            "Rating": Number(mentor.average_rating || 0),
            "Reviews": Number(mentor.review_count || 0),
            "Completed Sessions": Number(mentor.session_count || 0),
            "Starting Price (BDT)": mentor.minimum_price ?? mentor.min_price ?? "N/A"
            // "Starting Price (BDT)": mentor.min_price ?? "N/A"
        }));

        const worksheet = XLSX.utils.json_to_sheet(rows);
        const workbook = XLSX.utils.book_new();

        XLSX.utils.book_append_sheet(
            workbook,
            worksheet,
            "Mentors"
        );

        XLSX.writeFile(
            workbook,
            "AbroadMates_Mentor_List.xlsx"
        );

        showExportMessage("Excel file exported successfully.");

    } catch (error) {
        console.error("Excel export error:", error);
        showExportMessage(`Excel export failed: ${error.message}`, true);
    }
}

// EXPORT TO PDF
function exportToPDF() {
    if (currentMentors.length === 0) {
        showExportMessage("There are no mentors to export.", true);
        return;
    }

    if (!window.jspdf || typeof window.jspdf.jsPDF !== "function") {
        showExportMessage("PDF library did not load.", true);
        return;
    }

    try {
        const { jsPDF } = window.jspdf;

        const doc = new jsPDF({
            orientation: "landscape",
            unit: "mm",
            format: "a4"
        });

        doc.setFontSize(18);
        doc.text("AbroadMates - Mentor List", 14, 18);

        doc.setFontSize(10);
        doc.text(`Total mentors: ${currentMentors.length}`, 14, 25);

        const tableRows = currentMentors.map(mentor => [
            String(mentor.mentor_id ?? ""),
            String(mentor.full_name || ""),
            String(mentor.headline || ""),
            Number(mentor.average_rating || 0).toFixed(1),
            String(mentor.review_count || 0),
            String(mentor.session_count || 0),
            (mentor.minimum_price ?? mentor.min_price) != null
                ? `${mentor.minimum_price ?? mentor.min_price} ${mentor.currency || "BDT"}`
                : "Price unavailable"
            // mentor.min_price != null
            //     ? `${mentor.min_price} BDT`
            //     : "N/A"
        ]);

        if (typeof doc.autoTable !== "function") {
            throw new Error("PDF table plugin is missing.");
        }

        doc.autoTable({
            startY: 32,
            head: [[
                "ID",
                "Mentor Name",
                "Headline",
                "Rating",
                "Reviews",
                "Sessions",
                "Starting Price"
            ]],
            body: tableRows,
            theme: "grid",
            styles: {
                fontSize: 8,
                cellPadding: 3,
                overflow: "linebreak"
            },
            headStyles: {
                fillColor: [161, 70, 70],
                textColor: 255
            }
        });

        doc.save("AbroadMates_Mentor_List.pdf");

        showExportMessage("PDF file exported successfully.");

    } catch (error) {
        console.error("PDF export error:", error);
        showExportMessage(`PDF export failed: ${error.message}`, true);
    }
}

// SEARCH
searchBtn.addEventListener("click", loadMentors);

searchInput.addEventListener("keydown", event => {
    if (event.key === "Enter") {
        loadMentors();
    }
});

// FILTERS AND SORTING
[
    countryFilter,
    programFilter,
    serviceFilter,
    scholarshipFilter,
    sortFilter
].forEach(filter => {
    filter.addEventListener("change", loadMentors);
});

// RESET FILTERS
resetFilters.addEventListener("click", () => {
    countryFilter.value = "";
    programFilter.value = "";
    serviceFilter.value = "";
    scholarshipFilter.value = "";
    sortFilter.value = "top_rated";
    searchInput.value = "";

    loadMentors();
});

// EXPORT BUTTONS
exportExcelBtn.addEventListener("click", exportToExcel);
exportPdfBtn.addEventListener("click", exportToPDF);

// LOGOUT
document.getElementById("logoutBtn").addEventListener("click", () => {
    localStorage.removeItem("abroadmates_token");
    localStorage.removeItem("abroadmates_user");
    window.location.href = "./auth.html";
});

// GLOBAL EXPORT REGISTRATION
window.exportToExcel = exportToExcel;
window.exportToPDF = exportToPDF;

console.log("AbroadMates export functions registered.");

// INITIALIZE
async function initializePage() {
    if (!token) return;

    await loadFilters();
    await loadMentors();
}

initializePage();

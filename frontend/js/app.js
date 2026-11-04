const API_BASE_URL = "http://localhost:5000/api";

const countrySelect = document.getElementById("countrySelect");
const universitySelect = document.getElementById("universitySelect");
const statusMessage = document.getElementById("statusMessage");
const universityDetails = document.getElementById("universityDetails");
const menuToggle = document.getElementById("menuToggle");
const mainNav = document.getElementById("mainNav");

document.getElementById("year").textContent = new Date().getFullYear();

function showStatus(message, type = "info") {
  statusMessage.className = `status-message${type === "info" ? "" : ` ${type}`}`;
  statusMessage.replaceChildren();
  const dot = document.createElement("span");
  dot.className = "status-dot";
  const text = document.createElement("span");
  text.textContent = message;
  statusMessage.append(dot, text);
}

function getArray(payload) {
  if (Array.isArray(payload)) return payload;
  if (Array.isArray(payload?.data)) return payload.data;
  if (Array.isArray(payload?.data?.rows)) return payload.data.rows;
  if (Array.isArray(payload?.rows)) return payload.rows;
  return [];
}

async function readJson(response) {
  const contentType = response.headers.get("content-type") || "";
  if (!contentType.includes("application/json")) {
    const body = await response.text();
    throw new Error(`Expected JSON but received HTTP ${response.status}. ${body.slice(0, 160)}`);
  }
  const payload = await response.json();
  if (!response.ok) throw new Error(payload.message || `Request failed with HTTP ${response.status}`);
  return payload;
}

async function loadCountries() {
  countrySelect.disabled = true;
  showStatus("Connecting to the AbroadMates server…");
  try {
    const response = await fetch(`${API_BASE_URL}/catalog/countries`);
    const countries = getArray(await readJson(response));
    countrySelect.replaceChildren(new Option("Choose a country", ""));
    countries.forEach((country) => {
      const id = country.country_id ?? country.id;
      const name = country.country_name ?? country.name;
      if (id != null && name) countrySelect.add(new Option(name, id));
    });
    countrySelect.disabled = countries.length === 0;
    showStatus(countries.length
      ? `${countries.length} destinations are ready. Select a country to explore universities.`
      : "The API responded, but no countries were found in its data array.",
      countries.length ? "success" : "warning");
  } catch (error) {
    console.error("Countries API error:", error);
    showStatus(`Could not load countries: ${error.message}`, "error");
    countrySelect.replaceChildren(new Option("Could not load countries", ""));
  }
}

async function loadUniversities(countryId) {
  universitySelect.disabled = true;
  universitySelect.replaceChildren(new Option("Loading universities…", ""));
  universityDetails.hidden = true;
  universityDetails.replaceChildren();
  showStatus("Loading universities for your selected destination…");
  try {
    const response = await fetch(`${API_BASE_URL}/catalog/countries/${encodeURIComponent(countryId)}/universities`);
    const universities = getArray(await readJson(response));
    universitySelect.replaceChildren(new Option("Choose a university", ""));
    universities.forEach((university) => {
      const name = university.university_name ?? university.name;
      if (!name) return;
      const option = new Option(name, university.university_id ?? university.id ?? name);
      option.dataset.website = university.website_url ?? university.website ?? "";
      universitySelect.add(option);
    });
    universitySelect.disabled = universities.length === 0;
    if (universities.length) showStatus(`${universities.length} universities found. Choose one to see more details.`, "success");
    else {
      universitySelect.replaceChildren(new Option("No saved universities found", ""));
      showStatus("No saved universities found for this country. Sync universities first.", "warning");
    }
  } catch (error) {
    console.error("Universities API error:", error);
    universitySelect.replaceChildren(new Option("Could not load universities", ""));
    showStatus(`Could not load universities: ${error.message}`, "error");
  }
}

countrySelect.addEventListener("change", (event) => {
  const countryId = event.target.value;
  universityDetails.hidden = true;
  if (countryId) loadUniversities(countryId);
  else {
    universitySelect.disabled = true;
    universitySelect.replaceChildren(new Option("Choose a country first", ""));
    showStatus("Choose a country to load its universities.");
  }
});

universitySelect.addEventListener("change", () => {
  const selected = universitySelect.selectedOptions[0];
  if (!selected || !selected.value) { universityDetails.hidden = true; return; }
  universityDetails.replaceChildren();
  const heading = document.createElement("h4");
  heading.textContent = selected.textContent;
  const description = document.createElement("p");
  description.textContent = "University selected. You can use this choice in the next mentor-search and application-planning steps.";
  universityDetails.append(heading, description);
  if (selected.dataset.website) {
    const link = document.createElement("a");
    link.href = selected.dataset.website;
    link.target = "_blank";
    link.rel = "noopener noreferrer";
    link.textContent = "Visit university website ↗";
    universityDetails.append(link);
  }
  universityDetails.hidden = false;
});

menuToggle.addEventListener("click", () => {
  const isOpen = mainNav.classList.toggle("open");
  menuToggle.setAttribute("aria-expanded", String(isOpen));
});
mainNav.querySelectorAll("a").forEach((link) => link.addEventListener("click", () => {
  mainNav.classList.remove("open");
  menuToggle.setAttribute("aria-expanded", "false");
}));

loadCountries();

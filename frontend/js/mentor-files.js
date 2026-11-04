const FILE_API = "http://localhost:5000/api/mentor/files";
const FILE_TOKEN = localStorage.getItem("abroadmates_token");

if (!FILE_TOKEN) {
    window.location.href = "./auth.html";
}

async function uploadMentorFile(endpoint, inputId, fieldName, statusId) {
    const input = document.getElementById(inputId);
    const status = document.getElementById(statusId);
    const file = input.files[0];

    if (!file) {
        status.textContent = "Please choose a file first.";
        return;
    }

    const formData = new FormData();
    formData.append(fieldName, file);

    status.textContent = "Uploading...";

    try {
        const response = await fetch(`${FILE_API}/${endpoint}`, {
            method: "POST",
            headers: {
                Authorization: `Bearer ${FILE_TOKEN}`
            },
            body: formData
        });

        const result = await response.json();

        if (!response.ok || !result.success) {
            throw new Error(result.message || "Upload failed.");
        }

        status.textContent = result.message;
        input.value = "";

        if (endpoint === "photo" && result.photoUrl) {
            document.getElementById("currentProfilePhoto").src =
                `${result.photoUrl}?t=${Date.now()}`;
        }

    } catch (error) {
        status.textContent = error.message;
    }
}

document.getElementById("uploadPhotoButton")
    .addEventListener("click", () => {
        uploadMentorFile(
            "photo",
            "profilePhotoInput",
            "profilePhoto",
            "photoStatus"
        );
    });

document.getElementById("uploadCvButton")
    .addEventListener("click", () => {
        uploadMentorFile(
            "cv",
            "cvInput",
            "cv",
            "cvStatus"
        );
    });

document.getElementById("downloadCvButton")
    .addEventListener("click", async () => {
        const status = document.getElementById("cvStatus");
        status.textContent = "Preparing your CV...";

        try {
            const response = await fetch(`${FILE_API}/cv/download`, {
                headers: {
                    Authorization: `Bearer ${FILE_TOKEN}`
                }
            });

            if (!response.ok) {
                const result = await response.json();
                throw new Error(result.message || "CV download failed.");
            }

            const blob = await response.blob();
            const downloadUrl = URL.createObjectURL(blob);

            const link = document.createElement("a");
            link.href = downloadUrl;
            link.download = "mentor-cv.pdf";
            document.body.appendChild(link);
            link.click();
            link.remove();

            URL.revokeObjectURL(downloadUrl);
            status.textContent = "Your CV download has started.";

        } catch (error) {
            status.textContent = error.message;
        }
    });
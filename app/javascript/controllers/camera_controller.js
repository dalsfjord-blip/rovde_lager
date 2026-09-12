import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "video", "canvas", "preview", "startButton", "captureButton", "stopButton", "status"];

  connect() {
    this.stream = null;
  }

  disconnect() {
    this.stopCamera();
  }

  async startCamera() {
    if (!window.isSecureContext || !navigator.mediaDevices?.getUserMedia) {
      this.statusTarget.textContent = "Kamera krever localhost eller HTTPS. Åpne appen på http://localhost:3000 eller bruk HTTPS.";
      return;
    }

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: "environment" } }, audio: false });
      this.showCamera();
    } catch (error) {
      try {
        this.stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false });
        this.showCamera();
      } catch (fallbackError) {
        this.statusTarget.textContent = this.cameraErrorMessage(fallbackError);
      }
    }
  }

  showCamera() {
    this.videoTarget.srcObject = this.stream;
    this.videoTarget.hidden = false;
    this.captureButtonTarget.hidden = false;
    this.stopButtonTarget.hidden = false;
    this.startButtonTarget.hidden = true;
    this.statusTarget.textContent = "Kameraet er klart.";
  }

  cameraErrorMessage(error) {
    if (error.name === "NotAllowedError") return "Kameratilgang ble avslått. Tillat kamera for denne siden i nettleserens innstillinger.";
    if (error.name === "NotFoundError") return "Ingen kamera ble funnet. Kontroller at kameraet ikke brukes av en annen app.";
    if (error.name === "NotReadableError") return "Kameraet brukes allerede av en annen app. Lukk appen og prøv igjen.";

    return `Kameraet kunne ikke åpnes (${error.name}).`;
  }

  capturePhoto() {
    const video = this.videoTarget;
    const canvas = this.canvasTarget;
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    canvas.getContext("2d").drawImage(video, 0, 0);

    canvas.toBlob((blob) => {
      if (!blob) return;

      const file = new File([blob], `lagringsobjekt-${Date.now()}.jpg`, { type: "image/jpeg" });
      const files = new DataTransfer();
      Array.from(this.inputTarget.files).forEach((existingFile) => files.items.add(existingFile));
      files.items.add(file);
      this.inputTarget.files = files.files;
      this.previewTarget.insertAdjacentHTML("beforeend", `<img src="${URL.createObjectURL(file)}" alt="Forhåndsvisning av lagringsobjekt" class="h-24 w-24 rounded-md object-cover">`);
      this.statusTarget.textContent = `${this.inputTarget.files.length} bilde(r) klart for opplasting.`;
    }, "image/jpeg", 0.85);
  }

  stopCamera() {
    this.stream?.getTracks().forEach((track) => track.stop());
    this.stream = null;

    if (this.hasVideoTarget) this.videoTarget.srcObject = null;
    if (this.hasVideoTarget) this.videoTarget.hidden = true;
    if (this.hasCaptureButtonTarget) this.captureButtonTarget.hidden = true;
    if (this.hasStopButtonTarget) this.stopButtonTarget.hidden = true;
    if (this.hasStartButtonTarget) this.startButtonTarget.hidden = false;
  }

  showSelectedPhotos() {
    this.previewTarget.replaceChildren();
    Array.from(this.inputTarget.files).forEach((file) => {
      const image = document.createElement("img");
      image.src = URL.createObjectURL(file);
      image.alt = "Forhåndsvisning av lagringsobjekt";
      image.className = "h-24 w-24 rounded-md object-cover";
      this.previewTarget.appendChild(image);
    });

    this.statusTarget.textContent = `${this.inputTarget.files.length} bilde(r) klart for opplasting.`;
  }
}

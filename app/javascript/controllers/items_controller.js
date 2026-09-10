import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["meters", "itemTemplate"];
  static values = { pricePerMeter: { type: Number, default: 700 } };

  connect() {
    this.calculateTotal();
  }

  addItem() {
    const index = Date.now();
    const content = this.itemTemplateTarget.innerHTML.replace(/NEW_RECORD/g, index);

    this.element.querySelector("#storage_items").insertAdjacentHTML("beforeend", content);
    this.calculateTotal();
  }

  removeItem(event) {
    event.target.closest(".storage-item").remove();
    this.calculateTotal();
  }

  lookupVehicle(event) {
    const registrationNumber = event.target.value.trim();

    // Sjekk at vi har minst 6 tegn før vi slår opp
    if (registrationNumber.length < 6) return;

    fetch(`/api/vehicle_lookup?registration_number=${encodeURIComponent(registrationNumber)}`)
      .then((response) => {
        if (!response.ok) throw new Error("Fant ikke kjøretøy");
        return response.json();
      })
      .then((data) => {
        // Håndterer både om svaret er en liste [ { length_m: ... } ] eller et enkelt objekt { length_m: ... }
        const item = Array.isArray(data) ? data[0] : data;

        if (!item || !item.length_m) return;

        // Finner meter-feltet i samme rad/kort og oppdaterer verdien
        const metersInput = event.target.closest(".storage-item").querySelector('[data-items-target="meters"]');
        if (metersInput) {
          metersInput.value = Number(item.length_m).toFixed(2);
          this.calculateTotal();
        }
      })
      .catch((error) => {
        console.log("Oppslag feilet:", error.message);
      });
  }

  calculateTotal() {
    const totalMeters = this.metersTargets.reduce((total, input) => total + (parseFloat(input.value) || 0), 0);
    const totalPrice = totalMeters * this.pricePerMeterValue;

    const totalMetersEl = document.getElementById("total_meters");
    const totalPriceEl = document.getElementById("total_price");

    if (totalMetersEl) totalMetersEl.textContent = totalMeters.toFixed(2);
    if (totalPriceEl) {
      totalPriceEl.textContent = `${totalPrice.toLocaleString("no-NO", {
        minimumFractionDigits: 0,
        maximumFractionDigits: 0
      })} NOK`;
    }
  }
}
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
    const registrationNumber = event.target.value;

    if (registrationNumber.length < 6) return;

    fetch(`/api/vehicle_lookup?registration_number=${encodeURIComponent(registrationNumber)}`)
      .then((response) => response.json())
      .then((data) => {
        if (!data.length || !data[0].length_m) return;

        const metersInput = event.target.closest(".storage-item").querySelector('[data-items-target="meters"]');
        metersInput.value = Number(data[0].length_m).toFixed(2);
        this.calculateTotal();
      })
      .catch(() => {});
  }

  calculateTotal() {
    const totalMeters = this.metersTargets.reduce((total, input) => total + (parseFloat(input.value) || 0), 0);
    const totalPrice = totalMeters * this.pricePerMeterValue;

    document.getElementById("total_meters").textContent = totalMeters.toFixed(2);
    document.getElementById("total_price").textContent = `${totalPrice.toLocaleString("no-NO", {
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    })} NOK`;
  }
}

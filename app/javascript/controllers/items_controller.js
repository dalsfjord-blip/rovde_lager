import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["registrationNumber", "meters"];
  static values = { pricePerMeter: { type: Number, default: 700 } };

  connect() {
    this.calculateTotal();
  }

  addItem() {
    const newItemId = Date.now();
    const html = `
      <div id="storage_item_${newItemId}" class="p-4 border border-gray-200 rounded-lg space-y-4">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Registreringsnummer</label>
            <input type="text" name="rental_agreement[storage_items_attributes][${newItemId}][registration_number]"
                   class="w-full px-3 py-2 border border-gray-300 rounded-md"
                   placeholder="AB12345"
                   data-action="change->items#lookupVehicle" data-items-controller-target="registrationNumber">
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Beskrivelse</label>
            <input type="text" name="rental_agreement[storage_items_attributes][${newItemId}][description]"
                   class="w-full px-3 py-2 border border-gray-300 rounded-md"
                   placeholder="Båt på henger">
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Antall meter</label>
            <input type="number" name="rental_agreement[storage_items_attributes][${newItemId}][meters]"
                   class="w-full px-3 py-2 border border-gray-300 rounded-md"
                   step="0.01" min="0"
                   data-action="change->items#calculateTotal" data-items-controller-target="meters">
          </div>
        </div>
        <button type="button" data-action="click->items#removeItem" data-item-id="${newItemId}"
                class="text-red-500 hover:text-red-700 text-sm">Fjern</button>
      </div>
    `;
    this.element.querySelector('#storage_items').insertAdjacentHTML('beforeend', html);
    this.calculateTotal();
  }

  removeItem(event) {
    const itemId = event.target.dataset.itemId;
    document.getElementById(`storage_item_${itemId}`)?.remove();
    this.calculateTotal();
  }

  lookupVehicle(event) {
    const regNum = event.target.value;
    if (regNum.length >= 6) {
      fetch(`/api/vehicle_lookup?registration_number=${encodeURIComponent(regNum)}`)
        .then(response => response.json())
        .then(data => {
          if (data.length) {
            const meters = data[0].length_mm / 1000;
            const metersInput = event.target.closest('div').querySelector('[data-items-controller-target="meters"]');
            if (metersInput) metersInput.value = meters.toFixed(2);
            this.calculateTotal();
          }
        });
    }
  }

  calculateTotal() {
    let totalMeters = 0;
    this.metersTargets.forEach(input => {
      totalMeters += parseFloat(input.value) || 0;
    });

    const totalPrice = totalMeters * this.pricePerMeterValue;
    document.getElementById('total_meters').textContent = totalMeters.toFixed(2);
    document.getElementById('total_price').textContent = totalPrice.toLocaleString('nb-NO');
  }
}

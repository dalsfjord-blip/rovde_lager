import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["registrationNumber", "meters"];
  static values = { pricePerMeter: { type: Number, default: 700 } };

  connect() {
    this.calculateTotal();
  }

  addItem() {
    const form = this.element.querySelector('#items_form');
    const template = this.element.querySelector('#storage_items').firstElementChild;
    const newId = Date.now();
    
    // Clone the template and update IDs and names
    const newItem = template.cloneNode(true);
    newItem.id = `storage_item_${newId}`;
    
    // Update input names and IDs for nested attributes
    const inputs = newItem.querySelectorAll('input, label');
    inputs.forEach(input => {
      if (input.name) {
        input.name = input.name.replace(/\d+/, newId);
      }
      if (input.id) {
        input.id = input.id.replace(/\d+/, newId);
      }
      if (input.htmlFor) {
        input.htmlFor = input.htmlFor.replace(/\d+/, newId);
      }
    });
    
    // Clear values
    newItem.querySelectorAll('input[type="text"], input[type="number"]').forEach(input => {
      input.value = '';
    });
    
    // Update remove button
    const removeBtn = newItem.querySelector('button[type="button"]');
    if (removeBtn) {
      removeBtn.dataset.itemId = newId;
    }
    
    this.element.querySelector('#storage_items').appendChild(newItem);
    this.calculateTotal();
  }

  removeItem(event) {
    const itemId = event.target.dataset.itemId || event.target.closest('a, button').dataset.itemId;
    const itemElement = document.getElementById(`storage_item_${itemId}`);
    
    if (itemElement) {
      if (itemId === 'new') {
        itemElement.remove();
      } else {
        // For persisted items, use the Rails delete action
        event.preventDefault();
        const deleteUrl = event.target.href || event.target.closest('a').href;
        if (deleteUrl) {
          fetch(deleteUrl, { method: 'DELETE', headers: { 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content } })
            .then(() => itemElement.remove())
            .catch(() => alert('Feil ved sletting'));
        }
      }
      this.calculateTotal();
    }
  }

  lookupVehicle(event) {
    const regNum = event.target.value;
    if (regNum.length >= 6) {
      fetch(`/api/vehicle_lookup?registration_number=${encodeURIComponent(regNum)}`)
        .then(response => response.json())
        .then(data => {
          if (data.length && data[0].length_m) {
            const meters = data[0].length_m;
            const metersInput = event.target.closest('.grid').querySelector('[data-items-target="meters"]');
            if (metersInput) {
              metersInput.value = meters.toFixed(2);
              metersInput.dispatchEvent(new Event('change'));
            }
          }
        })
        .catch(() => {
          // Graceful fallback - do nothing
        });
    }
  }

  calculateTotal() {
    let totalMeters = 0;
    this.metersTargets.forEach(input => {
      totalMeters += parseFloat(input.value) || 0;
    });

    const totalPrice = totalMeters * this.pricePerMeterValue;
    
    const totalMetersEl = document.getElementById('total_meters');
    const totalPriceEl = document.getElementById('total_price');
    
    if (totalMetersEl) {
      totalMetersEl.textContent = totalMeters.toFixed(2);
    }
    if (totalPriceEl) {
      totalPriceEl.textContent = totalPrice.toLocaleString('no-NO', { 
        minimumFractionDigits: 0, 
        maximumFractionDigits: 0 
      }) + ' NOK';
    }
  }
}

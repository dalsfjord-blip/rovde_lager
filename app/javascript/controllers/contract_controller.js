import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["contractBox", "approvalCheckbox"];

  checkScroll() {
    const box = this.contractBoxTarget;
    if (box) {
      const isAtBottom = box.scrollHeight - box.scrollTop <= box.clientHeight + 1;
      if (isAtBottom) {
        this.approvalCheckboxTarget.disabled = false;
      }
    }
  }
}

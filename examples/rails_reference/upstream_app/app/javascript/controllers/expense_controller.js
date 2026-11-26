import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["total"];
  connect() { this.element.dataset.ready = "true"; }
  add() { this.totalTarget.textContent = String(Number(this.totalTarget.textContent) + 25); }
}

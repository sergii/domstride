import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["total"];
  connect() { this.element.dataset.ready = "true"; }
  fail() { throw new Error("Stimulus action failure"); }
  add() { this.totalTarget.textContent = String(Number(this.totalTarget.textContent) + 25); }
}

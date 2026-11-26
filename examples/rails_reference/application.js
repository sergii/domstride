import { Application, Controller } from "@hotwired/stimulus";
import "@hotwired/turbo";

const application = Application.start();
application.register("expense", class extends Controller {
  static targets = ["total"];
  connect() { this.element.dataset.ready = "true"; }
  add() { this.totalTarget.textContent = String(Number(this.totalTarget.textContent) + 25); }
});

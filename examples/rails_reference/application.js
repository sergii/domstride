import { Application } from "@hotwired/stimulus";
import "@hotwired/turbo";
import ExpenseController from "./upstream_app/app/javascript/controllers/expense_controller.js";

const application = Application.start();
application.register("expense", ExpenseController);

import { connectStreamSource, disconnectStreamSource } from "@hotwired/turbo";

const source = new EventTarget();
connectStreamSource(source);
const consumer = window.ActionCable.createConsumer("/cable");
const subscription = consumer.subscriptions.create("DomstrideReferenceChannel", {
  connected() { document.querySelector("#connection").textContent = "Connected"; },
  received(html) { source.dispatchEvent(new MessageEvent("message", { data: html })); },
  disconnected() { document.querySelector("#connection").textContent = "Disconnected"; }
});
window.referenceSubscription = subscription;
document.querySelector("#publish").addEventListener("click", () => subscription.perform("announce"));
document.querySelector("#disconnect").addEventListener("click", () => {
  subscription.unsubscribe();
  consumer.disconnect();
  disconnectStreamSource(source);
});

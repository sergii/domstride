// A document-scoped virtual clock. No host or Ruby clock is modified.
class VirtualClock {
  constructor(win, epoch) {
    this.win = win;
    this.epoch = epoch;
    this.now = 0;
    this.nextId = 0;
    this.timers = new Map();
    const clock = this;
    const RealDate = win.Date;
    function VirtualDate(...args) {
      if (!new.target) return new RealDate(clock.epoch + clock.now).toString();
      return Reflect.construct(RealDate, args.length ? args : [clock.epoch + clock.now], new.target);
    }
    VirtualDate.prototype = RealDate.prototype;
    Object.setPrototypeOf(VirtualDate, RealDate);
    VirtualDate.now = () => clock.epoch + clock.now;
    win.Date = VirtualDate;
    win.setTimeout = (callback, delay, ...args) => this.schedule(callback, delay, false, args);
    win.setInterval = (callback, delay, ...args) => this.schedule(callback, delay, true, args);
    win.clearTimeout = win.clearInterval = id => this.timers.delete(Number(id));
    win.requestAnimationFrame = callback => this.schedule(() => callback(this.now), 16, false, []);
    win.cancelAnimationFrame = id => this.timers.delete(Number(id));
  }

  schedule(callback, delay, repeat, args) {
    if (typeof callback !== "function") throw new TypeError("Virtual clock requires function timer callbacks");
    let ms = Number(delay) || 0;
    ms = Math.max(repeat ? 1 : 0, Math.min(2147483647, Math.trunc(ms)));
    const id = ++this.nextId;
    this.timers.set(id, { id, due: this.now + ms, repeat, ms, callback, args });
    return id;
  }

  next() {
    let next;
    for (const timer of this.timers.values()) {
      if (!next || timer.due < next.due || (timer.due === next.due && timer.id < next.id)) next = timer;
    }
    return next;
  }

  fire(timer) {
    this.now = Math.max(this.now, timer.due);
    if (timer.repeat) timer.due = this.now + timer.ms;
    else this.timers.delete(timer.id);
    timer.callback.apply(this.win, timer.args);
  }
}

module.exports = { VirtualClock };

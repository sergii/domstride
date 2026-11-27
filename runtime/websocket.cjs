// Explicit test-only loopback WebSocket bridge. Never connect to arbitrary remote hosts.
function installWebSocket(win, state) {
  const Native = win.WebSocket;
  const endpoint = state.websocketUrl ? new URL(state.websocketUrl) : null;
  if (endpoint && (endpoint.protocol !== "ws:" || endpoint.hostname !== "127.0.0.1" ||
      !endpoint.port || endpoint.username || endpoint.password || endpoint.hash || endpoint.search)) {
    throw new Error("Invalid loopback WebSocket endpoint");
  }
  const sockets = new Set();
  state.sockets = sockets;
  state.closeSockets = () => {
    state.socketClosing = true;
    for (const socket of sockets) {
      try { socket.close(); } catch (_) {}
    }
    sockets.clear();
  };
  if (state.websocketAuth) {
    win.WebSocket = authenticatedTransport(win, state, endpoint, sockets);
    return;
  }
  class TestWebSocket extends Native {
    constructor(url, protocols) {
      if (!endpoint || state.socketClosing) throw new Error("UNSUPPORTED_WEBSOCKET: configure a loopback endpoint");
      const requested = new URL(url, win.location.href);
      if (requested.protocol === "http:") requested.protocol = "ws:";
      if (requested.protocol === "https:") requested.protocol = "wss:";
      const logical = new URL(endpoint.pathname, win.location.href);
      logical.protocol = logical.protocol === "https:" ? "wss:" : "ws:";
      if (requested.href !== endpoint.href && requested.href !== logical.href) throw new Error("UNSUPPORTED_WEBSOCKET_ENDPOINT");
      if (sockets.size >= 8) throw new Error("WebSocket connection limit exceeded");
      super(endpoint.href, protocols);
      sockets.add(this);
      this.addEventListener("open", () => { state.activity += 1; });
      this.addEventListener("message", () => { state.activity += 1; });
      this.addEventListener("close", () => { sockets.delete(this); state.activity += 1; });
    }
  }
  // Action Cable enumerates constants on the constructor.
  for (const name of ["CONNECTING", "OPEN", "CLOSING", "CLOSED"]) {
    Object.defineProperty(TestWebSocket, name, { value: Native[name], enumerable: true });
  }
  win.WebSocket = TestWebSocket;
}

// Text-message transport for Action Cable. Private fields keep raw sockets and
// cookie headers out of application-facing objects. Never follow redirects.
function authenticatedTransport(win, state, endpoint, sockets) {
  const WS = require("ws");
  class AuthenticatedWebSocket extends win.EventTarget {
    #socket;
    #handlers = new Map();
    #url;
    constructor(url, protocols = []) {
      super();
      if (!endpoint || state.socketClosing) throw new Error("UNSUPPORTED_WEBSOCKET: configure a loopback endpoint");
      const requested = new URL(url, win.location.href);
      if (requested.protocol === "http:") requested.protocol = "ws:";
      const logical = new URL(endpoint.pathname, win.location.href);
      logical.protocol = "ws:";
      let target = endpoint.href;
      if (requested.href !== logical.href && requested.href !== endpoint.href) {
        // Only numeric account prefixes of the logical same-origin cable path.
        // Preserve the prefix so the actual Rails middleware resolves the account.
        if (state.websocketPathMode !== "numeric-account" || requested.origin !== logical.origin ||
            requested.username || requested.password || requested.search || requested.hash ||
            !/^\/[0-9]{1,20}\/cable$/.test(requested.pathname)) throw new Error("UNSUPPORTED_WEBSOCKET_ENDPOINT");
        target = new URL(requested.pathname, endpoint).href;
      }
      if (sockets.size >= 8) throw new Error("WebSocket connection limit exceeded");
      this.#url = requested.href;
      this.#socket = new WS(target, protocols, {
        headers: { origin: win.location.origin, cookie: state.websocketCookie || "" },
        followRedirects: false, handshakeTimeout: 5000, maxPayload: 8 * 1024 * 1024,
        perMessageDeflate: false
      });
      sockets.add(this);
      this.#socket.on("open", () => {
        state.activity += 1;
        if (!state.socketClosing) this.dispatchEvent(new win.Event("open"));
      });
      this.#socket.on("message", (data, binary) => {
        state.activity += 1;
        if (state.socketClosing) return;
        if (binary) { this.#socket.close(1003, "Text messages only"); return; }
        this.dispatchEvent(new win.MessageEvent("message", { data: data.toString("utf8"), origin: win.location.origin }));
      });
      this.#socket.on("error", () => {
        if (!state.socketClosing) this.dispatchEvent(new win.Event("error"));
      });
      this.#socket.on("close", (code, reason) => {
        sockets.delete(this);
        state.activity += 1;
        if (!state.socketClosing) this.dispatchEvent(new win.CloseEvent("close", {
          code, reason: reason.toString("utf8"), wasClean: code === 1000
        }));
      });
    }
    get url() { return this.#url; }
    get readyState() { return this.#socket.readyState; }
    get protocol() { return this.#socket.protocol; }
    get extensions() { return this.#socket.extensions; }
    get bufferedAmount() { return this.#socket.bufferedAmount; }
    send(data) {
      if (typeof data !== "string") throw new Error("UNSUPPORTED_WEBSOCKET_BINARY");
      if (this.readyState === WS.CONNECTING) throw new win.DOMException("Still connecting", "InvalidStateError");
      if (this.readyState === WS.OPEN) this.#socket.send(data);
    }
    close(code, reason) {
      if (code !== undefined && code !== 1000 && !(Number.isInteger(code) && code >= 3000 && code <= 4999)) throw new win.DOMException("Invalid close code", "InvalidAccessError");
      if (reason !== undefined && Buffer.byteLength(String(reason)) > 123) throw new win.DOMException("Close reason too long", "SyntaxError");
      this.#socket.close(code, reason);
    }
    get onopen() { return this.#handlers.get("open") || null; }
    set onopen(value) { this.#setHandler("open", value); }
    get onmessage() { return this.#handlers.get("message") || null; }
    set onmessage(value) { this.#setHandler("message", value); }
    get onerror() { return this.#handlers.get("error") || null; }
    set onerror(value) { this.#setHandler("error", value); }
    get onclose() { return this.#handlers.get("close") || null; }
    set onclose(value) { this.#setHandler("close", value); }
    #setHandler(name, value) {
      const previous = this.#handlers.get(name);
      if (previous) this.removeEventListener(name, previous);
      this.#handlers.delete(name);
      if (typeof value === "function") { this.#handlers.set(name, value); this.addEventListener(name, value); }
    }
  }
  for (const name of ["CONNECTING", "OPEN", "CLOSING", "CLOSED"]) {
    Object.defineProperty(AuthenticatedWebSocket, name, { value: WS[name], enumerable: true });
    Object.defineProperty(AuthenticatedWebSocket.prototype, name, { value: WS[name], enumerable: true });
  }
  return AuthenticatedWebSocket;
}

module.exports = { installWebSocket };

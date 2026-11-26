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

module.exports = { installWebSocket };

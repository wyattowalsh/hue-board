"use strict";

/**
 * Loopback-only synthetic Hue API for deterministic tests.
 * It contains no real credentials, addresses, room names, fixture names, or home data.
 */
const http = require("node:http");
const https = require("node:https");
const { once } = require("node:events");

const DEFAULT_BRIDGE_ID = "001788fffe123456";
const DEFAULT_APPLICATION_KEY = "synthetic-hue-board-key";
const DEFAULT_CLIENT_KEY = "00112233445566778899aabbccddeeff";
const DEFAULT_MAX_BODY_BYTES = 64 * 1024;

function copy(value) {
  return value == null ? value : structuredClone(value);
}

function syntheticHueState() {
  const device = {
    id: "device-1",
    type: "device",
    metadata: { name: "Synthetic lamp" },
    product_data: { model_id: "SYNTH-COLOR-1" },
  };
  const light = {
    id: "light-1",
    type: "light",
    owner: { rid: device.id, rtype: "device" },
    metadata: { name: "Synthetic lamp" },
    on: { on: true },
    dimming: { brightness: 42, min_dim_level: 1 },
    color: {
      xy: { x: 0.31, y: 0.33 },
      gamut: {
        red: { x: 0.6915, y: 0.3083 },
        green: { x: 0.17, y: 0.7 },
        blue: { x: 0.1532, y: 0.0475 },
      },
    },
    color_temperature: {
      mirek: 250,
      mirek_valid: true,
      mirek_schema: { mirek_minimum: 153, mirek_maximum: 500 },
    },
    dynamics: {
      status: "none",
      status_values: ["none", "dynamic_palette"],
    },
    gradient: { points_capable: 0 },
    effects: { effect_values: ["no_effect"] },
    mode: "normal",
  };
  const room = {
    id: "room-1",
    type: "room",
    metadata: { name: "Synthetic room" },
    children: [{ rid: device.id, rtype: "device" }],
  };
  const zone = {
    id: "zone-1",
    type: "zone",
    metadata: { name: "Synthetic zone" },
    children: [{ rid: light.id, rtype: "light" }],
  };
  return {
    room: new Map([[room.id, room]]),
    zone: new Map([[zone.id, zone]]),
    device: new Map([[device.id, device]]),
    light: new Map([[light.id, light]]),
    scene: new Map(),
  };
}

class FakeHueBridge {
  constructor({
    bridgeID = DEFAULT_BRIDGE_ID,
    applicationKey = DEFAULT_APPLICATION_KEY,
    clientKey = DEFAULT_CLIENT_KEY,
    maxBodyBytes = DEFAULT_MAX_BODY_BYTES,
    tls = null,
  } = {}) {
    if (!/^[a-f\d]{16}$/i.test(bridgeID)) {
      throw new TypeError("bridgeID must contain exactly 16 hexadecimal characters");
    }
    if (!Number.isSafeInteger(maxBodyBytes) || maxBodyBytes < 1) {
      throw new TypeError("maxBodyBytes must be a positive safe integer");
    }
    if (tls != null && (!tls.key || !tls.cert)) {
      throw new TypeError("tls requires key and cert");
    }
    this.bridgeID = bridgeID.toLowerCase();
    this.applicationKey = applicationKey;
    this.clientKey = clientKey;
    this.maxBodyBytes = maxBodyBytes;
    this.tls = tls;
    this.state = syntheticHueState();
    this.mutations = [];
    this.requests = [];
    this.faults = [];
    this.sseClients = new Set();
    this.linkButtonPressed = false;
    this.sceneSequence = 0;
    this.server = null;
    this.host = null;
    this.port = null;
  }

  get protocol() {
    return this.tls ? "https" : "http";
  }

  get baseURL() {
    if (!this.server || !this.port) throw new Error("FakeHueBridge is not running");
    return `${this.protocol}://${this.host}:${this.port}`;
  }

  async start({ host = "127.0.0.1", port = 0 } = {}) {
    if (this.server) throw new Error("FakeHueBridge is already running");
    const handler = this.#handle.bind(this);
    this.server = this.tls
      ? https.createServer(this.tls, handler)
      : http.createServer(handler);
    this.server.on("clientError", (_error, socket) => socket.destroy());
    this.server.listen(port, host);
    await once(this.server, "listening");
    const address = this.server.address();
    if (!address || typeof address === "string") throw new Error("No TCP address");
    this.host = host;
    this.port = address.port;
    return this;
  }

  async stop() {
    if (!this.server) return;
    for (const response of this.sseClients) response.end();
    this.sseClients.clear();
    this.server.closeIdleConnections?.();
    this.server.closeAllConnections?.();
    const server = this.server;
    this.server = null;
    await new Promise((resolve, reject) => {
      server.close((error) => (error && error.code !== "ERR_SERVER_NOT_RUNNING" ? reject(error) : resolve()));
    });
  }

  pressLinkButton(pressed = true) {
    this.linkButtonPressed = Boolean(pressed);
  }

  queueFault(fault) {
    const allowed = new Set(["delay", "status", "rate-limit", "malformed", "disconnect"]);
    if (!fault || !allowed.has(fault.kind)) throw new TypeError("Unsupported fault kind");
    this.faults.push({ ...fault });
  }

  emitEvent(data) {
    const payload = `data: ${JSON.stringify(copy(data))}\n\n`;
    for (const response of this.sseClients) response.write(payload);
  }

  resetMutations() {
    this.mutations.length = 0;
  }

  resource(type, id) {
    return copy(this.state[type]?.get(id) ?? null);
  }

  async #handle(request, response) {
    const url = new URL(request.url, `${this.protocol}://${request.headers.host || "localhost"}`);
    this.requests.push({ method: request.method, path: url.pathname, at: Date.now() });

    const fault = this.#takeFault(request.method, url.pathname);
    if (fault?.kind === "delay") {
      await new Promise((resolve) => setTimeout(resolve, Math.max(0, fault.ms ?? 0)));
    } else if (fault?.kind === "disconnect") {
      request.socket.destroy();
      return;
    } else if (fault?.kind === "malformed") {
      this.#sendRaw(response, fault.status ?? 200, fault.body ?? "{not-json", fault.headers);
      return;
    } else if (fault?.kind === "rate-limit") {
      this.#sendJSON(response, 429, fault.body ?? { errors: [{ description: "synthetic rate limit" }], data: [] });
      return;
    } else if (fault?.kind === "status") {
      this.#sendJSON(response, fault.status ?? 500, fault.body ?? { errors: [{ description: "synthetic fault" }], data: [] });
      return;
    }

    try {
      if (request.method === "GET" && url.pathname === "/api/config") {
        this.#sendJSON(response, 200, {
          bridgeid: this.bridgeID.toUpperCase(),
          modelid: "BSB002",
          apiversion: "1.68.0",
        });
        return;
      }

      if (request.method === "POST" && url.pathname === "/api") {
        await this.#readJSON(request);
        if (!this.linkButtonPressed) {
          this.#sendJSON(response, 200, [{
            error: { type: 101, address: "", description: "link button not pressed" },
          }]);
          return;
        }
        this.linkButtonPressed = false;
        this.#sendJSON(response, 200, [{
          success: { username: this.applicationKey, clientkey: this.clientKey },
        }]);
        return;
      }

      const isV2Resource = url.pathname.startsWith("/clip/v2/");
      const isEventStream = url.pathname === "/eventstream/clip/v2";
      if (!isV2Resource && !isEventStream) {
        this.#sendJSON(response, 404, { errors: [{ description: "not found" }], data: [] });
        return;
      }
      if (request.headers["hue-application-key"] !== this.applicationKey) {
        this.#sendJSON(response, 403, { errors: [{ description: "invalid application key" }], data: [] });
        return;
      }

      if (request.method === "GET" && isEventStream) {
        response.writeHead(200, {
          "content-type": "text/event-stream",
          "cache-control": "no-cache",
          connection: "keep-alive",
        });
        response.write("retry: 1000\n\n");
        this.sseClients.add(response);
        request.on("close", () => this.sseClients.delete(response));
        return;
      }

      const prefix = "/clip/v2/resource/";
      if (!url.pathname.startsWith(prefix)) {
        this.#sendJSON(response, 404, { errors: [{ description: "not found" }], data: [] });
        return;
      }
      const parts = url.pathname.slice(prefix.length).split("/").filter(Boolean);
      const [type, id] = parts;

      if (request.method === "GET") {
        const collection = this.state[type];
        if (!collection) {
          this.#sendJSON(response, 404, { errors: [{ description: "unknown resource type" }], data: [] });
          return;
        }
        if (id) {
          const item = collection.get(id);
          this.#sendJSON(response, item ? 200 : 404, {
            errors: item ? [] : [{ description: "resource not found" }],
            data: item ? [copy(item)] : [],
          });
          return;
        }
        this.#sendJSON(response, 200, { errors: [], data: [...collection.values()].map(copy) });
        return;
      }

      if (type === "light" && id && request.method === "PUT") {
        const light = this.state.light.get(id);
        if (!light) {
          this.#sendJSON(response, 404, { errors: [{ description: "resource not found" }], data: [] });
          return;
        }
        const body = await this.#readJSON(request);
        for (const key of ["on", "dimming", "color", "color_temperature", "dynamics", "gradient", "effects", "mode"]) {
          if (body[key] !== undefined) light[key] = copy(body[key]);
        }
        this.#recordMutation(request, url.pathname, body);
        this.emitEvent([{ type: "update", data: [copy(light)] }]);
        this.#ack(response, id, "light");
        return;
      }

      if (type === "scene" && !id && request.method === "POST") {
        const body = await this.#readJSON(request);
        const sceneID = `scene-${++this.sceneSequence}`;
        const scene = {
          id: sceneID,
          type: "scene",
          group: copy(body.group),
          metadata: copy(body.metadata ?? { name: `Synthetic scene ${this.sceneSequence}` }),
          actions: copy(body.actions ?? []),
          palette: copy(body.palette),
          speed: body.speed,
          auto_dynamic: body.auto_dynamic,
        };
        this.state.scene.set(sceneID, scene);
        this.#recordMutation(request, url.pathname, body, sceneID);
        this.#ack(response, sceneID, "scene");
        return;
      }

      if (type === "scene" && id && request.method === "PUT") {
        const scene = this.state.scene.get(id);
        if (!scene) {
          this.#sendJSON(response, 404, { errors: [{ description: "resource not found" }], data: [] });
          return;
        }
        const body = await this.#readJSON(request);
        this.#recordMutation(request, url.pathname, body, id);
        if (body.recall) {
          for (const light of this.state.light.values()) {
            light.dynamics = { ...(light.dynamics ?? {}), status: body.recall.action ?? "dynamic_palette" };
          }
          this.emitEvent([{ type: "update", data: [...this.state.light.values()].map(copy) }]);
        } else {
          Object.assign(scene, copy(body), { id, type: "scene" });
        }
        this.#ack(response, id, "scene");
        return;
      }

      if (type === "scene" && id && request.method === "DELETE") {
        if (!this.state.scene.delete(id)) {
          this.#sendJSON(response, 404, { errors: [{ description: "resource not found" }], data: [] });
          return;
        }
        this.#recordMutation(request, url.pathname, null, id);
        this.#ack(response, id, "scene");
        return;
      }

      this.#sendJSON(response, 405, { errors: [{ description: "method not allowed" }], data: [] });
    } catch (error) {
      const status = error?.statusCode ?? 400;
      this.#sendJSON(response, status, {
        errors: [{ description: error instanceof Error ? error.message : String(error) }],
        data: [],
      });
    }
  }

  #takeFault(method, path) {
    const index = this.faults.findIndex((fault) =>
      (fault.method == null || fault.method === method)
      && (fault.path == null || fault.path === path || (fault.path instanceof RegExp && fault.path.test(path)))
    );
    return index < 0 ? null : this.faults.splice(index, 1)[0];
  }

  async #readJSON(request) {
    const chunks = [];
    let bytes = 0;
    let tooLarge = false;
    for await (const chunk of request) {
      bytes += chunk.length;
      if (bytes > this.maxBodyBytes) {
        tooLarge = true;
      } else if (!tooLarge) {
        chunks.push(chunk);
      }
    }
    if (tooLarge) {
      const error = new Error(`request body exceeds ${this.maxBodyBytes} bytes`);
      error.statusCode = 413;
      throw error;
    }
    if (bytes === 0) return {};
    try {
      return JSON.parse(Buffer.concat(chunks).toString("utf8"));
    } catch {
      const error = new Error("invalid JSON request body");
      error.statusCode = 400;
      throw error;
    }
  }

  #recordMutation(request, path, body, resourceID = null) {
    this.mutations.push({
      method: request.method,
      path,
      resourceID,
      body: copy(body),
      at: Date.now(),
    });
  }

  #ack(response, id, type) {
    this.#sendJSON(response, 200, { errors: [], data: [{ rid: id, rtype: type }] });
  }

  #sendJSON(response, status, value) {
    this.#sendRaw(response, status, JSON.stringify(value), { "content-type": "application/json" });
  }

  #sendRaw(response, status, body, headers = {}) {
    if (response.headersSent || response.destroyed) return;
    response.writeHead(status, {
      "content-length": Buffer.byteLength(body),
      ...headers,
    });
    response.end(body);
  }
}

module.exports = {
  DEFAULT_APPLICATION_KEY,
  DEFAULT_BRIDGE_ID,
  DEFAULT_CLIENT_KEY,
  DEFAULT_MAX_BODY_BYTES,
  FakeHueBridge,
  syntheticHueState,
};

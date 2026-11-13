"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  DEFAULT_APPLICATION_KEY,
  FakeHueBridge,
} = require("./support/fake-hue-bridge.cjs");

async function json(url, options = {}) {
  const response = await fetch(url, options);
  const body = await response.json();
  return { response, body };
}

function v2Headers(extra = {}) {
  return {
    accept: "application/json",
    "content-type": "application/json",
    "hue-application-key": DEFAULT_APPLICATION_KEY,
    ...extra,
  };
}

test("pairing requires a synthetic physical link-button press", async (t) => {
  const bridge = await new FakeHueBridge().start();
  t.after(() => bridge.stop());

  const config = await json(`${bridge.baseURL}/api/config`);
  assert.equal(config.response.status, 200);
  assert.equal(config.body.bridgeid, bridge.bridgeID.toUpperCase());

  const denied = await json(`${bridge.baseURL}/api`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ devicetype: "hue_board#test", generateclientkey: true }),
  });
  assert.equal(denied.body[0].error.type, 101);

  bridge.pressLinkButton();
  const accepted = await json(`${bridge.baseURL}/api`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ devicetype: "hue_board#test", generateclientkey: true }),
  });
  assert.equal(accepted.body[0].success.username, DEFAULT_APPLICATION_KEY);
  assert.equal(accepted.body[0].success.clientkey, bridge.clientKey);
});

test("v2 inventory requires the application key and contains no home data", async (t) => {
  const bridge = await new FakeHueBridge().start();
  t.after(() => bridge.stop());

  const denied = await json(`${bridge.baseURL}/clip/v2/resource/light`);
  assert.equal(denied.response.status, 403);

  for (const type of ["room", "zone", "device", "light"]) {
    const result = await json(`${bridge.baseURL}/clip/v2/resource/${type}`, {
      headers: v2Headers(),
    });
    assert.equal(result.response.status, 200);
    assert.equal(result.body.errors.length, 0);
    assert.equal(result.body.data.length, 1);
    assert.match(JSON.stringify(result.body), /Synthetic/);
    assert.doesNotMatch(JSON.stringify(result.body), /real-home|personal-address|private-room/i);
  }
});

test("light writes and scene lifecycle are deterministic and logged", async (t) => {
  const bridge = await new FakeHueBridge().start();
  t.after(() => bridge.stop());

  const lightAction = { on: { on: false }, dimming: { brightness: 17 } };
  const light = await json(`${bridge.baseURL}/clip/v2/resource/light/light-1`, {
    method: "PUT",
    headers: v2Headers(),
    body: JSON.stringify(lightAction),
  });
  assert.deepEqual(light.body.data, [{ rid: "light-1", rtype: "light" }]);
  assert.equal(bridge.resource("light", "light-1").on.on, false);
  assert.equal(bridge.resource("light", "light-1").dimming.brightness, 17);

  const created = await json(`${bridge.baseURL}/clip/v2/resource/scene`, {
    method: "POST",
    headers: v2Headers(),
    body: JSON.stringify({
      group: { rid: "room-1", rtype: "room" },
      metadata: { name: "Synthetic Hue Board scene" },
      actions: [],
    }),
  });
  const sceneID = created.body.data[0].rid;
  assert.equal(sceneID, "scene-1");

  const lookup = await json(`${bridge.baseURL}/clip/v2/resource/scene/${sceneID}`, {
    headers: v2Headers(),
  });
  assert.equal(lookup.body.data[0].group.rid, "room-1");

  const recalled = await json(`${bridge.baseURL}/clip/v2/resource/scene/${sceneID}`, {
    method: "PUT",
    headers: v2Headers(),
    body: JSON.stringify({ recall: { action: "dynamic_palette" } }),
  });
  assert.equal(recalled.response.status, 200);
  assert.equal(bridge.resource("light", "light-1").dynamics.status, "dynamic_palette");

  const removed = await json(`${bridge.baseURL}/clip/v2/resource/scene/${sceneID}`, {
    method: "DELETE",
    headers: v2Headers(),
  });
  assert.equal(removed.response.status, 200);
  const stale = await json(`${bridge.baseURL}/clip/v2/resource/scene/${sceneID}`, {
    headers: v2Headers(),
  });
  assert.equal(stale.response.status, 404);
  assert.equal(bridge.mutations.length, 4);
  assert.deepEqual(bridge.mutations.map((entry) => entry.method), ["PUT", "POST", "PUT", "DELETE"]);
});

test("fault injection covers rate limiting, malformed payloads, delays, and body bounds", async (t) => {
  const bridge = await new FakeHueBridge({ maxBodyBytes: 32 }).start();
  t.after(() => bridge.stop());

  bridge.queueFault({ kind: "rate-limit", path: "/clip/v2/resource/light" });
  const limited = await json(`${bridge.baseURL}/clip/v2/resource/light`, {
    headers: v2Headers(),
  });
  assert.equal(limited.response.status, 429);

  bridge.queueFault({ kind: "malformed", path: "/clip/v2/resource/light" });
  const malformed = await fetch(`${bridge.baseURL}/clip/v2/resource/light`, {
    headers: v2Headers(),
  });
  assert.equal(await malformed.text(), "{not-json");

  bridge.queueFault({ kind: "status", path: "/api/config", status: 503 });
  const unavailable = await json(`${bridge.baseURL}/api/config`);
  assert.equal(unavailable.response.status, 503);

  bridge.queueFault({ kind: "disconnect", path: "/api/config" });
  await assert.rejects(() => fetch(`${bridge.baseURL}/api/config`));

  bridge.queueFault({ kind: "delay", path: "/api/config", ms: 20 });
  const before = Date.now();
  await fetch(`${bridge.baseURL}/api/config`);
  assert.ok(Date.now() - before >= 15);

  const oversized = await json(`${bridge.baseURL}/api`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ value: "x".repeat(128) }),
  });
  assert.equal(oversized.response.status, 413);
  assert.match(oversized.body.errors[0].description, /exceeds 32 bytes/);
});

test("SSE emits bounded synthetic Hue v2 events", async (t) => {
  const bridge = await new FakeHueBridge().start();
  t.after(() => bridge.stop());
  const controller = new AbortController();
  t.after(() => controller.abort());

  const response = await fetch(`${bridge.baseURL}/eventstream/clip/v2`, {
    headers: { "hue-application-key": DEFAULT_APPLICATION_KEY },
    signal: controller.signal,
  });
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type"), /text\/event-stream/);

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let text = "";
  while (!text.includes("retry: 1000\n\n")) {
    const { value, done } = await reader.read();
    assert.equal(done, false);
    text += decoder.decode(value, { stream: true });
  }

  bridge.emitEvent([{ type: "update", data: [{ id: "light-1", type: "light" }] }]);
  const eventText = await Promise.race([
    (async () => {
      let value = "";
      while (!value.includes("\n\n")) {
        const next = await reader.read();
        if (next.done) break;
        value += decoder.decode(next.value, { stream: true });
      }
      return value;
    })(),
    new Promise((_, reject) => setTimeout(() => reject(new Error("SSE timeout")), 1_000)),
  ]);
  assert.match(eventText, /"id":"light-1"/);
  controller.abort();
});

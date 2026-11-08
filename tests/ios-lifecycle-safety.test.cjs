'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = relative => fs.readFileSync(path.join(root, relative), 'utf8');

test('continued processing leases exactly one pending or running work item', () => {
  const source = read('ios/App/Services/ContinuedLiveCoordinator.swift');
  assert.match(source, /private final class RunningLease/);
  assert.match(source, /guard pending == nil, running == nil/);
  assert.match(source, /self\.pending = nil/);
  assert.match(source, /running = lease/);
  assert.match(source, /lease\.install\(task\)/);
  assert.match(source, /backgroundTask\.expirationHandler = \{ lease\.cancel\(\) \}/);
  assert.match(source, /if running === lease \{ running = nil \}/);
});

test('partial Bridge forgetting cannot resume with an in-memory deleted credential', () => {
  const source = read('ios/App/AppModel+Connection.swift');
  assert.match(source, /var credentialRemoved = false/);
  assert.match(source, /try keychain\.removeCredential/);
  assert.match(source, /credentialRemoved = true\s+credential = nil\s+connectionState = \.disconnected/s);
  assert.match(source, /if credentialRemoved \{/);
  assert.match(source, /No further Bridge requests will be sent/);
  assert.match(source, /else if isReady \{\s+startEventMonitoring\(\)/s);
});

test('saved Bridge retry reuses Keychain state and suppresses duplicate pairing', () => {
  const reconnect = read('ios/App/AppModel+Reconnect.swift');
  const sheet = read('ios/App/Views/ConnectionSheet.swift');
  assert.match(reconnect, /client\.verify\(profile: savedProfile\)/);
  assert.match(reconnect, /keychain\.credential/);
  assert.doesNotMatch(reconnect, /client\.pair\(/);
  assert.match(reconnect, /without creating a new Bridge application key/);
  assert.match(sheet, /if let pending = model\.pendingProfile, model\.credential == nil/);
  assert.match(sheet, /Retry saved connection/);
  assert.match(sheet, /model\.reconnectSavedBridge\(\)/);
});

test('passive event monitoring stops in background while continued Live remains separate', () => {
  const rootView = read('ios/App/Views/RootView.swift');
  assert.match(rootView, /case \.background:/);
  assert.match(rootView, /model\.stopEventMonitoring\(\)/);
  assert.match(rootView, /continued-processing task is separate/i);
});

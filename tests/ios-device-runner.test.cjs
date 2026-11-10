'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const read = relative => fs.readFileSync(path.join(root, relative), 'utf8');

test('physical-device helper is syntactically valid and fails closed', () => {
  const scriptPath = path.join(root, 'ios/scripts/device-run.sh');
  const script = read('ios/scripts/device-run.sh');
  const syntax = spawnSync('bash', ['-n', scriptPath], { encoding: 'utf8' });

  assert.equal(syntax.status, 0, syntax.stderr || syntax.stdout);
  assert.match(script, /^set -Eeuo pipefail$/m);
  assert.match(script, /Xcode 26 or newer is required/);
  assert.match(script, /corepack pnpm install --frozen-lockfile/);
  assert.match(script, /corepack pnpm verify:release/);
  assert.match(script, /git diff --exit-code --/);
  assert.match(script, /8445e778451c7e44237b90281bde622d764b0084/);
  assert.match(script, /-allowProvisioningUpdates/);
  assert.match(script, /-allowProvisioningDeviceRegistration/);
  assert.match(script, /devicectl device install app/);
  assert.match(script, /devicectl device process launch/);
  assert.doesNotMatch(script, /curl[^\n]*\|[^\n]*(?:sh|bash)/);
  assert.doesNotMatch(script, /sudo\s/);
});

test('device configuration template contains no committed account or device identifier', () => {
  const config = read('ios/device.env.example');
  assert.match(config, /^HUE_BOARD_TEAM_ID=$/m);
  assert.match(config, /^HUE_BOARD_DEVICE_ID=$/m);
  assert.match(config, /^HUE_BOARD_BUNDLE_ID=com\.wyattowalsh\.HueBoard\.dev$/m);
  assert.doesNotMatch(config, /HUE_BOARD_TEAM_ID=\S+/);
  assert.doesNotMatch(config, /HUE_BOARD_DEVICE_ID=\S+/);
});

test('Makefile exposes explicit preflight, build, install, and run targets', () => {
  const makefile = read('ios/Makefile');
  for (const target of [
    'iphone-preflight',
    'iphone-prepare',
    'iphone-list',
    'iphone-simulator-build',
    'iphone-build',
    'iphone-install',
    'iphone-launch',
    'iphone-run',
    'iphone-open',
  ]) {
    assert.match(makefile, new RegExp(`^${target}:`, 'm'), `Missing ${target}`);
  }
  assert.match(makefile, /-include device\.env/);
  assert.match(makefile, /bash scripts\/device-run\.sh device-run/);
});

test('local device configuration is ignored', () => {
  assert.match(read('.gitignore'), /^ios\/device\.env$/m);
});

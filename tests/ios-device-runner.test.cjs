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
  const help = spawnSync('bash', [scriptPath, 'help'], { encoding: 'utf8' });
  const nonMac = spawnSync('bash', [scriptPath, 'preflight'], { encoding: 'utf8' });

  assert.equal(syntax.status, 0, syntax.stderr || syntax.stdout);
  assert.equal(help.status, 0, help.stderr || help.stdout);
  assert.match(help.stdout, /device-run/);
  if (process.platform !== 'darwin') {
    assert.notEqual(nonMac.status, 0);
    assert.match(nonMac.stderr, /require macOS/);
  }

  assert.match(script, /^set -Eeuo pipefail$/m);
  assert.match(script, /Xcode 26 or newer is required/);
  assert.match(script, /corepack pnpm install --frozen-lockfile/);
  assert.match(script, /corepack pnpm verify:release/);
  assert.match(script, /corepack pnpm test\n/);
  assert.match(script, /corepack pnpm test:timing/);
  assert.match(script, /swift test --package-path/);
  assert.match(script, /git diff --exit-code --/);
  assert.match(script, /8445e778451c7e44237b90281bde622d764b0084/);
  assert.match(script, /swift build[^\n]+>&2/);
  assert.match(script, /-allowProvisioningUpdates/);
  assert.match(script, /-allowProvisioningDeviceRegistration/);
  assert.match(script, /devicectl device install app/);
  assert.match(script, /devicectl device process launch/);
  assert.doesNotMatch(script, /curl[^\n]*\|[^\n]*(?:sh|bash)/);
  assert.doesNotMatch(script, /sudo\s/);
});

test('qualification doctor is strict, sanitized, non-writing, and release-toolchain aligned', () => {
  const doctorPath = path.join(root, 'ios/scripts/device-doctor.sh');
  const doctor = read('ios/scripts/device-doctor.sh');
  const syntax = spawnSync('bash', ['-n', doctorPath], { encoding: 'utf8' });
  const nonMac = spawnSync('bash', [doctorPath], { encoding: 'utf8' });

  assert.equal(syntax.status, 0, syntax.stderr || syntax.stdout);
  if (process.platform !== 'darwin') {
    assert.notEqual(nonMac.status, 0);
    assert.match(nonMac.stderr, /requires macOS/);
  }

  assert.match(doctor, /^set -Eeuo pipefail$/m);
  assert.match(doctor, /readonly MIN_XCODE_MAJOR=27/);
  assert.match(doctor, /readonly MIN_XCODE_MINOR=2/);
  assert.match(doctor, /readonly MIN_IPHONEOS_SDK_MAJOR=27/);
  assert.match(doctor, /readonly MIN_IPHONEOS_SDK_MINOR=2/);
  assert.match(doctor, /security find-identity/);
  assert.match(doctor, /devicectl list devices/);
  assert.match(doctor, /supported_surface=iphone-portrait/);
  assert.match(doctor, /team_id_recorded=no/);
  assert.match(doctor, /device_identifier_recorded=no/);
  assert.doesNotMatch(doctor, /team_id=\$\{TEAM_ID\}/);
  assert.doesNotMatch(doctor, /device_identifier=\$\{DEVICE_ID\}/);
  assert.doesNotMatch(doctor, /\/clip\/v2\/resource\//);
  assert.doesNotMatch(doctor, /curl[^\n]*\|[^\n]*(?:sh|bash)/);
  assert.doesNotMatch(doctor, /sudo\s/);
});

test('device configuration template contains no committed account or device identifier', () => {
  const config = read('ios/device.env.example');
  assert.match(config, /^HUE_BOARD_TEAM_ID=$/m);
  assert.match(config, /^HUE_BOARD_DEVICE_ID=$/m);
  assert.match(config, /^HUE_BOARD_BUNDLE_ID=com\.wyattowalsh\.HueBoard\.dev$/m);
  assert.match(config, /Xcode 27\.2\+/);
  assert.doesNotMatch(config, /HUE_BOARD_TEAM_ID=\S+/);
  assert.doesNotMatch(config, /HUE_BOARD_DEVICE_ID=\S+/);
});

test('Makefile exposes qualification, build, install, and run targets', () => {
  const makefile = read('ios/Makefile');
  for (const target of [
    'iphone-preflight',
    'iphone-doctor',
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
  assert.match(makefile, /^iphone-doctor:\s*\n\tbash scripts\/device-doctor\.sh/m);
  assert.match(makefile, /^iphone-build: iphone-doctor$/m);
  assert.match(makefile, /^iphone-run: iphone-doctor$/m);
  assert.match(makefile, /bash scripts\/device-run\.sh device-run/);
});

test('local device configuration is ignored', () => {
  assert.match(read('.gitignore'), /^ios\/device\.env$/m);
});

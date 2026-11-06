const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const script = fs.readFileSync(path.join(__dirname, '../install/install-hue-board.js'), 'utf8');
const full = fs.readFileSync(path.join(__dirname, '../dist/hue-board.js'), 'utf8');
test('installer is valid Scriptable JavaScript', () => {
  const AsyncFunction = Object.getPrototypeOf(async function(){}).constructor;
  assert.doesNotThrow(() => new AsyncFunction('Request','Alert','FileManager','Script', script));
});
test('installer pins the published Hue Board build', () => {
  assert.match(script, /fc7c59d8d64cffac40d62a2450c5bb134ca02bfe/);
  assert.match(script, /dist\\/hue-board\\.js/);
  assert.match(full.slice(0, 150), /^\\/\\/ Hue Board 5\\.0\\.0/);
});
test('installer checks the response and backs up before replacing', () => {
  assert.match(script, /request\\.response\\?\\.statusCode !== 200/);
  assert.ok(script.indexOf('fm.copy(destination, backup)') < script.indexOf('fm.writeString(destination, code)'));
  assert.doesNotMatch(script, /Keychain\\.(?:set|remove)\\(/);
});

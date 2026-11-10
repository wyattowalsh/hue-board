'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = relative => fs.readFileSync(path.join(root, relative), 'utf8');

test('native recovery journal expands without replacing prior baselines', () => {
  const helper = read(
    'ios/Packages/HueBoardKit/Sources/HueBoardNativeCore/RestoreJournal+Capture.swift'
  );
  const recovery = read('ios/App/AppModel+Recovery.swift');
  assert.match(helper, /var capturedLightIDs: Set<HueResourceID>/);
  assert.match(helper, /let existing = capturedLightIDs/);
  assert.match(helper, /!existing\.contains\(\$0\.id\)/);
  assert.match(helper, /snapshots\.append/);
  assert.match(recovery, /captureMissing\(from: area, touchedIDs: touchedIDs\)/);
  assert.match(recovery, /saveRestoreJournal\(existing\)/);
});

test('emergency off reports incomplete coverage and retains recovery', () => {
  const everyday = read('ios/App/AppModel+Everyday.swift');
  assert.match(everyday, /targetIDs = journal\.capturedLightIDs/);
  assert.match(everyday, /var unresolved = targetIDs\.subtracting\(eligibleIDs\)/);
  assert.match(everyday, /unresolved\.insert\(id\)/);
  assert.match(everyday, /Emergency off reached/);
  assert.match(everyday, /saved baseline is retained/);
  assert.doesNotMatch(everyday, /saveRestoreJournal\(nil\)/);
});

test('destructive Bridge reset is separate, explicit, and confirmed in both recovery surfaces', () => {
  const connection = read('ios/App/AppModel+Connection.swift');
  const settings = read('ios/App/Views/SettingsView.swift');
  const sheet = read('ios/App/Views/ConnectionSheet.swift');

  assert.match(connection, /func discardRecoveryAndForgetBridge\(\)/);
  assert.match(connection, /guard let profile, hasRestorePoint, !isBusy/);
  assert.match(connection, /removeBridge\(profile, discardRecovery: true\)/);
  assert.match(connection, /if !discardRecovery, try await persistence\.loadRestoreJournal\(\) != nil/);

  for (const source of [settings, sheet]) {
    assert.match(source, /confirmationDialog\(/);
    assert.match(source, /Discard recovery & forget Bridge/);
    assert.match(source, /cannot be undone|permanently deletes/i);
  }
});

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = relative => fs.readFileSync(path.join(root, relative), 'utf8');

test('native persistence v2 is versioned, integrity checked, backed up, and quarantined', () => {
  const persistence = read('ios/Packages/HueBoardKit/Sources/HueBoardNativeCore/AppPersistence.swift');
  const models = read('ios/Packages/HueBoardKit/Sources/HueBoardNativeCore/PersistenceModels.swift');
  const checksum = read('ios/Packages/HueBoardKit/Sources/HueBoardNativeCore/PersistenceChecksum.swift');

  assert.match(persistence, /hue-board\.native\.state\.v2/);
  assert.match(persistence, /hue-board\.native\.recovery\.v2/);
  assert.match(persistence, /hue-board\.native\.legacy-backup\.v1/);
  assert.match(persistence, /hue-board\.native\.quarantine\.v2/);
  assert.match(persistence, /rollbackToLegacyBackup/);
  assert.match(persistence, /decodeEnvelope/);
  assert.match(persistence, /payloadSHA256/);
  assert.match(models, /currentSchema = 2/);
  assert.match(models, /profiles: \[String: BridgeProfile\]/);
  assert.match(models, /PersistenceMigrationReport/);
  assert.match(checksum, /sha256Hex/);
  assert.doesNotMatch(persistence, /removeObject\(forKey: Key\.legacyProfile\)/);
});

test('native app propagates persistence failures instead of silently discarding them', () => {
  const bridge = read('ios/App/AppModel+BridgePlayback.swift');
  const bridgeTransport = read('ios/Packages/HueBoardKit/Sources/HueBoardNativeCore/BridgeSceneTransport.swift');
  const connection = read('ios/App/AppModel+Connection.swift');
  const everyday = read('ios/App/AppModel+Everyday.swift');
  const events = read('ios/App/AppModel+Events.swift');

  assert.match(bridge, /BridgeSceneTransport/);
  assert.match(bridgeTransport, /try await persistence\.sceneID/);
  assert.match(bridgeTransport, /try await persistence\.saveSceneID/);
  assert.match(connection, /try await persistence\.loadSelectedAreaID/);
  assert.match(connection, /discardRecovery: discardRecovery/);
  assert.match(everyday, /try await persistence\.saveSelectedAreaID/);
  assert.match(events, /try await self\.persistence\.saveSelectedAreaID/);
});

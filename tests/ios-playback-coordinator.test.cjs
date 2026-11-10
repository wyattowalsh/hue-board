const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = relative => fs.readFileSync(path.join(root, relative), 'utf8');

test('playback coordinator defines a single writer epoch and stale lease gate', () => {
  const coordinator = read('ios/Packages/HueBoardKit/Sources/HueBoardNativeCore/PlaybackCoordinator.swift');
  const contract = read('ios/Packages/HueBoardKit/Sources/HueBoardKit/LightingTransport.swift');

  assert.match(coordinator, /private var epoch: UInt64 = 0/);
  assert.match(coordinator, /private var active: ActiveWriter\?/);
  assert.match(coordinator, /PlaybackCoordinationError\.busy/);
  assert.match(coordinator, /PlaybackCoordinationError\.staleLease/);
  assert.match(coordinator, /stopCurrent\(reason:/);
  assert.match(contract, /struct PlaybackWriterLease/);
  assert.match(contract, /struct PlaybackOperationID/);
  assert.match(contract, /struct WriterEpoch/);
  assert.match(contract, /protocol LightingTransport: Sendable/);
});

test('preview transport has no Bridge dependency or physical-write capability', () => {
  const preview = read('ios/Packages/HueBoardKit/Sources/HueBoardNativeCore/NullPreviewTransport.swift');
  assert.match(preview, /performsPhysicalWrites: false/);
  assert.match(preview, /capturedFrames/);
  assert.doesNotMatch(preview, /HueBridgeClient|URLSession|updateLight|createScene|recallScene/);
});

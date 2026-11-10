const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');

test('dynamic playback requires persisted first-use consent',()=>{
  const model=read('ios/App/AppModel.swift');
  const safety=read('ios/App/AppModel+Safety.swift');
  const bridge=read('ios/App/AppModel+BridgePlayback.swift');
  const live=read('ios/App/AppModel+Live.swift');
  const rootView=read('ios/App/Views/RootView.swift');
  assert.match(model,/pendingDynamicAction/);
  assert.match(safety,/safetyStore\.save/);
  const store=read('ios/Packages/HueBoardKit/Sources/HueBoardNativeCore/PhysicalLightSafetyStore.swift');
  assert.match(store,/payloadSHA256/);
  assert.match(store,/quarantine/);
  assert.match(bridge,/requiresDynamicLightConsent/);
  assert.match(live,/requiresDynamicLightConsent/);
  assert.match(rootView,/Dynamic light safety/);
  assert.match(rootView,/stop immediately if you feel discomfort/);
});

test('Reduce Light Motion bounds engine behavior and keeps emergency controls available',()=>{
  const policy=read('ios/Packages/HueBoardKit/Sources/HueBoardKit/PhysicalLightSafety.swift');
  const runner=read('ios/App/Services/NativeLiveRunner.swift');
  const settings=read('ios/App/Views/SettingsView.swift');
  const lights=read('ios/App/Views/LightsView.swift');
  assert.match(policy,/speed = min\(result\.speed, 0\.55\)/);
  assert.match(policy,/energy = min\(result\.energy, 45\)/);
  assert.match(policy,/return max\(8_000, count \* 800\)/);
  assert.match(runner,/adjustedEngineSettings/);
  assert.match(settings,/Reduce Light Motion/);
  assert.match(settings,/not a medical guarantee/);
  assert.match(lights,/Turn off now/);
});

test('ordinary static controls are not subject to dynamic brightness cap',()=>{
  const everyday=read('ios/App/AppModel+Everyday.swift');
  assert.doesNotMatch(everyday,/effectiveDynamicBrightness|maximumDynamicBrightness/);
});

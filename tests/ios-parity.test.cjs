const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const {ENGINE,PRESET_LIBRARY}=require('../dist/testable.cjs');
const resource=path.join(root,'ios/Packages/HueBoardKit/Sources/HueBoardKit/Resources/hue-board-contract.json');
const contract=JSON.parse(fs.readFileSync(resource,'utf8'));
const read=p=>fs.readFileSync(path.join(root,p),'utf8');

test('native contract mirrors JavaScript definitions',()=>{
  assert.equal(contract.schema,1);
  assert.equal(contract.release,require('../package.json').version);
  assert.equal(contract.patterns.length,ENGINE.shows.length);
  assert.equal(contract.palettes.length,ENGINE.palettes.length);
  assert.equal(contract.presets.length,PRESET_LIBRARY.length);
  assert.deepEqual(contract.patterns.map(x=>x.id),ENGINE.shows.map(x=>x[0]));
  assert.deepEqual(contract.presets.map(x=>x.id),PRESET_LIBRARY.map(x=>x.id));
  assert.equal(new Set(contract.presets.map(x=>x.id)).size,contract.presets.length);
});

test('native app source preserves no-write-on-open and restore gates',()=>{
  const appModelFiles=fs.readdirSync(path.join(root,'ios/App'))
    .filter(name=>/^AppModel.*\.swift$/.test(name))
    .sort()
    .map(name=>read(path.join('ios/App',name)));
  const model=appModelFiles.join('\n');
  const connection=read('ios/App/AppModel+Connection.swift');
  const bootstrap=connection.slice(connection.indexOf('func bootstrap()'),connection.indexOf('func discoverBridges()'));
  assert.doesNotMatch(bootstrap,/updateLight\(|recallScene\(|createScene\(|updateScene\(/);
  assert.match(model,/scene\.group\?\.resourceID == area\.id/);
  assert.match(model,/Stop and restore the current area before switching/);
  assert.match(model,/ensureRestoreJournal/);
  assert.match(model,/markBridgeRequestPending/);
  assert.match(model,/markUncertain/);
  assert.match(model,/requiresRecovery/);
  assert.match(model,/func turnOffNow\(\)/);
  assert.match(model,/ContinuedLiveCoordinator\.shared\.cancel\(\)/);
  assert.match(model,/saved baseline is retained/);
});

test('native app keeps credentials out of source and in Keychain',()=>{
  const roots=['ios/App','ios/Packages/HueBoardKit/Sources'];
  const files=[];
  const walk=dir=>fs.readdirSync(path.join(root,dir),{withFileTypes:true}).forEach(e=>{
    const rel=path.join(dir,e.name);e.isDirectory()?walk(rel):/\.(swift|plist|yml)$/.test(e.name)&&files.push(rel);
  });
  roots.forEach(walk);
  const source=files.map(read).join('\n');
  assert.doesNotMatch(source,/hue-application-key\s*[:=]\s*["'][A-Za-z0-9_-]{16,}/i);
  assert.doesNotMatch(source,/(?:manualHost|host)\s*=\s*["'](?:10|192\.168|172\.(?:1[6-9]|2\d|3[01]))\.\d+\.\d+["']/);
  assert.match(read('ios/App/Services/KeychainVault.swift'),/kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly/);
});

test('native project includes exact engine and explicit continued-processing contract',()=>{
  const project=read('ios/project.yml');
  const coordinator=read('ios/App/Services/ContinuedLiveCoordinator.swift');
  const plist=read('ios/App/Info.plist');
  assert.match(project,/product: HueBoardAppleEngine/);
  assert.match(coordinator,/#available\(iOS 26\.0/);
  assert.match(coordinator,/BGContinuedProcessingTaskRequest/);
  assert.match(coordinator,/request\.strategy = \.fail/);
  assert.match(plist,/com\.wyattowalsh\.HueBoard\.live/);
  assert.match(plist,/NSLocalNetworkUsageDescription/);
  const runner=read('ios/App/Services/NativeLiveRunner.swift');
  assert.match(runner,/minimumCycleSeconds/);
  assert.match(runner,/Task\.sleep\(\s*for:/);
  assert.match(runner,/Hue Entertainment transport/);
});

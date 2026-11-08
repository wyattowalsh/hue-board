const test=require('node:test');
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const {ENGINE,PRESET_LIBRARY}=require('../dist/testable.cjs');
const resources=path.join(root,'ios/Packages/HueBoardKit/Sources/HueBoardKit/Resources');
const contract=JSON.parse(fs.readFileSync(path.join(resources,'hue-board-contract.json'),'utf8'));
const golden=JSON.parse(fs.readFileSync(path.join(resources,'engine-golden.json'),'utf8'));
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

test('native engine manifest covers all 512 deterministic frames',()=>{
  assert.equal(golden.schema,1);
  assert.equal(golden.release,require('../package.json').version);
  assert.equal(golden.algorithm,'sha256');
  assert.equal(golden.numberFormat,'fixed-12-posix');
  assert.equal(golden.caseCount,PRESET_LIBRARY.length*golden.times.length*golden.positions.length);
  const fixed=value=>Math.abs(value)<5e-13?'0.000000000000':Number(value).toFixed(12);
  const lines=[];
  const observed=[];
  for(const preset of PRESET_LIBRARY){
    const settings=ENGINE.clean({...ENGINE.defaults,...preset.settings,brightness:golden.brightness,seed:golden.seed,topology:golden.topology});
    for(const time of golden.times)for(const position of golden.positions){
      const frame=ENGINE.sample(time,position,settings,0);
      lines.push([preset.id,fixed(time),fixed(position),...frame.rgb.map(fixed),fixed(frame.b)].join('|')+'\n');
      if(golden.anchors.some(a=>a.preset===preset.id&&a.time===time&&a.position===position)){
        observed.push({preset:preset.id,time,position,rgb:frame.rgb.map(v=>+v.toFixed(12)),brightness:+frame.b.toFixed(12)});
      }
    }
  }
  assert.equal(lines.length,golden.caseCount);
  assert.equal(crypto.createHash('sha256').update(lines.join(''),'utf8').digest('hex'),golden.sha256);
  assert.deepEqual(observed,golden.anchors);
});

test('native app source preserves no-write-on-open and complete restore gates',()=>{
  const appModelFiles=fs.readdirSync(path.join(root,'ios/App'))
    .filter(name=>/^AppModel.*\.swift$/.test(name))
    .sort()
    .map(name=>read(path.join('ios/App',name)));
  const model=appModelFiles.join('\n');
  const connection=read('ios/App/AppModel+Connection.swift');
  const recovery=read('ios/App/AppModel+Recovery.swift');
  const everyday=read('ios/App/AppModel+Everyday.swift');
  const journal=read('ios/Packages/HueBoardKit/Sources/HueBoardNativeCore/RestoreJournal+Capture.swift');
  const bootstrap=connection.slice(connection.indexOf('func bootstrap()'),connection.indexOf('func discoverBridges()'));
  assert.doesNotMatch(bootstrap,/updateLight\(|recallScene\(|createScene\(|updateScene\(/);
  assert.match(model,/scene\.group\?\.resourceID == area\.id/);
  assert.match(model,/Stop and restore the current area before switching/);
  assert.match(model,/ensureRestoreJournal/);
  assert.match(model,/markBridgeRequestPending/);
  assert.match(model,/markUncertain/);
  assert.match(model,/requiresRecovery/);
  assert.match(model,/recallAttempted/);
  assert.match(model,/No scene recall was sent/);
  assert.match(model,/func turnOffNow\(\)/);
  assert.match(model,/ContinuedLiveCoordinator\.shared\.cancel\(\)/);
  assert.match(model,/saved baseline is retained/);
  assert.match(recovery,/captureMissing\(from: area, touchedIDs: touchedIDs\)/);
  assert.match(journal,/let existing = capturedLightIDs/);
  assert.match(journal,/!existing\.contains\(\$0\.id\)/);
  assert.match(everyday,/targetIDs = journal\.capturedLightIDs/);
  assert.match(everyday,/No restorable non-streaming lights/);
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

test('native local transport verifies bridge identity and pins its certificate',()=>{
  const tls=read('ios/Packages/HueBoardKit/Sources/HueBoardNativeCore/HueBridgeTLS.swift');
  const client=read('ios/Packages/HueBoardKit/Sources/HueBoardNativeCore/HueBridgeClient.swift');
  const models=read('ios/Packages/HueBoardKit/Sources/HueBoardNativeCore/Models.swift');
  const connection=read('ios/App/AppModel+Connection.swift');
  const sheet=read('ios/App/Views/ConnectionSheet.swift');
  const plist=read('ios/App/Info.plist');
  assert.match(tls,/SecPolicyCreateSSL\(true, observation\.bridgeID/);
  assert.match(tls,/SecTrustSetAnchorCertificates\(/);
  assert.match(tls,/pinnedSHA256/);
  assert.match(tls,/certificate changed/i);
  assert.match(client,/func verify\(profile:/);
  assert.match(client,/requirePinned\(profile\)/);
  assert.match(client,/bridgeID == response\.certificate\.bridgeID/);
  assert.match(models,/certificateSHA256/);
  assert.match(connection,/client\.verify\(profile: savedProfile\)/);
  assert.match(sheet,/Certificate/);
  assert.match(sheet,/fail closed/i);
  assert.doesNotMatch(plist,/NSAllowsArbitraryLoads|NSExceptionAllowsInsecureHTTPLoads/);
});

test('native discovery and readback streams are bounded and non-writing',()=>{
  const discovery=read('ios/App/Services/HueLocalDiscovery.swift');
  const connection=read('ios/App/AppModel+Connection.swift');
  const stream=read('ios/Packages/HueBoardKit/Sources/HueBoardNativeCore/HueEventStreamClient.swift');
  const events=read('ios/Packages/HueBoardKit/Sources/HueBoardKit/HueEvents.swift');
  const plist=read('ios/App/Info.plist');
  assert.match(discovery,/NWBrowser/);
  assert.match(discovery,/bonjourWithTXTRecord\(type: "_hue\._tcp", domain: "local\."\)/);
  assert.match(discovery,/record\["bridgeid"\]/);
  assert.match(discovery,/currentPath\?\.remoteEndpoint/);
  assert.match(discovery,/keepAlive = self/);
  assert.match(discovery,/options\.version = \.v4/);
  assert.match(connection,/localDiscovery\.discover\(\)/);
  assert.match(connection,/client\.discover\(\)/);
  assert.match(plist,/NSBonjourServices/);
  assert.match(plist,/_hue\._tcp/);
  assert.doesNotMatch(discovery,/updateLight\(|recallScene\(|createScene\(|updateScene\(/);
  assert.match(stream,/case 429:/);
  assert.match(stream,/case 500\.\.<600:/);
  assert.match(stream,/text\/event-stream/);
  assert.match(events,/maximumEventBytes = 256 \* 1_024/);
  assert.doesNotMatch(stream,/updateLight\(|recallScene\(|createScene\(|updateScene\(/);
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

const test=require('node:test');
const assert=require('node:assert/strict');
const A=require('../dist/testable.cjs');

test('schema 2 scene export is complete, scope-free, and round trips',()=>{
  const document=A.makeSceneDocument({...A.ENGINE.defaults,brightness:72},'  Evening test  ');
  assert.equal(document.format,'hue-board.scene');
  assert.equal(document.schema,2);
  assert.equal(document.kind,'look');
  assert.equal(document.scope,'user-selected');
  assert.equal(document.name,'Evening test');
  assert.equal(document.settings.brightness,72);
  const encoded=JSON.stringify(document);
  for(const forbidden of ['applicationKey','clientKey','bridgeId','bridgeID','areaId','areaID','host','ip'])assert.equal(encoded.includes('"'+forbidden+'"'),false,forbidden);
  const result=A.validateSceneDocument(JSON.parse(encoded));
  assert.equal(result.source,'scene-schema-2');
  assert.deepEqual(result.warnings,[]);
  assert.deepEqual(result.settings,document.settings);
  assert.deepEqual(A.validatePreset(document),document.settings);
});

test('schema 2 rejects embedded physical target and unknown settings',()=>{
  const document=A.makeSceneDocument(A.ENGINE.defaults);
  assert.throws(()=>A.validateSceneDocument({...document,bridgeID:'001788fffe123456'}),/unsupported fields/i);
  assert.throws(()=>A.validateSceneDocument({...document,scope:'room'}),/cannot embed a physical target/i);
  assert.throws(()=>A.validateSceneDocument({...document,settings:{...document.settings,showA:'unknown'}}),/unknown pattern/i);
  assert.throws(()=>A.validateSceneDocument({...document,settings:{...document.settings,brightness:101}}),/brightness.*out of range/i);
  assert.throws(()=>A.validateSceneDocument({...document,settings:{...document.settings,extra:true}}),/unsupported fields/i);
});

test('legacy schema 3 remains importable and is normalized without a target',()=>{
  const legacy={app:'BOYZ.EXE',schema:3,settings:{brightness:999,showA:'unknown',palette:2}};
  const result=A.validateSceneDocument(legacy);
  assert.equal(result.source,'legacy-scriptable-schema-3');
  assert.equal(result.settings.brightness,100);
  assert.equal(result.settings.showA,A.ENGINE.defaults.showA);
  assert.equal(result.settings.paletteA,2);
  assert.match(result.warnings.join(' '),/legacy Scriptable schema 3/i);
  assert.deepEqual(A.validatePreset(legacy),result.settings);
});

test('schema 2 requires full deterministic settings and supported engine ABI',()=>{
  const document=A.makeSceneDocument(A.ENGINE.defaults);
  const {speed,...missing}=document.settings;
  assert.throws(()=>A.validateSceneDocument({...document,settings:missing}),/missing speed/i);
  assert.throws(()=>A.validateSceneDocument({...document,source:{...document.source,engineABI:99}}),/Engine ABI 99/i);
  assert.throws(()=>A.validateSceneDocument({...document,source:{...document.source,catalogRevision:'bad'}}),/catalog revision/i);
});

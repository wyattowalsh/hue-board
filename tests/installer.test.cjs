const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const script = fs.readFileSync(path.join(root, 'install/install-hue-board.js'), 'utf8');
const extract = pattern => { const value = script.match(pattern)?.[1]; assert.ok(value, 'Missing installer constant'); return value; };
const publishedVersion = extract(/const VERSION = '([^']+)'/);
const releaseManifest = require('../releases/v'+publishedVersion+'.json');

test('installer pins a versioned commit, exact release bytes, and uses valid Scriptable JavaScript', () => {
  const version = publishedVersion;
  const revision = extract(/const REVISION = '([a-f0-9]+)'/);
  const digest = extract(/const EXPECTED_SHA256 = '([a-f0-9]+)'/);
  assert.equal(version, releaseManifest.version);
  assert.equal(revision, releaseManifest.sourceRevision);
  assert.equal(digest, releaseManifest.sha256);
  assert.equal(releaseManifest.artifact, 'dist/hue-board.js');
  assert.match(digest, /^[a-f\d]{64}$/);
  assert.match(script, /https:\/\/raw\.githubusercontent\.com\/wyattowalsh\/hue-board\/\$\{REVISION\}\/dist\/hue-board\.js/);
  const AsyncFunction = Object.getPrototypeOf(async function(){}).constructor;
  assert.doesNotThrow(() => new AsyncFunction(script));
});

test('installer SHA-256 matches known vectors and UTF-8 release', () => {
  const body = script.slice(script.indexOf('function sha256Hex('), script.indexOf('\nasync function notice('));
  const sha = vm.runInNewContext(`${body}\nsha256Hex`);
  for (const sample of ['', 'abc', 'Hue Board ✅']) {
    const bytes = Buffer.from(sample, 'utf8');
    assert.equal(sha(bytes), crypto.createHash('sha256').update(bytes).digest('hex'));
  }
  assert.equal(sha(Buffer.from('Hue Board\n'.repeat(1024))), crypto.createHash('sha256').update('Hue Board\n'.repeat(1024)).digest('hex'));
});

test('tampered downloads never write or replace the installed script', async () => {
  let writes = 0, reads = 0;
  const notices = [];
  class Alert { addAction(){} addCancelAction(){} async presentAlert(){notices.push(this.title);return 0;} }
  class Request { constructor(url){assert.match(url,/\/dist\/hue-board\.js$/);} async loadString(){return `// Hue Board ${publishedVersion} | Standalone Scriptable controller\n// tampered`;} get response(){return {statusCode:200};} }
  const manager = {documentsDirectory:()=>'/tmp',joinPath:(a,b)=>a+'/'+b,fileExists:()=>{reads++;return true;},writeString:()=>{writes++;},copy:()=>{writes++;}};
  const context = {Alert,Request,FileManager:{iCloud:()=>manager,local:()=>manager},Data:{fromString:s=>({getBytes:()=>Array.from(Buffer.from(s))})},Script:{complete:()=>{}}};
  await vm.runInNewContext(`(async () => { ${script} })()`,context);
  assert.equal(writes,0);
  assert.equal(reads,0);
  assert.deepEqual(notices,['Installation stopped']);
});

test('installer does not touch Keychain or Hue lights', () => {
  assert.doesNotMatch(script, /Keychain\.(?:set|remove)\(/);
  assert.doesNotMatch(script, /\/clip\/v2\/resource\//);
  const hashAt = script.indexOf('sha256Hex(Data.fromString(script).getBytes())');
  const backupAt = script.indexOf('manager.copy(destination,');
  const writeAt = script.search(/manager\.writeString\(destination,\s*script\)/);
  assert.ok(hashAt >= 0 && backupAt > hashAt && writeAt > backupAt);
});

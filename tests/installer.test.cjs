const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const script=fs.readFileSync(path.join(__dirname,'../install/install-hue-board.js'),'utf8');
const m=require('../releases/v5.2.0.json');
const value=(name)=>{const v=script.match(new RegExp("const "+name+" = '([^']+)'"))?.[1];assert.ok(v,'Missing '+name);return v;};
test('Scriptable installer pins the published revision, version and digest',()=>{
 assert.equal(value('VERSION'),require('../package.json').version);
 assert.equal(value('REVISION'),m.sourceRevision);
 assert.equal(value('EXPECTED_SHA256'),m.sha256);
 assert.match(script,/raw\.githubusercontent\.com\/wyattowalsh\/hue-board\/\$\{REVISION\}\/dist\/hue-board\.js/);
 assert.doesNotThrow(()=>new (Object.getPrototypeOf(async function(){}).constructor)(script));
});
test('installer SHA-256 passes reference vectors and UTF-8 payloads',()=>{
 const body=script.slice(script.indexOf('function sha256Hex('),script.indexOf('\nasync function notice('));
 const hash=vm.runInNewContext(body+'\nsha256Hex');
 for(const s of ['','abc','Hue Board ✅','Hue Board\n'.repeat(1024)]){
   assert.equal(hash(Buffer.from(s,'utf8')),crypto.createHash('sha256').update(s).digest('hex'));
 }
});
test('a tampered download stops before reading or writing existing files',async()=>{
 let reads=0,writes=0;const notifications=[];
 class Alert{addAction(){}addCancelAction(){}async presentAlert(){notifications.push(this.title);return 0;}}
 class Request{async loadString(){return '// Hue Board 5.2.0 | Standalone Scriptable controller\n// tampered';}get response(){return {statusCode:200}}}
 const manager={documentsDirectory:()=>'/tmp',joinPath:(a,b)=>a+'/'+b,fileExists:()=>{reads++;return true},writeString:()=>{writes++},copy:()=>{writes++}};
 const c={Alert,Request,FileManager:{iCloud:()=>manager,local:()=>manager},Data:{fromString:s=>({getBytes:()=>Array.from(Buffer.from(s))})},Script:{complete(){}}};
 await vm.runInNewContext('(async()=>{'+script+'})()',c);
 assert.equal(reads,0);assert.equal(writes,0);assert.deepEqual(notifications,['Installation stopped']);
});
test('installer neither writes Hue state nor touches Keychain and checks hash before write',()=>{
 assert.doesNotMatch(script,/Keychain\.(?:set|remove)\(/);
 assert.doesNotMatch(script,/\/clip\/v2\/resource\//);
 const hash=script.indexOf('sha256Hex(Data.fromString(script).getBytes())');
 const backup=script.indexOf('manager.copy(destination,');
 const write=script.search(/manager\.writeString\(destination,\s*script\)/);
 assert.ok(hash>=0&&backup>hash&&write>backup);
});

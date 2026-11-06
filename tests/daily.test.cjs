const test=require('node:test'),assert=require('node:assert/strict');
const {A,env,light,flush,clone}=require('./helpers.cjs');
const placement=(x={})=>({ceiling:100,trim:1,...x});
const white=(id='w')=>light(id,{color:undefined,color_temperature:{mirek:250,mirek_valid:true,mirek_schema:{mirek_minimum:153,mirek_maximum:500}}});
const plug=(id='p')=>({id,type:'light',label:'Switch',on:{on:false},owner:{rid:'device-'+id,rtype:'device'},mode:'normal'});
async function command(e,name,payload){e.ctl.dispatch(name,payload);await e.step();await e.ctl.settled();}
test('normal brightness permits 100, never overdrive; legacy ceilings stay unchanged',()=>{
 assert.equal(A.ENGINE.clean({brightness:1000}).brightness,100);assert.equal(A.cleanLayout({},[light()]).placements.l1.ceiling,100);
 assert.equal(A.cleanLayout({placements:{l1:{ceiling:85,trim:.7}}},[light()]).placements.l1.ceiling,85);
 assert.equal(A.effectAction(light(),'cosmos',A.ENGINE.clean({brightness:100}),placement()).dimming.brightness,100);
 const f=A.actionFromFrame(light(),{b:150,rgb:[1,1,1]},placement(),A.ENGINE.clean({brightness:100}),1500);
 assert.equal(f.dimming.brightness,100);
});
test('manual input is strict and cannot address another room or inject API properties',()=>{
 const allowed=new Map([['l1',light()]]);
 for(const p of [{ids:[]},{ids:['foreign'],on:false},{ids:['l1'],brightness:101},{ids:['l1'],brightness:NaN},{ids:['l1'],brightness:0},{ids:['l1'],on:'yes'},{ids:['l1'],hex:'red'},{ids:['l1'],kelvin:4000,hex:'#ffffff'},{ids:['l1'],on:false,brightness:50}])assert.throws(()=>A.validateManualIntent(p,allowed));
 const valid=A.validateManualIntent({ids:['l1','l1'],on:true,brightness:100,metadata:{name:'bad'}},allowed);assert.deepEqual(valid,{ids:['l1'],on:true,brightness:100});
});
test('manual brightness respects device minimum, trim and ceiling',()=>{
 assert.equal(A.manualAction(light(),placement(),{brightness:100,on:true}).dimming.brightness,100);
 assert.equal(A.manualAction(light(),placement({trim:.75,ceiling:60}),{brightness:100,on:true}).dimming.brightness,60);
 assert.equal(A.manualAction(light('l',{dimming:{brightness:30,min_dim_level:3}}),placement(),{brightness:.1,on:true}).dimming.brightness,3);
 assert.throws(()=>A.manualAction(light('l',{dimming:{brightness:30,min_dim_level:10}}),placement({ceiling:5}),{brightness:1}),/below/);
});
test('turning a lamp on repeatedly does not compound its output trim',()=>{const p=placement({trim:.4}),l=light();let a=A.manualAction(l,p,{on:true});assert.equal(a.dimming.brightness,45);a=A.manualAction({...l,dimming:a.dimming},p,{on:true});assert.equal(a.dimming.brightness,45);});
test('off is explicit, includes no brightness and supports on/off-only resources',()=>{
 assert.deepEqual(A.manualAction(plug(),placement(),{on:false}),{on:{on:false}});
 assert.deepEqual(A.manualAction(plug(),placement(),{on:true}),{on:{on:true}});
 assert.equal(A.manualAction(plug(),placement(),{on:true,brightness:50}),null);
 assert.equal(A.manualAction(white(),placement(),{on:true,hex:'#00ccff'}),null);
});
test('white temperature uses each fixture range, never guesses missing schemas',()=>{
 assert.equal(A.manualAction(white(),placement(),{on:true,kelvin:10000}).color_temperature.mirek,153);
 assert.equal(A.manualAction(white(),placement(),{on:true,kelvin:1000}).color_temperature.mirek,500);
 assert.equal(A.capabilities(white()).temperatureRange.min,2000);
 assert.equal(A.manualAction(light(),placement(),{kelvin:4000,on:true}),null);
 assert.throws(()=>A.manualAction(light('l',{color_temperature:{}}),placement(),{kelvin:4000}),/range/);
});
test('manual colors are mapped into gamut and streaming is never overridden',()=>{
 const a=A.manualAction(light(),placement(),{on:true,hex:'#ff0000'});assert.ok(a.color.xy.x+a.color.xy.y<=1.001);
 assert.throws(()=>A.manualAction(light('l',{mode:'streaming'}),placement(),{on:false}),/streaming app/);
});
test('manual control uses same paced writer, acknowledges targets, and restores baseline',async()=>{
 const e=env({count:3});assert.equal(e.writes().length,0);
 await command(e,'manual',{ids:['l1','l2'],on:true,brightness:100});assert.equal(e.database.get('l1').dimming.brightness,100);assert.equal(e.database.get('l3').dimming.brightness,45);
 assert.deepEqual(e.ctl.state().manualResult.accepted,['l1','l2']);assert.equal(e.ctl.state().mode,'manual');assert.equal(e.ctl.state().telemetry.targets.l1.kind,'manual');
 const w=e.writes();assert.ok(w[1].at-w[0].at>=350);assert.equal(e.ctl.state().stats.maxConcurrentWriters,1);
 await command(e,'restore');assert.equal(e.database.get('l1').dimming.brightness,45);assert.equal(e.ctl.state().touched,0);await e.ctl.close();
});
test('manual edit stops live show and cue sequence, not a second writer',async()=>{
 const e=env({count:3});await e.start();await e.run(5000);await command(e,'manual',{ids:['l1'],on:false});const n=e.writes().length;await e.run(10000);
 assert.equal(e.writes().length,n);assert.equal(e.database.get('l1').on.on,false);assert.equal(e.ctl.state().sequence.enabled,false);await e.ctl.close();
});
test('Pause during pending manual write stops subsequent lamps',async()=>{
 let release;const e=env({count:3,apiOverride:async(c,m,p,v,b)=>{if(m==='PUT'&&p==='light/l1')return new Promise(r=>release=()=>b(c,m,p,v).then(r));return b(c,m,p,v);}});
 e.ctl.dispatch('manual',{ids:['l1','l2','l3'],on:true,brightness:100});await e.step();await flush(30);assert.ok(release);e.ctl.dispatch('pause');release();await e.ctl.settled();await e.step();assert.deepEqual(e.writes().map(w=>w.path),['light/l1']);await e.ctl.close();
});
test('strict invalid manual intent sends no writes and does not pause a running show',async()=>{
 const e=env({count:1});await e.start();const before=e.ctl.state().mode;e.ctl.dispatch('manual',{ids:['other'],on:true});assert.equal(e.ctl.state().mode,before);assert.match(e.ctl.state().error,/outside/);await e.ctl.close();
});
test('missing / unsupported / streaming fixtures are skipped and disclosed',async()=>{
 const e=env({count:3});e.database.get('l2').mode='streaming';e.database.delete('l3');await command(e,'manual',{ids:['l1','l2','l3'],brightness:100,on:true});assert.equal(e.ctl.state().manualResult.accepted.length,1);assert.equal(e.ctl.state().manualResult.skipped.length,2);await e.ctl.close();
});
test('recovery gate blocks manual on, but not an explicit Off',async()=>{
 const first=env({count:1});await command(first,'manual',{ids:['l1'],brightness:90,on:true});await first.ctl.close();const next=env({count:1,saved:first.store});assert.equal(next.ctl.state().session.recoveryRequired,true);
 await command(next,'manual',{ids:['l1'],on:true});assert.equal(next.writes().length,0);await command(next,'manual',{ids:['l1'],on:false});assert.equal(next.writes().length,1);await next.ctl.close();
});
test('on/off-only lamp can be controlled and restored with no dimming payload',async()=>{
 const e=env({count:1});e.group.lights=[plug('l1')];e.database.set('l1',plug('l1'));const ctl=A.makeController(e.cfg,e.group,{api:e.basic,read:e.read,save:e.save,now:e.now,sleep:async(ms)=>e.advance(ms),uid:()=> 'switch-session',autoDiscover:false});
 ctl.dispatch('manual',{ids:['l1'],on:true});ctl.tick();await ctl.settled();assert.equal(e.database.get('l1').on.on,true);assert.equal('dimming' in e.writes()[0].payload,false);
 ctl.dispatch('restore');ctl.tick();await ctl.settled();assert.equal(e.database.get('l1').on.on,false);await ctl.close();await e.ctl.close();
});
test('larger area permits everyday controls but selected live animation is bounded',async()=>{
 const e=env({count:29});await command(e,'manual',{ids:['l1'],on:false});assert.equal(e.writes().length,1);await command(e,'live');assert.match(e.ctl.state().error,/28/);assert.equal(e.ctl.state().mode,'error');await e.ctl.close();
});
test('saved scene static copy obeys limits and never modifies or recalls source scene',async()=>{
 const e=env({count:2,apiOverride:(c,m,p,v,b)=>m==='GET'&&p==='scene'?Promise.resolve({data:[{id:'scene-x',metadata:{name:'Saved look'},group:{rid:'room1',rtype:'room'},actions:[{target:{rid:'l1'}}]}]}):b(c,m,p,v)});
 e.scenes['scene-x']={id:'scene-x',metadata:{name:'Saved look'},group:{rid:'room1',rtype:'room'},actions:[{target:{rid:'l1',rtype:'light'},action:{on:{on:true},dimming:{brightness:100}}},{target:{rid:'foreign',rtype:'light'},action:{on:{on:true}}}]};
 const l=e.ctl.state().layout;l.placements.l1.ceiling=65;e.ctl.update({layout:l});e.ctl.dispatch('refreshScenes');await e.ctl.scenesSettled();assert.equal(e.ctl.state().savedScenes.items.length,1);
 await command(e,'applyScene','scene-x');assert.equal(e.database.get('l1').dimming.brightness,65);assert.ok(e.calls.every(c=>!['PUT','POST','DELETE'].includes(c.method)||c.path.startsWith('light/')));await e.ctl.close();
});
test('All lights synthetic area never creates a fake Hue scene group',async()=>{
 const e=env({count:1});const c=A.makeController(e.cfg,{...e.group,type:'all',id:'all-lights'},{api:e.basic,read:e.read,save:e.save,now:e.now,uid:()=> 'all-session'});c.dispatch('bridge');c.tick();await c.settled();assert.match(c.state().error,/Choose a room/);assert.equal(e.calls.filter(x=>x.method==='POST').length,0);await c.close();await e.ctl.close();
});
function workspace(e,extra={}){const all={...e.group,id:'all-lights',type:'all',name:'All lights'},other={...e.group,id:'zone2',type:'zone',name:'Desk zone',lights:e.group.lights.slice(0,1)};const groups=[e.group,all,other];const w=A.makeWorkspaceController(e.cfg,groups,e.group,{now:e.now,api:e.basic,read:e.read,save:e.save,uid:()=> 'workspace-session-'+Math.random(),sleep:async ms=>e.advance(ms),saveConfig:()=>{},autoDiscover:false,...extra});return {w,groups};}
test('area switching reuses the UI contract and creates no light writes',async()=>{
 const e=env({count:2}),{w}=workspace(e);const before=w.state();assert.equal(before.meta.scopeId,'room/room1');w.dispatch('switchArea','zone/zone2');assert.equal(w.state().navigation.switching,true);await w.settled();assert.equal(w.state().meta.name,'Desk zone');assert.equal(w.state().layout.order.length,1);assert.equal(e.writes().length,0);assert.equal(e.cfg.group.rid,'zone2');await w.close();await e.ctl.close();
});
test('ceilings and trims stay shared across overlapping scopes without silent lift',async()=>{
 const e=env({count:2});e.store['hue-board.workspace.v3']={'bridge-test/room/room1':{layout:{placements:{l1:{ceiling:85,trim:.7}}}}};
 const {w}=workspace(e);assert.equal(w.state().layout.placements.l1.ceiling,85);w.dispatch('switchArea','all/all-lights');await w.settled();assert.equal(w.state().layout.placements.l1.ceiling,85);
 const l=w.state().layout;l.placements.l1.ceiling=100;w.update({layout:l});w.dispatch('switchArea','room/room1');await w.settled();assert.equal(w.state().layout.placements.l1.ceiling,100);assert.equal(w.state().layout.placements.l1.trim,.7);await w.close();await e.ctl.close();
});
test('scope switch waits for in-flight writer and does not replay old controls in the new room',async()=>{
 let release;const e=env({count:2});const api=async(c,m,p,v)=>m==='PUT'&&p==='light/l1'?new Promise(r=>release=()=>e.basic(c,m,p,v).then(r)):e.basic(c,m,p,v);
 const {w}=workspace(e,{api});w.dispatch('manual',{ids:['l1','l2'],on:true,brightness:100});w.tick();await flush(40);assert.ok(release);w.dispatch('switchArea','zone/zone2');w.dispatch('manual',{ids:['l1'],on:false});assert.equal(w.state().navigation.switching,true);release();await w.settled();assert.equal(w.state().meta.scopeId,'zone/zone2');assert.deepEqual(e.writes().map(c=>c.path),['light/l1']);await w.close();await e.ctl.close();
});
test('close during a scope switch does not construct a replacement controller',async()=>{
 let calls=0,resolve;const e=env({count:1});const factory=g=>{calls++;return {state:()=>({layout:A.cleanLayout({},g.lights),settings:A.ENGINE.clean({}),ui:{}}),update(){},dispatch(){},meta:{name:g.name,lights:[]},close:()=>new Promise(r=>resolve=r),settled:async()=>{}}};
 const groups=[e.group,{...e.group,id:'next'}],w=A.makeWorkspaceController(e.cfg,groups,e.group,{factory,read:e.read,save:e.save,saveConfig:()=>{}});w.dispatch('switchArea','room/next');const done=w.close();resolve();await flush();resolve();await done;assert.equal(calls,1);await e.ctl.close();
});

 test('manual on cannot exceed a ceiling below minimum and never invents an unread brightness',()=>{
 assert.throws(()=>A.manualAction(light('l',{dimming:{brightness:30,min_dim_level:10}}),placement({ceiling:5}),{on:true}),/below/);
 assert.throws(()=>A.manualAction(light('l',{dimming:{min_dim_level:.2}}),placement(),{on:true}),/unavailable/);
 assert.equal(A.manualAction(light('l',{dimming:{min_dim_level:.2}}),placement(),{on:true,brightness:100}).dimming.brightness,100);
 });

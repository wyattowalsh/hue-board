const test=require('node:test'),assert=require('node:assert/strict');
const {A,env,clone,flush}=require('./helpers.cjs');

test('Background delegates a native dynamic palette and survives stopping Scriptable',async()=>{
 const e=env({count:3});e.ctl.dispatch('background');await e.step();await e.ctl.settled();
 const s=e.ctl.state();assert.equal(s.mode,'delegated');assert.equal(s.native,true);
 assert.equal(s.background.available,true);assert.equal(s.background.count,3);
 assert.equal(e.calls.filter(c=>c.method==='POST'&&c.path==='scene').length,1);
 assert.ok(e.calls.some(c=>c.method==='PUT'&&c.path.startsWith('scene/')&&c.payload.recall?.action==='dynamic_palette'));
 assert.ok([...e.database.values()].every(l=>l.dynamics.status==='dynamic_palette'));
 const writes=e.calls.filter(c=>c.method!=='GET').length;e.ctl.tick(true);await e.ctl.close();
 assert.equal(e.calls.filter(c=>c.method!=='GET').length,writes,'Closing did not send a stop command');
 assert.ok([...e.database.values()].every(l=>l.dynamics.status==='dynamic_palette'),'Bridge keeps playback');
});

test('Background preset configures the existing source engine and never starts a REST live loop',async()=>{
 const e=env({count:2});e.ctl.dispatch('backgroundPreset','deep-orbit');await e.step();await e.ctl.settled();
 assert.equal(e.ctl.state().mode,'delegated');assert.equal(e.ctl.state().settings.showA,'deep');
 const writes=e.writes().length;await e.run(9000);assert.equal(e.writes().length,writes);await e.ctl.close();
});

test('No scene is created for the All lights virtual scope',async()=>{
 const e=env({count:2});const all=A.makeController(e.cfg,{...e.group,id:'all-lights',type:'all'},{now:e.now,api:e.basic,read:e.read,save:e.save,uid:()=> 'all-test',sleep:async()=>{}});
 assert.equal(all.state().background.available,false);all.dispatch('background');all.tick();await all.settled();
 assert.match(all.state().error,/room or zone/i);assert.equal(e.calls.filter(c=>c.method!=='GET').length,0);
 await all.close();await e.ctl.close();
});

test('Devices lacking dynamic palettes are rejected before making scene writes',async()=>{
 const e=env({count:2,lightExtras:{dynamics:{status:'none',status_values:['none']}}});
 assert.equal(e.ctl.state().background.available,false);e.ctl.dispatch('background');await e.step();await e.ctl.settled();
 assert.match(e.ctl.state().error,/support/i);assert.equal(e.calls.filter(c=>c.method!=='GET').length,0);await e.ctl.close();
});

test('Invalid preset fails closed without changing settings or sending writes',async()=>{
 const e=env({count:1}),old=clone(e.ctl.state().settings);e.ctl.dispatch('backgroundPreset','not-a-real-preset');
 await e.step();await e.ctl.settled();assert.match(e.ctl.state().error,/valid scene/);assert.deepEqual(e.ctl.state().settings,old);
 assert.equal(e.calls.filter(c=>c.method!=='GET').length,0);await e.ctl.close();
});

test('Explicit stop ends delegated native effects without restoring/altering unrelated lights',async()=>{
 const e=env({count:2});e.ctl.dispatch('background');await e.step();await e.ctl.settled();
 e.ctl.dispatch('stopBridge');await e.step();await e.ctl.settled();
 assert.equal(e.ctl.state().native,false);assert.equal(e.ctl.state().mode,'paused');
 assert.ok([...e.database.values()].every(l=>l.dynamics.status==='none'||l.effects_v2.status.effect==='no_effect'));
 await e.ctl.close();
});

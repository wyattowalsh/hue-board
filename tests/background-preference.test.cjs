const test = require('node:test');
const assert = require('node:assert/strict');
const {env,clone}=require('./helpers.cjs');

test('background preference defaults off for upgraded installations',async()=>{
  const e=env({count:2});
  assert.equal(e.ctl.state().ui.continueInBackground,false);
  assert.equal(e.calls.filter(c=>c.method!=='GET').length,0);
  await e.ctl.close();
});

test('when preference is on, Play delegates to Hue Bridge without foreground frames',async()=>{
  const e=env({count:2});
  const s=e.ctl.state();e.ctl.update({ui:{...s.ui,continueInBackground:true}});
  assert.equal(e.ctl.state().ui.continueInBackground,true);
  e.ctl.dispatch('live');await e.step();await e.ctl.settled();
  assert.equal(e.ctl.state().mode,'delegated');
  assert.equal(e.ctl.state().running,false);
  assert.equal(e.calls.filter(c=>c.method==='POST'&&c.path==='scene').length,1);
  assert.equal(e.calls.filter(c=>c.method==='PUT'&&c.path.startsWith('scene/')&&c.payload?.recall?.action==='dynamic_palette').length,1);
  const n=e.writes().length;await e.run(9000);assert.equal(e.writes().length,n);
  await e.ctl.close();
});

test('turning preference on during Live sends an immediate native handoff',async()=>{
  const e=env({count:2});await e.start();await e.run(2000);
  assert.equal(e.ctl.state().running,true);
  const s=e.ctl.state();e.ctl.update({ui:{...s.ui,continueInBackground:true}});
  await e.step();await e.ctl.settled();
  assert.equal(e.ctl.state().running,false);
  assert.equal(e.ctl.state().native,true);
  assert.equal(e.ctl.state().mode,'delegated');
  const n=e.writes().length;await e.run(12000);assert.equal(e.writes().length,n);
  await e.ctl.close();
});

test('background-enabled preset uses native scene rather than foreground playback',async()=>{
  const e=env({count:2});const s=e.ctl.state();e.ctl.update({ui:{...s.ui,continueInBackground:true}});
  e.ctl.dispatch('playPreset','ion-eclipse');await e.step();await e.ctl.settled();
  assert.equal(e.ctl.state().native,true);
  assert.equal(e.ctl.state().running,false);
  assert.equal(e.ctl.state().settings.showA,'eclipse');
  await e.ctl.close();
});

test('cue sequence is refused instead of pretending it can run on Bridge',async()=>{
  const e=env({count:2});const s=e.ctl.state();e.ctl.update({ui:{...s.ui,continueInBackground:true}});
  e.ctl.dispatch('startSequence');await e.run(3000);
  assert.equal(e.ctl.state().running,false);
  assert.match(e.ctl.state().error,/Cue sequences need/);
  assert.equal(e.calls.filter(c=>c.method==='POST').length,0);
  await e.ctl.close();
});

test('All lights scope cannot silently start an unprotected foreground show when background is on',async()=>{
  const e=env({count:2});const s=e.ctl.state();e.group.type='all';
  // A controller created with an actual All lights scope must refuse native playback.
  const c=e.A.makeController(e.cfg,{...e.group,type:'all',id:'all-synthetic'},{now:e.now,api:e.basic,read:e.read,save:e.save,uid:()=> 'all-session',sleep:async()=>{}});
  c.update({ui:{...c.state().ui,continueInBackground:true}});c.dispatch('live');c.tick();await c.settled();
  assert.equal(c.state().running,false);assert.match(c.state().error,/room or zone/i);
  await c.close();await e.ctl.close();
});

test('continued playback preserves the preference and restore point after close',async()=>{
  const e=env({count:2});const s=e.ctl.state();e.ctl.update({ui:{...s.ui,continueInBackground:true}});
  e.ctl.dispatch('live');await e.step();await e.ctl.settled();await e.ctl.close();
  const c=e.A.makeController(e.cfg,e.group,{now:e.now,api:e.basic,read:e.read,save:e.save,uid:()=> 'reopened',sleep:async()=>{}});
  assert.equal(c.state().ui.continueInBackground,true);
  assert.equal(c.state().native,true);
  assert.equal(c.state().session.recoveryRequired,true);
  assert.equal(c.state().mode,'detached');
  await c.close();
});

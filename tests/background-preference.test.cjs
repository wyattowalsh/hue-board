const test=require('node:test'),assert=require('node:assert/strict');
const {env,clone}=require('./helpers.cjs');

test('automatic phone-free Play needs no preference and never starts on app open',async()=>{
  const e=env({count:2});
  assert.deepEqual(e.ctl.state().ui,{theme:'system',motion:'system',favorites:[]});
  await e.run(2000);
  assert.equal(e.calls.filter(c=>c.method!=='GET').length,0);
  assert.equal(e.ctl.state().native,false);
  await e.ctl.close();
});

test('legacy Keep playing switch no longer controls playback',async()=>{
  const e=env({count:2});
  const before=e.ctl.state().ui;
  e.ctl.update({ui:{...before,continueInBackground:false}});
  assert.deepEqual(e.ctl.state().ui,before);
  e.ctl.dispatch('playPreset','ion-eclipse');await e.step();await e.ctl.settled();
  assert.equal(e.ctl.state().mode,'delegated');
  assert.equal(e.ctl.state().settings.showA,'eclipse');
  assert.equal(e.calls.filter(c=>c.method==='POST'&&c.path==='scene').length,1);
  assert.equal(e.calls.filter(c=>c.method==='PUT'&&c.path.startsWith('scene/')&&c.payload?.recall?.action==='dynamic_palette').length,1);
  const n=e.writes().length;await e.run(9000);assert.equal(e.writes().length,n);
  await e.ctl.close();
});

test('explicit Live Studio keeps exact foreground motion and can be paused',async()=>{
  const e=env({count:2});await e.start();await e.run(5000);
  assert.equal(e.ctl.state().mode,'live');
  assert.equal(e.ctl.state().running,true);
  assert.ok(e.writes().length>0);
  assert.equal(e.calls.filter(c=>c.path==='scene').length,0);
  e.ctl.dispatch('pause');const n=e.writes().length;await e.run(2000);
  assert.equal(e.writes().length,n);
  await e.ctl.close();
});

test('cue sequence remains an explicit foreground session',async()=>{
  const e=env({count:2});e.ctl.dispatch('startSequence');await e.step();await e.ctl.settled();
  assert.equal(e.ctl.state().running,true);assert.equal(e.ctl.state().sequence.enabled,true);
  assert.equal(e.calls.filter(c=>c.path==='scene').length,0);
  await e.ctl.close();
});

test('a non-room scope refuses phone-free Play without mutating the saved composition or starting Live',async()=>{
  const e=env({count:2});const group={...e.group,type:'all',id:'all-synthetic'};
  const c=e.A.makeController(e.cfg,group,{now:e.now,api:e.basic,read:e.read,save:e.save,uid:()=> 'all-session',sleep:async()=>{}});
  const before=clone(c.state().settings);
  c.dispatch('playPreset','ion-eclipse');c.tick();await c.settled();
  assert.equal(c.state().running,false);assert.match(c.state().error,/room or zone/i);
  assert.deepEqual(c.state().settings,before);
  assert.equal(e.calls.filter(x=>x.method!=='GET').length,0);
  await c.close();await e.ctl.close();
});

test('accepted Bridge playback survives controller closure but needs recovery review on reopening',async()=>{
  const e=env({count:2});e.ctl.dispatch('playPreset','ion-eclipse');await e.step();await e.ctl.settled();await e.ctl.close();
  const c=e.A.makeController(e.cfg,e.group,{now:e.now,api:e.basic,read:e.read,save:e.save,uid:()=> 'reopened',sleep:async()=>{}});
  assert.equal(c.state().native,true);assert.equal(c.state().mode,'detached');
  assert.equal(c.state().session.recoveryRequired,true);
  await c.close();
});

test('loss of Bridge recall acknowledgment never claims automatic playback succeeded',async()=>{
  let recalls=0;
  const e=env({count:2,apiOverride:async(c,m,p,v,basic)=>{
    if(m==='PUT'&&p.startsWith('scene/')&&v?.recall){recalls++;throw new Error('Response lost after possible recall');}
    return basic(c,m,p,v);
  }});
  e.ctl.dispatch('playPreset','ion-eclipse');await e.step();await e.ctl.settled();
  const s=e.ctl.state();
  assert.equal(recalls,1);assert.equal(s.native,false);
  assert.equal(s.background.uncertain,true);
  assert.match(s.note,/retained/i);
  assert.ok(Object.values(s.delegated).every(d=>d.state==='request pending'));
  await e.ctl.close();
});


test('a prior dynamic Bridge status cannot confirm a recall whose receipt was lost',async()=>{
  const e=env({count:1,apiOverride:async(c,m,p,v,basic)=>{
    if(m==='PUT'&&p.startsWith('scene/')&&v?.recall)throw new Error('response lost');
    return basic(c,m,p,v);
  }});
  e.database.get('l1').dynamics.status='dynamic_palette';
  e.ctl.dispatch('background');await e.step();await e.ctl.settled();
  await e.run(4000);
  assert.equal(e.ctl.state().native,false);
  assert.equal(e.ctl.state().background.uncertain,true);
  assert.equal(e.ctl.state().delegated.l1.state,'request pending');
  await e.ctl.close();
});

const test=require('node:test'),assert=require('node:assert/strict');
const {env}=require('./helpers.cjs');

test('Play on a compatible room chooses native dynamic scene, not foreground REST animation',async()=>{
  const e=env({count:2});e.ctl.dispatch('background');await e.step();await e.ctl.settled();
  assert.equal(e.ctl.state().mode,'delegated');
  assert.equal(e.ctl.state().native,true);
  assert.equal(e.ctl.state().background.uncertain,false);
  assert.ok(e.calls.some(x=>x.path.startsWith('scene/')&&x.payload?.recall?.action==='dynamic_palette'));
  const n=e.writes().length;await e.run(11000);
  assert.equal(e.writes().length,n);await e.ctl.close();
});

test('unsupported dynamic fixtures do not silently fall back to foreground playback',async()=>{
  const e=env({count:2,lightExtras:{dynamics:{status:'none',status_values:['none']}}});
  e.ctl.dispatch('background');await e.step();await e.ctl.settled();
  assert.equal(e.ctl.state().native,false);
  assert.equal(e.ctl.state().running,false);
  assert.match(e.ctl.state().error,/no selected color lights/i);
  assert.equal(e.calls.filter(c=>c.method!=='GET').length,0);
  await e.ctl.close();
});

test('Stop Bridge remains available for uncertain handoff records after recall failure',async()=>{
  let reject=true;
  const e=env({count:2,apiOverride:async(c,m,p,v,basic)=>{
    if(reject&&m==='PUT'&&p.startsWith('scene/')&&v?.recall){reject=false;throw new Error('lost receipt');}
    return basic(c,m,p,v);
  }});
  e.ctl.dispatch('background');await e.step();await e.ctl.settled();
  assert.equal(e.ctl.state().native,false);
  assert.equal(e.ctl.state().background.uncertain,true);
  e.ctl.dispatch('stopBridge');await e.step();await e.ctl.settled();
  assert.equal(e.ctl.state().background.uncertain,false);
  assert.equal(Object.keys(e.ctl.state().delegated).length,0);
  await e.ctl.close();
});

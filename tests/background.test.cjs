const test=require('node:test');
const assert=require('node:assert/strict');
const {env}=require('./helpers.cjs');

test('opt-in never starts a show just by opening a controller',async()=>{
 const e=env({count:2});
 e.ctl.update({ui:{...e.ctl.state().ui,continueInBackground:true}});
 assert.equal(e.ctl.state().ui.continueInBackground,true);
 assert.equal(e.writes().length,0);
 assert.equal(e.ctl.state().native,false);
 await e.ctl.close();
});

test('Play in keep-playing mode delegates to Bridge, not foreground REST loop',async()=>{
 const e=env({count:2});
 e.ctl.update({ui:{...e.ctl.state().ui,continueInBackground:true}});
 e.ctl.dispatch('live');await e.step();await e.ctl.settled();
 assert.equal(e.ctl.state().native,true);
 assert.equal(e.ctl.state().mode,'delegated');
 assert.ok(e.calls.some(x=>x.path.startsWith('scene/')&&x.payload?.recall?.action==='dynamic_palette'));
 const n=e.writes().length;
 await e.run(11000);
 assert.equal(e.writes().length,n,'no live REST animation after handoff');
 await e.ctl.close();
 assert.equal(e.calls.filter(x=>x.payload?.recall?.action==='dynamic_palette').length,1);
});

test('enabling while already live queues an immediate Bridge handoff',async()=>{
 const e=env({count:2});await e.start();
 assert.equal(e.ctl.state().mode,'live');
 e.ctl.update({ui:{...e.ctl.state().ui,continueInBackground:true}});
 assert.equal(e.ctl.state().ui.continueInBackground,true);
 await e.step();await e.ctl.settled();
 assert.equal(e.ctl.state().mode,'delegated');
 assert.equal(e.ctl.state().native,true);
 await e.ctl.close();
});

test('cue sequence is rejected in native-only background mode',async()=>{
 const e=env({count:1});e.ctl.update({ui:{...e.ctl.state().ui,continueInBackground:true}});
 e.ctl.dispatch('startSequence');
 assert.match(e.ctl.state().error,/cue|sequence/i);
 assert.equal(e.writes().length,0);
 await e.ctl.close();
});

test('unsupported background mode preserves foreground show and refuses silent handoff',async()=>{
 const e=env({count:1});e.group.type='all';
 await e.start();
 assert.equal(e.ctl.state().mode,'live');
 e.ctl.update({ui:{...e.ctl.state().ui,continueInBackground:true}});
 assert.equal(e.ctl.state().ui.continueInBackground,false);
 assert.equal(e.ctl.state().mode,'live');
 assert.equal(e.ctl.state().native,false);
 await e.ctl.close();
});

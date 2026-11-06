const test=require('node:test'),assert=require('node:assert/strict');
const {A,light,env,flush,clone}=require('./helpers.cjs');
const {fixture,catalog}=require('./layout-fixture.cjs');
const near=(a,b)=>assert.ok(Math.abs(a-b)<1e-9,`${a} != ${b}`);

test('Hue layout: renderer references map shuffled services to exact bulb IDs',()=>{
 const f=fixture();f.services.reverse();f.lights.reverse();const c=catalog(f);assert.equal(c.matched,3);assert.equal(c.outside,1);
 assert.equal(c.records.find(r=>r.lightId==='l1').position.x,-.8);assert.equal(c.records.find(r=>r.lightId==='l2').position.x,.8);
 assert.ok(c.records.every(r=>r.matchedBy==='renderer_reference'));
});
test('Hue layout: exact service endpoints retained separately from sorted channel segments',()=>{
 const c=catalog(),r=c.records.find(r=>r.lightId==='l3');assert.equal(r.positions.length,2);assert.equal(r.channels.length,7);
 assert.deepEqual(r.channels.map(c=>c.index),[0,1,2,3,4,5,6]);near(r.position.x,0);assert.equal(r.position.z,.7);
 assert.equal(r.channels[0].channelId,30);assert.equal(r.channels[6].channelId,36);
});
test('Hue layout: unique device-owner fallback works without entertainment resource',()=>{
 const f=fixture();f.services=[];const c=catalog(f);assert.equal(c.matched,3);assert.ok(c.records.every(r=>r.matchedBy==='unique_device_owner'));
});
test('Hue layout: ambiguous multi-service device is never guessed from area membership or order',()=>{
 const f=fixture();f.services[0].renderer_reference=undefined;
 const second=light('same-owner',{owner:f.lights[0].owner});f.lights.push(second);f.area.light_services=[{rid:'l1',rtype:'light'}];
 assert.ok(!catalog(f).records.some(r=>r.lightId==='l1'));assert.ok(catalog(f).warnings.some(v=>/Ambiguous/.test(v)));
});
test('Hue layout: explicit renderer reference resolves a multi-light device precisely',()=>{
 const f=fixture();f.lights.push(light('same-owner',{owner:f.lights[0].owner}));assert.ok(catalog(f).records.some(r=>r.lightId==='l1'));
});
test('Hue layout: bad explicit reference does not silently fall back to device guess',()=>{
 const f=fixture();f.services[0].renderer_reference.rid='missing';assert.ok(!catalog(f).records.some(r=>r.lightId==='l1'));
});
test('Hue layout: no UUID-name or list-index matching',()=>{
 const f=fixture();f.services=[];f.devices=[];f.area.locations.service_locations[0].service={rid:'Lamp l1',rtype:'entertainment'};
 assert.equal(catalog(f).matched,0);
});
test('Hue layout: direct light reference supported without pretending channel ID is bulb ID',()=>{
 const f=fixture();f.area.locations.service_locations=[{service:{rid:'l1',rtype:'light'},positions:[{x:.1,y:.2,z:.3}]}];f.area.channels=[];
 assert.equal(catalog(f).records[0].matchedBy,'direct_light');
});
test('Hue layout: shared channels keep exact service placements and disclose member average',()=>{
 const f=fixture();f.area.channels=[{channel_id:0,position:{x:0,y:0,z:0},members:[{service:{rid:'e-l1',rtype:'entertainment'},index:0},{service:{rid:'e-l2',rtype:'entertainment'},index:0}]}];
 const c=catalog(f);assert.equal(c.records[0].position.x,-.8);assert.equal(c.records[0].channels[0].position.x,0);assert.equal(c.records[0].channels[0].shared,true);
});
test('Hue layout: channel-only fallback is explicitly labelled lower confidence',()=>{
 const f=fixture();f.area.locations={service_locations:[]};const c=catalog(f);assert.equal(c.matched,3);assert.ok(c.records.every(r=>r.source==='channel_average'));
});
test('Hue layout: deprecated single position is accepted without fabricating XYZ',()=>{
 const f=fixture();const loc=f.area.locations.service_locations[0];loc.position=loc.positions[0];delete loc.positions;assert.equal(catalog(f).records[0].position.x,-.8);
});
test('Hue layout: invalid, string, out-of-range and missing coordinates are rejected',()=>{
 for(const p of [null,{}, {x:0,y:0},{x:'0',y:0,z:0},{x:1.1,y:0,z:0},{x:NaN,y:0,z:0},{x:0,y:Infinity,z:0}])assert.equal(A.huePosition(p),null);
 const f=fixture();f.area.channels=[];f.area.locations.service_locations[0].positions[0].x=20;assert.ok(!catalog(f).records.some(r=>r.lightId==='l1'));
});
test('Hue layout: conflicting coordinates on one segment are skipped, not arbitrarily chosen',()=>{
 const f=fixture();f.area.channels.push({channel_id:99,position:{x:0,y:0,z:0},members:[{service:{rid:'e-l1',rtype:'entertainment'},index:0}]});assert.ok(!catalog(f).records.some(r=>r.lightId==='l1'));
});
test('Hue layout: conflicting duplicate service positions skipped',()=>{
 const f=fixture();f.area.locations.service_locations.push({service:{rid:'e-l1',rtype:'entertainment'},positions:[{x:.1,y:.1,z:.1}]});assert.ok(!catalog(f).records.some(r=>r.lightId==='l1'));
});
test('Hue layout: two service resources pointing at one bulb are not merged silently',()=>{
 const f=fixture();f.services.push({id:'second-e',renderer_reference:{rid:'l1',rtype:'light'}});f.area.locations.service_locations.push({service:{rid:'second-e',rtype:'entertainment'},positions:[{x:0,y:0,z:0}]});assert.ok(!catalog(f).records.some(r=>r.lightId==='l1'));
});
test('Hue layout: projection preserves coordinate scale and all three named views',()=>{
 const p={x:1,y:.5,z:-1};const xy=A.hueProjection(p,'xy'),xz=A.hueProjection(p,'xz'),yz=A.hueProjection(p,'yz');
 near((xy.x-.5)*312,88);near((xy.y-.5)*198,-44);near(xz.x,xy.x);near((xz.y-.5)*198,88);near((yz.x-.5)*312,44);
 near(A.hueProjection(p,'xy',true).x,1-xy.x);
});
test('Hue layout: phase derives from raw geometry, not selected fixture order',()=>{
 near(A.huePhase({x:0,y:1,z:0}),0);near(A.huePhase({x:1,y:0,z:0}),.25);near(A.huePhase({x:0,y:-1,z:0}),.5);
 assert.equal(A.huePhase({x:0,y:0,z:.5}),null);near(A.huePhase({x:0,y:0,z:.5},'z'),.75);
});
test('Hue layout: applying preserves selection, roles, brightness limits and unmatched lamps',()=>{
 const f=fixture(),scope=f.lights,current=A.cleanLayout({},scope);current.selected=['l1'];current.placements.l1.trim=.37;current.placements.l1.role='task';
 const c=catalog(f,f.scope);const before=clone(current);const result=A.applyHueLayout(current,scope,c,{projection:'xz',phaseMode:'z'},20000);
 assert.deepEqual(current,before);assert.deepEqual(result.selected,['l1']);assert.equal(result.placements.l1.trim,.37);assert.equal(result.placements.l1.role,'task');
 assert.deepEqual(result.placements.outside,before.placements.outside);assert.equal(result.placements.l1.hue.equalizationFactor,.6);assert.equal(result.placements.l1.hue.importedAt,20000);
 assert.equal(result.placements.l1.hue.position.z,.2);near(result.placements.l1.q,.6);
});
test('Hue layout: keep-path import and centre point do not invent a new angular phase',()=>{
 const f=fixture(),current=A.cleanLayout({},f.scope);current.placements.l1.q=.713;const c=catalog(f);
 assert.equal(A.applyHueLayout(current,f.scope,c,{phaseMode:'keep'}).placements.l1.q,.713);
 c.records.find(r=>r.lightId==='l1').position={x:0,y:0,z:1};assert.equal(A.applyHueLayout(current,f.scope,c,{phaseMode:'clockwise'}).placements.l1.q,.713);
});
test('Hue layout: co-located lamps stay co-located; no made-up spacing',()=>{
 const f=fixture();f.area.locations.service_locations[1].positions=clone(f.area.locations.service_locations[0].positions);const l=A.applyHueLayout({},f.scope,catalog(f));
 assert.equal(l.placements.l1.x,l.placements.l2.x);assert.equal(l.placements.l1.y,l.placements.l2.y);
});
test('Hue layout: source survives cleanLayout, selection edits and local map edits',()=>{
 const f=fixture(),l=A.applyHueLayout({},f.scope,catalog(f));l.selected=['l2'];l.placements.l1.x=.8;const out=A.cleanLayout(l,f.scope);
 assert.equal(out.placements.l1.hue.position.x,-.8);assert.equal(out.placements.l1.x,.8);assert.match(A.huePlacementText(out.placements.l1),/local placement\/path edited/);
});
test('Hue layout: read pipeline uses GET only and no streaming client key',async()=>{
 const f=fixture(),calls=[],data={entertainment_configuration:[f.area],entertainment:f.services,device:f.devices,light:f.lights};
 const c=await A.fetchHueLayoutCatalog({},f.scope,async(_cfg,m,p,v)=>{assert.equal(m,'GET');assert.equal(v,undefined);calls.push(p);return {data:data[p]};},()=>123);
 assert.equal(c[0].matched,3);assert.deepEqual(calls,['entertainment_configuration','entertainment','device','light']);
});
test('Hue layout: no-area fast path avoids unrelated collection reads',async()=>{
 let calls=0;assert.deepEqual(await A.fetchHueLayoutCatalog({},[],async()=>{calls++;return {data:[]};}),[]);assert.equal(calls,1);
});
test('Hue layout: optional entertainment 404 falls back to devices, auth errors do not',async()=>{
 const f=fixture(),data={entertainment_configuration:[f.area],device:f.devices,light:f.lights};
 const read=async(_c,_m,p)=>{if(p==='entertainment')throw new A.HueError('missing','Not found',404);return {data:data[p]};};
 assert.equal((await A.fetchHueLayoutCatalog({},f.scope,read))[0].matched,3);
 await assert.rejects(A.fetchHueLayoutCatalog({},f.scope,async(_c,_m,p)=>{if(p==='entertainment')throw new A.HueError('auth','No',403);return {data:data[p]};}),e=>e.status===403);
});
test('Hue layout: cancellation stops further collection reads',async()=>{
 let cancel=false,calls=0;await assert.rejects(A.fetchHueLayoutCatalog({},[],async()=>{calls++;cancel=true;return {data:[fixture().area]};},()=>1,()=>cancel),e=>e.kind==='cancelled');assert.equal(calls,1);
});
test('Hue layout: malformed collection response is surfaced instead of an empty-success claim',async()=>{
 await assert.rejects(A.fetchHueLayoutCatalog({},[],async()=>({errors:[],data:null})),e=>e.kind==='protocol');
});
function layoutEnv(){const f=fixture();const e=env({count:3,apiOverride:async(cfg,m,p,v,basic)=>{
 if(m==='GET'&&p==='entertainment_configuration')return {data:[f.area]};
 if(m==='GET'&&p==='entertainment')return {data:f.services};if(m==='GET'&&p==='device')return {data:f.devices};return basic(cfg,m,p,v);
 }});return e;}
test('Hue layout controller: automatic discovery never applies positions or writes lights',async()=>{
 const e=layoutEnv(),before=e.ctl.state().layout;await e.step();await e.ctl.layoutSettled();assert.equal(e.ctl.state().hueLayouts.areas[0].matched,3);assert.deepEqual(e.ctl.state().layout,before);assert.equal(e.writes().length,0);await e.ctl.close();
});
test('Hue layout controller: import, preservation, undo and persisted source work without writes',async()=>{
 const e=layoutEnv();await e.step();await e.ctl.layoutSettled();const before=e.ctl.state().layout;
 e.ctl.dispatch('importHueLayout',{areaId:'area1',projection:'xz',phaseMode:'z'});await e.step();await e.ctl.settled();
 let state=e.ctl.state();assert.equal(state.layout.hue.areaId,'area1');assert.equal(state.settings.topology,'path');assert.equal(state.hueLayouts.canUndo,true);assert.equal(state.mode,'paused');
 assert.equal(e.store['hue-board.workspace.v3'][e.ctl.area].layout.placements.l1.hue.serviceId,'e-l1');assert.equal(e.writes().length,0);
 e.ctl.dispatch('undoHueLayout');await e.step();await e.ctl.settled();assert.deepEqual(e.ctl.state().layout,before);assert.equal(e.ctl.state().settings.topology,'ring');assert.equal(e.writes().length,0);await e.ctl.close();
});
test('Hue layout controller: importing during live cancels future work without rewriting restore point',async()=>{
 const e=layoutEnv();await e.step();await e.ctl.layoutSettled();await e.start();await e.run(2000);await e.ctl.settled();const writes=e.writes().length,session=e.ctl._session();
 e.ctl.dispatch('importHueLayout',{areaId:'area1',phaseMode:'clockwise'});await e.step();await e.ctl.settled();await e.run(2000);
 assert.equal(e.writes().length,writes);assert.deepEqual(e.ctl._session(),session);assert.equal(e.ctl.state().mode,'paused');await e.ctl.close();
});
test('Hue layout controller: stale failed refresh blocks import without destroying previous placement',async()=>{
 let fail=false;const f=fixture(),e=env({count:3,apiOverride:async(c,m,p,v,basic)=>{
 if(p==='entertainment_configuration'){if(fail)throw new A.HueError('network','offline');return {data:[f.area]};}
 if(p==='entertainment')return {data:f.services};if(p==='device')return {data:f.devices};return basic(c,m,p,v);
 }});await e.step();await e.ctl.layoutSettled();const before=e.ctl.state().layout;fail=true;e.ctl.dispatch('refreshHueLayout');await e.ctl.layoutSettled();
 e.ctl.dispatch('importHueLayout',{areaId:'area1'});assert.match(e.ctl.state().error,/successful Hue layout read/);assert.deepEqual(e.ctl.state().layout,before);await e.ctl.close();
});
test('Hue layout controller: close ignores an outstanding discovery and launches no follow-ups',async()=>{
 let release,calls=0;const e=env({count:1,apiOverride:async(c,m,p,v,basic)=>{if(p==='entertainment_configuration'){calls++;return new Promise(r=>release=r);}if(['entertainment','device'].includes(p))calls++;return basic(c,m,p,v);}});
 await e.step();await e.ctl.close();release({data:[fixture().area]});await flush();await e.ctl.layoutSettled();assert.equal(calls,1);assert.equal(e.ctl.state().hueLayouts.areas.length,0);
});

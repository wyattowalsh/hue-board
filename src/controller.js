/** Shared state machine for both interfaces. UI intent never awaits the network writer. */
function makeController(cfg,group,options={}) {
  const now=options.now||(()=>Date.now()),api=options.api||endpoint;
  const read=options.read||readObject,save=options.save||writeObject,newId=options.uid||uid;
  const lights=orderedLights(cfg,group).filter(l=>typeof l.on?.on==='boolean'),byId=new Map(lights.map(l=>[l.id,l]));
  if(!lights.length)throw new HueError('validation','This area has no controllable lights.');
  const area=(cfg.bridgeId||cfg.ip)+'/'+group.type+'/'+group.id;
  const store=read(V3_STORE,{}),legacy=read(LEGACY_KEYS.olderWorkspace,{})[cfg.ip+'/'+group.id]||{};
  const stored=store[area]||legacy;
  let layoutUndo=stored.layoutUndo?{layout:cleanLayout(stored.layoutUndo.layout,lights),topology:stored.layoutUndo.topology==='path'?'path':'ring'}:null;
  let layoutCatalog=[],layoutJob=null,layoutAttempted=false;
  const layoutRead={pending:false,error:'',fetchedAt:null,revision:0};
  let ui=cleanUiPrefs(stored.ui),sequence={enabled:false,armed:false,index:0,cycle:0,nextAt:0},activeSeconds=0;
  let settings=ENGINE.clean(stored.settings),layout=cleanLayout(stored.layout||stored,lights);
  const presets=Array.isArray(stored.presets)?stored.presets.slice(0,20):[];
  const rooms=Array.isArray(stored.rooms)?stored.rooms.slice(0,12):[];
  let manualResult=null,sceneList=[],scenesPending=false,scenesReadAt=null,scenesError='',sceneJob=null;
  const journal=read(V3_SESSION,{});journal.current=journal.current||{};journal.history=Array.isArray(journal.history)?journal.history:[];
  let session=journal.current[area];
  if(!session||session.bridgeId!==(cfg.bridgeId||cfg.ip)||session.group!==group.id){
    const old=read(LEGACY_KEYS.olderRestore,{})[cfg.ip+'/'+group.id];
    session={id:newId(),bridgeId:cfg.bridgeId||cfg.ip,group:group.id,groupType:group.type,createdAt:now(),states:{},delegated:{},legacy:false};
    if(old?.ip===cfg.ip&&old?.group===group.id&&Array.isArray(old.states)){
      for(const e of old.states){const l=byId.get(e.id);if(!l)continue;const action=validatedSnapshot(e.action,l);if(action)session.states[e.id]={action,capturedAt:null,touchedAt:null};}
      if(Object.keys(session.states).length){session.legacy=true;session.createdAt=null;}
    }
  }
  session.states=session.states||{};session.delegated=session.delegated||{};
  // Sanitize persistence: never replay arbitrary payloads from an old saved file.
  for(const id of Object.keys(session.states)){const l=byId.get(id),a=l&&validatedSnapshot(session.states[id]?.action,l);if(a)session.states[id]={...session.states[id],action:a};else delete session.states[id];}
  for(const id of Object.keys(session.delegated))if(!byId.has(id))delete session.delegated[id];
  let recoveryRequired=Object.keys(session.states).length>0;
  const sceneRegistry=read(V3_SCENES,{});
  let mode=Object.keys(session.delegated).length?'detached':'idle',closed=false,epoch=0,job=null,pending=null;
  let elapsed=0,lastTick=now(),lastPrefs='',lastSave=0,controlError='',note='Ready. Opening the deck does not change lights.';
  let transitionAt=now(),fromFrames={},fromGradient={},surgeAt=-Infinity;
  let readRevision=0,sent=0,totalFailures=0,networkFailures=0,failures={},held={},activated={},lastOwn={},offChecks={};
  let requested={},logs=[],jobStarted=0,quarantined=false,lastSend=-Infinity,lastObservedAt=null,restoreFailures=[];
  let badGradients=new Set(),planner=new DeadlinePlanner();
  const stats={writes:0,readErrors:0,maxConcurrentWriters:0,currentWriters:0,missedDeadlines:0};
  function log(kind,message,id=null){logs.push({at:now(),kind,message:shortError(message),lamp:id?layout.order.indexOf(id)+1:null});if(logs.length>60)logs.shift();}
  function persist(){journal.current[area]=clone(session);save(V3_SESSION,journal);}
  function persistPrefs(force=false){const data={schema:3,settings,layout,presets,rooms,layoutUndo,ui},s=JSON.stringify(data);if(s!==lastPrefs&&(force||now()-lastSave>=1000)){store[area]=data;save(V3_STORE,store);lastPrefs=s;lastSave=now();}}
  function isCurrent(token){return !closed&&token===epoch;}
  function check(token){if(!isCurrent(token))throw new HueError('cancelled','Superseded by a newer control action.');}
  function surge(at=now()){const t=(at-surgeAt)/1000;return t>=0&&t<12?Math.sin(Math.PI*t/12)**2:0;}
  function desired(id,t=elapsed,at=now()){
    const p=layout.placements[id],f=fixtureSample(t,p,settings,surge(at));
    return fromFrames[id]?ENGINE.blend(fromFrames[id],f,ENGINE.smooth((at-transitionAt)/settings.transitionMs)):f;
  }
  function gradients(id,t=elapsed,at=now()){
    const l=byId.get(id),p=layout.placements[id],n=capabilities(l).gradient;if(!settings.gradient||n<2||badGradients.has(id)||p.role==='task')return null;
    return Array.from({length:n},(_,i)=>{const f=fixtureSample(t,{...p,q:p.q+(p.stripReverse?-1:1)*(i/(n-1)-.5)*p.extent},settings,surge(at));
      return fromGradient[id]?.[i]?ENGINE.blend(fromGradient[id][i],f,ENGINE.smooth((at-transitionAt)/settings.transitionMs)):f;});
  }
  function freezeForEdit(){const f={},g={};for(const l of lights){f[l.id]=desired(l.id);g[l.id]=gradients(l.id);}fromFrames=f;fromGradient=g;transitionAt=now();}
  function update(packet,fromSequence=false) {
    if(packet.ui){
      const previous=ui.continueInBackground;
      ui=cleanUiPrefs(packet.ui);
      // Handoff while still in the foreground. Waiting for document.hidden is unreliable on iOS.
      if(!previous&&ui.continueInBackground&&mode==='live'){
        dispatch('background');
        if(!pending?.command||pending.command!=='background'){
          ui.continueInBackground=false;
          note='Bridge handoff unavailable in this area; foreground Live remains active.';
        } else note='Handing the current look to the Hue Bridge. Keep Scriptable open until it confirms playback.';
      }
      persistPrefs(true);
    }
    const nextS=ENGINE.clean(packet.settings||settings),nextL=cleanLayout(packet.layout||layout,lights);
    if(JSON.stringify(nextS)!==JSON.stringify(settings)||JSON.stringify(nextL)!==JSON.stringify(layout)){
      if(sequence.enabled&&!fromSequence&&(JSON.stringify({...settings,brightness:nextS.brightness})!==JSON.stringify(nextS)||JSON.stringify(nextL)!==JSON.stringify(layout))){sequence.enabled=false;sequence.armed=false;note='Cue sequence stopped by a manual pattern or room edit.';}
      freezeForEdit();settings=nextS;layout=nextL;persistPrefs();
      if(mode==='live'&&!layout.selected.length){pause('No lamps selected. Live updates paused.');}
    }
  }
  function observe(data,finished,started=finished){
    const found=new Set();lastObservedAt=finished;readRevision++;
    for(const l of data){if(!byId.has(l.id))continue;found.add(l.id);const old=byId.get(l.id);byId.set(l.id,{...l,label:old.label,deviceLabel:old.deviceLabel,model:old.model});
      if(l.mode==='streaming'){held[l.id]='Streaming owner detected';offChecks[l.id]=0;continue;}
      if(mode==='live'&&settings.ownership==='yield_off'&&activated[l.id]&&started>(lastOwn[l.id]?.onAt||0)+500){
        if(l.on?.on===false){offChecks[l.id]=(offChecks[l.id]||0)+1;held[l.id]=offChecks[l.id]>=2?'Yielded to external off':'Checking an off readback';
          if(offChecks[l.id]===2)log('ownership','Yielded to two off readbacks; Start explicitly reclaims this lamp.',l.id);}
        else if(offChecks[l.id]===1&&l.on?.on===true){delete held[l.id];offChecks[l.id]=0;}
      }
      const d=session.delegated[l.id];if(d&&started>d.acceptedAt){const matches=d.kind==='effect'?((l.effects_v2?.status?.effect||l.effects?.status)===d.effect):l.dynamics?.status==='dynamic_palette';
        if(matches){d.confirmedAt=finished;d.state='reported';}
        else if(finished-d.acceptedAt>15000){d.state='not reported';}}
    }
    for(const l of lights)if(!found.has(l.id))held[l.id]='Missing from latest Bridge response';
  }
  const telemetry=makeTelemetryMonitor(cfg,lights,api,now,observe);
  function scanHueLayouts(){
    if(closed||layoutJob)return;layoutAttempted=true;layoutRead.pending=true;layoutRead.error='';layoutRead.revision++;
    layoutJob=fetchHueLayoutCatalog(cfg,lights,api,now,()=>closed).then(catalog=>{
      if(closed)return;layoutCatalog=catalog;layoutRead.fetchedAt=now();layoutRead.revision++;
    }).catch(e=>{if(!closed){layoutRead.error=shortError(e);layoutRead.revision++;}})
      .finally(()=>{layoutRead.pending=false;layoutJob=null;});
  }
  function importSavedHueLayout(payload,token){
    check(token);const candidate=layoutCatalog.find(a=>a.id===payload?.areaId);
    if(layoutRead.error||layoutRead.pending)throw new HueError('layout','Finish a successful Hue layout read before importing.');
    if(!candidate?.matched)throw new HueError('layout','Choose a saved Hue area with unambiguous matches in this room.');
    const next=applyHueLayout(layout,lights,candidate,payload,now());
    layoutUndo={layout:clone(layout),topology:settings.topology};
    const topology=next.hue.phaseMode==='keep'?settings.topology:next.hue.phaseMode==='clockwise'?'ring':'path';
    update({settings:{...settings,topology},layout:next});persistPrefs(true);
    note='Imported '+candidate.matched+'/'+candidate.total+' saved Hue placements. Unmatched lamps, selection, roles and brightness limits were preserved. No Hue layout or light writes were sent.';
    if(Object.keys(session.delegated).length)note+=' Existing Bridge playback continues.';
    mode=Object.keys(session.delegated).length?'detached':'paused';log('layout','Saved Hue placement imported locally.');
  }

  function pause(message='Updates paused. A request or fade already sent may still finish.') {
    sequence.enabled=false;sequence.armed=false;epoch++;pending=null;mode=Object.keys(session.delegated).length?'detached':'paused';note=message;log('control',message);
  }
  function active({includeHeld=false}={}){return layout.order.filter(id=>byId.get(id)?.dimming&&layout.selected.includes(id)&&(includeHeld||!held[id])&&byId.get(id)?.mode!=='streaming').map(id=>byId.get(id));}
  function launch(task){if(job||closed)return;jobStarted=now();quarantined=false;job=Promise.resolve().then(task).catch(e=>{
      if(errorKind(e)==='cancelled')return;
      controlError=shortError(e);log(errorKind(e),controlError);if(errorKind(e)==='auth'){epoch++;pending=null;mode='error';note='Authorization failed. No automatic re-pairing or retries.';}
    }).finally(()=>{job=null;jobStarted=0;quarantined=false;});}
  async function paced(token){check(token);while(now()-lastSend<350){await (options.sleep||sleep)(Math.max(1,350-(now()-lastSend)));check(token);}lastSend=now();}
  async function capture(ids,token,fresh=null){check(token);const missing=ids.filter(id=>!session.states[id]);if(!missing.length)return;
    const reply=fresh||await api(cfg,'GET','light');check(token);if(!Array.isArray(reply.data))throw new HueError('protocol','Invalid snapshot response.');
    for(const id of missing){const l=reply.data.find(x=>x.id===id);if(!l)throw new HueError('missing','A selected light is missing. Reopen the deck.');if(l.mode==='streaming')throw new HueError('ownership','A selected light belongs to an Entertainment stream. Stop it in its owning app first.');
      const base=byId.get(id);byId.set(id,{...l,label:base.label,deviceLabel:base.deviceLabel,model:base.model});
      session.states[id]={action:snapshotAction(l),capturedAt:now(),touchedAt:null,priorEffect:l.effects_v2?.status?.effect||l.effects?.status||null,priorDynamics:l.dynamics?.status||null};}
    persist();
  }
  async function write(id,action,kind,token){check(token);if(!session.states[id])throw new HueError('session','Restore state was not captured.');
    const light=byId.get(id);if(light?.mode==='streaming')throw new HueError('ownership','Entertainment owns this fixture. No REST write was sent.');
    await paced(token);check(token);
    session.states[id].touchedAt=session.states[id].touchedAt||now();persist();
    requested[id]={at:now(),kind,action:clone(action),status:'in flight'};
    const started=now();stats.currentWriters++;stats.maxConcurrentWriters=Math.max(stats.maxConcurrentWriters,stats.currentWriters);
    try{const reply=await api(cfg,'PUT','light/'+id,action);assertAck(reply,id);sent++;stats.writes++;
      telemetry.noteReply(id,action,kind,reply);requested[id].status='accepted';
      // Record the outcome even if Pause arrived while the request was already in flight.
      lastOwn[id]={acceptedAt:now(),onAt:action.on?.on===true?now():lastOwn[id]?.onAt||0,action:clone(action)};
      if(action.on?.on===true)activated[id]=true;
      if(kind==='live')networkFailures=0;
      return true;
    }catch(e){requested[id].status='uncertain / failed';requested[id].error=shortError(e);throw e;}
    finally{stats.currentWriters--;planner.complete(started,now());}
  }
  async function stopDelegated(token){
    const ids=Object.keys(session.delegated);if(!ids.length)return;
    const reply=await api(cfg,'GET','light');check(token);if(!Array.isArray(reply.data))throw new HueError('protocol','Cannot read state to stop Bridge effects.');
    for(const id of ids){check(token);const l=reply.data.find(x=>x.id===id);if(!l)throw new HueError('missing','A delegated light is missing; its restore point is retained.');
      byId.set(id,{...l,label:byId.get(id).label});const a=snapshotAction(l);delete a.on; // Do not turn a manually switched-off lamp back on.
      await write(id,a,'stop',token);delete session.delegated[id];persist();}
    note='Stop commands accepted. Readback shows whether the effect has stopped.';
  }
  function beginFromReadback(ids){const t=telemetry.snapshot();for(const id of ids){const row=t.data[id],l=byId.get(id);const p=layout.placements[id];
      // Baseline color conversion via telemetry's xy is approximate; frame interpolation starts at last intended frame if present.
      if(!fromFrames[id])fromFrames[id]=fixtureSample(elapsed,p,settings,0);
      const b=row?.brightness??l.dimming?.brightness;if(finite(b))fromFrames[id].b=row?.on===false?1:clamp(b,.1,100);}
    transitionAt=now();
  }
  async function startLive(token){check(token);if(recoveryRequired)throw new HueError('recovery','Choose Resume restore point or New baseline in Lab before starting.');
    const chosen=active({includeHeld:true});if(!chosen.length)throw new HueError('selection','Select a non-streaming dimmable light.');
    if(chosen.length>28)throw new HueError('validation','Select at most 28 dimmable lights for live animation. Everyday controls can manage larger areas.');
    await capture(chosen.map(l=>l.id),token);check(token);await stopDelegated(token);check(token);
    held={};offChecks={};failures={};activated={};badGradients.clear();networkFailures=0;controlError='';
    beginFromReadback(chosen.map(l=>l.id));planner.reset(chosen.map(l=>l.id),now());mode='live';lastTick=now();sequence.enabled=sequence.armed;sequence.armed=false;sequence.nextAt=activeSeconds+settings.sequenceHold;note='Live. External off yields control by default; only Start explicitly turns lamps on.';log('control','Live started');
  }
  async function nativePalette(token){
    if(!['room','zone'].includes(group.type))throw new HueError('validation','Choose a room or zone for a Bridge palette. The All lights view is local, not a Hue scene group.');
    if(recoveryRequired)throw new HueError('recovery','Resolve the saved restore point in Lab.');
    const chosen=active({includeHeld:true});if(!chosen.length)throw new HueError('selection','Select a light.');
    const animated=chosen.filter(l=>capabilities(l).color&&capabilities(l).dynamic&&!['task','anchor'].includes(layout.placements[l.id].role));
    if(!animated.length)throw new HueError('unsupported','No selected fixture advertises dynamic palettes. Try Bridge effects or Live.');
    await capture(chosen.map(l=>l.id),token);await stopDelegated(token);check(token);
    const s=clone(settings),layoutCopy=clone(layout);
    for(const lamp of animated){check(token);const current=byId.get(lamp.id),effect=current.effects_v2?.status?.effect||current.effects?.status;if(effect&&effect!=='no_effect'&&Object.keys(stopEffect(current)).length)await write(lamp.id,stopEffect(current),'handoff',token);}
    const actions=animated.map(l=>{const f=desired(l.id),a=actionFromFrame(l,f,layoutCopy.placements[l.id],s,0,true);delete a.dynamics;return {target:{rid:l.id,rtype:'light'},action:a};});
    // A shared native palette cannot preserve individual gain curves. Use the minimum
    // selected trim/ceiling as a conservative cap, and explain that limitation in UI.
    const level=Math.min(...animated.map(l=>Math.min(s.brightness*layoutCopy.placements[l.id].trim,layoutCopy.placements[l.id].ceiling,100)));
    const paletteIndex=s.morph<50?s.paletteA:s.paletteB;
    const payload={metadata:{name:'Hue Board | '+ENGINE.palettes[paletteIndex].name},actions,
      palette:{color:ENGINE.getColors(s,paletteIndex).map(c=>({color:{xy:ENGINE.xy(c)},dimming:{brightness:level}})),dimming:[],color_temperature:[],effects:[]},
      speed:+clamp(.15+s.speed*.35,.1,.8).toFixed(2),auto_dynamic:true};
    let id=sceneRegistry[area]?.id;
    if(id){try{const r=await api(cfg,'GET','scene/'+id);check(token);const actual=r.data?.find(x=>x.id===id);
        if(!actual||actual.group?.rid!==group.id||actual.group?.rtype!==group.type)throw new HueError('ownership','Saved scene identity/group mismatch. It was not modified.');
      }catch(e){if(e.status===404){id=null;delete sceneRegistry[area];save(V3_SCENES,sceneRegistry);}else throw e;}}
    await paced(token);
    if(id){const r=await api(cfg,'PUT','scene/'+id,payload);assertAck(r,id);}
    else {const r=await api(cfg,'POST','scene',{...payload,group:{rid:group.id,rtype:group.type}});id=r.data?.find(x=>x.rtype==='scene'||x.rid)?.rid;
      if(!id)throw new HueError('protocol','Scene creation result is uncertain. Inspect Hue scenes before retrying.');
      sceneRegistry[area]={id,group:group.id,type:group.type,createdAt:now()};save(V3_SCENES,sceneRegistry);}
    check(token);
    for(const l of animated){session.states[l.id].touchedAt=session.states[l.id].touchedAt||now();session.delegated[l.id]={kind:'palette',scene:id,acceptedAt:now(),state:'request pending'};}
    persist();await paced(token);check(token);const recall=await api(cfg,'PUT','scene/'+id,{recall:{action:'dynamic_palette'}});assertAck(recall,id);sent++;
    for(const l of animated){session.delegated[l.id].acceptedAt=now();session.delegated[l.id].state='accepted';telemetry.noteReply(l.id,null,'native',recall,id);}persist();
    for(const l of chosen.filter(l=>!animated.includes(l))){check(token);const p=layoutCopy.placements[l.id],f=fixtureSample(elapsed,{...p,role:p.role==='task'?'task':'anchor'},s);await write(l.id,{...actionFromFrame(l,f,p,s,2500,true),...stopEffect(l)},'static',token);}
    check(token);mode='delegated';note='Bridge palette accepted for '+animated.length+' lights. You may lock your phone; the Bridge continues independently. This is palette animation, not the exact Studio choreography.';
  }
  async function nativeEffect(token){
    if(recoveryRequired)throw new HueError('recovery','Resolve the saved restore point in Lab.');
    const chosen=active({includeHeld:true}),name=settings.effect,s=clone(settings),ls=clone(layout);
    const supported=chosen.filter(l=>capabilities(l).effects.includes(name)&&!['task','anchor'].includes(ls.placements[l.id].role));
    if(!supported.length)throw new HueError('unsupported','Select an advertised effect and at least one supported fixture.');
    await capture(chosen.map(l=>l.id),token);await stopDelegated(token);check(token);
    for(const l of supported){check(token);session.delegated[l.id]={kind:'effect',effect:name,acceptedAt:now(),state:'request pending'};persist();
      await write(l.id,effectAction(byId.get(l.id),name,s,ls.placements[l.id]),'effect',token);session.delegated[l.id].acceptedAt=now();session.delegated[l.id].state='accepted';persist();}
    for(const l of chosen.filter(l=>!supported.includes(l)&&['task','anchor'].includes(ls.placements[l.id].role))){check(token);const p=ls.placements[l.id];await write(l.id,{...actionFromFrame(l,fixtureSample(elapsed,p,s),p,s,2500,true),...stopEffect(l)},'static',token);}
    check(token);mode='delegated';note=name+' accepted for '+supported.length+'/'+chosen.length+' selected lamps. Unsupported accent/wash fixtures were left unchanged.';
  }
  async function restore(token){
    const errors=[];restoreFailures=[];
    for(const id of Object.keys(session.states)){check(token);const record=session.states[id];
      if(!record.touchedAt&&!session.legacy){delete session.states[id];continue;}
      try{await write(id,record.action,'restore',token);delete session.states[id];delete session.delegated[id];delete held[id];persist();}
      catch(e){if(errorKind(e)==='cancelled')throw e;errors.push(layout.order.indexOf(id)+1);restoreFailures.push({id,error:shortError(e)});log('restore',shortError(e),id);if(errorKind(e)==='auth'||errorKind(e)==='network')break;}
    }
    persist();check(token);mode='paused';recoveryRequired=false;note=errors.length?'Some restore commands failed. Remaining snapshots are retained; tap Restore to retry.':'Static restore commands accepted. Prior animations are not resumed.';
    if(errors.length)controlError=errors.length+' lamp restore command(s) failed.';
  }

  function refreshScenes(){
    if(closed||sceneJob)return;scenesPending=true;scenesError='';
    sceneJob=Promise.resolve().then(()=>api(cfg,'GET','scene')).then(r=>{
      if(closed)return;if(!Array.isArray(r?.data))throw new HueError('protocol','Invalid saved-scene response.');
      sceneList=r.data.filter(x=>typeof x.id==='string'&&(group.type==='all'||(x.group?.rid===group.id&&x.group?.rtype===group.type)))
        .map(x=>({id:x.id,name:String(x.metadata?.name||'Unnamed scene'),count:(x.actions||[]).filter(a=>byId.has(a.target?.rid)).length})).filter(x=>x.count>0);
      scenesReadAt=now();
    }).catch(e=>{if(!closed)scenesError=shortError(e);}).finally(()=>{scenesPending=false;sceneJob=null;});
  }
  async function manual(token,intent){
    check(token);
    if(recoveryRequired&&intent.on!==false)throw new HueError('recovery','Review the saved restore point above before changing lights. Off remains available.');
    const reply=await api(cfg,'GET','light');check(token);
    if(!Array.isArray(reply.data))throw new HueError('protocol','Cannot read current lights. Nothing was sent.');
    const fresh=new Map(reply.data.map(l=>[l.id,l])),actions=[];
    manualResult={at:now(),total:intent.ids.length,accepted:[],skipped:[],failed:[]};
    for(const id of intent.ids){const l=fresh.get(id),old=byId.get(id);
      if(!l){manualResult.skipped.push({id,reason:'Missing from current Bridge response'});continue;}
      byId.set(id,{...l,label:old.label,deviceLabel:old.deviceLabel,model:old.model});
      if(l.mode==='streaming'){manualResult.skipped.push({id,reason:'Owned by an Entertainment stream'});continue;}
      try{const action=manualAction(l,layout.placements[id],intent);if(action)actions.push({id,action});else manualResult.skipped.push({id,reason:'This control is not supported'});}
      catch(e){manualResult.skipped.push({id,reason:shortError(e)});}
    }
    if(!actions.length)throw new HueError('unsupported','No addressed light supports this action. Streaming lights are never overridden.');
    await capture(actions.map(a=>a.id),token,reply);check(token);
    for(const {id,action} of actions){check(token);
      try{await write(id,action,'manual',token);manualResult.accepted.push(id);delete session.delegated[id];delete held[id];persist();}
      catch(e){if(errorKind(e)==='cancelled')throw e;manualResult.failed.push({id,reason:shortError(e)});if(['auth','network','rate','server'].includes(errorKind(e)))break;}
    }
    check(token);mode=Object.keys(session.delegated).length?'detached':'manual';
    const unfinished=manualResult.total-manualResult.accepted.length-manualResult.skipped.length-manualResult.failed.length;
    note=manualResult.accepted.length+' / '+manualResult.total+' light command(s) accepted.'+(manualResult.skipped.length?' '+manualResult.skipped.length+' unsupported, missing or streaming.':'')+(unfinished?' Remaining commands were not sent.':'')+' Readback will confirm reported state.';
    if(manualResult.failed.length)controlError='Some light commands failed. Check the affected lights before retrying.';
    log('manual',note);persist();
  }
  async function applySavedScene(token,id){
    if(recoveryRequired)throw new HueError('recovery','Review the saved restore point before applying a scene.');
    if(typeof id!=='string'||!sceneList.some(x=>x.id===id))throw new HueError('selection','Refresh and choose one of this area’s saved Hue scenes.');
    const result=await api(cfg,'GET','scene/'+id);check(token);
    const scene=result.data?.find(x=>x.id===id);
    if(!scene||(group.type!=='all'&&(scene.group?.rid!==group.id||scene.group?.rtype!==group.type)))throw new HueError('ownership','Scene group changed. Refresh the list.');
    const response=await api(cfg,'GET','light');check(token);if(!Array.isArray(response.data))throw new HueError('protocol','Cannot inspect scene targets.');
    const current=new Map(response.data.map(l=>[l.id,l])),actions=[];
    for(const entry of scene.actions||[]){const lid=entry.target?.rid,light=current.get(lid),p=layout.placements[lid];
      if(entry.target?.rtype!=='light'||!p||!light||light.mode==='streaming'||actions.some(a=>a.id===lid))continue;
      const raw=entry.action||{};
      // A static copy only. No arbitrary scene effects, recalls or destructive operations.
      const action=validatedSnapshot({...raw,on:raw.on||light.on},light);if(!action)continue;
      if(action.dimming){const minimum=Math.max(.1,light.dimming?.min_dim_level||.1);if(p.ceiling<minimum)continue;action.dimming.brightness=+clamp(action.dimming.brightness*p.trim,minimum,p.ceiling).toFixed(2);}
      const previous=byId.get(lid);byId.set(lid,{...light,label:previous.label,deviceLabel:previous.deviceLabel,model:previous.model});actions.push({id:lid,action});
    }
    if(!actions.length)throw new HueError('unsupported','No compatible static scene actions in this area.');
    await capture(actions.map(a=>a.id),token,response);
    manualResult={at:now(),total:actions.length,accepted:[],skipped:[],failed:[]};
    for(const a of actions){check(token);try{await write(a.id,a.action,'scene-copy',token);manualResult.accepted.push(a.id);delete session.delegated[a.id];persist();}catch(e){if(errorKind(e)!=='cancelled')manualResult.failed.push({id:a.id,reason:shortError(e)});throw e;}}
    check(token);mode=Object.keys(session.delegated).length?'detached':'manual';note='Applied a static copy of '+String(scene.metadata?.name||'the scene')+'. Your fixture limits were retained; the saved Hue scene was not modified.';
  }
  function newSession(){if(job||Object.keys(session.delegated).length)throw new HueError('state','Pause and stop Bridge effects before starting a new baseline.');
    journal.history.push({area,archivedAt:now(),session:clone(session)});journal.history=journal.history.slice(-6);
    session={id:newId(),bridgeId:cfg.bridgeId||cfg.ip,group:group.id,groupType:group.type,createdAt:now(),states:{},delegated:{},legacy:false};
    recoveryRequired=false;activated={};held={};fromFrames={};fromGradient={};persist();note='New session. Fresh states will be captured on the next Start or Bridge handoff.';
  }
  function dispatch(command,payload=null){if(closed)return;
    if(command==='live'&&ui.continueInBackground)command='background';
    if(command==='background'||command==='backgroundPreset'){
      if(command==='backgroundPreset'&&!PRESET_LIBRARY.some(p=>p.id===payload)){controlError='Choose a valid scene from the library.';return;}
      const eligible=layout.order.filter(id=>layout.selected.includes(id)&&byId.get(id)?.mode!=='streaming'&&capabilities(byId.get(id)).color&&capabilities(byId.get(id)).dynamic&&!['task','anchor'].includes(layout.placements[id].role));
      if(!['room','zone'].includes(group.type)){controlError='Choose a Hue room or zone. All lights is a local view and cannot host a Bridge scene.';return;}
      if(!eligible.length){controlError='No selected color lights support a Bridge dynamic palette. Choose another area or try an advertised Bridge effect in Studio.';return;}
    }
    if(command==='setBackgroundPreference'){update({ui:{...ui,continueInBackground:payload===true}});return;}
    if(command==='refreshScenes'){refreshScenes();return;}
    if(command==='manual'){let intent;try{intent=validateManualIntent(payload,byId);}catch(e){controlError=shortError(e);return;}
      pause('Applying everyday lighting. Live animation is paused.');pending={command,token:epoch,payload:intent};controlError='';mode='adjusting';return;}
    if(command==='applyScene'){pause('Applying a static copy of the saved Hue scene.');pending={command,token:epoch,payload};controlError='';mode='adjusting';return;}
    if(command==='playPreset'||command==='backgroundPreset'){try{update({settings:applyLibraryPreset(settings,payload)});command=command==='backgroundPreset'||ui.continueInBackground?'background':'live';}catch(e){controlError=shortError(e);return;}}
    if(command==='applyPreset'){try{update({settings:applyLibraryPreset(settings,payload)});note='Preset applied without starting playback. Master brightness and room limits retained.';}catch(e){controlError=shortError(e);}return;}
    if(command==='stopSequence'){sequence.enabled=false;sequence.armed=false;note='Cue sequence stopped; the current live look continues.';return;}
    if(command==='startSequence'&&ui.continueInBackground){controlError='Cue sequences need an active controller. Turn off Keep playing when I leave to run a sequence.';return;}
    if(command==='startSequence'){
      const ids=settings.sequenceIds.filter(id=>PRESET_LIBRARY.some(p=>p.id===id));
      if(!ids.length){controlError='Add at least one valid preset to the cue sequence.';return;}
      update({settings:applyLibraryPreset({...settings,sequenceIds:ids},ids[0])},true);
      sequence={enabled:false,armed:true,index:0,cycle:0,nextAt:0};command='live';
    } else if(['live','bridge','background','restore','stopBridge'].includes(command)){sequence.enabled=false;sequence.armed=false;}

    if(command==='refreshHueLayout'){scanHueLayouts();return;}
    if(command==='importHueLayout'){
      if(layoutRead.error||layoutRead.pending){controlError='Finish a successful Hue layout read before importing.';return;}
      if(!layoutCatalog.some(a=>a.id===payload?.areaId&&a.matched)){controlError='Choose a Hue area with matching saved coordinates.';return;}
      pause('Pausing live updates before applying saved Hue positions. An in-flight request may still finish.');
      pending={command:'importHueLayout',payload:clone(payload),token:epoch};controlError='';return;
    }
    if(command==='undoHueLayout'){
      if(!layoutUndo){controlError='No layout import to undo.';return;}
      pause('Restoring the local layout from before the last Hue import.');pending={command:'undoHueLayout',token:epoch};controlError='';return;
    }
    if(command==='pause'){pause();return;}
    if(command==='resumeSession'){recoveryRequired=false;note='Saved restore point retained. Start continues that session.';return;}
    if(command==='newSession'){pause();try{newSession();}catch(e){controlError=shortError(e);}return;}
    if(command==='surge'){if(mode==='live'){surgeAt=now();note='12-second bounded lift; master and fixture caps still apply.';}return;}
    if(command==='clearYield'){held={};offChecks={};note='Yield flags cleared. Start is still required to turn an off lamp back on.';return;}
    if(command==='savePreset'||command==='saveRoom'){
      const name=String(payload||'').trim().slice(0,48);if(!name)return;const list=command==='savePreset'?presets:rooms,item=command==='savePreset'?{schema:3,name,settings:clone(settings)}:{schema:3,name,layout:clone(layout)};
      const i=list.findIndex(v=>v.name===name);if(i>=0)list[i]=item;else list.push(item);if(list.length>20)list.shift();persistPrefs(true);note='Saved '+name;return;}
    if(command==='loadPreset'||command==='loadRoom'){
      const list=command==='loadPreset'?presets:rooms,item=list.find(v=>v.name===payload);if(!item)return;update({settings:command==='loadPreset'?item.settings:settings,layout:command==='loadRoom'?item.layout:layout});note='Loaded '+item.name+'. No new show was started.';return;}
    if(command==='restoreArchive'){
      if(job||Object.keys(session.delegated).length){controlError='Pause and stop Bridge effects before recovering an archived baseline.';return;}
      const entry=journal.history.filter(v=>v.area===area).find(v=>v.session.id===payload);if(!entry)return;
      pause();const current=clone(session);session=clone(entry.session);session.delegated=session.delegated||{};for(const id of Object.keys(session.states||{})){const light=byId.get(id),action=light&&validatedSnapshot(session.states[id]?.action,light);if(action)session.states[id].action=action;else delete session.states[id];}for(const id of Object.keys(session.delegated))if(!byId.has(id))delete session.delegated[id];journal.history.push({area,archivedAt:now(),session:current});journal.history=journal.history.slice(-6);recoveryRequired=true;persist();note='Archived restore point selected. Review its timestamp before Restore.';return;
    }
    if(!['live','bridge','background','restore','stopBridge'].includes(command))return;
    epoch++;pending={command,token:epoch};controlError='';mode=command==='restore'?'restoring':command==='stopBridge'?'stopping':'preparing';
    note=job?'Waiting for the already-started request; no further old work will be launched.':'Preparing '+command+'.';
  }
  function launchPending(){if(!pending||job)return;const task=pending;pending=null;launch(async()=>{
      try {check(task.token);if(task.command==='importHueLayout'){importSavedHueLayout(task.payload,task.token);}
      else if(task.command==='undoHueLayout'){const previous=layoutUndo;layoutUndo=null;update({settings:{...settings,topology:previous.topology},layout:previous.layout});persistPrefs(true);note='Previous local layout restored. No light or Hue layout writes sent.';}
      else if(task.command==='manual')await manual(task.token,task.payload);else if(task.command==='applyScene')await applySavedScene(task.token,task.payload);
      else if(task.command==='live')await startLive(task.token);else if(task.command==='background')await nativePalette(task.token);else if(task.command==='bridge')await (settings.nativeKind==='effect'?nativeEffect(task.token):nativePalette(task.token));else if(task.command==='restore')await restore(task.token);else{await stopDelegated(task.token);check(task.token);mode='paused';}}
      catch(e){if(errorKind(e)==='cancelled')return;if(isCurrent(task.token)){mode=Object.keys(session.delegated).length?'detached':'error';note='Action stopped. Restore points and partial handoffs are retained.';}throw e;}
    });}
  function launchFrame(){
    const time=now(),candidates=active().filter(l=>!failures[l.id]||time>=failures[l.id].retryAt);
    const plan=planner.plan(candidates.map(l=>l.id),time);if(!plan)return;
    if(plan.overloaded){pause('Request latency is too high for coherent live fades. Use Bridge playback or a smaller area.');return;}
    const token=epoch,l=byId.get(plan.id),p=layout.placements[l.id];planner.start(l.id,time,plan.cycle);if(plan.lateness>350)stats.missedDeadlines++;
    launch(async()=>{
      try{check(token);if(!session.states[l.id])await capture([l.id],token);check(token);
        const at=now()+plan.horizon,targetT=elapsed+plan.horizon/1000*settings.speed;
        const f=desired(l.id,targetT,at),g=gradients(l.id,targetT,at);
        let action=actionFromFrame(byId.get(l.id),f,p,settings,plan.horizon,!activated[l.id]||settings.ownership==='hold',g);
        if(!activated[l.id])action={...action,...stopEffect(byId.get(l.id))};
        try{await write(l.id,action,'live',token);}catch(e){
          if(action.gradient&&errorKind(e)==='api'&&/gradient|points|palette/i.test(e.message)){badGradients.add(l.id);log('capability','Gradient rejected; using whole-light color.',l.id);check(token);
            action=actionFromFrame(byId.get(l.id),f,p,settings,plan.horizon,!activated[l.id]);await write(l.id,action,'live',token);}
          else throw e;}
        delete failures[l.id];
      }catch(e){if(errorKind(e)==='cancelled')return;const n=(failures[l.id]?.count||0)+1;totalFailures++;const retryAt=now()+Math.min(60000,2000*2**Math.min(n-1,5));
        failures[l.id]={count:n,retryAt,error:shortError(e),kind:errorKind(e)};log(errorKind(e),shortError(e),l.id);
        if(errorKind(e)==='auth'){pause('Authorization rejected. Fix pairing from the main menu.');mode='error';controlError=shortError(e);}
        else if(['network','server','rate'].includes(errorKind(e))){networkFailures++;if(networkFailures>=3){pause('Bridge connection failed repeatedly. Start retries after you resolve it.');mode='error';controlError=shortError(e);}}
        else if(['api','unsupported','missing','ownership'].includes(errorKind(e))){held[l.id]=shortError(e);}
      }
    });
  }
  function tick(hidden=false){if(closed)return;
    const stamp=now(),dt=stamp-lastTick;lastTick=stamp;
    if(hidden||dt<0||dt>8000){if(['live','preparing','adjusting'].includes(mode))pause('Paused after app suspension or a clock interruption. Tap Start to resume.');}
    else if(mode==='live'){
      elapsed+=dt/1000*settings.speed;activeSeconds+=dt/1000;
      if(sequence.enabled&&activeSeconds>=sequence.nextAt){
        const ids=settings.sequenceIds.filter(id=>PRESET_LIBRARY.some(p=>p.id===id));
        if(!ids.length)sequence.enabled=false;
        else {sequence.cycle++;const old=sequence.index;
          sequence.index=settings.sequenceOrder==='shuffle'?Math.floor(ENGINE.hash(settings.seed,sequence.cycle+9000)*ids.length):(old+1)%ids.length;
          if(ids.length>1&&sequence.index===old)sequence.index=(old+1)%ids.length;
          update({settings:applyLibraryPreset(settings,ids[sequence.index])},true);sequence.nextAt=activeSeconds+settings.sequenceHold;
          note='Cue '+(sequence.index+1)+' / '+ids.length+': '+PRESET_LIBRARY.find(p=>p.id===ids[sequence.index]).name;
        }
      }
    }
    if(!hidden){telemetry.tick();if(!layoutAttempted&&options.autoDiscover!==false)scanHueLayouts();}
    if(job&&stamp-jobStarted>12000&&!quarantined){quarantined=true;epoch++;pending=null;mode='error';controlError='A request has not settled. Writer quarantined; no overlapping retries will be sent.';note='Close only after the request settles, or stop the script. An in-flight request cannot be recalled.';log('timeout',controlError);}
    if(!job&&!hidden){if(pending)launchPending();else if(mode==='live')launchFrame();}
    persistPrefs();
  }
  function state(){const telem=telemetry.snapshot(),design={};for(const l of lights)design[l.id]=desired(l.id);
    const effective={};for(const id of layout.order)effective[id]=held[id]||session.delegated[id]?.state||(mode==='live'&&layout.selected.includes(id)?'live':'uncontrolled');
    const backgroundEligible=['room','zone'].includes(group.type)?layout.selected.filter(id=>{const l=byId.get(id);return l&&l.mode!=='streaming'&&capabilities(l).color&&capabilities(l).dynamic&&!['task','anchor'].includes(layout.placements[id].role);}).length:0;
    return {version:VERSION,background:{available:backgroundEligible>0,count:backgroundEligible,groupType:group.type},ui:clone(ui),sequence:{...sequence,remaining:Math.max(0,sequence.nextAt-activeSeconds)},systemDark:typeof Device!=='undefined'&&typeof Device.isUsingDarkAppearance==='function'?Device.isUsingDarkAppearance():null,mode,running:mode==='live',native:Object.keys(session.delegated).length>0,busy:!!job||!!pending,inFlight:!!job,quarantined,
      sent,t:elapsed,note,error:controlError,settings:clone(settings),layout:clone(layout),design,surge:surge(),telemetry:clone(telem),
      touched:Object.values(session.states).filter(v=>v.touchedAt||session.legacy).length,
      session:{id:session.id,createdAt:session.createdAt,legacy:session.legacy,recoveryRequired,entries:Object.entries(session.states).map(([id,v])=>({id,capturedAt:v.capturedAt,touchedAt:v.touchedAt})),archives:journal.history.filter(v=>v.area===area).map(v=>({id:v.session.id,createdAt:v.session.createdAt,archivedAt:v.archivedAt}))},
      ownership:effective,failures:clone(failures),requested:clone(requested),delegated:clone(session.delegated),restoreFailures:clone(restoreFailures),
      hueLayouts:{...layoutRead,canUndo:!!layoutUndo,areas:layoutCatalog.map(a=>({id:a.id,name:a.name,type:a.type,active:a.active,matched:a.matched,total:a.total,outside:a.outside,fetchedAt:a.fetchedAt,
        warnings:a.warnings,unmatched:a.unmatched,matchedNames:a.records.map(r=>byId.get(r.lightId)?.label||'Lamp')}))},
      manualResult:clone(manualResult),savedScenes:{items:clone(sceneList),pending:scenesPending,error:scenesError,readAt:scenesReadAt},
      effects:availableEffects([...byId.values()],layout),capabilities:Object.fromEntries([...byId].map(([id,l])=>[id,capabilities(l)])),
      effectParams:Object.fromEntries([...byId].map(([id,l])=>[id,{effect:l.effects_v2?.status?.effect,speed:finite(l.effects_v2?.status?.parameters?.speed),color:!!l.effects_v2?.status?.parameters?.color}])),
      stats:{...stats,latencyMs:Math.round(planner.latency),horizonMs:Math.round(planner.horizon),failures:totalFailures},
      logs:clone(logs),presets:clone(presets),rooms:clone(rooms),clock:now(),lastObservedAt};}
  function diagnostics(){const s=state();return {app:'hue-board',version:VERSION,exportedAt:new Date(now()).toISOString(),mode:s.mode,
    stats:s.stats,session:{createdAt:s.session.createdAt,legacy:s.session.legacy,entries:s.session.entries.length},
    lamps:layout.order.map((id,i)=>({number:i+1,capabilities:s.capabilities[id],ownership:s.ownership[id],failure:s.failures[id]?{count:s.failures[id].count,kind:s.failures[id].kind}:null,readAge:TELEMETRY.age(s.telemetry.data[id]?.fetchedAt,now())})),
    // Names, resource IDs, IPs, keys, payloads and raw network errors deliberately excluded.
    events:logs.map(v=>({at:v.at,kind:v.kind,lamp:v.lamp}))};}
  async function close(){closed=true;epoch++;pending=null;mode='paused';telemetry.stop();persistPrefs(true);persist();if(job)await job;persist();}
  function recovery(choice){if(choice==='resume'){recoveryRequired=false;note='Saved session retained.';}else if(choice==='new')newSession();}
  return {tick,dispatch,update,state,diagnostics,close,recovery,area,meta:{name:group.name,lights:lights.map(l=>({id:l.id,name:l.label,device:l.deviceLabel||'',capabilities:capabilities(l)}))},
    settled:async()=>{if(job)await job;},scenesSettled:async()=>{if(sceneJob)await sceneJob;},layoutSettled:async()=>{if(layoutJob)await layoutJob;},_observe:observe,_planner:planner,_session:()=>clone(session)};
}

/** First-class native fallback. Direct selection pages, not repetitive cycling. */
function makeCompatibilityPanel(meta,initial) {
  const table=new UITable();table.showSeparators=true;
  let s=clone(initial.settings),l=clone(initial.layout),state=initial,dirty=false,command=null,view='lights',picker=null,lastRender='',hueProjectionChoice=initial.layout.hue?.projection||'xy',huePhaseChoice=initial.layout.hue?.phaseMode||'clockwise';
  const lamp=id=>meta.lights.find(v=>v.id===id);
  const colors={ink:()=>Color.dynamic(new Color('#15202b'),new Color('#e7f1f7')),muted:()=>Color.dynamic(new Color('#596b7b'),new Color('#9db1c0')),cyan:()=>Color.dynamic(new Color('#00738a'),new Color('#69dcee')),lime:()=>Color.dynamic(new Color('#3e6400'),new Color('#c9f58b'))};
  function send(name,payload=null){const urgent=['pause','restore','stopBridge','stopSequence'];if(command&&urgent.includes(command.name)&&!urgent.includes(name))return;command={name,payload};render(true);}
  function changed(){dirty=true;render(true);}
  function text(title,subtitle='',height=70){const row=new UITableRow();row.height=Math.max(height,55+Math.ceil(title.length/40)*13+Math.ceil(subtitle.length/55)*13);row.dismissOnSelect=false;const c=row.addText(title,subtitle);c.titleColor=colors.ink();c.subtitleColor=colors.muted();table.addRow(row);return row;}
  function button(row,title,fn,enabled=true){const c=row.addButton(enabled?title:title+' · unavailable');c.dismissOnTap=false;c.titleColor=enabled?colors.cyan():colors.muted();c.widthWeight=1;c.onTap=()=>{if(enabled)fn();};return c;}
  function buttons(items,height=60){const row=new UITableRow();row.height=height;row.dismissOnSelect=false;for(const item of items)button(row,...item);table.addRow(row);}
  function pick(title,items,handler){picker={title,items,handler};render(true);}
  function field(key,title,items){const value=s[key],row=text(title,items.find(x=>x[0]===value)?.[1]||String(value));row.onSelect=()=>pick(title,items,v=>{s[key]=v;changed();});}
  function range(key,label,min,max,step,unit){const row=new UITableRow();row.height=60;const c=row.addText(label+' '+(step<1?s[key].toFixed(2):Math.round(s[key]))+unit);c.widthWeight=3;c.titleColor=colors.ink();for(const [text,dir]of[['−',-1],['+',1]])button(row,text,()=>{s[key]=+clamp(s[key]+dir*step,min,max).toFixed(2);changed();},s[key]+dir*step>=min&&s[key]+dir*step<=max);table.addRow(row);}
  function importHueChoice(){const areas=(state.hueLayouts?.areas||[]).filter(a=>a.matched);
    pick('Saved Hue Entertainment areas',areas.map(a=>[a.id,a.name+' · '+a.matched+'/'+a.total+' lamps']),async id=>{const a=areas.find(v=>v.id===id);if(!a)return;
      const detail='Import '+a.matched+'/'+a.total+' placements? '+(a.unmatched.length?'Unchanged: '+a.unmatched.map(v=>v.name).join(', ')+'. ':'')+a.warnings.join(' ')+' Live pauses; no Hue layout/light writes. The old local layout is saved for Undo.';
      if(await confirm(a.name,detail))send('importHueLayout',{areaId:id,projection:hueProjectionChoice,phaseMode:huePhaseChoice});});}
  function promptName(commandName){input('Save '+(commandName==='saveRoom'?'room layout':'mix'),'Choose a short name.').then(name=>{if(name)send(commandName,name);}).catch(()=>{});}
  function render(force=false){const sig=JSON.stringify({s,l,view,picker:picker?.title,mode:state.mode,busy:state.busy,error:state.error,note:state.note,session:state.session,hue:state.hueLayouts,telemetry:state.telemetry?.revision,ages:Math.floor(Date.now()/5000),command});
    if(!force&&sig===lastRender)return;lastRender=sig;table.removeAllRows();
    text('Hue Board',meta.name+' · '+(state.mode||'ready'),65);
    if(picker){const current=picker;buttons([['Back',()=>{picker=null;render(true);}]]);text(current.title,'Select an option directly.');for(const [id,name]of current.items){const row=text(name,'',54);row.onSelect=()=>{picker=null;current.handler(id);render(true);};}table.reload();return;}
    if(state.navigation){const row=text('Room or zone',meta.name+' · tap to change');row.onSelect=()=>pick('Choose an area',state.navigation.areas.map(a=>[a.id,a.name+' · '+a.count+' lights']),id=>send('switchArea',id));}
    buttons([['Lights',()=>{view='lights';render(true);}],['Studio',()=>{view='perform';render(true);}],['Room',()=>{view='room';render(true);}],['Lab',()=>{view='lab';render(true);}]]);
    const stop=['live','preparing','adjusting','restoring','stopping'].includes(state.mode)||state.busy;
    buttons([[stop?'Pause / cancel':'Start live',()=>send(stop?'pause':'live'),stop||l.selected.length>0],
      [state.native?'Stop background':'Play in background',()=>send(state.native?'stopBridge':'background'),state.native||state.background?.available],
      ['Restore',()=>send('restore'),state.touched>0]],72);
    text(state.note||'Ready',state.error||'Light changes require a power, brightness, color, playback or restore action.',90);
    text('Bridge-reported state',TELEMETRY.summary(state.telemetry,Date.now())+'\nResource readback is not optical telemetry.',85);
    if(view==='lights'){
      const ids=l.order.slice(),dimmers=ids.filter(id=>lamp(id).capabilities.dimming),whites=ids.filter(id=>lamp(id).capabilities.temperature);
      text('Everyday lighting','On/off, brightness, white and color. Manual actions pause the local show. Values below come from Bridge reads.',90);
      if(state.session?.recoveryRequired)buttons([['Keep restore point',()=>send('resumeSession')],['Review baseline',()=>{view='lab';render(true);}]]);
      buttons([['Area on',()=>send('manual',{ids,on:true}),!state.navigation?.switching],['Area off',()=>send('manual',{ids,on:false}),!state.navigation?.switching]]);
      buttons([['Set brightness',async()=>{const raw=await input('Area brightness','1–100%. Turns dimmable lights on. Saved trim/ceiling limits still apply.','70');if(raw!==null&&raw.trim()!==''&&Number.isFinite(Number(raw)))send('manual',{ids:dimmers,on:true,brightness:clamp(Number(raw),1,100)});},dimmers.length>0],['Bright 100%',()=>send('manual',{ids:dimmers,on:true,brightness:100}),dimmers.length>0]]);
      buttons([['Warm white',()=>send('manual',{ids:whites,on:true,kelvin:2700,brightness:45}),whites.length>0],['Focus white',()=>send('manual',{ids:whites,on:true,kelvin:4000,brightness:80}),whites.length>0]]);
      buttons([['Allow 100% ceilings',async()=>{if(await confirm('Raise saved ceilings?','Allow dimmable lights in this area up to 100%. Trims remain unchanged. Current brightness does not change unless the live show uses the new limit.')){for(const id of dimmers)l.placements[id].ceiling=100;changed();}},dimmers.length>0]]);
      for(const id of ids){const light=lamp(id),r=text(light.name,TELEMETRY.stateText(state.telemetry?.data?.[id]),85);r.onSelect=()=>{view='direct:'+id;render(true);};}
      buttons([['Read saved Hue scenes',()=>send('refreshScenes'),!state.savedScenes?.pending]]);
      if(state.savedScenes?.error)text('Scene read failed',state.savedScenes.error);
      if(state.savedScenes?.items?.length)buttons([['Apply static scene',()=>pick('Saved Hue scenes (static copies)',state.savedScenes.items.map(a=>[a.id,a.name]),id=>send('applyScene',id))]]);
    }else if(view.startsWith('direct:')){
      const id=view.slice(7),light=lamp(id),cap=light.capabilities,p=l.placements[id],row=state.telemetry?.data?.[id],ids=[id];
      buttons([['Back to lights',()=>{view='lights';render(true);}]]);text(light.name,TELEMETRY.stateText(row)+' · '+TELEMETRY.ageText(row?.fetchedAt,Date.now()),90);
      buttons([['On',()=>send('manual',{ids,on:true}),!cap.streaming],['Off',()=>send('manual',{ids,on:false}),!cap.streaming]]);
      if(cap.dimming){const r=text('Set brightness','Tap to enter 1–100%. Ceiling '+p.ceiling+'%, trim '+Math.round(p.trim*100)+'%.');r.onSelect=async()=>{const raw=await input('Brightness','Turns this light on. Enter 1–100.',String(row?.brightness||50));if(raw!==null&&raw.trim()!==''&&Number.isFinite(Number(raw)))send('manual',{ids,on:true,brightness:clamp(Number(raw),1,100)});};}
      if(cap.temperature&&cap.temperatureRange){const r=text('White temperature','Tap for Kelvin: '+cap.temperatureRange.min+'–'+cap.temperatureRange.max);r.onSelect=async()=>{const raw=await input('White temperature','Kelvin within the advertised range.',String(row?.kelvin||4000));if(raw!==null&&raw.trim()!==''&&Number.isFinite(Number(raw)))send('manual',{ids,on:true,kelvin:clamp(Number(raw),cap.temperatureRange.min,cap.temperatureRange.max)});};}
      if(cap.color){const r=text('Set color','Enter a six-digit hex color, for example #00bddd.');r.onSelect=async()=>{const hex=await input('Color','Six-digit hex color. Turns this light on.','#00bddd');if(hex!==null)send('manual',{ids,on:true,hex});};}
    }else if(view==='perform'){
      buttons([['Preset library · 32',()=>pick('Curated looks',PRESET_LIBRARY.map(p=>[p.id,p.name+' · '+p.category]),id=>send('applyPreset',id))]]);
      buttons([[state.sequence?.enabled?'Stop cue sequence':'Start cue sequence',()=>send(state.sequence?.enabled?'stopSequence':'startSequence'),l.selected.length>0]]);
      text('Cue sequence',s.sequenceIds.map(id=>PRESET_LIBRARY.find(p=>p.id===id)?.name||id).join(' → ')+' · '+s.sequenceHold+' seconds each');
      buttons([['Add cue',()=>pick('Add a preset cue',PRESET_LIBRARY.map(p=>[p.id,p.name]),id=>{if(s.sequenceIds.length<12){s.sequenceIds=s.sequenceIds.concat(id);changed();}}),s.sequenceIds.length<12],['Remove last cue',()=>{s.sequenceIds=s.sequenceIds.slice(0,-1);changed();},s.sequenceIds.length>0]]);
      range('sequenceHold','Cue dwell',30,600,30,' s');field('sequenceOrder','Cue order',[['forward','Forward'],['shuffle','Seeded shuffle']]);
      if(state.hueLayouts?.areas?.some(a=>a.matched)&&!l.hue)buttons([['Use saved Hue positions',()=>{view='room';render(true);}]]);
      field('showA','Look A',ENGINE.shows);field('paletteA','Palette A',ENGINE.palettes.map((p,i)=>[i,p.name]));
      field('showB','Look B',ENGINE.shows);field('paletteB','Palette B',ENGINE.palettes.map((p,i)=>[i,p.name]));
      range('brightness','Master',5,100,5,'%');range('energy','Energy',0,100,5,'%');range('speed','Motion',.25,1.6,.05,'×');range('morph','A / B',0,100,5,'%');
      buttons([['12s lift',()=>send('surge'),state.mode==='live'],['Reverse: '+(s.reverse?'on':'off'),()=>{s.reverse=!s.reverse;changed();}]]);
      field('nativeKind','Bridge playback',[['palette','Dynamic palette'],['effect','Fixture effect']]);
      if(s.nativeKind==='effect'){
        field('effect','Advertised effect',(state.effects||[]).map(e=>[e.name,e.name+' · '+e.supported+'/'+e.total+' eligible']));
        const current=Object.values(state.effectParams||{}).filter(p=>p.effect===s.effect);
        if(current.some(p=>p.speed))range('effectSpeed','Effect speed',0,1,.05,'');
        if(current.some(p=>p.color))buttons([['Palette tint: '+(s.effectTint?'on':'off'),()=>{s.effectTint=!s.effectTint;changed();}]]);
        text('Parameter availability','Effect parameters appear only when readback advertises them. Unsupported accent/wash lamps are unchanged.');
      }
      buttons([['Apply Bridge playback',()=>send('bridge'),l.selected.length>0]]);
      buttons([['Save mix',()=>promptName('savePreset')],['Load mix',()=>pick('Saved mixes',(state.presets||[]).map(p=>[p.name,p.name]),name=>send('loadPreset',name)),!!state.presets?.length]]);
      buttons([['Export mix',()=>send('exportMix')],['Import mix',()=>send('importMix')]]);
    }else if(view==='room'){
      const info=state.hueLayouts||{};
      text('Reuse saved Hue positions',info.pending?'Reading Entertainment layouts…':info.error?'Read failed: '+info.error:info.fetchedAt==null?'Checking saved layouts.':(info.areas||[]).length+' saved Entertainment area(s). Uses your existing key; no export needed.',90);
      const pr=text('Import map projection',({xy:'Top X / Y',xz:'Front X / Z',yz:'Side Y / Z'})[hueProjectionChoice]);pr.onSelect=()=>pick('Projection',[['xy','Top X / Y'],['xz','Front X / Z'],['yz','Side Y / Z']],v=>{hueProjectionChoice=v;render(true);});
      const ph=text('Import animation path',({clockwise:'Clockwise around X / Y',x:'Left to right X',y:'Back to front Y',z:'Bottom to top Z',keep:'Keep existing phases'})[huePhaseChoice]);ph.onSelect=()=>pick('Animation path',[['clockwise','Clockwise X / Y'],['x','Left to right X'],['y','Back to front Y'],['z','Bottom to top Z'],['keep','Keep existing phases']],v=>{huePhaseChoice=v;render(true);});
      buttons([['Import Hue positions',importHueChoice,!info.pending&&!info.error&&info.areas?.some(a=>a.matched)],['Read Hue again',()=>send('refreshHueLayout'),!info.pending]]);
      buttons([['Undo layout import',async()=>{if(await confirm('Undo layout import','Return to the local layout and path topology before the last import? Live pauses; no light/Hue layout writes.'))send('undoHueLayout');},info.canUndo]]);
      if(l.hue)text('Imported from '+l.hue.areaName,'XYZ preserved. Relative coordinates, not measured metres. Local edits are retained until an explicit new import.');
      field('topology','Animation path',[['ring','Closed ring'],['path','Open path']]);
      text('Stable lamp positions','Tap a lamp to edit it. Excluding one lamp never changes another lamp’s path phase. X / Y arrange the graphical map; phase drives the show.');
      for(const id of l.order){const light=lamp(id),row=text((l.selected.includes(id)?'✓ ':'○ ')+light.name,TELEMETRY.stateText(state.telemetry?.data?.[id])+'\n'+(state.ownership?.[id]||'uncontrolled'),95);
        row.onSelect=()=>{view='lamp:'+id;render(true);};}
      buttons([['Save room',()=>promptName('saveRoom')],['Load room',()=>pick('Room layouts',(state.rooms||[]).map(p=>[p.name,p.name]),name=>send('loadRoom',name)),!!state.rooms?.length]]);
      buttons([['Redistribute clockwise',async()=>{if(await confirm('Redistribute positions','Explicitly redistribute every lamp, including unchecked lamps, along the ring?')){l.order.forEach((id,i)=>{const q=i/l.order.length;l.placements[id]={...l.placements[id],q,x:.5+.37*Math.sin(q*Math.PI*2),y:.5-.32*Math.cos(q*Math.PI*2)};});changed();}}]]);
    }else if(view.startsWith('lamp:')){
      const id=view.slice(5),light=lamp(id),p=l.placements[id];buttons([['Back to room',()=>{view='room';render(true);}]]);text(light.name,TELEMETRY.stateText(state.telemetry?.data?.[id]));text('Saved placement',huePlacementText(p));
      buttons([[l.selected.includes(id)?'Exclude lamp':'Include lamp',()=>{l.selected=l.selected.includes(id)?l.selected.filter(v=>v!==id):l.selected.concat(id);changed();}]]);
      const r=text('Role',p.role);r.onSelect=()=>pick('Light role',[['wash','Architectural wash'],['accent','Moving accent'],['task','Steady task / face'],['anchor','Steady background']],v=>{p.role=v;changed();});
      for(const [key,label,min,max,scale] of [['q','Path phase %',0,100,100],['x','Map X %',4,96,100],['y','Map Y %',6,94,100],['trim','Output trim %',10,100,100],['ceiling','Brightness cap %',5,100,1]]){
        const row=text(label,(p[key]*scale).toFixed(1)+' · tap to edit',56);row.onSelect=async()=>{const raw=await input(label,'Enter '+min+' to '+max,(p[key]*scale).toFixed(1));if(raw!==null&&raw.trim()!==''&&Number.isFinite(Number(raw))){p[key]=clamp(Number(raw),min,max)/scale;changed();}};}
      if(light.capabilities.gradient>=2){buttons([['Gradients: '+(s.gradient?'on':'off'),()=>{s.gradient=!s.gradient;changed();}],['Reverse strip',()=>{p.stripReverse=!p.stripReverse;changed();}]]);
        for(const [key,label,min,max,scale]of[['extent','Strip extent %',2,50,100],['angle','Strip map angle',-180,180,1]]){const row=text(label,String(p[key]*scale),56);row.onSelect=async()=>{const raw=await input(label,'Enter '+min+' to '+max,p[key]*scale);if(raw!==null&&raw.trim()!==''&&Number.isFinite(Number(raw))){p[key]=clamp(Number(raw),min,max)/scale;changed();}};}}
      const idx=l.order.indexOf(id);buttons([['Move earlier',()=>{[l.order[idx],l.order[idx-1]]=[l.order[idx-1],l.order[idx]];changed();},idx>0],['Move later',()=>{[l.order[idx],l.order[idx+1]]=[l.order[idx+1],l.order[idx]];changed();},idx<l.order.length-1]]);
    }else{
      text('Request budget',(state.stats?.latencyMs||0)+' ms smoothed request time · '+((state.stats?.horizonMs||0)/1000).toFixed(1)+' s horizon\n'+(state.stats?.writes||0)+' accepted writes · '+(state.stats?.failures||0)+' failures');
      for(const args of [['depth','Depth',0,100,5,'%'],['spread','Width',.5,2,.05,'×'],['tension','Color tension',0,100,5,'%'],['focus','Focus',0,100,5,'%'],['saturation','Saturation',0,100,5,'%'],['ambientFloor','Atmosphere floor',0,65,5,'%'],['accentMix','Accent amount',0,100,5,'%'],['density','Ring copies',1,4,1,''],['phaseOffset','Phase offset',-1,1,.05,''],['brightnessCurve','Intensity curve',.5,2,.05,'×'],['directorSeconds','Director act',30,180,5,' s']])range(...args);
      text('Appearance','Native controls follow system appearance. The graphical panel adds System / Light / Dark overrides in Lab.');
      for(let ci=0;ci<4;ci++){const row=text('Custom palette color '+(ci+1),s.customColors[ci]+' · tap to edit');row.onSelect=async()=>{const raw=await input('Hex color','Enter #RRGGBB',s.customColors[ci]);if(raw!==null&&/^#[0-9a-fA-F]{6}$/.test(raw)){s.customColors=s.customColors.slice();s.customColors[ci]=raw;changed();}};}
      field('ownership','External control',[['yield_off','Yield to external off'],['hold','Keep enforcing on']]);
      const seedRow=text('Seed',String(s.seed)+' · tap to edit');seedRow.onSelect=async()=>{const value=await input('Seed','Integer 0–999999',s.seed);if(value!==null&&Number.isFinite(Number(value))){s.seed=Math.round(clamp(Number(value),0,999999));changed();}};
      const fadeRow=text('Edit crossfade',s.transitionMs/1000+' seconds');fadeRow.onSelect=async()=>{const value=await input('Crossfade','Seconds: 2.5–15',s.transitionMs/1000);if(value!==null&&Number.isFinite(Number(value))){s.transitionMs=clamp(Number(value),2.5,15)*1000;changed();}};
      text('Restore point',state.session?.createdAt?new Date(state.session.createdAt).toLocaleString():'Legacy / capture date unknown');
      text(state.session?.recoveryRequired?'Recovery choice required':'Static restore only','Prior animations are not resumed. Archived sessions remain available.');
      buttons([['Resume saved point',()=>send('resumeSession'),state.session?.recoveryRequired],['New baseline',async()=>{if(await confirm('New session','Archive the current baseline? Fresh values are captured on the next Start.'))send('newSession');},!state.busy&&!state.native]],76);
      buttons([['Archived baselines',()=>pick('Archived sessions',(state.session?.archives||[]).map(a=>[a.id,a.createdAt?new Date(a.createdAt).toLocaleString():'Unknown capture date']),id=>send('restoreArchive',id)),!!state.session?.archives?.length&&!state.busy&&!state.native]]);
      buttons([['Redacted diagnostics',()=>send('exportDiagnostics')]]);
      for(const id of l.order){const t=state.telemetry||{},r=t.data?.[id];text(lamp(id).name,TELEMETRY.stateText(r)+'\n'+TELEMETRY.ageText(r?.fetchedAt,Date.now())+' · '+TELEMETRY.connection(t.links?.[r?.owner],Date.now())+'\n'+TELEMETRY.targetText(t.targets?.[id],Date.now())+'\n'+(state.ownership?.[id]||'uncontrolled'),120);}
    }
    text('Foreground live / phone-free Bridge playback','Done stops new live work and leaves current states. Stop Bridge or Restore changes delegated playback. Trusted Wi-Fi only; local certificate validation is disabled.',110);
    table.reload();
  }
  function report(next){if(next.meta&&next.meta.scopeId!==meta.scopeId){meta=next.meta;dirty=false;command=null;picker=null;view='lights';s=clone(next.settings);l=clone(next.layout);}state=next;let force=false;if(!dirty){if(JSON.stringify(s)!==JSON.stringify(next.settings)){s=clone(next.settings);force=true;}if(JSON.stringify(l)!==JSON.stringify(next.layout)){l=clone(next.layout);force=true;}}render(force);}
  render(true);
  return {present:()=>table.present(false),async exchange(next){report(next);const packet={edit:dirty?{settings:clone(s),layout:clone(l)}:null,command,hidden:false};dirty=false;command=null;return packet;},async report(next){report(next);},async fail(message){state={...state,error:message,note:'Close with Done and reopen.',mode:'error'};render(true);}};
}

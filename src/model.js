/** Capability, layout and static restoration models. */
function capabilities(light) {
  const v2=light.effects_v2?.action?.effect_values;
  const legacy=light.effects?.effect_values;
  const sc=light.color_temperature?.mirek_schema;
  const temperatureRange=sc&&finite(sc.mirek_minimum)&&finite(sc.mirek_maximum)&&sc.mirek_minimum>0&&sc.mirek_maximum>=sc.mirek_minimum?{min:Math.ceil(1000000/sc.mirek_maximum),max:Math.floor(1000000/sc.mirek_minimum)}:null;
  return {power:typeof light.on?.on==='boolean',color:!!light.color,dimming:!!light.dimming,temperature:!!light.color_temperature,temperatureRange,minBrightness:finite(light.dimming?.min_dim_level)?light.dimming.min_dim_level:null,
    dynamic:light.dynamics?.status_values?.includes('dynamic_palette')===true,
    gradient:Math.min(5,Math.max(0,Number(light.gradient?.points_capable)||0)),
    effects:(Array.isArray(v2)?v2:Array.isArray(legacy)?legacy:[]).filter(x=>typeof x==='string'),
    effectsV2:Array.isArray(v2),streaming:light.mode==='streaming'};
}
function cleanLayout(raw,lights) {
  const src=raw&&typeof raw==='object'?raw:{},ids=lights.map(l=>l.id), valid=new Set(ids);
  const order=Array.isArray(src.order)?[...new Set(src.order.filter(id=>valid.has(id)))]:[];
  for(const id of ids)if(!order.includes(id))order.push(id);
  const selected=Array.isArray(src.selected)?[...new Set(src.selected.filter(id=>valid.has(id)))]:lights.filter(l=>l.color).map(l=>l.id);
  const placements={};
  for(const [index,id] of order.entries()) {
    const q=index/Math.max(1,order.length),p=src.placements?.[id]||{};
    const num=(k,lo,hi,d)=>finite(p[k])?clamp(p[k],lo,hi):d;
    placements[id]={q:num('q',0,1,q),x:num('x',.04,.96,.5+.37*Math.sin(2*Math.PI*q)),y:num('y',.06,.94,.5-.32*Math.cos(2*Math.PI*q)),
      role:['wash','accent','task','anchor'].includes(p.role)?p.role:lights.find(l=>l.id===id)?.color?'wash':'task',trim:num('trim',.1,1,1),ceiling:num('ceiling',5,100,100),
      stripReverse:p.stripReverse===true,extent:num('extent',.02,.5,.18),angle:num('angle',-180,180,0)};
  }
  for(const id of order){const h=cleanHuePlacement(src.placements?.[id]?.hue);if(h)placements[id].hue=h;}
  const hue=cleanHueLayoutMeta(src.hue);
  return {order,selected,placements,...(hue?{hue}:{})};
}
function orderedLights(cfg,group) {
  const raw=cfg.orders?.[group.id]||[],byId=new Map(group.lights.map(l=>[l.id,l]));
  const ids=[...new Set(Array.isArray(raw)?raw:[])].filter(id=>byId.has(id));
  const remaining=group.lights.filter(l=>!ids.includes(l.id)).sort((a,b)=>a.label.localeCompare(b.label));
  return ids.map(id=>byId.get(id)).concat(remaining);
}
function stopEffect(light) {
  const c=capabilities(light);
  if(c.effects.includes('no_effect'))return c.effectsV2?{effects_v2:{action:{effect:'no_effect'}}}:{effects:{effect:'no_effect'}};
  return {};
}
function snapshotAction(light) {
  if(!light?.on||typeof light.on.on!=='boolean')throw new HueError('protocol','Cannot capture an incomplete light state.');
  const a={on:{on:light.on.on},...(light.dimming?{dynamics:{duration:1500}}:{}),...stopEffect(light)};
  if(finite(light.dimming?.brightness))a.dimming={brightness:clamp(light.dimming.brightness,.1,100)};
  // Temperature validity wins over leftover gradient values from an older command.
  if(light.color_temperature?.mirek_valid&&finite(light.color_temperature.mirek))a.color_temperature={mirek:light.color_temperature.mirek};
  else if(light.gradient?.points?.length>=2){a.gradient={points:clone(light.gradient.points)};if(light.gradient.mode)a.gradient.mode=light.gradient.mode;}
  else if(light.color?.xy)a.color={xy:clone(light.color.xy)};
  return a;
}
function validatedSnapshot(action,light) {
  if(!action||typeof action.on?.on!=='boolean')return null;
  const a={on:{on:action.on.on},...(light.dimming?{dynamics:{duration:1500}}:{}),...stopEffect(light)};
  if(finite(action.dimming?.brightness)&&light.dimming)a.dimming={brightness:clamp(action.dimming.brightness,.1,100)};
  const point=p=>p&&finite(p.x)&&finite(p.y)&&p.x>=0&&p.y>0&&p.x+p.y<=1.001;
  if(finite(action.color_temperature?.mirek)&&light.color_temperature){const s=light.color_temperature.mirek_schema||{};a.color_temperature={mirek:Math.round(clamp(action.color_temperature.mirek,s.mirek_minimum||153,s.mirek_maximum||500))};}
  else if(light.gradient&&Array.isArray(action.gradient?.points)&&action.gradient.points.length>=2&&action.gradient.points.every(p=>point(p.color?.xy))){a.gradient={points:action.gradient.points.slice(0,Math.max(2,light.gradient.points_capable||5)).map(p=>({color:{xy:{x:p.color.xy.x,y:p.color.xy.y}}}))};if(light.gradient.mode_values?.includes(action.gradient.mode))a.gradient.mode=action.gradient.mode;}
  else if(light.color&&point(action.color?.xy))a.color={xy:{x:action.color.xy.x,y:action.color.xy.y}};
  return a;
}
function fixtureSample(t,placement,settings,surge=0) {
  let f=ENGINE.sample(t,placement.q,settings,surge);
  if(placement.role==='task')f={rgb:[.92,.94,1],b:settings.brightness*.72};
  else if(placement.role==='anchor')f={rgb:ENGINE.getColors(settings,settings.paletteA)[0],b:settings.brightness*.46};
  else if(placement.role==='wash')f.b=f.b*.7+settings.brightness*.18;
  f.b=clamp(f.b*placement.trim,.1,Math.min(settings.brightness,placement.ceiling,100));return f;
}
function actionFromFrame(light,frame,placement,settings,duration,on=false,gradientFrames=null) {
  const a={dimming:{brightness:+clamp(frame.b,.1,Math.min(settings.brightness,placement.ceiling,100)).toFixed(2)},dynamics:{duration:Math.round(duration/100)*100}};
  if(on)a.on={on:true};
  if(placement.role==='task'&&light.color_temperature){const sc=light.color_temperature.mirek_schema||{};a.color_temperature={mirek:clamp(250,sc.mirek_minimum||153,sc.mirek_maximum||500)};}
  else if(light.color)a.color={xy:ENGINE.xy(frame.rgb,light.color.gamut)};
  if(gradientFrames?.length>=2&&light.gradient&&placement.role!=='task') {
    a.gradient={points:gradientFrames.map(f=>({color:{xy:ENGINE.xy(f.rgb,light.color?.gamut)}}))};
    if(light.gradient.mode_values?.includes('interpolated_palette'))a.gradient.mode='interpolated_palette';delete a.color;
  }
  return a;
}
function effectAction(light,effect,settings,placement) {
  const c=capabilities(light);if(!c.effects.includes(effect)||effect==='no_effect')throw new HueError('unsupported','This fixture does not advertise the selected effect.');
  const a={on:{on:true},dimming:{brightness:Math.min(settings.brightness*placement.trim,placement.ceiling,100)}};
  if(c.effectsV2){a.effects_v2={action:{effect}};const reported=light.effects_v2.status;
    // Parameter availability is advertised conservatively by readback for this effect.
    if(reported?.effect===effect&&reported.parameters){const parameters={};if(finite(reported.parameters.speed))parameters.speed=settings.effectSpeed;
      if(settings.effectTint&&reported.parameters.color&&light.color)parameters.color={xy:ENGINE.xy(ENGINE.getColors(settings,settings.paletteA)[1],light.color.gamut)};
      if(Object.keys(parameters).length)a.effects_v2.action.parameters=parameters;}
  } else a.effects={effect};return a;
}
function availableEffects(lights,layout) {
  const chosen=lights.filter(l=>layout.selected.includes(l.id)&&l.mode!=='streaming'&&!['task','anchor'].includes(layout.placements[l.id].role));
  const names=[...new Set(chosen.flatMap(l=>capabilities(l).effects))].filter(n=>n!=='no_effect'&&n!=='unknown');
  return names.map(name=>({name,supported:chosen.filter(l=>capabilities(l).effects.includes(name)).length,total:chosen.length})).sort((a,b)=>a.name.localeCompare(b.name));
}
/** Absolute deadlines with adaptive latency budgeting. No queued animation frames. */
class DeadlinePlanner {
  constructor(){this.due=new Map();this.lastStart=-Infinity;this.latency=100;this.horizon=4500;this.samples=[];}
  plan(ids,now) {
    // Budget for the 120 ms UI loop plus native evaluation/dispatch overhead.
    // RTT alone underestimates a full pass when many lights are selected.
    const slot=Math.max(350,this.latency*1.35+80),wakeBudget=180;
    const cycle=Math.max(4200,ids.length*(slot+wakeBudget));
    this.horizon=Math.max(4500,cycle*1.18+this.latency*1.5+300);
    if(this.horizon>60000)return {overloaded:true,horizon:this.horizon};
    if(now-this.lastStart<slot)return null;
    for(const id of ids)if(!this.due.has(id))this.due.set(id,now);
    let id=null,earliest=Infinity;for(const candidate of ids){const d=this.due.get(candidate);if(d<earliest){earliest=d;id=candidate;}}
    if(!id||earliest>now)return null;
    return {id,cycle,horizon:this.horizon,lateness:Math.max(0,now-earliest)};
  }
  start(id,now,cycle){this.lastStart=now;this.due.set(id,now+cycle);}
  complete(start,finish){const elapsed=Math.max(0,finish-start);this.latency=this.latency*.75+elapsed*.25;this.samples.push(elapsed);if(this.samples.length>100)this.samples.shift();}
  reset(ids,now){this.due.clear();ids.forEach((id,i)=>this.due.set(id,now+i*350));this.lastStart=-Infinity;}
}

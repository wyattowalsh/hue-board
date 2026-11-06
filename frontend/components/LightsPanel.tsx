import * as React from 'react';
import {deck,META,T,PRESETS} from '../lib/bridge';
import type {State,Layout,UiPrefs} from '../types';
import {Button,Input,Select,Fold,Field,FieldGroup,ToggleGroup,Badge,Empty,Confirm,Alert,Card,CardHeader,CardTitle,CardDescription,CardContent,CardFooter} from './ui';
import {cn} from '../lib/utils';

/** This is an edit target, never a fabricated readback. Commit at release, key-up or blur, not every frame. */
function CommitRange({label,value,min=1,max=100,unit='%',disabled=false,onCommit}:{label:string;value:number;min?:number;max?:number;unit?:string;disabled?:boolean;onCommit:(v:number)=>void}){
 const [draft,setDraft]=React.useState(value),dirty=React.useRef(false),id=React.useId();
 React.useEffect(()=>{if(!dirty.current)setDraft(Math.min(max,Math.max(min,value)))},[value,min,max]);
 const commit=()=>{if(disabled||!dirty.current)return;dirty.current=false;onCommit(draft)};
 return <Field><label htmlFor={id} className="flex items-center justify-between gap-3 text-sm font-medium"><span>{label}</span><output htmlFor={id} className="tabular-nums text-primary">{Math.round(draft)}{unit}</output></label><input id={id} type="range" value={draft} min={min} max={max} step={unit===' K'?50:1} disabled={disabled} onChange={e=>{dirty.current=true;setDraft(Number(e.currentTarget.value))}} onPointerUp={commit} onKeyUp={e=>{if(['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','Home','End','PageUp','PageDown'].includes(e.key))commit()}} onBlur={commit} className="h-11 w-full cursor-pointer accent-primary disabled:opacity-45"/></Field>
}
const PowerIcon=()=> <svg data-icon="inline-start" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true"><path d="M12 3v9M7.2 5.8a8 8 0 1 0 9.6 0" strokeLinecap="round"/></svg>;
function LightCard({id,state,layout,locked}:{id:string;state:State;layout:Layout;locked:boolean}){
 const light=META.lights.find(l=>l.id===id)!,c=state.capabilities?.[id]||light.capabilities,p=layout.placements[id],r=state.telemetry?.data?.[id];
 const [expanded,setExpanded]=React.useState(false),[color,setColor]=React.useState('#00bddd');
 const age=r?.fetchedAt==null?null:T.age(r.fetchedAt,Date.now()),stale=age==null||age>6;
 const streaming=c.streaming||r?.mode==='streaming',disabled=locked||streaming;
 const link=r&&state.telemetry.links?.[r.owner],linkBad=link&&Date.now()-link.fetchedAt<30000&&['disconnected','connectivity_issue'].includes(link.status);
 const name=light.name,send=(change:Record<string,unknown>)=>deck.send({name:'manual',payload:{ids:[id],...change}});
 const type=c.color?'Color':c.temperature?'Adjustable white':c.dimming?'Dimmable':'On / off';
 const power=r?.on===true?'On':r?.on===false?'Off':'Not read yet';
 return <article className={cn('light-card',r?.on===true?'is-on':undefined)} aria-label={name}>
  <div className="light-row"><button type="button" className="light-main" aria-expanded={expanded} aria-controls={'light-details-'+id} onClick={()=>setExpanded(!expanded)}>
   <span className="light-orb" style={{'--lamp':T.color(r)} as React.CSSProperties} aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M8 16c0-3-3-3.5-3-7a7 7 0 0 1 14 0c0 3.5-3 4-3 7M8 17h8M9 20h6M10 22h4" strokeLinecap="round"/></svg></span>
   <span className="min-w-0"><strong>{name}</strong><span className="light-description">{power}{r?.brightness!=null?` · ${Math.round(r.brightness)}%${r.on===false?' stored':''}`:''}{streaming?' · Streaming':linkBad?' · Link issue':stale?' · Not current':''}</span></span>
  </button><Button variant={r?.on===true?'default':'outline'} size="icon" disabled={disabled} aria-label={`${r?.on===true?'Turn off':'Turn on'} ${name}`} onClick={()=>send({on:r?.on!==true})}><PowerIcon/></Button></div>
  {expanded?<div className="light-details" id={'light-details-'+id}>
   <div className="flex flex-wrap items-center justify-between gap-2"><Badge variant="outline">{type}</Badge><span className="text-xs text-muted-foreground">{r?.fetchedAt==null?'Waiting for readback':`Bridge read ${Math.floor(age||0)}s ago`}</span></div>
   {streaming?<Alert title="Controlled by a streaming app">Stop its Entertainment stream before using these controls.</Alert>:null}
   {c.dimming?<CommitRange label={'Set brightness · '+name} value={r?.brightness||50} min={Math.max(1,Math.ceil(c.minBrightness||1))} disabled={disabled} onCommit={v=>send({on:true,brightness:v})}/>:null}
   {c.temperature&&c.temperatureRange?<><div className="flex flex-wrap gap-2">{[[2700,'Warm'],[4000,'Neutral'],[6000,'Cool']].map(([k,label])=><Button key={k} variant="outline" size="sm" disabled={disabled} onClick={()=>send({on:true,kelvin:k})}>{label}</Button>)}</div><CommitRange label={'White temperature · '+name} value={r?.kelvin||4000} min={c.temperatureRange.min} max={c.temperatureRange.max} unit=" K" disabled={disabled} onCommit={v=>send({on:true,kelvin:v})}/></>:null}
   {c.color?<Field><label className="text-sm font-medium" htmlFor={'color-'+id}>Choose a color</label><div className="color-apply"><input type="color" id={'color-'+id} aria-label={'Color for '+name} value={color} disabled={disabled} onChange={e=>setColor(e.currentTarget.value)}/><Button variant="outline" disabled={disabled} onClick={()=>send({on:true,hex:color})}>Set color</Button></div></Field>:null}
   <p className="muted-note">{c.dimming?`Ceiling ${Math.round(p.ceiling)}% · trim ${Math.round(p.trim*100)}%. `:''}Changing a value turns this light on and pauses the local show. Reported values above update after a Bridge read.</p>
  </div>:null}
 </article>
}
export function LightsPanel({state,layout,ui,onLooks}:{state:State;layout:Layout;ui:UiPrefs;onLooks:()=>void}){
 const [scope,setScope]=React.useState('area'),[search,setSearch]=React.useState(''),[filter,setFilter]=React.useState('all'),[confirmLimits,setConfirmLimits]=React.useState(false),[groupColor,setGroupColor]=React.useState('#00bddd');
 const ids=scope==='selected'?layout.selected:layout.order,locked=!!state.navigation?.switching;
 const lights=META.lights,targets=lights.filter(l=>ids.includes(l.id)),dimmers=targets.filter(l=>l.capabilities.dimming),whites=targets.filter(l=>l.capabilities.temperature),colors=targets.filter(l=>l.capabilities.color);
 const read=state.telemetry?.data||{},on=lights.filter(l=>read[l.id]?.on===true).length,unknown=lights.filter(l=>read[l.id]?.on==null).length;
 const capped=dimmers.filter(l=>layout.placements[l.id].ceiling<100||layout.placements[l.id].trim<1);
 const values=dimmers.map(l=>read[l.id]?.brightness).filter((v):v is number=>typeof v==='number');const average=values.length?Math.round(values.reduce((a,b)=>a+b,0)/values.length):50;
 const send=(change:Record<string,unknown>,subset=ids)=>deck.send({name:'manual',payload:{ids:subset,...change}});
 const visible=lights.filter(l=>l.name.toLowerCase().includes(search.toLowerCase())&&(filter==='all'||filter==='on'&&read[l.id]?.on===true||filter==='selected'&&layout.selected.includes(l.id)));
 const favorites=PRESETS.filter(p=>ui.favorites.includes(p.id)).slice(0,4);
 const fresh=state.telemetry?.lastRead!=null&&Date.now()-state.telemetry.lastRead<=6000;
 return <div className="lights-home">
  <section className="everyday" aria-label="Everyday lighting">
   <div className="everyday-heading"><div><h2 className="panel-heading">Your lights, your way.</h2><p className="muted-note mt-2">{on} on · {lights.length} lights{unknown?` · ${unknown} not read yet`:''}{!fresh?' · Waiting for current state':''}</p></div><Badge variant="outline">{state.mode==='live'?'Animating':'Everyday'}</Badge></div>
   <ToggleGroup label="Control scope" value={scope} options={[["area",`This area · ${layout.order.length}`],["selected",`Selected · ${layout.selected.length}`]]} onChange={setScope}/>
   <div className="power-pair"><Button disabled={locked||!ids.length} onClick={()=>send({on:true})}><PowerIcon/>Turn on</Button><Button variant="outline" disabled={locked||!ids.length} onClick={()=>send({on:false})}><PowerIcon/>Turn off</Button></div>
   {dimmers.length?<CommitRange label={`Set brightness · ${dimmers.length} dimmable lights`} value={average} disabled={locked} onCommit={v=>send({on:true,brightness:v},dimmers.map(l=>l.id))}/>:null}
   <section className="background-quick" aria-label="Phone-free ambient lighting">
    <div><h3 className="text-base font-semibold">Ambient light, phone-free</h3><p className="muted-note mt-1">Bridge-native colors keep moving after lock. Exact spatial effects need Live Studio.</p></div>
    <Button disabled={locked||(!state.native&&!state.background?.available)} onClick={()=>deck.send({name:state.native?'stopBridge':'background'})}>{state.native?'Stop ambience':'Play in background'}</Button>
    {!state.native&&!state.background?.available?<p className="muted-note">Select a Hue room or zone with compatible color lights. The All lights view cannot host a Bridge scene.</p>:null}
   </section>
   <div className="quick-looks" aria-label="Everyday presets"><Button variant="secondary" disabled={locked||!whites.length} onClick={()=>send({on:true,kelvin:2700,brightness:45},whites.map(l=>l.id))}><span>Warm<small>2700 K · 45%</small></span></Button><Button variant="secondary" disabled={locked||!whites.length} onClick={()=>send({on:true,kelvin:4000,brightness:80},whites.map(l=>l.id))}><span>Focus<small>4000 K · 80%</small></span></Button><Button variant="secondary" disabled={locked||!dimmers.length} onClick={()=>send({on:true,brightness:100},dimmers.map(l=>l.id))}><span>Bright<small>100% · same color</small></span></Button></div>
   <details className="control-help"><summary>How these controls work</summary><p className="muted-note mt-2">Sliders apply on release and turn addressed lights on. Manual controls pause the local animation. White presets only affect adjustable-white lights. 100% is the device’s normal maximum setting, not a brightness boost beyond its specifications.</p></details>
   {capped.length?<div className="limit-callout"><p>{capped.length} saved limit{capped.length===1?'':'s'} / trim{capped.length===1?'':'s'} active</p><Button size="sm" variant="outline" onClick={()=>setConfirmLimits(true)}>Review 100% ceilings</Button></div>:null}
  </section>
  <section aria-label="Individual lights"><div className="section-heading"><h2>Individual lights</h2><span className="text-xs text-muted-foreground">Tap a name for color &amp; white</span></div><div className="light-filters"><Input aria-label="Find a light" placeholder="Find a light…" value={search} onChange={e=>setSearch(e.currentTarget.value)}/><Select label="Show" value={filter} options={[["all","All"],["on","On"],["selected","Show selection"]]} onChange={setFilter}/></div>
   <div className="light-list">{visible.map(l=><LightCard key={l.id} id={l.id} state={state} layout={layout} locked={locked}/>)}</div>{!visible.length?<Empty>No lights match. Clear the search or choose All.</Empty>:null}
  </section>
  <Fold title="Color for this area"><p className="muted-note">Affects {colors.length} color-capable lights in the current control scope.</p><Field><label htmlFor="areaColor" className="text-sm font-medium">Choose a color</label><div className="color-apply"><input id="areaColor" aria-label="Area color" type="color" value={groupColor} onChange={e=>setGroupColor(e.currentTarget.value)}/><Button variant="outline" disabled={locked||!colors.length} onClick={()=>send({on:true,hex:groupColor},colors.map(l=>l.id))}>Apply color</Button></div></Field></Fold>
  <Fold title="Your saved Hue scenes"><p className="muted-note">Applies the scene’s static light settings within this area, respecting your ceilings and trims. Dynamic effects are not copied. Your saved Hue scene is never edited.</p><Button variant="outline" disabled={state.savedScenes?.pending} onClick={()=>deck.send({name:'refreshScenes'})}>{state.savedScenes?.pending?'Reading…':'Read saved scenes'}</Button>{state.savedScenes?.error?<Alert title="Scene list unavailable" destructive>{state.savedScenes.error}</Alert>:null}<div className="saved-scenes">{state.savedScenes?.items?.map(s=><Button key={s.id} variant="outline" disabled={locked} onClick={()=>deck.send({name:'applyScene',payload:s.id})}>{s.name}</Button>)}</div>{state.savedScenes?.readAt&&!state.savedScenes.items.length?<Empty>No applicable saved Hue scenes in this area.</Empty>:null}</Fold>
  <section className="favorites-shortcut"><div className="section-heading"><h2>Put on a light show</h2><Button variant="ghost" size="sm" onClick={onLooks}>Browse looks</Button></div><p className="muted-note">These presets use a Hue Bridge palette, not exact spatial choreography. Master brightness and fixture limits remain in place.</p><div className="saved-scenes">{(favorites.length?favorites:PRESETS.filter(p=>['ion-eclipse','deep-orbit'].includes(p.id))).map(p=><Button key={p.id} variant="outline" disabled={locked||!state.background?.available} onClick={()=>deck.send({name:'backgroundPreset',payload:p.id})}>Ambient {p.name}</Button>)}</div></section>
  {state.manualResult&&(state.manualResult.skipped.length||state.manualResult.failed.length)?<Alert title="Some lights were not changed">{[...state.manualResult.skipped,...state.manualResult.failed].map(x=><p key={x.id}>{lights.find(l=>l.id===x.id)?.name||'Light'}: {x.reason}</p>)}</Alert>:null}
  {confirmLimits?<Confirm title="Allow these lamps up to 100%?" description={`This raises the ceiling of ${dimmers.length} dimmable lights in the chosen scope. It does not change their current brightness. Output trims are preserved. If a live show is running, its subsequent targets can use the new limit.`} onClose={()=>setConfirmLimits(false)} onAccept={()=>{const next=JSON.parse(JSON.stringify(layout));for(const l of dimmers)next.placements[l.id].ceiling=100;deck.layout(next)}}/>:null}
 </div>
}

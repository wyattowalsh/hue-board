import * as React from 'react';
import {deck,META,T,PRESETS} from '../lib/bridge';
import type {State,Layout,UiPrefs} from '../types';
import {Button,Input,Select,Fold,Field,ToggleGroup,Badge,Empty,Confirm,Alert} from './ui';
import {CommitRange} from './lights/CommitRange';
import {PowerIcon,LightCard} from './lights/LightCard';

export function LightsPanel({state,layout,ui,onLooks}:{state:State;layout:Layout;ui:UiPrefs;onLooks:()=>void}){
 const [scope,setScope]=React.useState('area'),[search,setSearch]=React.useState(''),[filter,setFilter]=React.useState('all'),[confirmLimits,setConfirmLimits]=React.useState(false),[groupColor,setGroupColor]=React.useState('#00bddd');
 const ids=scope==='selected'?layout.selected:layout.order,locked=!!state.navigation?.switching;
 const lights=META.lights,targets=lights.filter(l=>ids.includes(l.id)),dimmers=targets.filter(l=>l.capabilities.dimming),whites=targets.filter(l=>l.capabilities.temperature),colors=targets.filter(l=>l.capabilities.color);
 const read=state.telemetry?.data||{},on=lights.filter(l=>read[l.id]?.on===true).length,unknown=lights.filter(l=>read[l.id]?.on==null).length;
 const capped=dimmers.filter(l=>{const placement=layout.placements[l.id];return !!placement&&(placement.ceiling<100||placement.trim<1)});
 const values=dimmers.map(l=>read[l.id]?.brightness).filter((v):v is number=>typeof v==='number');const average=values.length?Math.round(values.reduce((a,b)=>a+b,0)/values.length):50;
 const send=(change:Record<string,unknown>,subset=ids)=>deck.send({name:'manual',payload:{ids:subset,...change}});
 const visible=lights.filter(l=>l.name.toLowerCase().includes(search.toLowerCase())&&(filter==='all'||filter==='on'&&read[l.id]?.on===true||filter==='selected'&&layout.selected.includes(l.id)));
 const favorites=PRESETS.filter(p=>ui.favorites.includes(p.id)).slice(0,4);
 const fresh=state.telemetry?.lastRead!=null&&Date.now()-state.telemetry.lastRead<=6000;
 return <div className="lights-home">
  <section className="everyday" aria-label="Everyday lighting">
   <div className="everyday-heading"><div><h2 className="panel-heading">Your lights, your way.</h2><p className="muted-note mt-2">{on} on · {lights.length} lights{unknown?` · ${unknown} not read yet`:''}{!fresh?' · Waiting for current state':''}</p></div><Badge variant="outline">{state.mode==='live'?'Animating':'Everyday'}</Badge></div>
   <div className="mb-4 rounded-xl border border-border bg-muted/40 p-3 text-sm" role="note">
    <strong className="block">Phone-free Play is automatic</strong><p className="mt-1 text-xs text-muted-foreground">{state.background?.available
      ? 'Press Play on any look to start a supported Hue Bridge dynamic palette. Wait for confirmation, then lock your phone. Exact Live Studio requires a foreground controller.'
      : 'No compatible Hue dynamic palette in this scope. Select a supported room or zone for phone-free Play; Live Studio still works while Scriptable is open.'}</p>
   </div>
   <ToggleGroup label="Control scope" value={scope} options={[["area",`This area · ${layout.order.length}`],["selected",`Selected · ${layout.selected.length}`]]} onChange={setScope}/>
   <div className="power-pair"><Button disabled={locked||!ids.length} onClick={()=>send({on:true})}><PowerIcon/>Turn on</Button><Button variant="outline" disabled={locked||!ids.length} onClick={()=>send({on:false})}><PowerIcon/>Turn off</Button></div>
   {dimmers.length?<CommitRange label={`Set brightness · ${dimmers.length} dimmable lights`} value={average} disabled={locked} onCommit={v=>send({on:true,brightness:v},dimmers.map(l=>l.id))}/>:null}
   <div className="quick-looks" aria-label="Everyday presets"><Button variant="secondary" disabled={locked||!whites.length} onClick={()=>send({on:true,kelvin:2700,brightness:45},whites.map(l=>l.id))}><span>Warm<small>2700 K · 45%</small></span></Button><Button variant="secondary" disabled={locked||!whites.length} onClick={()=>send({on:true,kelvin:4000,brightness:80},whites.map(l=>l.id))}><span>Focus<small>4000 K · 80%</small></span></Button><Button variant="secondary" disabled={locked||!dimmers.length} onClick={()=>send({on:true,brightness:100},dimmers.map(l=>l.id))}><span>Bright<small>100% · same color</small></span></Button></div>
   <details className="control-help"><summary>How these controls work</summary><p className="muted-note mt-2">Sliders apply on release and turn addressed lights on. Manual controls pause the local animation. White presets only affect adjustable-white lights. 100% is the device’s normal maximum setting, not a brightness boost beyond its specifications.</p></details>
   {capped.length?<div className="limit-callout"><p>{capped.length} saved limit{capped.length===1?'':'s'} / trim{capped.length===1?'':'s'} active</p><Button size="sm" variant="outline" onClick={()=>setConfirmLimits(true)}>Review 100% ceilings</Button></div>:null}
  </section>
  <section aria-label="Individual lights"><div className="section-heading"><h2>Individual lights</h2><span className="text-xs text-muted-foreground">Tap a name for color &amp; white</span></div><div className="light-filters"><Input aria-label="Find a light" placeholder="Find a light…" value={search} onChange={e=>setSearch(e.currentTarget.value)}/><Select label="Show" value={filter} options={[["all","All"],["on","On"],["selected","Show selection"]]} onChange={setFilter}/></div>
   <div className="light-list">{visible.map(l=><LightCard key={l.id} id={l.id} state={state} layout={layout} locked={locked}/>)}</div>{!visible.length?<Empty>No lights match. Clear the search or choose All.</Empty>:null}
  </section>
  <Fold title="Color for this area"><p className="muted-note">Affects {colors.length} color-capable lights in the current control scope.</p><Field><label htmlFor="areaColor" className="text-sm font-medium">Choose a color</label><div className="color-apply"><input id="areaColor" aria-label="Area color" type="color" value={groupColor} onChange={e=>setGroupColor(e.currentTarget.value)}/><Button variant="outline" disabled={locked||!colors.length} onClick={()=>send({on:true,hex:groupColor},colors.map(l=>l.id))}>Apply color</Button></div></Field></Fold>
  <Fold title="Your saved Hue scenes"><p className="muted-note">Applies the scene’s static light settings within this area, respecting your ceilings and trims. Dynamic effects are not copied. Your saved Hue scene is never edited.</p><Button variant="outline" disabled={state.savedScenes?.pending} onClick={()=>deck.send({name:'refreshScenes'})}>{state.savedScenes?.pending?'Reading…':'Read saved scenes'}</Button>{state.savedScenes?.error?<Alert title="Scene list unavailable" destructive>{state.savedScenes.error}</Alert>:null}<div className="saved-scenes">{state.savedScenes?.items?.map(s=><Button key={s.id} variant="outline" disabled={locked} onClick={()=>deck.send({name:'applyScene',payload:s.id})}>{s.name}</Button>)}</div>{state.savedScenes?.readAt&&!state.savedScenes.items.length?<Empty>No applicable saved Hue scenes in this area.</Empty>:null}</Fold>
  <section className="favorites-shortcut"><div className="section-heading"><h2>Put on a light show</h2><Button variant="ghost" size="sm" onClick={onLooks}>Browse looks</Button></div><p className="muted-note">Play starts the current animation selection. Master brightness and lamp limits stay as you set them.</p><div className="saved-scenes">{(favorites.length?favorites:PRESETS.filter(p=>['ion-eclipse','deep-orbit'].includes(p.id))).map(p=><Button key={p.id} variant="outline" disabled={locked||!layout.selected.length} onClick={()=>deck.send({name:'playPreset',payload:p.id})}>Play {p.name}</Button>)}</div></section>
  {state.manualResult&&(state.manualResult.skipped.length||state.manualResult.failed.length)?<Alert title="Some lights were not changed">{[...state.manualResult.skipped,...state.manualResult.failed].map(x=><p key={x.id}>{lights.find(l=>l.id===x.id)?.name||'Light'}: {x.reason}</p>)}</Alert>:null}
  {confirmLimits?<Confirm title="Allow these lamps up to 100%?" description={`This raises the ceiling of ${dimmers.length} dimmable lights in the chosen scope. It does not change their current brightness. Output trims are preserved. If a live show is running, its subsequent targets can use the new limit.`} onClose={()=>setConfirmLimits(false)} onAccept={()=>{const next=JSON.parse(JSON.stringify(layout));for(const l of dimmers)next.placements[l.id].ceiling=100;deck.layout(next)}}/>:null}
 </div>
}

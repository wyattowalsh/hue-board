import * as React from 'react';
import {deck,E,T,H,META,useNow} from '../lib/bridge';
import type {Layout,State,Settings,Placement} from '../types';
import {Badge,ToggleGroup,Select,Alert,Fold} from './ui';
export function MapPreview({state,layout,settings,roomMode,focusId,onFocus}:{state:State;layout:Layout;settings:Settings;roomMode:boolean;focusId:string;onFocus:(id:string)=>void}){
 const [source,setSource]=React.useState('reported'),now=useNow(),svg=React.useRef<SVGSVGElement>(null);const moving=React.useRef<string|null>(null);
 const lamp=META.lights.find(l=>l.id===focusId),reported=state.telemetry?.data?.[focusId];
 function move(id:string,x:number,y:number){deck.layout({...layout,placements:{...layout.placements,[id]:{...layout.placements[id],x:Math.min(.96,Math.max(.04,x)),y:Math.min(.94,Math.max(.06,y))}}})}
 function drag(e:React.PointerEvent<SVGSVGElement>){if(!moving.current||!svg.current)return;const r=svg.current.getBoundingClientRect(),x=(e.clientX-r.left)/r.width*360,y=(e.clientY-r.top)/r.height*230;move(moving.current,(x-24)/312,(y-16)/198)}
 const fresh=state.telemetry?.lastRead!=null&&now-state.telemetry.lastRead<=6000;
 return <div className="flex flex-col gap-3">
 <div className="flex items-center justify-between gap-3"><h2 className="text-sm font-semibold">Your room</h2><Badge variant="outline">{layout.selected.length} / {META.lights.length} selected</Badge></div>
 <ToggleGroup label="Preview data source" value={source} options={[["reported","Reported"],["target","Sent target"],["design","Design"]]} onChange={setSource}/>
 <p className="min-h-4 text-xs text-muted-foreground" data-testid="telemetry-summary">{T.summary(state.telemetry,now)}</p>
 <svg ref={svg} className={roomMode?"room-map":"room-map compact-map"} viewBox="0 0 360 230" role="group" aria-label="Bulb placement and state" onPointerMove={drag} onPointerUp={()=>moving.current=null} onPointerCancel={()=>moving.current=null}>
 <path className="map-grid" d="M24 54H336M24 94H336M24 134H336M24 174H336M76 16V214M128 16V214M180 16V214M232 16V214M284 16V214"/>
 <rect x="24" y="16" width="312" height="198" rx="16" fill="none" stroke="var(--grid)"/>
 {layout.order.map((id,index)=>{const p=layout.placements[id],light=META.lights.find(l=>l.id===id);let row:unknown=state.telemetry?.data?.[id];const target=state.telemetry?.targets?.[id];
  if(source==='target')row=target&&target.kind!=='native'&&target.action?T.normalize({id,...target.action},target.acceptedAt):null;
  // A color target without an on/off field leaves power unchanged. Render its requested color, not a fabricated off state.
  const targetRow=row as {on?:boolean|null}|null;
  const displayRow=source==='target'&&targetRow&&targetRow.on==null?{...targetRow,on:true}:row;
  const color=source==='design'?E.css((state.design?.[id]||E.sample(state.t,p.q,settings)).rgb):T.color(displayRow);
  const r=row as {on?:boolean;fetchedAt?:number;missing?:boolean;brightness?:number}|null;
  const stale=source==='reported'&&(!r||r.fetchedAt==null||now-r.fetchedAt>6000||r.missing);const on=source==='design'?layout.selected.includes(id):source==='target'?!!r&&r.on!==false:r?.on===true;
  const level=source==='design'?(state.design?.[id]?.b||0)/100:Math.max(0,(r?.brightness||0)/100);
  const x=24+p.x*312,y=16+p.y*198,selected=id===focusId;
  const h=p.hue,edited=h?.applied&&(Math.abs(h.applied.x-p.x)>.0001||Math.abs(h.applied.y-p.y)>.0001);
  const geometry=h&&!edited?h.positions.map(v=>H.project(v,h.projection,h.mirror)):[];
  return <g key={id}>
   {geometry.length>1?<polyline points={geometry.map(v=>`${24+v.x*312},${16+v.y*198}`).join(' ')} fill="none" stroke="var(--muted-foreground)" opacity=".35" strokeWidth="2"/>:null}
   <g className="map-bulb" role="button" tabIndex={0} aria-label={`${light?.name}. ${source==='reported'?T.stateText(row):source==='target'?T.targetText(target,now):'Design simulation'}`} aria-pressed={selected}
     onClick={()=>onFocus(id)} onPointerDown={e=>{onFocus(id);if(roomMode){e.preventDefault();moving.current=id;svg.current?.setPointerCapture(e.pointerId)}}}
     onKeyDown={e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();onFocus(id)}if(roomMode&&['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(e.key)){e.preventDefault();move(id,p.x+(e.key==='ArrowRight'?.02:e.key==='ArrowLeft'?-.02:0),p.y+(e.key==='ArrowDown'?.02:e.key==='ArrowUp'?-.02:0))}}}>
     <circle className="hit" cx={x} cy={y} r="22" fill="transparent" stroke={selected?'var(--primary)':'transparent'} strokeWidth="1.5"/>
     <circle cx={x} cy={y} r={on?13+level*3:12} fill={color} opacity={stale?.35:on?.45+.55*level:.5} stroke="var(--lamp-edge)" strokeDasharray={stale?'3 3':undefined}/>
     <text x={x} y={y+4} textAnchor="middle" style={{fill:on?'#fff':'var(--muted-foreground)',paintOrder:'stroke',stroke:on?'#0007':'transparent',strokeWidth:2}}>{index+1}</text>
   </g>
  </g>})}
 </svg>
 <p className="text-center text-[10px] font-medium tracking-wide text-muted-foreground">{source==='reported'?'BRIDGE STATE · APPROXIMATE SCREEN COLORS':source==='target'?'LAST ACCEPTED TARGET · NOT OPTICAL OUTPUT':'DESIGN SIMULATION · NOT REPORTED STATE'}</p>
 <Fold title={roomMode?'Inspect and position a bulb':'Bulb inspector'} open={roomMode}> <Select label="Inspect a bulb" value={focusId} options={META.lights.map(l=>[l.id,l.name])} onChange={onFocus}/>
 {lamp?<div className="flex flex-col gap-1 rounded-xl bg-muted p-3"><p className="text-sm font-semibold">{lamp.name}</p><p className="text-xs leading-relaxed text-muted-foreground">{T.stateText(reported)}</p><p className="text-xs text-muted-foreground">{T.ageText(reported?.fetchedAt,now)} · {T.connection(state.telemetry?.links?.[reported?.owner||''],now)}</p><p className="text-xs text-muted-foreground">{state.ownership?.[focusId]||'uncontrolled'}</p></div>:null}</Fold>
 {roomMode?<> {state.hueLayouts?.areas?.some(a=>a.matched)&&!layout.hue?<p className="muted-note">Saved Hue positions are available in Room. Importing preserves lamp selection and limits.</p>:null}
 <p className="muted-note">{layout.hue?`Placement: ${layout.hue.areaName}. Relative coordinates, not measured metres.`:'Local placement. Import saved Hue positions in Room.'} {roomMode?'Drag a bulb or use arrow keys; map edits do not change path phase.':''}</p></>:null}
 {!fresh&&state.telemetry?.lastRead!=null?<Alert title="Readback is stale">Last-known values are retained. They are not current optical measurements.</Alert>:null}
 </div>
}

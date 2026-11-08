import * as React from 'react';
import {deck,META,T} from '../../lib/bridge';
import type {State,Layout} from '../../types';
import {Button,Badge,Alert,Field} from '../ui';
import {cn} from '../../lib/utils';
import {CommitRange} from './CommitRange';

export const PowerIcon=()=> <svg data-icon="inline-start" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true"><path d="M12 3v9M7.2 5.8a8 8 0 1 0 9.6 0" strokeLinecap="round"/></svg>;
export function LightCard({id,state,layout,locked}:{id:string;state:State;layout:Layout;locked:boolean}){
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

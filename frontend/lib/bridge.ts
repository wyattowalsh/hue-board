import * as React from 'react';
import type {State,Settings,UiPrefs,Layout,Meta,Command,Engine,Preset} from '../types';
declare global { interface Window { BOYZ_ENGINE:()=>Engine;BOYZ_TELEMETRY:()=>{color:(r:unknown)=>string;age:(stamp:unknown,now:number)=>number|null;ageText:(stamp:unknown,now:number)=>string;stateText:(r:unknown)=>string;summary:(t:unknown,now:number)=>string;targetText:(t:unknown,now:number)=>string;normalize:(r:unknown,at:number)=>unknown;connection:(r:unknown,now:number)=>string;xyCSS:(p:unknown)=>string};BOYZ_LAYOUT:{project:(p:unknown,projection?:string,mirror?:boolean)=>{x:number;y:number};text:(p:unknown)=>string};BOYZ_PRESETS:Preset[];BOYZ_INITIAL:State;BOYZ_META:Meta;DECK_BOOT:{ready:boolean;error:string};deckBootError:(m:string)=>void;DECK:{exchange:(next:State)=>string;report:(next:State)=>void};} }
export const E=window.BOYZ_ENGINE();export const T=window.BOYZ_TELEMETRY();export const H=window.BOYZ_LAYOUT;export const PRESETS=window.BOYZ_PRESETS;export let META=window.BOYZ_META;
const copy=<T,>(v:T):T=>JSON.parse(JSON.stringify(v));
let state:State=window.BOYZ_INITIAL;
let snapshot={status:state,settings:copy(state.settings),layout:copy(state.layout),ui:state.ui||{theme:'system' as const,motion:'system' as const,favorites:[]},heartbeat:Date.now()};
let dirty=false,pending:Command|null=null;const listeners=new Set<()=>void>();
const emit=()=>{for(const fn of listeners)fn()};
export const deck={
 subscribe(fn:()=>void){listeners.add(fn);return()=>{listeners.delete(fn)}},getSnapshot:()=>snapshot,
 settings(p:Partial<Settings>){snapshot={...snapshot,settings:E.clean({...snapshot.settings,...p})};dirty=true;emit()},
 layout(next:Layout){snapshot={...snapshot,layout:copy(next)};dirty=true;emit()},
 ui(p:Partial<UiPrefs>){snapshot={...snapshot,ui:{...snapshot.ui,...p}};dirty=true;emit()},
 send(command:Command){const urgent=['pause','restore','stopBridge','stopSequence'];if(pending&&urgent.includes(pending.name)&&!urgent.includes(command.name))return;pending=command;emit()},
 report(next:State){if(next.meta&&next.meta.scopeId!==META.scopeId){META=next.meta;dirty=false;pending=null;}state=next;snapshot={...snapshot,status:next,heartbeat:Date.now(),...(!dirty?{settings:copy(next.settings),layout:copy(next.layout),ui:copy(next.ui||snapshot.ui)}:{})};emit()},
 exchange(next:State){deck.report(next);const packet={edit:dirty?{settings:snapshot.settings,layout:snapshot.layout,ui:snapshot.ui}:null,command:pending,hidden:document.hidden};dirty=false;pending=null;return JSON.stringify(packet)}
};
window.DECK={exchange:deck.exchange,report:deck.report};
export function useDeck(){return React.useSyncExternalStore(deck.subscribe,deck.getSnapshot,deck.getSnapshot)}
export function useNow(){const [now,setNow]=React.useState(Date.now());React.useEffect(()=>{const id=setInterval(()=>setNow(Date.now()),1000);return()=>clearInterval(id)},[]);return now}
export function useAppearance(ui:UiPrefs,nativeDark:boolean|null){const [media,setMedia]=React.useState(()=>matchMedia('(prefers-color-scheme: dark)').matches);const [reduce,setReduce]=React.useState(()=>matchMedia('(prefers-reduced-motion: reduce)').matches);
 React.useEffect(()=>{const m=matchMedia('(prefers-color-scheme: dark)'),r=matchMedia('(prefers-reduced-motion: reduce)');const a=()=>setMedia(m.matches),b=()=>setReduce(r.matches);m.addEventListener('change',a);r.addEventListener('change',b);return()=>{m.removeEventListener('change',a);r.removeEventListener('change',b)}},[]);
 const theme=ui.theme==='system'?((nativeDark??media)?'dark':'light'):ui.theme;const reduced=reduce||ui.motion==='reduce';
 React.useLayoutEffect(()=>{document.documentElement.dataset.theme=theme;document.documentElement.classList.toggle('dark',theme==='dark');document.documentElement.style.colorScheme=theme;document.documentElement.dataset.motion=reduced?'reduce':'normal'},[theme,reduced]);return {theme,reduced};}

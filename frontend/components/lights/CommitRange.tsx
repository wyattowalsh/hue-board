import * as React from 'react';
import {Field} from '../ui';

/** This is an edit target, never a fabricated readback. Commit at release, key-up or blur, not every frame. */
export function CommitRange({label,value,min=1,max=100,unit='%',disabled=false,onCommit}:{label:string;value:number;min?:number;max?:number;unit?:string;disabled?:boolean;onCommit:(v:number)=>void}){
 const [draft,setDraft]=React.useState(value),dirty=React.useRef(false),id=React.useId();
 React.useEffect(()=>{if(!dirty.current)setDraft(Math.min(max,Math.max(min,value)))},[value,min,max]);
 const commit=()=>{if(disabled||!dirty.current)return;dirty.current=false;onCommit(draft)};
 return <Field><label htmlFor={id} className="flex items-center justify-between gap-3 text-sm font-medium"><span>{label}</span><output htmlFor={id} className="tabular-nums text-primary">{Math.round(draft)}{unit}</output></label><input id={id} type="range" value={draft} min={min} max={max} step={unit===' K'?50:1} disabled={disabled} onChange={e=>{dirty.current=true;setDraft(Number(e.currentTarget.value))}} onPointerUp={commit} onKeyUp={e=>{if(['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','Home','End','PageUp','PageDown'].includes(e.key))commit()}} onBlur={commit} className="h-11 w-full cursor-pointer accent-primary disabled:opacity-45"/></Field>
}

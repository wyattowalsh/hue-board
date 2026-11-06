import * as React from 'react';
import {deck,META,useDeck,useNow,useAppearance} from './lib/bridge';
import {Button,Alert,Badge,Select,ToggleGroup,Fold,Confirm} from './components/ui';
import {MapPreview} from './components/MapPreview';
import {LightsPanel} from './components/LightsPanel';
import {PerformPanel} from './components/PerformPanel';
import {LibraryPanel} from './components/LibraryPanel';
import {RoomPanel} from './components/RoomPanel';
import {LabPanel} from './components/LabPanel';
const tabs=[['lights','Lights'],['library','Looks'],['perform','Studio'],['settings','Settings']] as const;
type Tab=typeof tabs[number][0];
export default function App(){
 const {status:state,settings,layout,ui,heartbeat}=useDeck(),now=useNow();
 const [tab,setTab]=React.useState<Tab>('lights'),[settingsTab,setSettingsTab]=React.useState('room'),[focusId,setFocus]=React.useState(META.lights[0]?.id||''),[newBaseline,setNewBaseline]=React.useState(false);
 const {theme,reduced}=useAppearance(ui,state.systemDark),scopeId=state.meta?.scopeId||META.name;
 const idle=now-heartbeat>7000,switching=!!state.navigation?.switching,stopping=['live','preparing','adjusting','restoring','stopping'].includes(state.mode)||state.busy;
 React.useLayoutEffect(()=>{window.DECK_BOOT.ready=true;const boot=document.getElementById('boot');if(boot)boot.hidden=true},[]);
 React.useEffect(()=>{setFocus(META.lights[0]?.id||'')},[scopeId]);
 function selectTab(id:Tab){setTab(id);window.scrollTo({top:0,behavior:'auto'})}
 function tabKeys(event:React.KeyboardEvent<HTMLButtonElement>,i:number){let n=i;if(event.key==='ArrowRight')n=(i+1)%tabs.length;else if(event.key==='ArrowLeft')n=(i+tabs.length-1)%tabs.length;else if(event.key==='Home')n=0;else if(event.key==='End')n=tabs.length-1;else return;event.preventDefault();selectTab(tabs[n][0]);document.getElementById('tab-'+tabs[n][0])?.focus()}
 const summary=state.mode==='live'?'Animation running':state.native?'Bridge playback':state.mode==='adjusting'?'Applying lighting':state.busy?'Working':idle?'Controller idle':'Ready';
 return <><main className="app" data-surface={tab}>
  <header className="app-header"><div><h1 className="wordmark">Hue<span> Board</span></h1><p className="app-subtitle">Everyday light. Extraordinary nights.</p></div><div className="topbar-status"><div>{summary}</div><p className="mt-1 text-muted-foreground">{ui.theme==='system'?'System · ':''}{theme}</p></div></header>
  {state.navigation?<div className="area-picker"><Select id="areaPicker" label="Room or zone" disabled={switching} value={state.navigation.current} options={state.navigation.areas.map(a=>[a.id,`${a.name} · ${a.count} ${a.type==='all'?'lights on this Bridge':a.type==='zone'?'lights / zone':'lights'}`])} onChange={id=>deck.send({name:'switchArea',payload:id})}/>{switching?<p className="muted-note" role="status">Finishing the current request before switching. No overlapping controller is started.</p>:null}</div>:<p className="mb-5 text-sm text-muted-foreground">{META.name}</p>}
  <nav className="tabs" role="tablist" aria-label="Control surfaces">{tabs.map(([id,label],i)=><button id={'tab-'+id} key={id} type="button" role="tab" aria-selected={tab===id} aria-controls={'panel-'+id} tabIndex={tab===id?0:-1} onClick={()=>selectTab(id)} onKeyDown={e=>tabKeys(e,i)}>{label}</button>)}</nav>
  {state.navigation?.error?<div className="mb-5"><Alert title="Could not change area" destructive>{state.navigation.error}</Alert></div>:null}
  {state.error?<div className="mb-5"><Alert title="Needs attention" destructive>{state.error}</Alert></div>:null}
  {idle?<div className="mb-5"><Alert title="Controller is not responding">Keep Scriptable open. Values below retain their last read time; commands are not confirmed until acknowledged.</Alert></div>:null}
  {state.session.recoveryRequired?<div className="mb-5"><Alert title="Keep your previous restore point?"><p>It was captured {state.session.createdAt?new Date(state.session.createdAt).toLocaleString():'at an unknown time in an older version'}. Keep it to continue, or start a fresh baseline. Neither choice turns lights on.</p><div className="mt-3 flex flex-wrap gap-2"><Button size="sm" onClick={()=>deck.send({name:'resumeSession'})}>Keep restore point</Button><Button size="sm" variant="outline" onClick={()=>setNewBaseline(true)}>Start fresh</Button></div></Alert></div>:null}
  {state.sequence?.enabled?<div className="sequence-banner"><span>Cue {state.sequence.index+1}/{settings.sequenceIds.length} · next in {Math.ceil(state.sequence.remaining)}s</span><Button variant="ghost" size="sm" onClick={()=>deck.send({name:'stopSequence'})}>Keep this look</Button></div>:null}
  <section role="tabpanel" id={'panel-'+tab} aria-labelledby={'tab-'+tab} tabIndex={0} key={scopeId}>
   {tab==='lights'?<LightsPanel state={state} layout={layout} ui={ui} onLooks={()=>selectTab('library')}/>:null}
   {tab==='library'?<LibraryPanel state={state} settings={settings} ui={ui}/>:null}
   {tab==='perform'?<div className="work-area"><aside className="preview-column"><Fold title="Your room · live readback"><MapPreview state={state} settings={settings} layout={layout} roomMode={false} focusId={focusId} onFocus={setFocus}/></Fold></aside><div className="control-column"><div className="studio-heading"><h2 className="panel-heading">Make it move.</h2><p className="muted-note mt-2">Compose without starting. Press Play when you’re ready.</p></div><PerformPanel state={state} settings={settings} theme={theme} reduced={reduced}/></div></div>:null}
   {tab==='settings'?<div className="flex flex-col gap-6"><ToggleGroup label="Settings section" value={settingsTab} options={[["room","Room setup"],["lab","App & recovery"]]} onChange={setSettingsTab}/>{settingsTab==='room'?<div className="work-area"><aside className="preview-column"><MapPreview state={state} settings={settings} layout={layout} roomMode focusId={focusId} onFocus={setFocus}/></aside><div className="control-column"><RoomPanel state={state} settings={settings} layout={layout} focusId={focusId} onFocus={setFocus}/></div></div>:<LabPanel state={state} settings={settings} ui={ui} theme={theme}/>}</div>:null}
  </section>
  <p className="mt-6 muted-note" role="status" aria-live="polite">{state.note}</p>
 </main>
 <footer className="transport"><div>{tab==='lights'?<div className="daily-transport"><span className="muted-note">{switching?'Changing area…':stopping?'Local control active':state.native?'Bridge playback may continue':'Local to your Hue Bridge'}</span><div className="flex gap-2">{stopping?<Button size="sm" variant="outline" onClick={()=>deck.send({name:'pause'})}>Pause / cancel</Button>:null}{state.native?<Button size="sm" variant="outline" onClick={()=>deck.send({name:'stopBridge'})}>Stop Bridge</Button>:null}<Button size="sm" variant="outline" disabled={!state.touched||switching} onClick={()=>deck.send({name:'restore'})}>Restore session</Button></div></div>:<><div className="transport-grid"><Button disabled={switching||(!stopping&&!layout.selected.length)} onClick={()=>deck.send({name:stopping?'pause':'live'})}>{stopping?'Pause / cancel':'Play animation'}</Button><Button variant="outline" disabled={switching||(!state.native&&!layout.selected.length)} onClick={()=>deck.send({name:state.native?'stopBridge':'bridge'})}>{state.native?'Stop Bridge':'Run on Bridge'}</Button><Button variant="outline" disabled={!state.touched||switching} onClick={()=>deck.send({name:'restore'})}>Restore session</Button></div><p className="mt-2 text-center text-[10px] leading-relaxed text-muted-foreground">{state.native?'Bridge playback can continue independently.':state.mode==='live'?'Keep Scriptable open and your phone awake.':'Previewing and editing do not start playback.'} {state.inFlight?'An already-sent request can still finish.':''}</p></>}</div></footer>
 {newBaseline?<Confirm title="Start a new restore baseline?" description="Archive the earlier point and capture fresh light states on your next action. Live playback will pause. Stop Bridge playback first if it is active." onClose={()=>setNewBaseline(false)} onAccept={()=>deck.send({name:'newSession'})}/>:null}
 </>
}

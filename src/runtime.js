// Preserve the working 2.1 WebView startup strategy and native fallback.
async function uiTimeout(promise,label,ms=7000){let timer;try{return await Promise.race([promise,new Promise((_,reject)=>{timer=Timer.schedule(ms,false,()=>reject(new Error(label+' timed out. Use Compatibility controls.')));})]);}finally{if(timer)timer.invalidate();}}
function localDeckRequest(request){const url=String(request?.url||'');return url===''||/^about:blank(?:[?#]|$)/i.test(url)||/^data:text\/html[;,]/i.test(url);}
async function makeWebPanel(meta,initial){
  const view=new WebView();view.shouldAllowRequest=localDeckRequest;
  await uiTimeout(view.loadHTML(buildPage(meta,initial)),'Loading interface');
  const raw=await uiTimeout(view.evaluateJavaScript('JSON.stringify({ready:!!(window.DECK_BOOT&&window.DECK_BOOT.ready&&window.DECK),error:window.DECK_BOOT&&window.DECK_BOOT.error||""})',false),'Checking interface');
  const boot=JSON.parse(raw);if(!boot.ready||boot.error)throw new Error('Interface initialization failed: '+(boot.error||'control bridge missing'));
  return {present:()=>view.present(false),async exchange(next){const text=await uiTimeout(view.evaluateJavaScript('(function(){if(window.DECK_BOOT.error)return JSON.stringify({uiError:window.DECK_BOOT.error});return window.DECK.exchange('+safeJSON(next)+');})()',false),'Reading interface');const p=JSON.parse(text);if(p.uiError)throw new Error(p.uiError);return p;},
    async report(next){await uiTimeout(view.evaluateJavaScript('window.DECK.report('+safeJSON(next)+');true;',false),'Updating interface');},
    async fail(message){try{await uiTimeout(view.evaluateJavaScript('window.deckBootError('+safeJSON(message)+');true;',false),'Showing error',1500);}catch(_){}}};
}
function validatePreset(value){if(!value||!['hue-board',LEGACY_MIX_APP].includes(value.app)||value.schema!==3||!value.settings||typeof value.settings!=='object')throw new Error('Expected a Hue Board schema 3 mix. Nothing was imported.');return ENGINE.clean(value.settings);}
async function exportDocument(name,value){const fm=FileManager.local(),path=fm.joinPath(fm.documentsDirectory(),name);fm.writeString(path,JSON.stringify(value,null,2));await ShareSheet.present([path]);}
async function runDeck(cfg,group,kind='web',groups=[group]){
  const ctl=makeWorkspaceController(cfg,groups,group);let panel,closed=false,uiError='';
  try{panel=kind==='compatibility'?makeCompatibilityPanel(ctl.meta,ctl.state()):await makeWebPanel(ctl.meta,ctl.state());}
  catch(e){await ctl.close();throw e;}
  const presentation=panel.present().then(()=>{closed=true;},e=>{closed=true;uiError=shortError(e);});
  await sleep(350);
  let auxiliary=null;
  try{while(!closed){const packet=await panel.exchange(ctl.state());if(closed)break;
      if(packet.edit)ctl.update(packet.edit);
      const command=packet.command;
      if(command&&['exportDiagnostics','exportMix','importMix'].includes(command.name)){
        // Pause before presenting a native share sheet or clipboard prompt. Never overlap auxiliary dialogs.
        ctl.dispatch('pause','Opening export/import');
        if(!auxiliary){const before=ctl.state();auxiliary=(async()=>{
          if(command.name==='exportDiagnostics')await exportDocument('hue-board-diagnostics.json',ctl.diagnostics());
          else if(command.name==='exportMix')await exportDocument('hue-board-mix.json',{app:'hue-board',schema:3,settings:before.settings});
          else {const value=await input('Import mix','Paste a Hue Board schema 3 JSON mix. Importing does not start lights.','');if(value!==null){const s=validatePreset(JSON.parse(value));ctl.update({settings:s,layout:ctl.state().layout});}}
        })().catch(e=>inform('Export / import',shortError(e))).finally(()=>{auxiliary=null;});}
      }else if(command)ctl.dispatch(command.name,command.payload);
      ctl.tick(packet.hidden||!!auxiliary);
      await sleep(120);
    }
  }catch(e){uiError=shortError(e);ctl.dispatch('pause');if(!closed)await panel.fail(uiError);}
  finally{await ctl.close();}
  await presentation;if(auxiliary)await auxiliary;if(uiError)console.warn(uiError);
}
async function shortcutBackground(cfg,group,groups,command,presetId=null){
  const ctl=makeWorkspaceController(cfg,groups,group,{autoDiscover:false});
  try{
    if(presetId&&!PRESET_LIBRARY.some(p=>p.id===presetId))throw new HueError('validation','Unknown scene preset. No lights changed.');
    ctl.dispatch(command,presetId);ctl.tick(false);await ctl.settled();
    const result=ctl.state();
    if(result.error)throw new HueError('control',result.error);
    if(command==='stopBridge'&&result.native)throw new HueError('control','Some delegated playback remains. Open the control deck to inspect.');
    if(command!=='stopBridge'&&!result.native)throw new HueError('control',result.note||'Bridge playback could not be started.');
    if(typeof Script.setShortcutOutput==='function')Script.setShortcutOutput(command==='stopBridge'?'Bridge stop requested':'Bridge playback accepted');
  }finally{await ctl.close();}
}
async function main(){const cfg=readConfig();if(!await bridgeSetup(cfg)||!await ensurePairing(cfg))return;
  let groups=await inventory(cfg);if(!groups.length)throw new Error('No controllable Hue lights found.');
  if(!getGroup(cfg,groups)&&!await selectGroup(cfg,groups))return;
  const shortcut=typeof args!=='undefined'&&typeof args.shortcutParameter==='string'?args.shortcutParameter.trim():'';
  const action=shortcut==='background'?'background':shortcut==='stop-background'?'stopBridge':shortcut.startsWith('background:')?'backgroundPreset':null;
  if(action){await shortcutBackground(cfg,getGroup(cfg,groups),groups,action,action==='backgroundPreset'?shortcut.slice('background:'.length):null);return;}
  for(;;){const g=getGroup(cfg,groups);if(!g){if(!await selectGroup(cfg,groups))return;continue;}
    const action=await choose('Hue Board',g.name+'\nYour existing pairing is reused. Do not run another Hue Board controller at the same time.',
      ['Open control deck','Compatibility controls (no WebView)','Play in background','Stop background','Choose room / zone','Change Bridge address','Refresh inventory'],'Exit');if(action<0)return;
    if(action===2||action===3){try{await shortcutBackground(cfg,g,groups,action===2?'background':'stopBridge');await inform('Hue Board',action===2?'Bridge playback accepted. Lock your phone if you wish.':'Bridge stop accepted.');}catch(e){await inform('Playback',shortError(e));}continue;}
    if(action<=1){try{await runDeck(cfg,g,action===1?'compatibility':'web',groups);}catch(e){await inform('Control deck',shortError(e)+'\nThe native compatibility controls remain available.');}}
    else if(action===4)await selectGroup(cfg,groups);
    else if(action===5){if(await bridgeSetup(cfg,true)&&await ensurePairing(cfg)){groups=await inventory(cfg);if(!getGroup(cfg,groups)&&!await selectGroup(cfg,groups))return;}}
    else groups=await inventory(cfg);
  }
}

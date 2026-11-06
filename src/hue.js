/** HTTPS transport and identity-aware pairing. Keys never enter either UI model. */
async function http(ip,method,path,payload,key) {
  if(!validIp(ip))throw new HueError('validation','Use a private LAN IPv4 Bridge address.');
  const r=new Request('https://'+ip+path);r.method=method;r.timeoutInterval=5;r.allowInsecureRequest=true;r.onRedirect=()=>null;
  const headers={'Content-Type':'application/json','Accept':'application/json'};if(key)headers['hue-application-key']=key;r.headers=headers;
  if(payload!==undefined)r.body=JSON.stringify(payload);
  let raw;try{raw=await r.loadString();}catch(_){throw new HueError('network','Cannot reach the Bridge. Check Wi-Fi, Local Network permission and the Bridge address.');}
  const code=r.response?.statusCode||0;
  if(code===401||code===403)throw new HueError('auth','Bridge authorization was rejected (HTTP '+code+'). The existing key has not been deleted.',code);
  if(code===429)throw new HueError('rate','Bridge asked the controller to slow down (HTTP 429).',code);
  if(code>=300&&code<400)throw new HueError('redirect','Bridge redirect was rejected to protect your key.',code);
  let data;try{data=raw?JSON.parse(raw):{};}catch(_){throw new HueError('protocol','Bridge returned non-JSON (HTTP '+code+').',code);}
  const details=Array.isArray(data.errors)?data.errors:[];
  if(code>=400||details.length){const desc=details.map(v=>v.description||'Hue error').join('; ');throw new HueError(code===404?'missing':code>=500?'server':'api',desc||'Bridge request failed (HTTP '+code+').',code,details);}
  return data;
}
function authName(cfg){return cfg.bridgeId?'hue-board.bridgekey.'+cfg.bridgeId:AUTH_PREFIX+cfg.ip;}
function endpoint(cfg,method,path,payload){const name=authName(cfg);if(!Keychain.contains(name))throw new HueError('auth','No saved Bridge key. Run pairing from the main menu.');return http(cfg.ip,method,'/clip/v2/resource/'+path,payload,Keychain.get(name));}
function readConfig(){migrateLegacyState();return Object.assign({orders:{}},readObject(STORAGE,{}));}
function saveConfig(cfg){writeObject(STORAGE,cfg);}
async function bridgeSetup(cfg,force=false) {
  if(validIp(cfg.ip)&&!force)return true;
  let ips=[];try{const r=new Request('https://discovery.meethue.com/');r.timeoutInterval=5;const data=await r.loadJSON();ips=[...new Set((Array.isArray(data)?data:[]).map(v=>v.internalipaddress).filter(validIp))];}catch(_){}
  const pick=await choose('Choose Hue Bridge','Use trusted home Wi-Fi. Local Hue certificate verification is disabled in this Scriptable implementation.',ips.map(ip=>'Bridge '+ip).concat('Enter IP manually'),'Cancel');if(pick<0)return false;
  const ip=pick<ips.length?ips[pick]:await input('Bridge IP','Find the local IP in the Hue app.',cfg.ip||'');if(ip===null)return false;if(!validIp(ip))throw new HueError('validation','Invalid private LAN IPv4 address.');
  cfg.ip=ip;saveConfig(cfg);return true;
}
async function ensurePairing(cfg) {
  // Preserve a known identity until a new address has answered. Never send its key blindly.
  let probe;
  for(;;){try{probe=await http(cfg.ip,'GET','/api/config');if(!probe||!(probe.bridgeid||probe.modelid||probe.apiversion))throw new HueError('protocol','This address did not identify itself as a Hue Bridge.');break;}
    catch(e){const action=await choose('Bridge connection',shortError(e),['Retry address','Choose another address'],'Cancel');if(action<0)return false;if(action===1&&!await bridgeSetup(cfg,true))return false;}}
  const previous=cfg.bridgeId;
  const publicId=typeof probe.bridgeid==='string'?probe.bridgeid.toLowerCase():null;
  if(publicId&&previous&&publicId!==previous){delete cfg.group;}
  if(publicId)cfg.bridgeId=publicId;else if(previous&&cfg.knownIp!==cfg.ip)delete cfg.bridgeId;
  const canonical=authName(cfg);
  migrateLegacyBridgeKey(cfg);
  for(;;){if(Keychain.contains(canonical)){
      try {const result=await endpoint(cfg,'GET','bridge');const bridge=result.data?.[0];if(!bridge)throw new HueError('protocol','Bridge validation returned no bridge resource.');
        const id=typeof bridge.bridge_id==='string'?bridge.bridge_id.toLowerCase():publicId||bridge.id;
        if(publicId&&bridge.bridge_id&&id!==publicId)throw new HueError('identity','Bridge identity changed during authorization.');
        const key=Keychain.get(canonical);cfg.bridgeId=id;cfg.knownIp=cfg.ip;Keychain.set(authName(cfg),key);saveConfig(cfg);return true;
      } catch(e){if(errorKind(e)!=='auth'){
          const action=await choose('Connection check failed',shortError(e)+'\n\nThis is not evidence that pairing was lost.', ['Retry connection','Change Bridge address'],'Cancel');if(action<0)return false;if(action===1){if(!await bridgeSetup(cfg,true))return false;return ensurePairing(cfg);}continue;}
        const action=await choose('Pairing required',shortError(e),['Pair using Bridge button'],'Cancel');if(action<0)return false;}
    }
    const action=await choose('Pair with the Bridge','Press its physical center button, then tap Pair now. No lights or scenes will be removed.', ['Pair now'],'Cancel');if(action<0)return false;
    const reply=await http(cfg.ip,'POST','/api',{devicetype:'hue_board#iphone'});const key=reply?.[0]?.success?.username;
    if(typeof key==='string'&&key.length>=8){Keychain.set(canonical,key);continue;}
    await inform('Pairing not granted',String(reply?.[0]?.error?.description||'No key returned. Press the button and try again.'));
  }
}
async function inventory(cfg) {
  const result=await Promise.all(['room','zone','light','device'].map(p=>endpoint(cfg,'GET',p)));
  for(const r of result)if(!Array.isArray(r.data))throw new HueError('protocol','Invalid inventory response.');
  const [rooms,zones,raw,ds]=result.map(r=>r.data),devices=new Map(ds.map(d=>[d.id,d]));
  const ls=raw.filter(l=>typeof l?.id==='string'&&typeof l.on?.on==='boolean');
  const labels=new Map();for(const l of ls){const d=devices.get(l.owner?.rid),n=l.metadata?.name||d?.metadata?.name||'Light '+l.id.slice(0,6);labels.set(n,(labels.get(n)||0)+1);}
  const lights=ls.map(l=>{const d=devices.get(l.owner?.rid),name=l.metadata?.name||d?.metadata?.name||'Light '+l.id.slice(0,6);
    return {...l,label:name+(labels.get(name)>1?' · '+l.id.slice(0,4):''),deviceLabel:d?.metadata?.name||'',model:d?.product_data?.model_id||'',capabilities:capabilities(l)};});
  const groups=rooms.concat(zones).map(g=>{const children=new Set((g.children||[]).map(c=>c.rid));return {id:g.id,type:g.type,name:g.metadata?.name||'Unnamed area',lights:lights.filter(l=>children.has(l.id)||children.has(l.owner?.rid))};}).filter(g=>g.lights.length).sort((a,b)=>a.name.localeCompare(b.name));
  // A local view, never submitted as a real Hue room or scene group.
  if(lights.length)groups.unshift({id:'all-lights',type:'all',name:'All lights',lights});
  return groups;
}
function getGroup(cfg,groups){return groups.find(g=>g.id===cfg.group?.rid&&g.type===cfg.group?.rtype);}
async function selectGroup(cfg,groups){const i=await choose('Choose lighting area','Choose the lights you want to manage. Opening an area does not change them.',groups.map(g=>g.name+' · '+g.lights.length+' lights'));if(i<0)return false;cfg.group={rid:groups[i].id,rtype:groups[i].type};saveConfig(cfg);return true;}

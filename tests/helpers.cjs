const A=require('../dist/testable.cjs');
const clone=v=>JSON.parse(JSON.stringify(v));
const flush=async(n=12)=>{for(let i=0;i<n;i++)await Promise.resolve();};
function light(id='l1',extra={}){return {id,type:'light',label:'Lamp '+id,metadata:{name:'Lamp '+id},owner:{rid:'device-'+id,rtype:'device'},on:{on:true},dimming:{brightness:45,min_dim_level:0.2},color:{xy:{x:.19,y:.25},gamut:{red:{x:.6915,y:.3083},green:{x:.17,y:.7},blue:{x:.1532,y:.0475}}},dynamics:{status:'none',status_values:['none','dynamic_palette']},effects_v2:{action:{effect_values:['no_effect','cosmos','underwater']},status:{effect:'no_effect',effect_values:['no_effect','cosmos','underwater']}},mode:'normal',...extra};}
function env({count=6,latency=0,apiOverride=null,saved={},lightExtras={}}={}) {
  let stamp=100000,id=0,writers=0,maxWriters=0;
  const ls=Array.from({length:count},(_,i)=>light('l'+(i+1),lightExtras));
  const database=new Map(ls.map(l=>[l.id,clone(l)])),store=clone(saved),calls=[],scenes={};
  const cfg={ip:'192.168.1.4',bridgeId:'bridge-test',orders:{}};
  const group={id:'room1',type:'room',name:'Synthetic room',lights:ls};
  const read=(k,f)=>clone(store[k]||f),save=(k,v)=>{store[k]=clone(v);};
  const basic=async(_cfg,method,path,payload)=>{
    calls.push({at:stamp,method,path,payload:clone(payload??null)});
    if(method==='GET'&&path==='entertainment_configuration')return {data:[],errors:[]};
    if(method==='GET'&&path==='light')return {data:clone([...database.values()]),errors:[]};
    if(method==='GET'&&path==='zigbee_connectivity')return {data:ls.map(l=>({id:'c'+l.id,owner:l.owner,status:'connected'})),errors:[]};
    if(path.startsWith('light/')&&method==='PUT'){
      writers++;maxWriters=Math.max(maxWriters,writers);stamp+=latency;const lid=path.slice(6),l=database.get(lid);
      if(!l){writers--;throw new A.HueError('missing','missing',404);}
      for(const [k,v]of Object.entries(payload||{})){if(k==='effects_v2')l.effects_v2={...l.effects_v2,status:{...l.effects_v2.status,effect:v.action.effect,parameters:v.action.parameters}};else if(k==='effects')l.effects={...l.effects,status:v.effect};else if(k!=='dynamics')l[k]=clone(v);}
      if(payload.color||payload.dimming)l.dynamics.status='none';writers--;
      return {data:[{rid:lid,rtype:'light'}],errors:[]};
    }
    if(method==='POST'&&path==='scene'){const rid='scene'+(++id);scenes[rid]={...clone(payload),id:rid};return {data:[{rid,rtype:'scene'}],errors:[]};}
    if(path.startsWith('scene/')){const rid=path.slice(6);if(!scenes[rid])throw new A.HueError('missing','No scene',404);
      if(method==='GET')return {data:[clone(scenes[rid])],errors:[]};
      if(payload.recall)for(const a of scenes[rid].actions){const l=database.get(a.target.rid);Object.assign(l,clone(a.action));l.dynamics={status:'dynamic_palette',status_values:['none','dynamic_palette']};}
      else Object.assign(scenes[rid],clone(payload));return {data:[{rid,rtype:'scene'}],errors:[]};
    }
    throw Error('Unhandled '+method+' '+path);
  };
  const api=apiOverride?((cfg,m,p,v)=>apiOverride(cfg,m,p,v,basic,()=>stamp)):basic;
  const ctl=A.makeController(cfg,group,{now:()=>stamp,api,read,save,uid:()=>`session-${++id}`,sleep:async ms=>{stamp+=ms;}});
  async function step(ms=120){stamp+=ms;ctl.tick();await flush();}
  async function run(ms=15000){const end=stamp+ms;let guard=0;while(stamp<end){await step();if(++guard>20000)throw Error('test runaway');}}
  async function start(){ctl.dispatch('live');await step();await ctl.settled();await step();}
  return {A,ctl,cfg,group,database,store,calls,scenes,read,save,step,run,start,basic,now:()=>stamp,setNow:v=>stamp=v,advance:v=>stamp+=v,maxWriters:()=>maxWriters,writes:()=>calls.filter(c=>c.method==='PUT'&&c.path.startsWith('light/'))};
}
module.exports={A,light,env,flush,clone};

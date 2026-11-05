function makeTelemetryTools() {
  const finite = v => typeof v === 'number' && Number.isFinite(v);
  const clamp = (v,a,b) => Math.max(a,Math.min(b,v));
  function point(v) {
    return v && finite(v.x) && finite(v.y) && v.x>=0 && v.y>0 && v.x+v.y<=1.001
      ? {x:v.x,y:v.y} : null;
  }
  function normalize(light, fetchedAt) {
    const temp=light.color_temperature;
    return {id:light.id, owner:light.owner && light.owner.rid || null, fetchedAt, missing:false,
      on:light.on && typeof light.on.on==='boolean' ? light.on.on : null,
      brightness:light.dimming && finite(light.dimming.brightness) ? clamp(light.dimming.brightness,0,100) : null,
      xy:point(light.color && light.color.xy),
      kelvin:temp && temp.mirek_valid===true && finite(temp.mirek) && temp.mirek>0 ? Math.round(1000000/temp.mirek) : null,
      gradient:((light.gradient && Array.isArray(light.gradient.points)) ? light.gradient.points : []).slice(0,64).map(p=>point(p.color && p.color.xy)).filter(Boolean),
      dynamics:light.dynamics && typeof light.dynamics.status==='string' ? light.dynamics.status : null,
      effect:light.effects_v2 && light.effects_v2.status && typeof light.effects_v2.status.effect==='string' ? light.effects_v2.status.effect : light.effects && typeof light.effects.status==='string' ? light.effects.status : null,
      mode:typeof light.mode==='string' ? light.mode : null};
  }
  function xyCSS(p) {
    p=point(p); if(!p)return '#8a99a5';
    const X=p.x/p.y, Y=1, Z=(1-p.x-p.y)/p.y;
    let rgb=[3.2406*X-1.5372*Y-0.4986*Z,-0.9689*X+1.8758*Y+0.0415*Z,0.0557*X-0.2040*Y+1.0570*Z].map(v=>Math.max(0,v));
    const scale=Math.max(1,...rgb); rgb=rgb.map(v=>v/scale);
    const channel=v=>Math.round(255*clamp(v<=0.0031308?12.92*v:1.055*Math.pow(v,1/2.4)-0.055,0,1));
    return 'rgb('+rgb.map(channel).join(',')+')';
  }
  function age(stamp, now) {return finite(stamp) ? Math.max(0,(now-stamp)/1000) : null;}
  function ageText(stamp, now) {const a=age(stamp,now);return a===null?'not read':Math.floor(a)+'s ago';}
  function connection(entry, now) {
    if(!entry || !finite(entry.fetchedAt) || age(entry.fetchedAt,now)>30)return 'link unknown';
    const labels={connected:'link connected',disconnected:'link disconnected',connectivity_issue:'link issue',unidirectional_incoming:'one-way link',pending_discovery:'discovery pending'};
    return labels[entry.status] || 'link unknown';
  }
  function stateText(row) {
    if(!row)return 'No Bridge read yet';
    if(row.missing)return 'Missing from latest Bridge response';
    const bits=[row.on===true?'On':row.on===false?'Off':'Power unknown'];
    if(finite(row.brightness))bits.push(Math.round(row.brightness)+'%'+(row.on===false?' stored':' brightness'));
    if(row.kelvin)bits.push(row.kelvin+' K');
    else if(row.xy)bits.push('xy '+row.xy.x.toFixed(3)+', '+row.xy.y.toFixed(3));
    if(row.gradient && row.gradient.length)bits.push(row.gradient.length+' gradient points');
    if(row.dynamics && row.dynamics!=='none')bits.push(row.dynamics);
    if(row.effect && row.effect!=='no_effect')bits.push(row.effect);
    if(row.mode==='streaming')bits.push('streaming');
    return bits.join(' · ');
  }
  function targetText(target, now) {
    if(!target)return 'No target sent this session';
    if(target.kind==='native')return 'Native palette recall accepted '+ageText(target.acceptedAt,now)+'; no single color target';
    const a=target.action || {}, bits=[target.kind==='restore'?'Restore accepted':'Target accepted',ageText(target.acceptedAt,now)];
    if(a.on && typeof a.on.on==='boolean')bits.push(a.on.on?'On':'Off');
    if(a.dimming && finite(a.dimming.brightness))bits.push(Math.round(a.dimming.brightness)+'%');
    if(a.color && point(a.color.xy))bits.push('xy '+a.color.xy.x.toFixed(3)+', '+a.color.xy.y.toFixed(3));
    if(a.gradient && Array.isArray(a.gradient.points))bits.push(a.gradient.points.length+' gradient points');
    return bits.join(' · ');
  }
  function summary(telem, now) {
    if(!telem)return 'Waiting for the first Bridge read';
    let text=telem.lastRead==null?'Waiting for the first Bridge read':'Bridge read '+ageText(telem.lastRead,now);
    if(telem.lastRead!=null && age(telem.lastRead,now)>6)text+=' · STALE';
    if(telem.error)text+=' · '+telem.error;
    return text;
  }
  function color(row) {
    if(!row || row.missing || row.on!==true)return '#273442';
    // White-temperature mode is labeled numerically, not painted as a false calibrated tint.
    if(row.kelvin)return '#d8dde1';
    return xyCSS(row.gradient && row.gradient.length ? row.gradient[0] : row.xy);
  }
  return {normalize,point,xyCSS,age,ageText,connection,stateText,targetText,summary,color};
}
const TELEMETRY=makeTelemetryTools();

function makeTelemetryMonitor(cfg, lights, request=endpoint, now=()=>Date.now(), onData=()=>{}) {
  const ids=new Set(lights.map(l=>l.id));
  const model={revision:0,lastRead:null,latencyMs:null,error:'',connectivityError:'',readCount:0,data:{},links:{},targets:{}};
  let closed=false, pending=false, nextLights=0, nextLinks=0, lightFailures=0, linkFailures=0;
  function noteAccepted(id, action, kind='live') {
    if(closed || !ids.has(id))return;
    model.targets[id]={acceptedAt:now(),kind,action:kind==='native'?null:JSON.parse(JSON.stringify(action))};model.revision++;
  }
  function tick() {
    if(closed || pending)return;
    const stamp=now(), kind=stamp>=nextLights?'light':stamp>=nextLinks?'zigbee_connectivity':null;
    if(!kind)return;
    pending=true;
    // At most one read in flight. This promise never blocks the UI or write loop.
    Promise.resolve().then(()=>request(cfg,'GET',kind)).then(result=>{
      if(closed)return;
      if(!result || !Array.isArray(result.data))throw new Error('Malformed telemetry response');
      const finished=now();
      if(kind==='light') {
        const returned=new Set();
        for(const light of result.data)if(light && ids.has(light.id)) {
          model.data[light.id]=TELEMETRY.normalize(light,finished);returned.add(light.id);
        }
        for(const id of ids)if(!returned.has(id))model.data[id]={...(model.data[id]||{id,fetchedAt:null}),missing:true};
        onData(result.data.filter(l=>l && ids.has(l.id)),finished,stamp);
        model.lastRead=finished;model.latencyMs=Math.max(0,finished-stamp);model.error='';model.readCount++;
        lightFailures=0;nextLights=finished+2000;
      } else {
        const links={};
        for(const link of result.data)if(link && link.owner && typeof link.owner.rid==='string' && typeof link.status==='string')
          links[link.owner.rid]={status:link.status,fetchedAt:finished};
        model.links=links;model.connectivityError='';linkFailures=0;nextLinks=finished+10000;
      }
      model.revision++;
    }).catch(error=>{
      if(closed)return;
      const message=String(error && error.message || error).slice(0,220);
      if(kind==='light') {model.error=message;lightFailures++;nextLights=now()+Math.min(30000,2000*Math.pow(2,Math.min(lightFailures,4)));}
      else {model.connectivityError=message;linkFailures++;nextLinks=now()+Math.min(60000,10000*Math.pow(2,Math.min(linkFailures,3)));}
      model.revision++;
    }).finally(()=>{pending=false;});
  }
  function noteReply(id,action,kind,reply,expectedRid=id) {
    if(reply && Array.isArray(reply.data) && reply.data.some(item=>item && item.rid===expectedRid))noteAccepted(id,action,kind);
  }
  return {tick,noteAccepted,noteReply,snapshot:()=>model,stop:()=>{closed=true;},isPending:()=>pending};
}


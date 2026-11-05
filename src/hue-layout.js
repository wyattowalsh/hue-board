/** Read-only import of saved Hue Entertainment placement. No streaming or layout writes.
 * Resource identity is explicit: entertainment.renderer_reference -> light.
 * Unique device ownership is a fallback; names, collection order and channel IDs are not.
 */
function huePosition(value) {
  if(!value || !['x','y','z'].every(k=>finite(value[k])&&value[k]>=-1&&value[k]<=1))return null;
  return {x:value.x,y:value.y,z:value.z};
}
function hueMean(points) {
  if(!points.length)return null;
  return {x:points.reduce((n,p)=>n+p.x,0)/points.length,y:points.reduce((n,p)=>n+p.y,0)/points.length,z:points.reduce((n,p)=>n+p.z,0)/points.length};
}
function hueProjection(p,projection='xy',mirror=false) {
  // The SVG map is 312 x 198 units. A single scale keeps both axes isotropic.
  const u=projection==='yz'?p.y:p.x,v=projection==='xy'?p.y:p.z;
  return {x:.5+(mirror?-1:1)*u*88/312,y:.5-v*88/198};
}
function huePhase(p,mode='clockwise') {
  if(['x','y','z'].includes(mode))return (p[mode]+1)/2;
  if(Math.hypot(p.x,p.y)<1e-7)return null; // A centre point has no angular bearing.
  return ((Math.atan2(p.x,p.y)/(2*Math.PI))%1+1)%1;
}
function cleanHuePlacement(raw) {
  if(!raw||typeof raw.areaId!=='string'||!huePosition(raw.position))return null;
  const channels=Array.isArray(raw.channels)?raw.channels.slice(0,256).filter(c=>huePosition(c.position)&&Number.isInteger(c.index)&&c.index>=0).map(c=>({channelId:Number.isInteger(c.channelId)?c.channelId:null,index:c.index,position:huePosition(c.position),shared:c.shared===true})):[];
  return {areaId:raw.areaId.slice(0,128),areaName:String(raw.areaName||'Hue area').slice(0,160),serviceId:String(raw.serviceId||'').slice(0,128),
    source:raw.source==='channel_average'?'channel_average':'service_locations',matchedBy:String(raw.matchedBy||'').slice(0,64),position:huePosition(raw.position),
    positions:(Array.isArray(raw.positions)?raw.positions:[]).slice(0,256).map(huePosition).filter(Boolean),channels,
    equalizationFactor:finite(raw.equalizationFactor)?raw.equalizationFactor:null,fetchedAt:finite(raw.fetchedAt)?raw.fetchedAt:null,
    importedAt:finite(raw.importedAt)?raw.importedAt:null,projection:['xy','xz','yz'].includes(raw.projection)?raw.projection:'xy',mirror:raw.mirror===true,
    phaseMode:['keep','clockwise','x','y','z'].includes(raw.phaseMode)?raw.phaseMode:'keep',
    applied:raw.applied&&['x','y','q'].every(k=>finite(raw.applied[k]))?{x:raw.applied.x,y:raw.applied.y,q:raw.applied.q}:null};
}
function cleanHueLayoutMeta(raw) {
  if(!raw||typeof raw.areaId!=='string')return null;
  return {areaId:raw.areaId.slice(0,128),areaName:String(raw.areaName||'Hue area').slice(0,160),
    projection:['xy','xz','yz'].includes(raw.projection)?raw.projection:'xy',mirror:raw.mirror===true,
    phaseMode:['keep','clockwise','x','y','z'].includes(raw.phaseMode)?raw.phaseMode:'keep',
    fetchedAt:finite(raw.fetchedAt)?raw.fetchedAt:null,importedAt:finite(raw.importedAt)?raw.importedAt:null};
}
function huePlacementText(p) {
  const h=p?.hue;if(!h)return 'Local placement; no Hue coordinates imported.';
  const xyz=h.position,changed=h.applied&&(Math.abs(p.x-h.applied.x)>1e-6||Math.abs(p.y-h.applied.y)>1e-6||Math.abs(p.q-h.applied.q)>1e-6);
  return 'Hue: '+h.areaName+' · XYZ '+[xyz.x,xyz.y,xyz.z].map(n=>n.toFixed(2)).join(', ')+
    ' · '+(h.source==='channel_average'?'channel-average fallback':'saved service geometry')+
    (h.channels.length?' · '+h.channels.length+' channel segment(s)':'')+(changed?' · local placement/path edited':'');
}
function buildHueLayoutCatalog(configurations,entertainments,devices,allLights,scopeLights,fetchedAt=Date.now()) {
  const lightMap=new Map(allLights.filter(l=>typeof l?.id==='string').map(l=>[l.id,l]));
  const scope=new Set(scopeLights.map(l=>l.id)),serviceMap=new Map(entertainments.filter(e=>typeof e?.id==='string').map(e=>[e.id,e]));
  const deviceList=devices.filter(d=>typeof d?.id==='string');
  function resolve(ref,area) {
    if(!ref||typeof ref.rid!=='string')return {error:'Missing service reference'};
    if(ref.rtype==='light')return lightMap.has(ref.rid)?{id:ref.rid,matchedBy:'direct_light'}:{error:'Referenced light is missing'};
    if(ref.rtype!=='entertainment')return {error:'Unsupported reference type: '+String(ref.rtype)};
    const service=serviceMap.get(ref.rid),renderer=service?.renderer_reference;
    if(renderer){
      if(renderer.rtype==='light'&&lightMap.has(renderer.rid))return {id:renderer.rid,matchedBy:'renderer_reference'};
      return {error:'Renderer reference is invalid or its light is missing'}; // Never guess around a broken explicit link.
    }
    const owners=new Set();
    if(service?.owner?.rtype==='device'&&service.owner.rid)owners.add(service.owner.rid);
    for(const d of deviceList)if((d.services||[]).some(r=>r.rtype==='entertainment'&&r.rid===ref.rid))owners.add(d.id);
    if(owners.size!==1)return {error:owners.size?'Conflicting service owners':'No entertainment-to-device link'};
    const owner=[...owners][0],candidateIds=new Set();
    for(const l of lightMap.values())if(l.owner?.rtype==='device'&&l.owner.rid===owner)candidateIds.add(l.id);
    const device=deviceList.find(d=>d.id===owner);
    for(const r of device?.services||[])if(r.rtype==='light'&&lightMap.has(r.rid))candidateIds.add(r.rid);
    if(candidateIds.size!==1)return {error:candidateIds.size?'Ambiguous device with multiple light services':'Owner has no matching light service'};
    return {id:[...candidateIds][0],matchedBy:'unique_device_owner'};
  }
  return configurations.filter(a=>typeof a?.id==='string').map(area=>{
    const warnings=[],services=new Map(),blocked=new Set(),ambiguous=new Set();
    const message=(text)=>{if(warnings.length<80&&!warnings.includes(text))warnings.push(text);};
    const entry=ref=>{
      const key=ref?.rtype+':'+ref?.rid;if(blocked.has(key))return null;
      const resolved=resolve(ref,area);if(resolved.error){message(resolved.error);return null;}
      if(!services.has(key))services.set(key,{lightId:resolved.id,serviceId:ref.rid,matchedBy:resolved.matchedBy,positions:[],channels:[],equalizationFactor:null});
      return services.get(key);
    };
    for(const loc of area.locations?.service_locations||[]) {
      const e=entry(loc.service);if(!e)continue;
      const source=Array.isArray(loc.positions)&&loc.positions.length?loc.positions:loc.position?[loc.position]:[];
      const valid=source.map(huePosition);
      if(!valid.length||valid.some(p=>!p)||valid.length>256){message('Invalid/missing saved service coordinates; no replacement coordinates invented.');continue;}
      if(e.positions.length&&JSON.stringify(e.positions)!==JSON.stringify(valid)){
        blocked.add(loc.service.rtype+':'+loc.service.rid);services.delete(loc.service.rtype+':'+loc.service.rid);ambiguous.add(e.lightId);message('Conflicting service locations were skipped.');continue;
      }
      e.positions=valid;e.equalizationFactor=finite(loc.equalization_factor)?loc.equalization_factor:null;
    }
    for(const ch of area.channels||[]) {
      const position=huePosition(ch.position);if(!position){message('Invalid channel coordinates were skipped.');continue;}
      for(const member of ch.members||[]){const e=entry(member.service);if(!e)continue;
        if(!Number.isInteger(member.index)||member.index<0){message('A channel member has no valid segment index; skipped.');continue;}
        const old=e.channels.find(c=>c.index===member.index);
        if(old&&JSON.stringify(old.position)!==JSON.stringify(position)){ambiguous.add(e.lightId);message('Conflicting channel positions for the same segment were skipped.');continue;}
        if(!old)e.channels.push({channelId:Number.isInteger(ch.channel_id)?ch.channel_id:null,index:member.index,position,shared:ch.members.length>1});
      }
    }
    const mapped=new Map();
    for(const e of services.values()) {
      e.channels.sort((a,b)=>a.index-b.index);
      const base=e.positions.length?e.positions:e.channels.map(c=>c.position);if(!base.length)continue;
      if(!e.positions.length)message('Some placements use channel averages, not individual service geometry.');
      if(e.channels.some(c=>c.shared))message('Shared channel coordinates are member averages; kept separate from service geometry.');
      if(e.matchedBy==='unique_device_owner')message('Some mappings use a unique device-owner fallback; no name/order matching.');
      const record={...e,position:hueMean(base),source:e.positions.length?'service_locations':'channel_average'};
      if(mapped.has(e.lightId)){ambiguous.add(e.lightId);message('More than one entertainment service maps to a light; that light was skipped.');}
      else mapped.set(e.lightId,record);
    }
    for(const id of ambiguous)mapped.delete(id);
    const records=[...mapped.values()].filter(e=>scope.has(e.lightId));
    const unmatched=scopeLights.filter(l=>!mapped.has(l.id)).map(l=>({id:l.id,name:l.label||l.metadata?.name||l.id}));
    return {id:area.id,name:String(area.metadata?.name||area.name||'Unnamed Entertainment area').slice(0,160),
      type:String(area.configuration_type||'other'),active:area.status==='active',fetchedAt,
      records,matched:records.length,total:scopeLights.length,unmatched,outside:[...mapped.keys()].filter(id=>!scope.has(id)).length,
      warnings,channelCount:(area.channels||[]).length};
  }).sort((a,b)=>b.matched-a.matched||a.name.localeCompare(b.name));
}
async function fetchHueLayoutCatalog(cfg,scopeLights,request=endpoint,now=()=>Date.now(),cancelled=()=>false) {
  const get=async type=>{if(cancelled())throw new HueError('cancelled','Layout read cancelled.');
    const reply=await request(cfg,'GET',type);if(cancelled())throw new HueError('cancelled','Layout read cancelled.');
    if(!Array.isArray(reply?.data))throw new HueError('protocol','Invalid '+type+' layout response.');return reply.data;};
  const configurations=await get('entertainment_configuration');if(!configurations.length)return [];
  let services=[];try{services=await get('entertainment');}catch(e){if(e.status!==404)throw e;}
  const devices=await get('device'),lights=await get('light');
  return buildHueLayoutCatalog(configurations,services,devices,lights,scopeLights,now());
}
function applyHueLayout(current,lights,area,options={},at=Date.now()) {
  if(!area?.records?.length)throw new HueError('layout','No unambiguous positions in this Entertainment area match the current room.');
  const layout=cleanLayout(current,lights),projection=['xy','xz','yz'].includes(options.projection)?options.projection:'xy';
  const phaseMode=['keep','clockwise','x','y','z'].includes(options.phaseMode)?options.phaseMode:'clockwise',mirror=options.mirror===true;
  for(const r of area.records) {
    if(!layout.placements[r.lightId]||!huePosition(r.position))continue;
    const p=layout.placements[r.lightId],xy=hueProjection(r.position,projection,mirror),phase=phaseMode==='keep'?null:huePhase(r.position,phaseMode);
    p.x=xy.x;p.y=xy.y;if(phase!==null)p.q=phase;
    p.hue=cleanHuePlacement({areaId:area.id,areaName:area.name,serviceId:r.serviceId,source:r.source,matchedBy:r.matchedBy,
      position:r.position,positions:r.positions,channels:r.channels,equalizationFactor:r.equalizationFactor,
      fetchedAt:area.fetchedAt,importedAt:at,projection,phaseMode,mirror,applied:{x:p.x,y:p.y,q:p.q}});
  }
  layout.hue=cleanHueLayoutMeta({areaId:area.id,areaName:area.name,projection,mirror,phaseMode,fetchedAt:area.fetchedAt,importedAt:at});
  return layout;
}

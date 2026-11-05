/** One active writer across area switches. Physical limits are shared across overlapping rooms/zones. */
function makeWorkspaceController(cfg, groups, initialGroup, options={}) {
  const read=options.read||readObject,save=options.save||writeObject;
  const factory=options.factory||((g)=>makeController(cfg,g,options));
  const limitKey='boyzexe.hue.fixtureLimits.v5',bridge=cfg.bridgeId||cfg.ip;
  const limits=read(limitKey,{});limits[bridge]=limits[bridge]||{};
  // Conservative one-time migration. Never silently lifts an old ceiling or resets a trim.
  for(const [key,value]of Object.entries(read(V3_STORE,{}))){if(!key.startsWith(bridge+'/'))continue;
    for(const [id,p]of Object.entries(value?.layout?.placements||{})){
      if(!finite(p.ceiling)||!finite(p.trim))continue;
      const existing=limits[bridge][id];if(!existing)limits[bridge][id]={ceiling:clamp(p.ceiling,5,100),trim:clamp(p.trim,.1,1),migrated:true};
      else if(existing.migrated===true){existing.ceiling=Math.min(existing.ceiling,clamp(p.ceiling,5,100));existing.trim=Math.min(existing.trim,clamp(p.trim,.1,1));}
    }
  }
  // Seal migration: future old versions must not silently re-lower an explicitly changed limit.
  for(const p of Object.values(limits[bridge]))delete p.migrated;
  save(limitKey,limits);
  const key=g=>g.type+'/'+g.id;
  let group=initialGroup,ctl,closed=false,switchJob=null,switchError='';
  function create(g){const next=factory(g),s=next.state(),layout=clone(s.layout);
    for(const id of layout.order){const limit=limits[bridge][id];if(limit)Object.assign(layout.placements[id],limit);else limits[bridge][id]={ceiling:layout.placements[id].ceiling,trim:layout.placements[id].trim};}
    next.update({layout});save(limitKey,limits);return next;}
  ctl=create(group);
  function state(){return {...ctl.state(),meta:{...ctl.meta,scopeId:key(group),type:group.type},navigation:{current:key(group),switching:!!switchJob,error:switchError,areas:groups.map(g=>({id:key(g),name:g.name,type:g.type,count:g.lights.length}))}};}
  function update(packet){if(closed||switchJob)return;
    const before=ctl.state().layout;ctl.update(packet);const after=ctl.state().layout;
    let changed=false;for(const id of after.order){const p=after.placements[id],b=before.placements[id];if(!b||p.ceiling!==b.ceiling||p.trim!==b.trim){limits[bridge][id]={ceiling:p.ceiling,trim:p.trim};changed=true;}}
    if(changed)save(limitKey,limits);
  }
  function dispatch(name,payload){if(closed)return;
    if(name!=='switchArea'){if(!switchJob)ctl.dispatch(name,payload);else if(name==='pause')ctl.dispatch(name);return;}
    if(switchJob)return;
    const next=groups.find(g=>key(g)===payload);if(!next){switchError='That area is no longer available. Refresh inventory from the main menu.';return;}
    if(next===group)return;switchError='';const old=group;
    ctl.dispatch('pause');
    switchJob=(async()=>{await ctl.close();if(closed)return;
      try{const replacement=create(next);ctl=replacement;group=next;cfg.group={rid:group.id,rtype:group.type};if(options.saveConfig)options.saveConfig(cfg);else saveConfig(cfg);}
      catch(e){switchError=shortError(e);if(!closed){ctl=create(old);group=old;}}
    })().finally(()=>{switchJob=null;});
  }
  return {get meta(){return {...ctl.meta,scopeId:key(group),type:group.type};},state,update,dispatch,
    tick(hidden){if(!closed&&!switchJob)ctl.tick(hidden);},diagnostics:()=>ctl.diagnostics(),
    async close(){closed=true;if(switchJob)await switchJob;await ctl.close();},
    async settled(){if(switchJob)await switchJob;await ctl.settled();},_controller:()=>ctl};
}

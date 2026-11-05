const {A,env,light,clone,flush}=require('./helpers.cjs');
function everyday(){
 const e=env({count:6});e.setNow(Date.now());
 const temp={mirek:333,mirek_valid:true,mirek_schema:{mirek_minimum:153,mirek_maximum:500}};
 const fixtures=[
  light('l1',{label:'Sofa glow',color_temperature:clone(temp)}),
  light('l2',{label:'Reading lamp',color:undefined,color_temperature:clone(temp),on:{on:false},dimming:{brightness:35,min_dim_level:1}}),
  light('l3',{label:'Ceiling wash',color:undefined,on:{on:true},dimming:{brightness:70,min_dim_level:2}}),
  {id:'l4',type:'light',label:'Accent plug',metadata:{name:'Accent plug'},owner:{rid:'device-l4',rtype:'device'},mode:'normal',on:{on:false}},
  light('l5',{label:'Shelf gradient',gradient:{points_capable:5,points:[{color:{xy:{x:.15,y:.25}}},{color:{xy:{x:.25,y:.45}}}],mode_values:['interpolated_palette']}}),
  light('l6',{label:'Office light',color_temperature:clone(temp)})
 ];
 e.database.clear();for(const l of fixtures){l.metadata={name:l.label};e.database.set(l.id,clone(l));}
 const groups=[{id:'all-lights',type:'all',name:'All lights',lights:fixtures},
 {id:'room1',type:'room',name:'Living room',lights:fixtures.slice(0,5)},
 {id:'office',type:'room',name:'Office',lights:fixtures.slice(5)},
 {id:'reading',type:'zone',name:'Reading corner',lights:[fixtures[1],fixtures[3]]}];
 const group=groups[1],layout=A.cleanLayout({},group.lights);layout.placements.l1.ceiling=85;layout.placements.l2.trim=.75;layout.selected=['l1','l2','l3','l5'];
 e.store['boyzexe.hue.cyberdeck.v3']={'bridge-test/room/room1':{settings:A.ENGINE.clean({brightness:70}),layout,ui:{theme:'system',motion:'system',favorites:[]}}};
 const savedScenes=[{id:'saved-cozy',metadata:{name:'Evening unwind'},group:{rid:'room1',rtype:'room'},actions:[{target:{rid:'l1',rtype:'light'},action:{on:{on:true},dimming:{brightness:40},color_temperature:{mirek:400}}},{target:{rid:'l3',rtype:'light'},action:{on:{on:false}}}]},
 {id:'saved-office',metadata:{name:'Office focus'},group:{rid:'office',rtype:'room'},actions:[{target:{rid:'l6',rtype:'light'},action:{on:{on:true},dimming:{brightness:80}}}]}];
 const api=async(c,m,p,v)=>{
  if(m==='GET'&&p==='scene'){e.calls.push({at:e.now(),method:m,path:p,payload:null});return {data:clone(savedScenes),errors:[]};}
  if(m==='GET'&&p.startsWith('scene/saved-')){e.calls.push({at:e.now(),method:m,path:p,payload:null});return {data:clone(savedScenes.filter(s=>s.id===p.slice(6))),errors:[]};}
  const old=p.startsWith('light/')?clone(e.database.get(p.slice(6))):null;
  const result=await e.basic(c,m,p,v);
  if(old&&m==='PUT'){const l=e.database.get(old.id);if(v.dimming)l.dimming={...old.dimming,...v.dimming};if(v.color)l.color={...old.color,...v.color};if(v.color_temperature)l.color_temperature={...old.color_temperature,...v.color_temperature,mirek_valid:true};if(v.gradient)l.gradient={...old.gradient,...v.gradient};if(v.color)l.color_temperature&&(l.color_temperature.mirek_valid=false);}
  return result;
 };
 const w=A.makeWorkspaceController(e.cfg,groups,group,{now:e.now,api,read:e.read,save:e.save,uid:()=>`daily-${e.now()}`,sleep:async ms=>e.advance(ms),saveConfig:()=>{},autoDiscover:false});
 async function tick(ms=120){e.advance(ms);w.tick(false);await flush(30);}
 async function run(ms){const end=e.now()+ms;while(e.now()<end)await tick();}
 return {e,w,fixtures,groups,tick,run,async close(){await w.close();await e.ctl.close();}};
}
module.exports={everyday};

const fs=require('node:fs'),path=require('node:path');
const {A,env}=require('./helpers.cjs');
(async()=>{
 const e=env({count:6});const names=['Sofa left','Sofa right','Window wash','Shelf gradient','Desk lamp','Corner uplight'];
 e.group.name='Midweek / synthetic test room';
 e.group.lights.forEach((l,i)=>{l.label=names[i];l.metadata.name=names[i];if(i===3){l.gradient={points_capable:5,points:[{color:{xy:{x:.18,y:.2}}},{color:{xy:{x:.3,y:.5}}}],mode_values:['interpolated_palette']};}});
 const store={};const ctl=A.makeController(e.cfg,e.group,{now:()=>Date.now(),api:e.basic,read:(k,f)=>store[k]||f,save:(k,v)=>store[k]=v,uid:()=> 'synthetic-session'});
 let state=ctl.state();const now=Date.now();state.telemetry.lastRead=now;state.telemetry.revision=1;state.telemetry.data={};state.telemetry.links={};
 for(const [i,l]of e.group.lights.entries()){const sample=A.ENGINE.sample(18,i/6,state.settings);const xy=A.ENGINE.xy(sample.rgb,l.color.gamut);state.telemetry.data[l.id]={id:l.id,owner:l.owner.rid,fetchedAt:now,missing:false,on:i!==4,brightness:sample.b,xy,gradient:i===3?[{x:.18,y:.2},{x:.24,y:.4},{x:.4,y:.45}]:[],dynamics:'none',effect:'no_effect',mode:'normal'};state.telemetry.links[l.owner.rid]={fetchedAt:now,status:'connected'};state.design[l.id]=sample;}
 const out=path.join(__dirname,'../qa');fs.mkdirSync(out,{recursive:true});
 fs.writeFileSync(path.join(out,'demo.html'),A.buildPage(ctl.meta,state));fs.writeFileSync(path.join(out,'state.json'),JSON.stringify(state));fs.writeFileSync(path.join(out,'meta.json'),JSON.stringify(ctl.meta));
 await ctl.close();await e.ctl.close();console.log('Demo uses synthetic fixtures only.');
})();

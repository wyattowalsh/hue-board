const fs=require('node:fs'),path=require('node:path');
const {A,light,clone}=require('./helpers.cjs');
const root=path.join(__dirname,'../qa');
const before=JSON.parse(fs.readFileSync(path.join(root,'state.json'),'utf8'));
const meta=JSON.parse(fs.readFileSync(path.join(root,'meta.json'),'utf8'));
const ls=meta.lights.map(l=>light(l.id,{label:l.name}));ls.push(light('outside',{label:'Outside current room / synthetic'}));
const defs=[['l1',[[-.72,-.55,0]]],['l2',[[.7,-.55,0]]],['l3',[[-.85,.45,.5]]],['l4',[[-.75,.9,.6],[.75,.9,.6]]],['l6',[[.9,.6,-.6]]],['outside',[[0,-1,-1]]]];
const xyz=a=>({x:a[0],y:a[1],z:a[2]}),ref=id=>({rid:'ent-'+id,rtype:'entertainment'});
const services=defs.map(([id])=>({id:'ent-'+id,owner:{rid:'device-'+id,rtype:'device'},renderer_reference:{rid:id,rtype:'light'}}));
const devices=defs.map(([id])=>({id:'device-'+id,services:[ref(id),{rid:id,rtype:'light'}]}));
const area={id:'demo-hue-area',metadata:{name:'Lounge / synthetic Hue area'},configuration_type:'screen',status:'inactive',locations:{service_locations:defs.map(([id,ps])=>({service:ref(id),positions:ps.map(xyz)}))},channels:[]};
for(const [id,ps]of defs){const n=id==='l4'?7:1;for(let i=0;i<n;i++){const t=n===1?0:i/(n-1);const p=ps[0].map((v,j)=>v+((ps.at(-1)[j])-v)*t);area.channels.push({channel_id:area.channels.length,position:xyz(p),members:[{service:ref(id),index:i}]});}}
const c=A.buildHueLayoutCatalog([area],services,devices,ls,ls.slice(0,6),Date.now())[0];
before.hueLayouts={pending:false,error:'',revision:1,fetchedAt:Date.now(),canUndo:false,areas:[{...c,records:undefined,matchedNames:c.records.map(r=>ls.find(l=>l.id===r.lightId).label)}]};
const after=clone(before);after.layout=A.applyHueLayout(before.layout,ls.slice(0,6),c,{phaseMode:'clockwise',projection:'xy'},Date.now());after.mode='paused';after.hueLayouts.canUndo=true;after.note='Imported 5/6 saved placements. Desk lamp is unchanged. No light commands sent.';
fs.writeFileSync(path.join(root,'hue-demo.html'),A.buildPage(meta,before));
fs.writeFileSync(path.join(root,'hue-before.json'),JSON.stringify(before));fs.writeFileSync(path.join(root,'hue-after.json'),JSON.stringify(after));
console.log('Generated synthetic saved-Hue-layout fixture, with one unmatched lamp.');

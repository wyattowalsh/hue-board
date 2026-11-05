const {A,light}=require('./helpers.cjs');
function fixture(){
  const lights=[light('l1'),light('l2'),light('l3'),light('outside')];
  const ref=id=>({rid:id,rtype:'entertainment'});
  const services=lights.map(l=>({id:'e-'+l.id,owner:l.owner,renderer_reference:{rid:l.id,rtype:'light'}}));
  const devices=lights.map(l=>({id:l.owner.rid,services:[{rid:l.id,rtype:'light'},ref('e-'+l.id)]}));
  const area={id:'area1',metadata:{name:'TV / test area'},configuration_type:'screen',status:'inactive',
    locations:{service_locations:[
      {service:ref('e-l1'),positions:[{x:-.8,y:.9,z:.2}],equalization_factor:.6},
      {service:ref('e-l2'),positions:[{x:.8,y:.9,z:.2}]},
      {service:ref('e-l3'),positions:[{x:-.9,y:.8,z:.7},{x:.9,y:.8,z:.7}]},
      {service:ref('e-outside'),positions:[{x:0,y:-1,z:-1}]}
    ]},channels:services.slice(0,2).map((e,i)=>({channel_id:20-i,position:{x:i?.8:-.8,y:.9,z:.2},members:[{service:ref(e.id),index:0}]}))};
  for(let i=6;i>=0;i--)area.channels.push({channel_id:30+i,position:{x:-.9+i*.3,y:.8,z:.7},members:[{service:ref('e-l3'),index:i}]});
  return {lights,services,devices,area,scope:lights.slice(0,3)};
}
function catalog(f=fixture(),scope=f.scope){return A.buildHueLayoutCatalog([f.area],f.services,f.devices,f.lights,scope,12345)[0];}
module.exports={fixture,catalog};

/** Explicit everyday light intents. Never trusts browser-supplied Hue payloads. */
function validateManualIntent(raw, allowed) {
  if(!raw||typeof raw!=='object'||!Array.isArray(raw.ids))throw new HueError('validation','Choose at least one light.');
  const ids=[...new Set(raw.ids.filter(id=>typeof id==='string'))];
  if(!ids.length||ids.some(id=>!allowed.has(id)))throw new HueError('selection','One or more lights are outside this area. Nothing was sent.');
  const intent={ids};
  if(raw.on!==undefined){if(typeof raw.on!=='boolean')throw new HueError('validation','Power must be on or off.');intent.on=raw.on;}
  if(raw.brightness!==undefined){if(!finite(raw.brightness)||raw.brightness<.1||raw.brightness>100)throw new HueError('validation','Brightness must be greater than zero and at most 100%. Use Off to switch lights off.');intent.brightness=raw.brightness;}
  if(raw.kelvin!==undefined){if(!finite(raw.kelvin)||raw.kelvin<1000||raw.kelvin>10000)throw new HueError('validation','Invalid white temperature.');intent.kelvin=raw.kelvin;}
  if(raw.hex!==undefined){if(typeof raw.hex!=='string'||!/^#[0-9a-f]{6}$/i.test(raw.hex))throw new HueError('validation','Choose a six-digit color.');intent.hex=raw.hex;}
  if(intent.hex&&intent.kelvin)throw new HueError('validation','Choose color or white temperature, not both.');
  if(Object.keys(intent).length===1)throw new HueError('validation','No lighting change was selected.');
  if(intent.on===false&&Object.keys(intent).length>2)throw new HueError('validation','An Off command must not also change brightness or color.');
  return intent;
}
function manualAction(light, placement, intent) {
  const cap=capabilities(light),p=placement||{ceiling:100,trim:1};
  if(cap.streaming)throw new HueError('ownership','A streaming app owns this light. Stop it there first.');
  // A mixed room must never turn on unrelated switches merely because a white/color preset was used.
  if(intent.kelvin!==undefined&&!cap.temperature)return null;
  if(intent.hex!==undefined&&!cap.color)return null;
  if(intent.brightness!==undefined&&!cap.dimming)return null;
  const action={};
  if(intent.on!==undefined)action.on={on:intent.on};
  if(intent.on===false)return action;
  const ceiling=clamp(p.ceiling,5,100),trim=clamp(p.trim,.1,1);
  const minimum=Math.max(.1,Math.min(100,finite(light.dimming?.min_dim_level)?light.dimming.min_dim_level:.1));
  const bounded=value=>{if(ceiling<minimum)throw new HueError('validation','This light’s ceiling is below its advertised minimum dim level.');return +clamp(value*trim,minimum,ceiling).toFixed(2);};
  // Take a one-time static appearance when turning on, so a delegated effect does not keep fighting the control.
  if(intent.on===true&&cap.dimming){if(ceiling<minimum)throw new HueError('validation','This light’s ceiling is below its advertised minimum dim level.');if(!finite(light.dimming?.brightness)&&intent.brightness===undefined)throw new HueError('protocol','Current brightness is unavailable. Set a brightness explicitly.');action.dimming={brightness:+clamp(finite(light.dimming?.brightness)?light.dimming.brightness:minimum,minimum,ceiling).toFixed(2)};}
  if(intent.brightness!==undefined)action.dimming={brightness:bounded(intent.brightness)};
  if(intent.kelvin!==undefined){
    const sc=light.color_temperature?.mirek_schema;
    if(!sc||!finite(sc.mirek_minimum)||!finite(sc.mirek_maximum)||sc.mirek_minimum<=0||sc.mirek_maximum<sc.mirek_minimum)throw new HueError('unsupported','The Bridge did not advertise a valid white-temperature range.');
    action.color_temperature={mirek:Math.round(clamp(1000000/intent.kelvin,sc.mirek_minimum,sc.mirek_maximum))};
  } else if(intent.hex!==undefined){const rgb=[1,3,5].map(i=>parseInt(intent.hex.slice(i,i+2),16)/255);action.color={xy:ENGINE.xy(rgb,light.color.gamut)};}
  if(cap.dimming)action.dynamics={duration:700};
  return {...action,...stopEffect(light)};
}

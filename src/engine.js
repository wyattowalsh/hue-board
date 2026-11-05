/** Pure deterministic engine. No I/O, platform APIs, clocks or mutable global state. */
function makeEngine() {
  const TAU=2*Math.PI, cap=(v,a,b)=>Math.max(a,Math.min(b,v)), mix=(a,b,t)=>a+(b-a)*t;
  const wrap=x=>((x%1)+1)%1, smooth=x=>{x=cap(x,0,1);return x*x*(3-2*x);};
  const palettes=[
    {name:'Ion storm',colors:['#102cba','#00b9f2','#36e5d1','#a4ed51']},
    {name:'Toxic core',colors:['#10399b','#02bbb8','#80e63c','#fa9228']},
    {name:'Afterburn',colors:['#123da7','#1484e5','#09c9e0','#ff922d']},
    {name:'Void rift',colors:['#1f2b90','#584dc9','#188cc9','#3bdfbd']},
    {name:'Black ice',colors:['#132b66','#1d53a3','#0b9cbc','#4cdad2']},
    {name:'Laser grid',colors:['#2031bf','#04bdd6','#44dc8a','#a8e44d']},
    {name:'Arcade mint',colors:['#142962','#008fa8','#30e5b7','#b8f266']},
    {name:'Solar forge',colors:['#222d6b','#b33b20','#ff7d25','#ffd173']},
    {name:'Pacific',colors:['#10244b','#005f87','#00b5ba','#7ce7d1']},
    {name:'Cobalt chrome',colors:['#172464','#225cf2','#4daff1','#d3ecff']},
    {name:'Acid circuit',colors:['#162a35','#148c68','#78d629','#e5f285']},
    {name:'Lava lamp',colors:['#281d60','#773cbe','#e65932','#ffc85c']},
    {name:'Aurora borealis',colors:['#162953','#197d84','#47d59d','#9b83e6']},
    {name:'Desert dusk',colors:['#343d65','#7b6c96','#c58b66','#e8bc72']},
    {name:'Glacier',colors:['#183b67','#267c9b','#80c9d0','#d8ecf2']},
    {name:'Industrial amber',colors:['#263c45','#566c65','#d69a34','#efd58a']},
    {name:'Ultraviolet',colors:['#212565','#4b40bd','#9254db','#36c6da']},
    {name:'Jungle signal',colors:['#173e3c','#147b54','#55c887','#d8dd4b']},
    {name:'Custom four-color',colors:['#102cba','#00b9f2','#36e5d1','#a4ed51']}
  ];
  const shows=[['director','Director'],['eclipse','Ion Eclipse'],['turbine','Plasma Turbine'],['comet','Afterburner'],['deep','Deep Orbit'],['orbit','Orbit'],['helix','Double helix'],['reactor','Reactor'],['aurora','Aurora'],['prism','Prism'],
    ['wave','Wavefront'],['scanner','Scanner'],['binary','Twin comets'],['ripples','Ripple field'],
    ['pendulum','Pendulum'],['vortex','Vortex'],['breath','Breathing room'],['moire','Moire'],
    ['lattice','Lattice'],['tide','Tidal flow'],['embers','Embers'],['nebula','Nebula'],
    ['ribbons','Ribbons'],['static','Static atmosphere']];
  const defaults={showA:'eclipse',showB:'turbine',paletteA:0,paletteB:1,morph:0,brightness:60,speed:1,depth:75,spread:1.2,energy:65,tension:65,focus:55,reverse:false,gradient:false,seed:731,topology:'ring',transitionMs:4500,ownership:'yield_off',nativeKind:'palette',effect:'',effectSpeed:0.4,effectTint:false,
    saturation:100,ambientFloor:0,accentMix:100,density:1,phaseOffset:0,brightnessCurve:1,
    directorSeconds:52,customColors:['#102cba','#00b9f2','#36e5d1','#a4ed51'],
    sequenceIds:['ion-eclipse','plasma-turbine','deep-orbit'],sequenceHold:90,sequenceOrder:'forward'};
  function clean(raw) {
    const s=raw&&typeof raw==='object'?raw:{};
    const n=(k,a,b)=>typeof s[k]==='number'&&Number.isFinite(s[k])?cap(s[k],a,b):defaults[k];
    const sh=(k,d)=>shows.some(v=>v[0]===s[k])?s[k]:d;
    return {showA:sh('showA',shows.some(v=>v[0]===s.mode)?s.mode:defaults.showA),showB:sh('showB',defaults.showB),
      paletteA:Math.round(typeof s.palette==='number'&&s.paletteA==null?cap(s.palette,0,palettes.length-1):n('paletteA',0,palettes.length-1)),paletteB:Math.round(n('paletteB',0,palettes.length-1)),
      morph:n('morph',0,100),brightness:n('brightness',5,100),speed:n('speed',0.25,1.6),depth:n('depth',0,100),spread:n('spread',0.5,2),energy:n('energy',0,100),tension:n('tension',0,100),focus:n('focus',0,100),
      reverse:s.reverse===true,gradient:s.gradient===true,seed:Math.round(n('seed',0,999999)),topology:s.topology==='path'?'path':'ring',
      transitionMs:n('transitionMs',2500,15000),ownership:['yield_off','hold'].includes(s.ownership)?s.ownership:'yield_off',
      nativeKind:s.nativeKind==='effect'?'effect':'palette',effect:typeof s.effect==='string'?s.effect.slice(0,40):'',effectSpeed:n('effectSpeed',0,1),effectTint:s.effectTint===true,
      saturation:n('saturation',0,100),ambientFloor:n('ambientFloor',0,65),accentMix:n('accentMix',0,100),density:Math.round(n('density',1,4)),phaseOffset:n('phaseOffset',-1,1),brightnessCurve:n('brightnessCurve',.5,2),directorSeconds:n('directorSeconds',30,180),
      customColors:Array.isArray(s.customColors)&&s.customColors.length===4&&s.customColors.every(v=>typeof v==='string'&&/^#[0-9a-f]{6}$/i.test(v))?s.customColors.map(v=>v.toUpperCase()):defaults.customColors.slice(),
      sequenceIds:Array.isArray(s.sequenceIds)?s.sequenceIds.filter(v=>typeof v==='string'&&/^[a-z0-9-]{1,50}$/.test(v)).slice(0,12):defaults.sequenceIds.slice(),
      sequenceHold:n('sequenceHold',30,600),sequenceOrder:s.sequenceOrder==='shuffle'?'shuffle':'forward'};
  }
  function hash(seed,n){let x=(seed^Math.imul(n+1,0x9e3779b9))>>>0;x=Math.imul(x^(x>>>16),0x21f0aaad);x=Math.imul(x^(x>>>15),0x735a2d97);return ((x^(x>>>15))>>>0)/4294967296;}
  const lin=v=>v<=0.04045?v/12.92:((v+0.055)/1.055)**2.4;
  const gamma=v=>v<=0.0031308?12.92*v:1.055*Math.pow(v,1/2.4)-0.055;
  const rgb=hex=>[1,3,5].map(i=>parseInt(hex.slice(i,i+2),16)/255);
  function lab(c){const [r,g,b]=c.map(lin);const l=Math.cbrt(.4122214708*r+.5363325363*g+.0514459929*b),m=Math.cbrt(.2119034982*r+.6806995451*g+.1073969566*b),s=Math.cbrt(.0883024619*r+.2817188376*g+.6299787005*b);return [.2104542553*l+.793617785*m-.0040720468*s,1.9779984951*l-2.428592205*m+.4505937099*s,.0259040371*l+.7827717662*m-.808675766*s];}
  function unlab(c){const [L,a,b]=c,l=(L+.3963377774*a+.2158037573*b)**3,m=(L-.1055613458*a-.0638541728*b)**3,s=(L-.0894841775*a-1.291485548*b)**3;return [4.0767416621*l-3.3077115913*m+.2309699292*s,-1.2684380046*l+2.6097574011*m-.3413193965*s,-.0041960863*l-.7034186147*m+1.707614701*s].map(v=>cap(gamma(Math.max(0,v)),0,1));}
  function blend(a,b,f){f=cap(f,0,1);if(f===0)return {rgb:a.rgb.slice(),b:a.b};if(f===1)return {rgb:b.rgb.slice(),b:b.b};const al=lab(a.rgb),bl=lab(b.rgb);return {rgb:unlab(al.map((v,i)=>mix(v,bl[i],f))),b:mix(a.b,b.b,f)};}
  function colorMix(a,b,f){return blend({rgb:a,b:0},{rgb:b,b:0},f).rgb;}
  const colors=palettes.map(p=>p.colors.map(rgb));
  const getColors=(s,i)=>i===palettes.length-1?s.customColors.map(rgb):colors[i];
  function trail(q,head,dir,topology,width) {
    const behind=dir*(head-q),d=topology==='ring'?wrap(behind):behind;
    return d>=0 ? (1-Math.exp(-d/.035))*Math.exp(-d/width)*(topology==='ring'?1-smooth((d-.65)/.35):1) : 0;
  }
  function wave(kind,t,q,s,palette) {
    const ring=s.topology==='ring';q=ring?wrap(q*s.density+s.phaseOffset):cap(q+s.phaseOffset,0,1);
    const dir=s.reverse?-1:1,phase=hash(s.seed,1)*TAU;
    const travel=dir*t/38+hash(s.seed,2),head=ring?wrap(travel):.5-.5*Math.cos(TAU*travel);
    const tailBlend=ring?(dir>0?1:0):.5+.5*Math.tanh(8*dir*Math.sin(TAU*travel));
    const dist=x=>ring?Math.min(wrap(x),1-wrap(x)):Math.abs(x);
    const width=mix(.27,.09,s.focus/100)/s.spread;
    const crest=Math.exp(-Math.pow(dist(q-head)/width,2));
    const sine=x=>.5+.5*Math.sin(TAU*x);
    const base=getColors(s,palette),e=s.energy/100;
    let motif=crest,accent=0,shift=.1;
    if(kind==='turbine'||kind==='helix'){const a=sine(2*q-dir*t/38),b=sine(3*q+dir*t/51);motif=a*.6+b*.4;shift=.35*b;accent=Math.pow(a*b,2)*.28;}
    else if(kind==='reactor'){motif=sine(2*q-dir*t/18)*.7+sine(q+dir*t/37)*.3;shift=.2;accent=Math.pow(motif,4)*.18;}
    else if(kind==='comet'){const wake=mix(trail(q,head,-1,s.topology,width*1.7),trail(q,head,1,s.topology,width*1.7),tailBlend);motif=cap(crest*.8+wake*.6,0,1);shift=.07;accent=crest;}
    else if(kind==='deep'){const tide=sine(q+t/99)*.35;motif=.2+tide;const cycle=Math.floor(t/130),at=t%130,start=60+hash(s.seed,cycle+100)*25;accent=Math.sin(Math.PI*cap((at-start)/24,0,1))**2*Math.exp(-Math.pow(dist(q-hash(s.seed,cycle+900))/.22,2));shift=.08;}
    else if(kind==='aurora'){motif=.5+.23*Math.sin(TAU*q+Math.sin(t/23)+phase)+.22*Math.sin(TAU*3*q-t/31);shift=.2*sine(q+t/113);}
    else if(kind==='prism'){motif=sine(2*q-dir*t/55);shift=.4*sine(q-dir*t/87);}
    else if(kind==='wave'){motif=sine(q-dir*t/42);shift=.12;accent=Math.pow(motif,5)*.55;}
    else if(kind==='scanner'){const h=.5-.5*Math.cos(t/13);motif=Math.exp(-Math.pow(dist(q-h)/(width*1.25),2));shift=.08;accent=motif*.45;}
    else if(kind==='binary'){const other=ring?wrap(-head+.5):1-head;const second=Math.exp(-Math.pow(dist(q-other)/width,2));motif=Math.max(crest,second*.8);accent=second*.8;shift=.14;}
    else if(kind==='ripples'){motif=Math.pow(sine(3*q-dir*t/39),2)*(.75+.25*sine(q+t/63));shift=.24;accent=Math.pow(motif,3)*.45;}
    else if(kind==='pendulum'){motif=.5+.5*Math.cos(TAU*q+1.8*Math.sin(t/17));shift=.18*sine(t/57);accent=Math.pow(motif,5)*.25;}
    else if(kind==='vortex'){motif=.5+.3*Math.sin(TAU*2*q-dir*t/15)+.2*Math.sin(TAU*q+dir*t/27);shift=.2;accent=Math.pow(cap(motif,0,1),4)*.6;}
    else if(kind==='breath'){motif=sine(t/32);shift=.1+.15*sine(q);accent=.1*sine(t/79);}
    else if(kind==='moire'){const a=sine(3*q-dir*t/47),b=sine(4*q+dir*t/53);motif=(a+b)*.5;shift=.22*b;accent=Math.pow(a*b,2)*.6;}
    else if(kind==='lattice'){motif=sine(4*q)*(.45+.55*sine(t/35))*.75+.25*sine(q-t/69);shift=.25;accent=Math.pow(motif,3)*.55;}
    else if(kind==='tide'){motif=.5+.5*Math.sin(TAU*q+.7*Math.sin(t/43)-dir*t/23);shift=.2*sine(t/89);accent=Math.pow(motif,5)*.3;}
    else if(kind==='embers'){motif=.3+.35*sine(2*q+t/56+hash(s.seed,8))+.15*sine(3*q-t/79);shift=.2;accent=Math.pow(sine(q+t/32+hash(s.seed,7)),4)*.7;}
    else if(kind==='nebula'){motif=.5+.22*Math.sin(TAU*q+Math.sin(t/27))+.2*Math.cos(TAU*2*q+Math.sin(t/41));shift=.25*sine(t/81);accent=Math.pow(sine(3*q+t/57),4)*.25;}
    else if(kind==='ribbons'){motif=sine(2*q-dir*t/44+Math.sin(t/71)*.25);shift=.35*sine(q+t/113);accent=.4*Math.pow(motif,3);}
    else if(kind==='static'){motif=.5+.25*Math.sin(TAU*q);shift=.12;accent=0;}
    else { // Eclipse / Orbit: atmosphere, broad motion, sparse gentle accents.
      const cycle=Math.floor(t/70),at=t%70,start=42+hash(s.seed,cycle+30)*8;
      accent=Math.sin(Math.PI*cap((at-start)/14,0,1))**2*crest*.32;shift=.05;
    }
    const depth=s.depth/100,contrast=mix(.82,.36+.64*cap(motif,0,1),depth);
    let c=colorMix(base[0],base[1],cap(shift+motif*.78,0,1));
    c=colorMix(c,base[2],.12*motif);
    c=colorMix(c,base[3],cap(accent*(.25+.75*s.tension/100)*s.accentMix/100,0,1));
    return {rgb:c,b:s.brightness*(.62+.38*e)*contrast};
  }
  function show(kind,t,q,s,palette){if(kind!=='director')return wave(kind,t,q,s,palette);const acts=['eclipse','turbine','aurora','comet','prism','deep','ripples','nebula'],hold=s.directorSeconds,n=Math.floor(t/hold),at=t%hold;return blend(wave(acts[n%acts.length],t,q,s,palette),wave(acts[(n+1)%acts.length],t,q,s,palette),smooth((at-(hold-10))/10));}
  function sample(t,q,s,surge=0){const a=show(s.showA,t,q,s,s.paletteA),b=show(s.showB,t,q,s,s.paletteB),v=blend(a,b,s.morph/100);v.b=cap(Math.max(s.ambientFloor/100,Math.pow(cap(v.b/s.brightness,0,1),s.brightnessCurve))*s.brightness*(1+.2*cap(surge,0,1)),1,s.brightness);if(s.saturation<100){const L=lab(v.rgb);v.rgb=unlab([L[0],L[1]*s.saturation/100,L[2]*s.saturation/100]);}return v;}
  function clip(p,gamut){if(!gamut?.red||!gamut?.green||!gamut?.blue)return p;const pts=[gamut.red,gamut.green,gamut.blue];const cross=(a,b,c)=>(b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x);if(Math.abs(cross(...pts))<1e-9)return p;const sg=pts.map((v,i)=>cross(v,pts[(i+1)%3],p));if(sg.every(v=>v>=-1e-10)||sg.every(v=>v<=1e-10))return p;const near=pts.map((a,i)=>{const b=pts[(i+1)%3],dx=b.x-a.x,dy=b.y-a.y,d=dx*dx+dy*dy,u=d?cap(((p.x-a.x)*dx+(p.y-a.y)*dy)/d,0,1):0;return {x:a.x+u*dx,y:a.y+u*dy};});return near.sort((a,b)=>(a.x-p.x)**2+(a.y-p.y)**2-(b.x-p.x)**2-(b.y-p.y)**2)[0];}
  function xy(c,gamut){const [r,g,b]=c.map(lin),X=r*.4124564+g*.3575761+b*.1804375,Y=r*.2126729+g*.7151522+b*.072175,Z=r*.0193339+g*.119192+b*.9503041,tot=X+Y+Z;const p=clip(tot>1e-12?{x:X/tot,y:Y/tot}:{x:.3127,y:.329},gamut);return {x:+p.x.toFixed(6),y:+p.y.toFixed(6)};}
  const css=c=>'rgb('+c.map(v=>Math.round(cap(v,0,1)*255)).join(',')+')';
  return {palettes,shows,defaults,clean,sample,blend,xy,css,colors,getColors,wrap,smooth,trail,hash,lab,unlab};
}
const ENGINE=makeEngine();

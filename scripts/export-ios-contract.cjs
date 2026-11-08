'use strict';
const crypto=require('node:crypto');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const {ENGINE,PRESET_LIBRARY}=require(path.join(root,'dist/testable.cjs'));
const pkg=require(path.join(root,'package.json'));
const contract={
  schema:1,
  release:pkg.version,
  defaults:ENGINE.defaults,
  patterns:ENGINE.shows.map(([id,name])=>({id,name})),
  palettes:ENGINE.palettes.map((palette,index)=>({index,name:palette.name,colors:palette.colors.map(c=>c.toUpperCase())})),
  presets:PRESET_LIBRARY.map(p=>({
    id:p.id,name:p.name,category:p.category,description:p.description,
    pattern:p.settings.showA,palette:p.settings.paletteA,
    speed:p.settings.speed,energy:p.settings.energy,depth:p.settings.depth,focus:p.settings.focus
  }))
};
const times=[0,7.25,31.5,83.125],positions=[0,.125,.5,.875];
const fixed=value=>Math.abs(value)<5e-13?'0.000000000000':Number(value).toFixed(12);
const lines=[];const anchors=[];
for(const preset of PRESET_LIBRARY){
  const settings=ENGINE.clean({...ENGINE.defaults,...preset.settings,brightness:72,seed:731,topology:'ring'});
  for(const time of times)for(const position of positions){
    const frame=ENGINE.sample(time,position,settings,0);
    const values=[...frame.rgb,frame.b].map(fixed),index=lines.length;
    lines.push([preset.id,fixed(time),fixed(position),...values].join('|')+'\n');
    if(index<4||index>=PRESET_LIBRARY.length*times.length*positions.length-4)anchors.push({preset:preset.id,time,position,rgb:frame.rgb.map(v=>+v.toFixed(12)),brightness:+frame.b.toFixed(12)});
  }
}
const golden={schema:1,release:pkg.version,algorithm:'sha256',numberFormat:'fixed-12-posix',brightness:72,seed:731,topology:'ring',times,positions,caseCount:lines.length,sha256:crypto.createHash('sha256').update(lines.join(''),'utf8').digest('hex'),anchors};
const out=path.join(root,'ios/Packages/HueBoardKit/Sources/HueBoardKit/Resources');
fs.mkdirSync(out,{recursive:true});
fs.writeFileSync(path.join(out,'hue-board-contract.json'),JSON.stringify(contract,null,2)+'\n');
fs.writeFileSync(path.join(out,'engine-golden.json'),JSON.stringify(golden,null,2)+'\n');
console.log(`Exported iOS contract: ${contract.presets.length} presets, ${contract.patterns.length} patterns, ${golden.caseCount} golden frames, ${golden.sha256}.`);

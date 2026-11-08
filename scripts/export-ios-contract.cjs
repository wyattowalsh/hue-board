'use strict';
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
const golden=[];
for(const preset of PRESET_LIBRARY){
  const settings=ENGINE.clean({...ENGINE.defaults,...preset.settings,brightness:72,seed:731,topology:'ring'});
  for(const time of [0,7.25,31.5,83.125])for(const position of [0,.125,.5,.875]){
    const frame=ENGINE.sample(time,position,settings,0);
    golden.push({preset:preset.id,time,position,rgb:frame.rgb.map(v=>+v.toFixed(12)),brightness:+frame.b.toFixed(12)});
  }
}
const out=path.join(root,'ios/Packages/HueBoardKit/Sources/HueBoardKit/Resources');
fs.mkdirSync(out,{recursive:true});
fs.writeFileSync(path.join(out,'hue-board-contract.json'),JSON.stringify(contract,null,2)+'\n');
fs.writeFileSync(path.join(out,'engine-golden.json'),JSON.stringify({schema:1,release:pkg.version,cases:golden},null,2)+'\n');
console.log(`Exported iOS contract: ${contract.presets.length} presets, ${contract.patterns.length} patterns, ${golden.length} golden frames.`);

/**
 * Hue Board README lighting-console concept rendered by Takumi.
 * Takumi generates SVG from an explicit HTML/CSS layout, with no runtime browser.
 * Run: cd scripts/readme-art && npm install && npm run build
 * Inspect the resulting SVG before committing; this is not an auto-update job.
 */
import {renderSvg} from 'takumi-js';
import {writeFile, mkdir} from 'node:fs/promises';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';

const here=dirname(fileURLToPath(import.meta.url));
const output=resolve(here,'../../assets/readme/hero-takumi.svg');
const lamps=[
  ['#37E1E7',90,155],['#7786FF',225,62],['#CCEF78',400,107],
  ['#FFAE73',460,240],['#35D9BF',305,283],['#A183FE',105,281]
].map(([color,x,y])=>`<div style="position:absolute;left:${x}px;top:${y}px;width:25px;height:25px;border-radius:50%;background:${color};border:2px solid #DEFDFF;box-shadow:0 0 26px ${color};"></div>`).join('');
const html=`<div style="display:flex;flex-direction:row;box-sizing:border-box;width:1600px;height:550px;padding:76px;background:linear-gradient(135deg,#07111F,#0B1726 68%,#10152E);font-family:Arial,sans-serif;color:#F6FBFF;overflow:hidden;">
<div style="display:flex;flex-direction:column;flex:1;min-width:0;padding-top:15px;">
<div style="font-size:19px;font-weight:700;letter-spacing:5px;color:#9EC7D7;margin-bottom:64px;">HUE BOARD / LIGHTING INSTRUMENT</div>
<div style="font-size:82px;font-weight:750;letter-spacing:-3px;line-height:1.08;">Shape the<br/>atmosphere.</div>
<div style="font-size:24px;color:#92B1C4;margin-top:33px;">Everyday control. Cinematic scenes. Your room, reimagined.</div>
<div style="display:flex;flex-direction:row;gap:12px;margin-top:48px;">${['LIGHTS','SCENES','STUDIO'].map(x=>`<span style="padding:12px 24px;border-radius:28px;border:1px solid #426176;background:#122A3C;font-size:16px;font-weight:700;letter-spacing:2px;color:#BDECF6;">${x}</span>`).join('')}</div></div>
<div style="position:relative;width:580px;height:393px;border-radius:30px;background:#0B1C2B;border:2px solid #47657B;overflow:hidden;">
<div style="position:absolute;top:26px;left:32px;font-size:14px;letter-spacing:3px;font-weight:700;color:#8DB2C7;">ROOM PREVIEW / DESIGN</div>
<div style="position:absolute;top:93px;left:48px;width:480px;height:260px;border:2px dashed #31516A;border-radius:50%;"></div>
<div style="position:absolute;top:137px;left:116px;width:350px;height:178px;border:1px solid #264359;border-radius:50%;"></div>
<div style="position:absolute;top:147px;left:155px;width:280px;height:88px;border-radius:18px;background:#102A3A;border:1px solid #3B697B;display:flex;flex-direction:column;align-items:center;justify-content:center;">
<div style="font-size:23px;font-weight:700;letter-spacing:2px;">ION ECLIPSE</div>
<div style="font-size:15px;color:#A3C2D1;margin-top:8px;">Scene preview • illustrative</div></div>
<div style="position:absolute;top:20px;left:17px;width:540px;height:330px;">${lamps}</div>
</div></div>`;
const svg=await renderSvg(html,{width:1600,height:550});
if(!svg.includes('<svg'))throw Error('Takumi returned no SVG output');
await mkdir(dirname(output),{recursive:true});
await writeFile(output,svg,'utf8');
console.log('Takumi SVG rendered:',output);

/**
 * Render the Hue Board README banner with Takumi.
 * Run: cd scripts/readme-art && npm install && npm run build
 */
import { renderSvg } from "takumi-js";
import { writeFile, mkdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { resolve, dirname } from "node:path";
const here = dirname(fileURLToPath(import.meta.url));
const output = resolve(here, "../../assets/readme/hero.svg");
const leds = [
  ["#30D9E3",0,96],["#6E82FF",105,8],["#AAE969",299,19],
  ["#FCA86F",399,105],["#30D9D0",301,237],["#8171FA",105,234],
].map(([color,x,y]) =>
  '<div style="position:absolute;left:'+x+'px;top:'+y+'px;width:35px;height:35px;border-radius:50%;background:'+color+';border:3px solid #D5F7FA;box-shadow:0 0 40px '+color+';"></div>'
).join("");
const html = '<div style="display:flex;flex-direction:row;width:1440px;height:480px;box-sizing:border-box;overflow:hidden;padding:70px 78px;background:linear-gradient(125deg,#0B141C,#081323 68%,#101C2C);color:#F7FCFF;font-family:Arial,sans-serif;">'+
'<div style="display:flex;flex-direction:column;width:655px;">'+
'<div style="display:flex;flex-direction:row;align-items:center;gap:14px;margin-bottom:38px;">'+
'<div style="width:42px;height:42px;border-radius:50%;border:2px solid #35DAE6;background:#163240;display:flex;align-items:center;justify-content:center;font-size:24px;color:#A6FCFC;font-weight:700;">H</div>'+
'<div style="font-size:22px;font-weight:700;letter-spacing:4px;color:#DCE9F2;">HUE BOARD</div></div>'+
'<div style="font-size:64px;font-weight:750;letter-spacing:-3px;line-height:1.1;">Make light<br/>feel alive.</div>'+
'<div style="font-size:22px;color:#91AFBF;margin-top:25px;">Control, compose, and animate your Hue lights.</div>'+
'<div style="display:flex;flex-direction:row;gap:12px;margin-top:35px;">'+
['LIGHTS','SCENES','STUDIO'].map(x=>'<span style="background:#15323E;border:1px solid #355362;color:#B2E5ED;border-radius:30px;padding:10px 28px;font-size:15px;font-weight:600;">'+x+'</span>').join('')+
'</div></div>'+
'<div style="position:relative;width:535px;height:340px;border-radius:30px;background:#0D1D2B;border:1px solid #365466;overflow:hidden;">'+
'<div style="position:absolute;top:36px;left:38px;width:456px;height:268px;border:2px dashed #2C5367;border-radius:50%;"></div>'+
'<div style="position:absolute;top:72px;left:83px;width:362px;height:200px;border:1px solid #214153;border-radius:50%;"></div>'+
'<div style="position:absolute;top:116px;left:190px;width:155px;height:110px;border-radius:60px;background:#102D3B;display:flex;flex-direction:column;align-items:center;justify-content:center;border:1px solid #296074;">'+
'<div style="font-size:25px;font-weight:700;">Room</div><div style="font-size:15px;color:#93BECA;">in harmony</div></div>'+
'<div style="position:absolute;left:54px;top:44px;width:435px;height:290px;">'+leds+'</div></div></div>';
const svg = await renderSvg(html, {width:1440,height:480});
if (!svg.includes("<svg")) throw new Error("Takumi did not return an SVG");
await mkdir(dirname(output),{recursive:true});
await writeFile(output,svg,"utf8");
console.log("Takumi banner rendered:",output);

const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.join(__dirname,'..'),read=p=>fs.readFileSync(path.join(root,p),'utf8');
test('README artwork is an accessible, self-contained vector',()=>{
 const svg=read('assets/readme/hero.svg');
 assert.match(svg,/^<svg\b/);assert.match(svg,/viewBox="0 0 1600 550"/);
 assert.match(svg,/<title id="title">/);assert.match(svg,/<desc id="desc">/);
 assert.match(svg,/HUE BOARD/);assert.match(svg,/Shape the/);
 assert.doesNotMatch(svg,/<script\b|<foreignObject\b|(?:href|src)=["']https?:\/\//i);
 assert.ok(svg.length>4000&&svg.length<40000);
});
test('Takumi artwork renderer uses pinned package and explicit output dimensions',()=>{
 const gen=read('scripts/readme-art/generate.mjs');
 const pkg=JSON.parse(read('scripts/readme-art/package.json'));
 assert.equal(pkg.dependencies['takumi-js'],'2.19.0');
 assert.match(gen,/renderSvg\(html,\{width:1600,height:550\}\)/);
 assert.doesNotMatch(gen,/fetch\(|https?:\/\//i);
});

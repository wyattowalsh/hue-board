const fs=require('node:fs'),path=require('node:path');
const root=__dirname;
function load(name,fallback){try{return require(name)}catch(e){if(fallback&&fs.existsSync(fallback))return require(fallback);throw new Error(`Install the pinned build dependencies before rebuilding the frontend: ${name}`)}}
const ts=load('typescript','/usr/local/slides_js/node_modules/typescript');
const tw=load('tailwindcss','/usr/local/slides_js/node_modules/tailwindcss/dist/lib.js');
const twRoot=(()=>{try{return path.dirname(require.resolve('tailwindcss/package.json'))}catch(_){return '/usr/local/slides_js/node_modules/tailwindcss'}})();
function walk(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(path.join(dir,e.name)):/\.tsx?$/.test(e.name)&&!e.name.endsWith('.d.ts')?[path.join(dir,e.name)]:[])}
(async()=>{
 const modules={},tokens=new Set();let diagnostics=[];
 for(const file of walk(root)){const source=fs.readFileSync(file,'utf8'),id=path.relative(root,file).replaceAll('\\','/').replace(/\.tsx?$/,'');
  const ast=ts.createSourceFile(file,source,ts.ScriptTarget.ES2020,true,file.endsWith('.tsx')?ts.ScriptKind.TSX:ts.ScriptKind.TS);
  function visit(n){if(ts.isStringLiteralLike(n))n.text.split(/\s+/).filter(Boolean).forEach(v=>tokens.add(v));ts.forEachChild(n,visit)}visit(ast);
  const result=ts.transpileModule(source,{fileName:file,reportDiagnostics:true,compilerOptions:{jsx:ts.JsxEmit.React,module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020,esModuleInterop:true,strict:true,removeComments:false}});
  diagnostics.push(...(result.diagnostics||[]).filter(d=>d.category===ts.DiagnosticCategory.Error));modules[id]=result.outputText;
 }
 if(diagnostics.length)throw new Error(ts.formatDiagnosticsWithColorAndContext(diagnostics,{getCurrentDirectory:()=>root,getCanonicalFileName:x=>x,getNewLine:()=>"\n"}));
 const compiler=await tw.compile(fs.readFileSync(path.join(root,'theme.css'),'utf8'),{base:root,loadStylesheet:async(id,base)=>{
  const file=id==='tailwindcss'?path.join(twRoot,'index.css'):id.startsWith('tailwindcss/')?path.join(twRoot,id.slice(12)):path.resolve(base,id);return {path:file,base:path.dirname(file),content:fs.readFileSync(file,'utf8')};}});
 const css=compiler.build([...tokens]);
 const app=`(function(){'use strict';const modules={${Object.entries(modules).map(([id,code])=>JSON.stringify(id)+':function(module,exports,require){\n'+code+'\n}').join(',\n')}};const cache={};function resolve(id,from){if(id[0]!=='.')return id;const parts=from.split('/');parts.pop();for(const p of id.split('/')){if(p==='..')parts.pop();else if(p!=='.')parts.push(p);}return parts.join('/');}function req(id,from=''){id=resolve(id,from);if(id==='react')return window.React;if(id==='react-dom')return window.ReactDOM;if(id==='react-dom/client')return {createRoot:window.ReactDOM.createRoot};if(!modules[id])throw Error('Missing bundled module '+id);if(cache[id])return cache[id].exports;const m={exports:{}};cache[id]=m;modules[id](m,m.exports,n=>req(n,id));return m.exports;}req('main');})();`;
 const out=path.join(root,'../dist');fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'frontend.js'),app);fs.writeFileSync(path.join(out,'frontend.css'),css);
 fs.writeFileSync(path.join(out,'frontend-build.json'),JSON.stringify({typescript:ts.version,tailwind:require(path.join(twRoot,'package.json')).version,modules:Object.keys(modules),candidateCount:tokens.size,bytes:{js:Buffer.byteLength(app),css:Buffer.byteLength(css)},checks:'TypeScript syntax/transpile diagnostics. Full semantic checking is separate.'},null,2));
 console.log('Frontend compiled:',Object.keys(modules).length,'modules;',app.length,'JS bytes;',css.length,'CSS bytes');
})().catch(e=>{console.error(e);process.exitCode=1});

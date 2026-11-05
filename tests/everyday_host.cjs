const fs=require('node:fs'),path=require('node:path'),readline=require('node:readline');
const {everyday}=require('./everyday_fixture.cjs');const {A,flush,clone}=require('./helpers.cjs');
(async()=>{const f=everyday();await f.tick();await f.tick(2200);const output=()=>({state:f.w.state(),writes:f.e.writes().length,calls:f.e.calls,bulbs:[...f.e.database.values()]});
 if(process.argv.includes('--demo')){const out=path.join(__dirname,'../qa/v5');fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'everyday-demo.html'),A.buildPage(f.w.meta,f.w.state()));fs.writeFileSync(path.join(out,'everyday-state.json'),JSON.stringify(f.w.state()));await f.close();return;}
 const rl=readline.createInterface({input:process.stdin});let queue=Promise.resolve();
 rl.on('line',line=>{queue=queue.then(async()=>{try{const m=JSON.parse(line);if(m.edit)f.w.update(m.edit);if(m.command)f.w.dispatch(m.command.name,m.command.payload);await f.tick();await f.w.settled();if(m.scenes)await f.w._controller().scenesSettled();if(m.run)await f.run(m.run);await flush(30);if(m.close)await f.close();console.log(JSON.stringify(output()));}catch(e){console.log(JSON.stringify({error:String(e.stack)}));}});});
})();

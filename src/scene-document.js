/**
 * Versioned, scope-free Hue Board scene documents.
 *
 * Scene documents describe lighting intent only. They cannot carry Bridge
 * credentials, host addresses, resource IDs, or an implicit physical target.
 * The user chooses the active room/zone at Apply or Play time.
 */
const SCENE_DOCUMENT_FORMAT='hue-board.scene';
const SCENE_DOCUMENT_SCHEMA=2;
const SCENE_DOCUMENT_ENGINE_ABI=1;
const SCENE_DOCUMENT_ROOT_KEYS=Object.freeze(['format','schema','kind','documentId','name','createdAt','modifiedAt','scope','source','settings']);
const SCENE_DOCUMENT_SOURCE_KEYS=Object.freeze(['productVersion','engineABI','catalogRevision','implementation']);
const SCENE_DOCUMENT_SETTING_KEYS=Object.freeze([
  'showA','showB','paletteA','paletteB','morph','brightness','speed','depth','spread','energy','tension','focus',
  'reverse','gradient','seed','topology','transitionMs','ownership','nativeKind','effect','effectSpeed','effectTint',
  'saturation','ambientFloor','accentMix','density','phaseOffset','brightnessCurve','directorSeconds','customColors',
  'sequenceIds','sequenceHold','sequenceOrder'
]);
function sceneDocumentId(){
  return 'scene-'+Date.now().toString(36)+'-'+Math.floor(Math.random()*0xffffffff).toString(36).padStart(7,'0');
}
function makeSceneDocument(settings,name='Hue Board look'){
  const now=new Date().toISOString(),cleanName=String(name||'Hue Board look').trim().slice(0,80)||'Hue Board look';
  return {format:SCENE_DOCUMENT_FORMAT,schema:SCENE_DOCUMENT_SCHEMA,kind:'look',documentId:sceneDocumentId(),name:cleanName,
    createdAt:now,modifiedAt:now,scope:'user-selected',
    source:{productVersion:VERSION,engineABI:SCENE_DOCUMENT_ENGINE_ABI,catalogRevision:null,implementation:'scriptable'},
    settings:ENGINE.clean(settings)};
}
function sceneDocumentExactKeys(value,allowed,label){
  if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('The '+label+' must be an object. Nothing was imported.');
  const unknown=Object.keys(value).filter(key=>!allowed.includes(key));
  if(unknown.length)throw new Error('The '+label+' contains unsupported fields: '+unknown.sort().join(', ')+'. Nothing was imported.');
}
function sceneDocumentNumber(value,key,a,b){
  if(typeof value!=='number'||!Number.isFinite(value)||value<a||value>b)throw new Error('The '+key+' scene setting is out of range. Nothing was imported.');
}
function validateSceneSettings2(raw){
  sceneDocumentExactKeys(raw,SCENE_DOCUMENT_SETTING_KEYS,'scene settings');
  for(const key of SCENE_DOCUMENT_SETTING_KEYS)if(!Object.prototype.hasOwnProperty.call(raw,key))throw new Error('The scene is missing '+key+'. Nothing was imported.');
  const shows=new Set(ENGINE.shows.map(v=>v[0]));
  if(!shows.has(raw.showA)||!shows.has(raw.showB))throw new Error('The scene references an unknown pattern. Nothing was imported.');
  if(!Number.isInteger(raw.paletteA)||!Number.isInteger(raw.paletteB)||raw.paletteA<0||raw.paletteB<0||raw.paletteA>=ENGINE.palettes.length||raw.paletteB>=ENGINE.palettes.length)throw new Error('The scene references an unknown palette. Nothing was imported.');
  for(const [key,a,b] of [
    ['morph',0,100],['brightness',5,100],['speed',.25,1.6],['depth',0,100],['spread',.5,2],['energy',0,100],
    ['tension',0,100],['focus',0,100],['transitionMs',2500,15000],['effectSpeed',0,1],['saturation',0,100],
    ['ambientFloor',0,65],['accentMix',0,100],['phaseOffset',-1,1],['brightnessCurve',.5,2],['directorSeconds',30,180],
    ['sequenceHold',30,600]
  ])sceneDocumentNumber(raw[key],key,a,b);
  if(!Number.isInteger(raw.seed)||raw.seed<0||raw.seed>999999||!Number.isInteger(raw.density)||raw.density<1||raw.density>4)throw new Error('The scene integer settings are out of range. Nothing was imported.');
  if(typeof raw.reverse!=='boolean'||typeof raw.gradient!=='boolean'||typeof raw.effectTint!=='boolean')throw new Error('The scene boolean settings are invalid. Nothing was imported.');
  if(!['ring','path'].includes(raw.topology)||!['yield_off','hold'].includes(raw.ownership)||!['palette','effect'].includes(raw.nativeKind)||!['forward','shuffle'].includes(raw.sequenceOrder))throw new Error('The scene contains an invalid mode setting. Nothing was imported.');
  if(typeof raw.effect!=='string'||raw.effect.length>40)throw new Error('The scene effect identifier is invalid. Nothing was imported.');
  if(!Array.isArray(raw.customColors)||raw.customColors.length!==4||!raw.customColors.every(v=>typeof v==='string'&&/^#[0-9a-f]{6}$/i.test(v)))throw new Error('The scene requires exactly four valid custom colors. Nothing was imported.');
  if(!Array.isArray(raw.sequenceIds)||raw.sequenceIds.length>12||!raw.sequenceIds.every(v=>typeof v==='string'&&/^[a-z0-9-]{1,50}$/.test(v)))throw new Error('The scene sequence identifiers are invalid. Nothing was imported.');
  return ENGINE.clean(raw);
}
function validateSceneDocument(value){
  if(value&&value.format===SCENE_DOCUMENT_FORMAT){
    sceneDocumentExactKeys(value,SCENE_DOCUMENT_ROOT_KEYS,'scene document');
    if(value.schema!==SCENE_DOCUMENT_SCHEMA)throw new Error('Hue Board scene schema '+String(value.schema)+' is not supported. Nothing was imported.');
    if(value.kind!=='look'||value.scope!=='user-selected')throw new Error('Hue Board scene documents cannot embed a physical target or unsupported document kind. Nothing was imported.');
    if(typeof value.documentId!=='string'||!/^[A-Za-z0-9._-]{1,80}$/.test(value.documentId))throw new Error('The scene document identifier is invalid. Nothing was imported.');
    if(typeof value.name!=='string'||!value.name.trim()||value.name.trim().length>80||/[\u0000-\u001f\u007f]/.test(value.name))throw new Error('The scene name is invalid. Nothing was imported.');
    const created=Date.parse(value.createdAt),modified=Date.parse(value.modifiedAt);
    if(!Number.isFinite(created)||!Number.isFinite(modified)||modified<created)throw new Error('The scene timestamps are invalid. Nothing was imported.');
    sceneDocumentExactKeys(value.source,SCENE_DOCUMENT_SOURCE_KEYS,'scene source');
    if(value.source.engineABI!==SCENE_DOCUMENT_ENGINE_ABI)throw new Error('Engine ABI '+String(value.source.engineABI)+' is not supported. Nothing was imported.');
    if(typeof value.source.productVersion!=='string'||!/^[A-Za-z0-9.+_-]{1,40}$/.test(value.source.productVersion)||typeof value.source.implementation!=='string'||!/^[A-Za-z0-9._-]{1,40}$/.test(value.source.implementation))throw new Error('The scene source metadata is invalid. Nothing was imported.');
    if(value.source.catalogRevision!==null&&value.source.catalogRevision!==undefined&&(typeof value.source.catalogRevision!=='string'||!/^[0-9a-f]{64}$/i.test(value.source.catalogRevision)))throw new Error('The catalog revision is invalid. Nothing was imported.');
    return {settings:validateSceneSettings2(value.settings),warnings:[],source:'scene-schema-2',document:value};
  }
  if(value&&['hue-board',LEGACY_MIX_APP].includes(value.app)&&value.schema===3&&value.settings&&typeof value.settings==='object'&&!Array.isArray(value.settings)){
    return {settings:ENGINE.clean(value.settings),warnings:['Migrated a legacy Scriptable schema 3 mix to scene schema 2.'],source:'legacy-scriptable-schema-3',document:null};
  }
  throw new Error('Expected a Hue Board scene schema 2 document or legacy schema 3 mix. Nothing was imported.');
}
// Preserve the public helper used by existing migration tests and integrations.
validatePreset=function validateScenePreset(value){return validateSceneDocument(value).settings;};
// Upgrade the existing runtime export call without duplicating the control loop.
const legacySceneExportDocument=exportDocument;
exportDocument=async function exportSceneDocument(name,value){
  if(name==='hue-board-mix.json'&&value&&value.app==='hue-board'&&value.schema===3&&value.settings){
    return legacySceneExportDocument('hue-board-scene.json',makeSceneDocument(value.settings));
  }
  return legacySceneExportDocument(name,value);
};
// Keep the runtime bridge intact while making its native prompt describe both accepted formats.
const legacySceneInput=input;
input=async function sceneDocumentInput(title,message,value){
  if(title==='Import mix'&&/schema 3/i.test(String(message||''))){
    return legacySceneInput('Import scene','Paste a Hue Board scene schema 2 document or legacy schema 3 mix. Importing does not start lights.',value);
  }
  return legacySceneInput(title,message,value);
};

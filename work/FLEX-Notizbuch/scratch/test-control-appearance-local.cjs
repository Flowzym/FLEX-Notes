// Real preference, persistence and color functions; no browser or personal data.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const read=f=>fs.readFileSync('scratch/'+f,'utf8'),values=new Map(),properties=new Map([['--panel-bg','#303e2b'],['--footer-bg','#263623'],['--text','#f6f5eb']]);
const c=vm.createContext({console,setTimeout,clearTimeout,KEY:'isolated-controls',uid:()=> 'image1',window:{addEventListener(){}},validPupilColor:v=>typeof v==='string'&&/^#[a-f\d]{6}$/i.test(v),localStorage:{getItem:k=>values.get(k)||null,setItem:(k,v)=>values.set(k,v),removeItem:k=>values.delete(k)},document:{documentElement:{style:{setProperty:(k,v)=>properties.set(k,v)}}},getComputedStyle:()=>({getPropertyValue:k=>properties.get(k)||''})});
const settings=read('settings.js');
vm.runInContext(['modal-appearance.js','surface-appearance.js','background-image.js','preference-store.js','control-appearance.js'].map(read).join('\n')+'\n'+settings.slice(0,settings.indexOf('const settingsNav=')),c);
const clean=c.cleanPreferences(null);assert.equal(clean.buttonTransparency,6);assert.equal(clean.fieldTransparency,6);assert.equal(clean.modalTransparency,0);
assert.equal(c.cleanPreferences({backgroundMode:'image',backgroundImage:'data:image/png;base64,YQ=='}).modalTransparency,100);
const p=c.cleanPreferences({...clean,buttonColor:'#ABCDEF',buttonTransparency:-1,fieldColor:'#ffffff',fieldTransparency:100,modalColor:'#000000',modalTransparency:34});
assert.equal(p.buttonColor,'#abcdef');assert.equal(p.buttonTransparency,0);assert.equal(p.fieldTransparency,100);assert.equal(c.cleanPreferences({fieldTransparency:Infinity,modalColor:'red'}).fieldTransparency,6);assert.equal(c.cleanPreferences({modalColor:'red'}).modalColor,'');
c.writeStoredPreferences(p);const restored=c.cleanPreferences(c.readStoredPreferences());assert.equal(JSON.stringify(restored),JSON.stringify(p));
c.appPreferences=p;c.applyControlAppearance();assert.equal(properties.get('--button-fill'),'rgb(171 205 239 / 1)');assert.equal(properties.get('--field-fill'),'rgb(255 255 255 / 0)');assert.equal(properties.get('--button-ink'),'#000000');
assert.equal(c.controlSurfaceValues('#000000',0,'#ffffff').ink,'#ffffff');assert.equal(c.controlSurfaceValues('#000000',100,'#ffffff').ink,'#000000');
const oldField=properties.get('--field-fill');c.appPreferences={...p,buttonTransparency:100,modalTransparency:100};c.applyControlAppearance();assert.equal(properties.get('--field-fill'),oldField);assert.equal(properties.get('--modal-fill'),'rgb(0 0 0 / 0)');assert.equal(properties.get('--button-fill'),'rgb(171 205 239 / 0)');
vm.runInContext(read('data-validation.js'),c);c.CATS=restored.shortcutOrder.map(x=>[x]);assert.equal(c.validBackupPreferences(restored),true);assert.equal(c.validBackupPreferences({...restored,fieldTransparency:101}),false);assert.equal(c.validBackupPreferences({...restored,modalColor:'url(x)'}),false);
let linked=c.synchronizeAppearance({...p,appearanceLinked:true},p);
for(const key of ['header','card','button','field','modal']){assert.equal(linked[key+'Color'],p.buttonColor);assert.equal(linked[key+'Transparency'],p.buttonTransparency);}
assert.equal(linked.modalHeaderTransparency,0);assert.equal(linked.modalFooterTransparency,0);
linked=c.synchronizeAppearance({...linked,modalFooterTransparency:100},linked);for(const key of ['header','card','button','field','modal','modalHeader','modalFooter'])assert.equal(linked[key+'Transparency'],100);
linked=c.synchronizeAppearance({...linked,fieldColor:'#ffcc00'},linked);for(const key of ['header','card','button','field','modal'])assert.equal(linked[key+'Color'],'#ffcc00');
const unlinked=c.synchronizeAppearance({...linked,appearanceLinked:false,fieldColor:'#ffffff'},linked);assert.equal(unlinked.fieldColor,'#ffffff');assert.equal(unlinked.buttonColor,'#ffcc00');
c.writeStoredPreferences(linked);assert.equal(c.cleanPreferences(c.readStoredPreferences()).appearanceLinked,true);assert.equal(c.validBackupPreferences(linked),true);assert.equal(c.validBackupPreferences({...linked,appearanceLinked:'yes'}),false);
c.appPreferences=linked;c.applyControlAppearance();c.applyModalAppearance();assert.equal(properties.get('--modal-header-fill'),properties.get('--modal-fill'));assert.equal(properties.get('--modal-footer-fill'),properties.get('--modal-fill'));
console.log('PASS: legacy defaults, independent controls, 0/100 endpoints, readable ink, linked changes from every control type, unlinking, storage round-trip and backup validation. No browser tests.');

const controlAppearanceDefaults={buttonColor:'',buttonTransparency:6,fieldColor:'',fieldTransparency:6,modalColor:'',modalTransparency:100};
function synchronizeAppearance(next,previous){
 if(!next.appearanceLinked)return next;
 const colors=['headerColor','cardColor','buttonColor','fieldColor','modalColor'],transparencies=['headerTransparency','cardTransparency','buttonTransparency','fieldTransparency','modalTransparency','modalHeaderTransparency','modalFooterTransparency'];
 const colorKey=!previous.appearanceLinked?'buttonColor':colors.find(key=>next[key]!==previous[key]);
 const transparencyKey=!previous.appearanceLinked?'buttonTransparency':transparencies.find(key=>next[key]!==previous[key]);
 const result={...next};if(colorKey)for(const key of colors)result[key]=next[colorKey];if(transparencyKey)for(const key of transparencies)result[key]=next[transparencyKey];return result;
}
function linkedAppearanceSettings(){return `<section class="settings-panel appearance-presets"><label class="switch-label"><input type="checkbox" role="switch" class="entry-switch" id="appearanceLinked">Alle Flächen gemeinsam einstellen</label><p>Übernimmt zunächst die Buttonwerte. Danach gelten Farb- und Transparenzänderungen für alle Flächen. Ausschalten ermöglicht wieder getrennte Werte.</p></section>`;}
function cleanControlAppearance(raw){
 const result={};for(const name of ['button','field','modal']){
  const color=raw?.[name+'Color'],value=raw?.[name+'Transparency'];
  result[name+'Color']=validPupilColor(color)?color.toLowerCase():'';
  result[name+'Transparency']=Number.isFinite(value)?Math.max(0,Math.min(100,value)):(name==='modal'&&raw?.backgroundMode!=='image'?0:controlAppearanceDefaults[name+'Transparency']);
 }return result;
}
function controlSurfaceValues(color,transparency,underlay){
 const alpha=1-transparency/100,perceived=mixColor(color,underlay,1-alpha);
 const ink=colorContrast(perceived,'#ffffff')>colorContrast(perceived,'#000000')?'#ffffff':'#000000';
 return {fill:'rgb('+colorChannels(color).join(' ')+' / '+alpha+')',ink};
}
function controlBaseColor(name){
 const style=getComputedStyle(document.documentElement),panel=style.getPropertyValue('--panel-bg').trim();
 return appPreferences[name+'Color']||(name==='modal'||appPreferences.appearanceLinked?panel:mixColor(panel,style.getPropertyValue('--text').trim(),.06));
}
function applyControlAppearance(){
 const root=document.documentElement,style=getComputedStyle(root),panel=style.getPropertyValue('--panel-bg').trim();
 const underlay=appPreferences.backgroundMode==='image'?mixColor(appPreferences.backgroundTint,'#000000',appPreferences.backgroundDim):appPreferences.background;
 const modalColor=controlBaseColor('modal'),modalUnderlay=mixColor(modalColor,underlay,appPreferences.modalTransparency/100);
 for(const name of ['button','field','modal']){const value=controlSurfaceValues(controlBaseColor(name),appPreferences[name+'Transparency'],name==='modal'?underlay:modalUnderlay);root.style.setProperty('--'+name+'-fill',value.fill);root.style.setProperty('--'+name+'-ink',value.ink);}
 for(const [name,token]of [['header','panel-bg'],['footer','footer-bg']]){const value=controlSurfaceValues(appPreferences.appearanceLinked?modalColor:style.getPropertyValue('--'+token).trim(),appPreferences['modal'+name[0].toUpperCase()+name.slice(1)+'Transparency'],modalUnderlay);root.style.setProperty('--modal-'+name+'-ink',value.ink);}
}
function controlAppearanceSettings(names=['button','field','modal']){return names.map(name=>`<section class="settings-panel surface-settings"><div class="settings-section-head"><h2>${{button:'Buttons',field:'Eingabefelder',modal:'Dialoghintergrund'}[name]}</h2><button type="button" class="settings-reset" data-reset-control="${name}">Zurücksetzen</button></div><p>${name==='modal'?'Farbfläche über dem Dialogbild. Kopf- und Fußzeile stellst du separat ein.':name==='button'?'Hintergrund der Auswahl- und Zusatzbuttons in Dialogen. Aktive Auswahl und Positiv-/Negativfarben bleiben erkennbar.':'Hintergrund der Schreibfelder und Auswahllisten in Dialogen.'}</p><label for="${name}Transparency">Transparenz <output id="${name}TransparencyValue"></output></label><input type="range" id="${name}Transparency" min="0" max="100" step="1"><div class="settings-color-row"><input type="color" id="${name}Color" aria-label="${name==='modal'?'Dialog':name==='button'?'Button':'Eingabefeld'}-Hintergrundfarbe"><div><label for="${name}ColorHex">Eigene Farbe</label><input type="text" id="${name}ColorHex" maxlength="7" spellcheck="false" autocomplete="off"></div></div><div class="settings-swatches" role="group" aria-label="Farbvorschläge">${appearancePalette.map(([color,label])=>`<button type="button" data-control="${name}" data-control-color="${color}" aria-label="${label}" title="${label}"><span style="background:${color}"></span></button>`).join('')}</div><button type="button" class="surface-auto" data-control-auto="${name}">Farbe automatisch anpassen</button><p class="help">0 %: deckend. 100 %: keine Farbfüllung.${name==='modal'?' Das aktivierte Hintergrundbild bleibt sichtbar.':''}</p></section>`).join('');}
function refreshControlAppearance(){for(const name of ['button','field','modal']){const input=$('#'+name+'Color');if(!input)continue;const color=controlBaseColor(name);input.value=color;$('#'+name+'ColorHex').value=color.toUpperCase();$('#'+name+'ColorHex').removeAttribute('aria-invalid');$('#'+name+'Transparency').value=appPreferences[name+'Transparency'];$('#'+name+'TransparencyValue').textContent=appPreferences[name+'Transparency']+' %';settingsPage.querySelector('[data-control-auto="'+name+'"]').setAttribute('aria-pressed',String(!appPreferences[name+'Color']));settingsPage.querySelectorAll('[data-control="'+name+'"]').forEach(b=>b.setAttribute('aria-pressed',String(appPreferences[name+'Color']===b.dataset.controlColor)));}}
function bindControlAppearance(){
 $('#appearanceLinked').onchange=e=>savePreferences(synchronizeAppearance({...appPreferences,appearanceLinked:e.target.checked},appPreferences));
 for(const name of ['button','field','modal']){
  $('#'+name+'Color').oninput=e=>previewPreference(name+'Color',e.target.value);$('#'+name+'Color').onchange=commitAppearancePreview;
  $('#'+name+'Transparency').oninput=e=>previewPreference(name+'Transparency',Number(e.target.value));$('#'+name+'Transparency').onchange=commitAppearancePreview;
  $('#'+name+'ColorHex').onchange=e=>{const value=e.target.value.trim();if(!validPupilColor(value)){e.target.setAttribute('aria-invalid','true');$('#settingsStatus').textContent='Bitte einen gültigen HEX-Farbwert eingeben, z. B. #303E2B.';return;}savePreferences({...appPreferences,[name+'Color']:value});};
 }
 settingsPage.querySelectorAll('[data-control-color]').forEach(b=>b.onclick=()=>savePreferences({...appPreferences,[b.dataset.control+'Color']:b.dataset.controlColor}));
 settingsPage.querySelectorAll('[data-control-auto]').forEach(b=>b.onclick=()=>savePreferences({...appPreferences,[b.dataset.controlAuto+'Color']:''}));
 settingsPage.querySelectorAll('[data-reset-control]').forEach(b=>b.onclick=()=>{const name=b.dataset.resetControl;savePreferences({...appPreferences,[name+'Color']:'',[name+'Transparency']:name==='modal'&&appPreferences.backgroundMode!=='image'?0:controlAppearanceDefaults[name+'Transparency']});});
}

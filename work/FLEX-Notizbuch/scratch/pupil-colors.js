function pupilColorPalette(){return ['#53747e','#756582','#49765a','#b87943','#ac5d72','#487f85','#8a7845','#6478a6','#8c6553','#73834c'];}
function validPupilColor(value){return typeof value==='string'&&/^#[0-9a-f]{6}$/i.test(value);}
function unusedPupilColor(used){for(const color of pupilColorPalette())if(!used.has(color))return color;for(let i=0;i<100000;i++){const hue=(i*137.508)%360,s=.38,l=.44,a=s*Math.min(l,1-l),f=n=>{const k=(n+hue/30)%12;return Math.round(255*(l-a*Math.max(-1,Math.min(k-3,9-k,1)))).toString(16).padStart(2,'0');},color='#'+f(0)+f(8)+f(4);if(!used.has(color))return color;}return '#53747e';}
function assignStudentColors(students){const used=new Set(students.filter(s=>validPupilColor(s.color)).map(s=>s.color.toLowerCase()));let changed=false;for(const s of students){if(validPupilColor(s.color))continue;s.color=unusedPupilColor(used);used.add(s.color);changed=true;}return changed;}
function pupilColor(student){if(validPupilColor(student.color))return student.color.toLowerCase();const pupils=db.students.map(s=>({...s}));assignStudentColors(pupils);return pupils.find(s=>s.id===student.id)?.color||pupilColorPalette()[0];}
function suggestedPupilColor(){return unusedPupilColor(new Set(db.students.map(pupilColor)));}
function colorField(id){return `<fieldset class="pupil-color-field"><legend>Farbe</legend><div class="pupil-color-options">${pupilColorPalette().map((color,i)=>`<button type="button" class="pupil-color-swatch" data-color-target="${id}" data-pupil-color="${color}" style="--swatch:${color}" aria-label="Farbe ${i+1}: ${color}" aria-pressed="false" title="${color}"></button>`).join('')}</div><label class="pupil-custom-color" for="${id}"><input type="color" id="${id}" value="#53747e"><span>Eigene Farbe wählen</span></label></fieldset>`;}
function refreshColorField(input){input.closest('fieldset').querySelectorAll('[data-pupil-color]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.pupilColor===input.value.toLowerCase())));}
$('#studentName').insertAdjacentHTML('afterend',colorField('studentColor'));
$('#pupilName').insertAdjacentHTML('afterend',colorField('pupilColor'));
document.addEventListener('click',e=>{const b=e.target.closest('[data-pupil-color]');if(!b)return;const input=document.getElementById(b.dataset.colorTarget);input.value=b.dataset.pupilColor;refreshColorField(input);});
for(const id of ['studentColor','pupilColor'])$('#'+id).addEventListener('input',e=>refreshColorField(e.target));
const openAddWithColor=$('#addStudent').onclick;$('#addStudent').onclick=()=>{openAddWithColor();$('#studentColor').value=suggestedPupilColor();refreshColorField($('#studentColor'));};
const managePupilWithColor=managePupil;managePupil=function(){managePupilWithColor();$('#pupilColor').value=pupilColor(db.students.find(s=>s.id===active));refreshColorField($('#pupilColor'));};
// Persist one migration for existing pupils; subsequent loads keep their assigned colors.
if(assignStudentColors(db.students)&&canStore)persist();
renderStudents();

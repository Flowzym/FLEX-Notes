// Isolated event-level model checks. No browser process or user data.
const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),nodes=new Map();
class Element{
 constructor(tag){this.tagName=tag.toUpperCase();this.children=[];this.dataset={};this.attrs={};this.listeners={};this.value='';this.maxLength=4000;this.classList={add(){},remove(){}};}
 set id(value){this._id=value;nodes.set(value,this);}get id(){return this._id||'';}
 setAttribute(k,v){this.attrs[k]=String(v);}removeAttribute(k){delete this.attrs[k];}
 append(...items){for(const n of items){n.parent=this;this.children.push(n);}}prepend(...items){for(const n of items){n.parent=this;}this.children.unshift(...items);}after(n){n.parent=this.parent;this.parent.children.splice(this.parent.children.indexOf(this)+1,0,n);}
 replaceChildren(...items){this.children=[];this.append(...items);}remove(){if(this.parent)this.parent.children=this.parent.children.filter(x=>x!==this);nodes.delete(this.id);}
 querySelector(s){return s==='label'?label:null;}querySelectorAll(s){return s==='button'?this.children.filter(x=>x.tagName==='BUTTON'):[];}
 closest(s){if(s==='[data-social-context]')return this.dataset.socialContext?this:null;if(s==='.field')return field;return null;}
 addEventListener(type,fn){(this.listeners[type]||=[]).push(fn);}dispatchEvent(e){for(const fn of this.listeners[e.type]||[])fn(e);}focus(){this.focused=true;}
}
const field=new Element('div'),label=new Element('label'),box=new Element('div'),input=new Element('textarea');input.id='entryText';input.value='Ließ den Partner ausreden.';field.append(label,box);box.append(input);
const c=vm.createContext({Event,document:{createElement:tag=>new Element(tag),getElementById:id=>nodes.get(id)||null},observationTagField:()=>box,toast:message=>{throw Error(message);}});
vm.runInContext(fs.readFileSync('scratch/social-narrative.js','utf8').split('AppFlows.use(')[0],c);c.configureSocialNarrative(input,true);
const group=nodes.get('entryTextContextTags'),editor=input._socialNarrativeEditor;assert.equal(field.children[1],group);assert.equal(input.hidden,true);assert.equal(label.htmlFor,editor.free.id);
function choose(tag){group.onclick({target:group.children.find(b=>b.dataset.socialContext===tag)});}
choose('Vor dem Unterricht');assert.equal(editor.tags.children.length,1);assert.equal(editor.free.value,'Ließ den Partner ausreden.');assert.equal(group.children[0].hidden,true);
choose('Pause');assert.equal(editor.tags.children.length,1);assert.equal(editor.tag,'Pause');assert.equal(group.children[0].hidden,false);assert.ok(!input.value.includes('Vor dem Unterricht'));assert.equal(c.splitSocialContext(input.value).tags.length,1);
editor.free.value='Neue Beobachtung';editor.free.dispatchEvent(new Event('input'));assert.equal(input.value,'Pause\n\nNeue Beobachtung');editor.tags.children[0].onclick();assert.equal(input.value,'Neue Beobachtung');assert.equal(editor.tags.children.length,0);
choose('Nach dem Unterricht');c.configureSocialNarrative(input,false);assert.equal(input.hidden,false);assert.equal(input.value,'Nach dem Unterricht\n\nNeue Beobachtung');c.configureSocialNarrative(input,true);assert.equal(input._socialNarrativeEditor.tag,'Nach dem Unterricht');assert.equal(input.listeners.input.length,1);
assert.equal(c.toggleSocialContext('Vor dem Unterricht · Pause\n\nAlt','Während des Unterrichts'),'Während des Unterrichts\n\nAlt');
vm.runInContext(fs.readFileSync('scratch/participants.js','utf8').split('AppFlows.use(')[0],c);
const participants=[{studentId:'s1',name:'Kind A'},{studentId:'s1',name:'Kind A'},{studentId:'',name:'Frau Huber'},{studentId:'',name:' frau huber '}];assert.equal(c.cleanParticipants(participants).length,2);assert.equal(c.participantValues({participantsEnabled:false,participants}).length,0);assert.equal(c.participantValues({participants}).length,2);assert.equal(c.participantText({participants}),'Beteiligt: Kind A, Frau Huber');
console.log('PASS: context chip placement, single choice/replacement/removal, canonical text synchronization, category round-trip, participant deduplication, disabled state and readable history. No browser tests.');

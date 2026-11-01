// Preserve identity, rather than a detached DOM node, across list refreshes.
const renderStudentsWithFocus=renderStudents;
renderStudents=function(){
 const focused=document.activeElement;
 const owner=focused?.closest('#students,#todayPanels');
 const attributes=owner?[...focused.attributes].filter(a=>a.name.startsWith('data-')).map(a=>[a.name,a.value]):[];
 const selector=attributes.length?focused.tagName.toLowerCase()+attributes.map(([key,value])=>'['+key+'="'+CSS.escape(value)+'"]').join(''):null;
 const result=renderStudentsWithFocus();
 if(selector&&!focused.isConnected)owner.querySelector(selector)?.focus({preventScroll:true});
 return result;
};
const pagePositions=new Map();let returnMainPage='students';
const switchPageWithPosition=switchPage;
switchPage=function(view){
 pagePositions.set(pageView,{scroll:window.scrollY,search:$('#studentSearch').value});if(['today','students'].includes(pageView))returnMainPage=pageView;
 switchPageWithPosition(view);
 const saved=pagePositions.get(view);if(saved){$('#studentSearch').value=saved.search;renderStudents();}window.scrollTo({top:saved?.scroll||0,left:0,behavior:'instant'});
 const heading=$('.page-head h1');heading.tabIndex=-1;heading.focus({preventScroll:true});
};

// Stable entry points. Named extensions are composed once in explicit build order.
const AppFlows=(()=>{const flows=new Map();return {
 create(name,base){if(flows.has(name))throw Error('Duplicate flow: '+name);const flow={base,stages:[],compiled:null};flows.set(name,flow);return function(...args){if(!flow.compiled)flow.compiled=flow.stages.reduce((next,stage)=>stage.factory(next),flow.base);return flow.compiled.apply(this,args);};},
 use(name,id,factory){const flow=flows.get(name);if(!flow||flow.stages.some(s=>s.id===id))throw Error('Invalid flow registration: '+name+'/'+id);flow.stages.push({id,factory});flow.compiled=null;},
 stages(name){return (flows.get(name)?.stages||[]).map(s=>s.id);}
};})();
renderModal=AppFlows.create('renderModal',renderModal);
editRecord=AppFlows.create('editRecord',editRecord);

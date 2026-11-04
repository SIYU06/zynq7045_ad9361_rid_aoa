import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {parseHTML} from '../web_release_20261102_0230/qa/node_modules/linkedom/esm/index.js';
const root='F:/2026fpga/rid_receiver/ground_station/';
const [signalFeed,pipelineFeed]=await Promise.all(['/api/signals','/api/pipeline'].map(async path=>{
 const response=await fetch('http://127.0.0.1:18770'+path);assert.equal(response.ok,true);return response.json();
}));
const {document}=parseHTML(readFileSync(root+'index.html','utf8'));globalThis.document=document;
const intervals=[];globalThis.setInterval=fn=>{intervals.push(fn);return intervals.length;};
let signalReads=0;
globalThis.fetch=async path=>({ok:true,json:async()=>{
 if(path==='/api/signals'){signalReads++;return structuredClone(signalFeed);}
 if(path==='/api/pipeline')return structuredClone(pipelineFeed);
 throw new Error('Unexpected request '+path);
}});
const {reset,state}=await import('file:///'+root+'data.js');
const {setupSignals}=await import('file:///'+root+'signals-view.js');
const {setupPipeline}=await import('file:///'+root+'pipeline-view.js');
reset('external');
const view=setupSignals({setMode:reset,toast:()=>{}});
for(const select of document.querySelectorAll('select'))Object.defineProperty(select,'value',{get(){return this.querySelector('option')?.getAttribute('value')||'';}});
setupPipeline({toast:()=>{}});view.activate(true);
const settle=()=>new Promise(resolve=>setImmediate(resolve));await settle();
const $=id=>document.getElementById(id);
assert.ok($('processing-sources').querySelector('tr'));
const originalReads=signalReads;
$('signals-pause').onclick();
assert.equal(state.signalsPaused,true);assert.equal($('signals-pause').textContent,'恢复列表');
const frozenTable=$('signals-body').innerHTML, frozenSources=$('processing-sources').innerHTML;
for(let i=0;i<20;i++){await intervals[0]();await intervals[1]();}
assert.equal(signalReads,originalReads);assert.equal($('signals-body').innerHTML,frozenTable);assert.equal($('processing-sources').innerHTML,frozenSources);
assert.equal($('processing-auto').disabled,true);
signalFeed.packets=[{id:987654,station:'B',session_id:'dom-check',protocol:'RID',frame_name:'Beacon',observed_at:Date.now(),frame_hex:'00',source_mac:'mac_c27c02f297'}];
$('signals-pause').onclick();await settle();
assert.equal(state.signalsPaused,false);assert.equal(signalReads,originalReads+1);
assert.match($('signals-body').textContent,/987654/);assert.equal($('signals-body').querySelectorAll('tr').length,1);
$('signals-body').querySelector('tr').onclick();assert.match($('signals-details').textContent,/Beacon/);
view.activate(false);
console.log('PASS real HTML DOM + local read-only API snapshots: pause button, frame/source tables, pipeline, resume once, row/detail handlers. DOM verification only; no browser rendering.');

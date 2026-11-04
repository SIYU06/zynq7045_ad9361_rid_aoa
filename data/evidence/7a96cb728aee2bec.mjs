import assert from 'node:assert/strict';
import {state,reset} from './data.js';
import {setupSignals} from './signals-view.js';
import {setupPipeline} from './pipeline-view.js';

// A small DOM fixture exercises the real handlers without an installed browser.
const nodes=new Map();
class Node{
 constructor(id=''){this.id=id;this.dataset={};this.value=['signals-protocol','signals-station'].includes(id)?'all':'';this.children=[];this.style={};this.classList={toggle(){}};this.textContent='';this._html='';}
 set innerHTML(value){this._html=value;this.children=this.id==='signals-body'?[...value.matchAll(/data-row="(\d+)"/g)].map(m=>{const row=new Node();row.dataset.row=m[1];return row;}):[];}
 get innerHTML(){return this._html;}
 append(node){this.children.push(node);}before(){}after(){}setAttribute(name,value){this[name]=String(value);}addEventListener(){}
 querySelector(selector){return selector==='h3'?null:get(selector.replace(/^\./,''));}
 querySelectorAll(selector){return selector==='button'?[...this._html.matchAll(/data-sort="([^"]+)"/g)].map(m=>{const n=new Node();n.dataset.sort=m[1];return n;}):[];}
}
const get=id=>{if(!nodes.has(id))nodes.set(id,new Node(id));return nodes.get(id);};
globalThis.document={getElementById:get,createElement:()=>new Node(),querySelector:selector=>get(selector.includes('signals')?'signals-section':selector)};
const original={fetch:globalThis.fetch,setInterval:globalThis.setInterval,setTimeout:globalThis.setTimeout,clearTimeout:globalThis.clearTimeout};
const originalNow=Date.now;let clock=originalNow();Date.now=()=>clock;
const intervals=[],timers=new Map(),requests=[],toasts=[];let timerId=0;
const settle=()=>new Promise(resolve=>setImmediate(resolve));
function pending(url){return requests.filter(r=>r.url===url&&!r.closed&&!r.options.signal?.aborted).at(-1);}
function reply(request,value){assert.ok(request);request.closed=true;request.resolve({ok:true,json:async()=>structuredClone(value)});}
const packet=id=>({id,station:'B',session_id:'session',protocol:'RID',frame_hex:'00',source_mac:'mac_8488e7d8d8',destination_mac:'mac_927ac519ac',frequency_mhz:2437,observed_at:Date.now()+id,frame_type:0,frame_name:'Beacon',length:80,fcs_valid:true,decoded:{}});
const snapshot=id=>({packets:[packet(id)],sources:[],stations:[{id:'B',mode:'live'}],total:id,connected:true});
const pipeline=n=>({sources:Array.from({length:n},(_,i)=>({key:'s'+i,mac:'02:11:22:33:44:'+i,frequencyMhz:2437,receiverStations:['B'],fresh:true,recognition:{kind:'wifi',label:'Wi-Fi',identities:[],evidence:[],eligible:false},direction:{timestamp:Date.now(),stations:{B:{timestamp:Date.now(),angleDeg:20}}},stages:{}})),counts:{},resources:{stations:[]},coverage:{}});
try{
 reset('external');
 globalThis.setInterval=fn=>{intervals.push(fn);return intervals.length;};
 globalThis.setTimeout=fn=>{timers.set(++timerId,fn);return timerId;};globalThis.clearTimeout=id=>timers.delete(id);
 globalThis.fetch=(url,options={})=>new Promise((resolve,reject)=>{const request={url,options,resolve,reject,closed:false,ignoreAbort:false};requests.push(request);options.signal?.addEventListener('abort',()=>{if(!request.ignoreAbort){request.closed=true;reject(Object.assign(new Error('aborted'),{name:'AbortError'}));}},{once:true});});
 const view=setupSignals({setMode:reset,toast:t=>toasts.push(t)});setupPipeline({toast:t=>toasts.push(t)});view.activate(true);
 reply(pending('/api/pipeline'),pipeline(1));reply(pending('/api/signals'),snapshot(101));await settle();
 assert.match(get('signals-body').innerHTML,/101/);get('signals-body').children[0].onclick();const details=get('signals-details').innerHTML;
 get('signals-pause').onclick();assert.equal(state.signalsPaused,true);const frozen=get('signals-body').innerHTML,chain=get('processing-sources').innerHTML;
 const before=requests.filter(r=>r.url==='/api/signals').length;
 for(let i=0;i<100;i++)await intervals[0]();assert.equal(requests.filter(r=>r.url==='/api/signals').length,before,'暂停不轮询、不排队');assert.equal(get('signals-body').innerHTML,frozen);assert.equal(get('signals-details').innerHTML,details);
 clock+=60000;const refreshPipeline=intervals[1]();reply(pending('/api/pipeline'),pipeline(2));await refreshPipeline;
 assert.equal(get('processing-sources').innerHTML,chain,'目标处理链同样冻结');assert.match(get('home-chain').textContent,/检测 2/,'其他页面统计仍读最新数据');assert.equal(get('processing-auto').disabled,true);
 get('processing-auto').onclick();assert.equal(requests.some(r=>r.options.method==='POST'),false,'冻结期间不调度旧快照目标');
 view.activate(false);view.activate(true);assert.equal(state.signalsPaused,true,'切页返回仍维持暂停');
 get('signals-pause').onclick();assert.equal(state.signalsPaused,false);assert.equal(requests.filter(r=>r.url==='/api/signals').length,before+1,'恢复只发一次最新快照请求');assert.match(get('signals-status').textContent,/最新快照/);assert.doesNotMatch(get('signals-details').innerHTML,/Beacon/,'清除旧帧详情');
 for(let i=0;i<50;i++)await intervals[0]();assert.equal(requests.filter(r=>r.url==='/api/signals').length,before+1,'慢请求期间单飞，不堆积');
 reply(pending('/api/signals'),snapshot(303));await settle();assert.match(get('signals-body').innerHTML,/303/);assert.doesNotMatch(get('signals-body').innerHTML,/>101</,'不补播旧帧');
 intervals[0]();const old=pending('/api/signals');old.ignoreAbort=true;get('signals-pause').onclick();assert.equal(old.options.signal.aborted,true);get('signals-pause').onclick();const fresh=pending('/api/signals');reply(fresh,snapshot(404));await settle();reply(old,snapshot(202));await settle();assert.match(get('signals-body').innerHTML,/404/);assert.doesNotMatch(get('signals-body').innerHTML,/>202</,'暂停前的迟到响应不能覆盖恢复后的数据');
 intervals[0]();const timeout=pending('/api/signals');[...timers.values()].at(-1)();await settle();assert.equal(timeout.options.signal.aborted,true);assert.match(get('signals-status').textContent,/超时/);
 const retry=intervals[0]();reply(pending('/api/signals'),snapshot(505));await retry;assert.match(get('signals-body').innerHTML,/505/,'超时可恢复，不锁死忙状态');
 intervals[0]();const obsolete=pending('/api/signals');obsolete.ignoreAbort=true;reset('replay');view.render();reply(obsolete,snapshot(606));await settle();assert.equal(state.signalsPaused,false);assert.doesNotMatch(get('signals-body').innerHTML,/>606</,'旧模式响应隔离');
 reset('external');view.activate(true);const bounded=snapshot(999999);bounded.packets=Array.from({length:2000},(_,i)=>packet(i));reply(pending('/api/signals'),bounded);await settle();assert.match(get('signals-count').textContent,/800帧/,'只保留有界最新窗口');assert.equal(get('signals-body').children.length,100,'单次只渲染一页');
 view.activate(false);assert.equal(requests.filter(r=>r.url==='/api/signals'&&!r.closed&&!r.options.signal.aborted).length,0);assert.equal(intervals.length,2,'暂停恢复不新增轮询器');
 console.log('PASS real pause/resume: frozen table/detail/pipeline, no queued polls, one latest snapshot, abort/late response isolation, timeout recovery, bounded memory and independent background stats');
}finally{Object.assign(globalThis,original);Date.now=originalNow;}

import {state,changes} from './data.js';
import {esc,fmt,jsonFetch,time,phaseStateLabel} from './workspace-core.js';
export const stageCounts=feed=>[feed.sources?.filter(s=>s.fresh).length||0,(feed.counts?.rid||0)+(feed.counts?.video_candidate||0)+(feed.counts?.ssid_candidate||0),feed.sources?.filter(s=>s.fresh&&s.recognition?.identities?.length).length||0,feed.sources?.filter(s=>s.fresh!==false&&['diagnostic','rid_position'].includes(s.stages?.direction)).length||0];
export const directionStatus=(s,now=Date.now())=>{
 if(!s.fresh)return '已过期';
 if(s.positioning?.method==='rid'||s.stages?.direction==='rid_position')return 'RID位置直显';
 if(s.stages?.direction==='unsupported_phy')return '当前PHY暂不支持测向';
 const observations=Object.values(s.direction?.stations||{}).filter(v=>Number.isFinite(v.timestamp)&&now-v.timestamp<15000);
 if(observations.some(v=>Number.isFinite(v.angleDeg)))return observations.some(v=>v.referencePolicy==='operator_fixed_outdoor_reference')?'AOA测向中／固定参考':s.direction?.calibrationStatus==='provisional_reference'?'AOA测向中':'未校准测向';
 const phase=observations.find(v=>Number.isFinite(v.phaseDeg));
 if(phase)return phaseStateLabel(phase);
 return s.recognition?.eligible?'AOA排队中':'继续观测';
};
export const referenceLabel=d=>Object.values(d?.stations||{}).some(s=>s.referencePolicy==='operator_fixed_outdoor_reference')?'户外固定参考':d?.calibrationStatus==='provisional_reference'?'临时参考':Object.values(d?.stations||{}).some(s=>s.calibrationStatus==='provisional_reference')?'部分站参考':'未校准';
export const fpgaBuildCards=fpga=>!fpga?[]:fpga.stationBuilds?Object.entries(fpga.stationBuilds).map(([id,build])=>({label:`${id}站 · XC7Z045`,build})):[{label:'XC7Z045 · FPGA资源',build:fpga}];
export const scoreBreakdownHTML=r=>!r?.scoreBreakdown?.length?'':`<table class="score-breakdown"><thead><tr><th>评分特征</th><th>实际观测</th><th>本次加分</th></tr></thead><tbody>${r.scoreBreakdown.map(rule=>`<tr><td>${esc(rule.label)}<small>满足时 +${esc(rule.maxPoints)}</small></td><td>${esc(rule.observed)}${rule.observable===false?'<small>当前未取得可判定数据</small>':''}</td><td>${rule.matched?`+${esc(rule.points)}`:'0'}</td></tr>`).join('')}</tbody></table><p class="muted">规则合计 ${esc(r.rawEvidenceScore)} 分，展示上限 ${esc(r.maxEvidenceScore)} 分；分数不代表无人机概率。</p>`;
export function setupPipeline({toast}){
 const $=id=>document.getElementById(id),signals=document.querySelector('[data-page="signals"]');
 const panel=document.createElement('article');panel.className='processing-panel';panel.innerHTML=`<div class="processing-stages" id="processing-stages"></div><div class="processing-heading"><h2>目标处理链</h2><span id="processing-active">当前测向目标：等待信源</span><button id="processing-auto" title="取消手动指定，自动选择可测目标">自动选择目标</button></div><p id="processing-coverage" class="muted"></p><p class="muted">RID身份＋有效经纬度 → 地图与轨迹；无有效RID位置的疑似无人机 → AOA测向与轨迹。无RID不等于已确认黑飞。</p><div class="table-scroll"><table class="processing-table"><thead><tr><th>信源 / 频率</th><th>特征识别 / PHY协议</th><th>身份解析</th><th>定位与跟踪</th><th></th></tr></thead><tbody id="processing-sources"></tbody></table></div><details id="processing-evidence"><summary>识别依据与消息</summary><div id="processing-detail">选择信源查看依据</div></details>`;
 signals.querySelector('.signals-toolbar').before(panel);
 const home=document.createElement('div');home.className='home-chain';home.id='home-chain';home.textContent='检测采集 → 特征识别 → 身份解析 → 测向定位';document.querySelector('.home-summary').after(home);
 const resources=document.createElement('article');resources.className='resource-panel';resources.innerHTML='<div class="section-heading"><h2>平台资源</h2><span>CPU / 内存实时采样 · FPGA静态占用</span></div><div id="resource-stations" class="resource-stations">等待板端资源接口</div><div id="resource-fpga" class="resource-fpga"></div>';
 document.querySelector('[data-page="stations"]').append(resources);
 let feed=null,busy=false,selected=null,pausedFeed=null,pausedEpoch=-1,pausedAt=0;
 const bar=(label,value)=>`<div class="resource-metric"><span>${label}</span><meter min="0" max="100" value="${Number.isFinite(value)?Math.max(0,Math.min(100,value)):0}"></meter><b>${Number.isFinite(value)?fmt(value,1)+'%':'—'}</b></div>`;
 function showDetail(row){selected=row.key;$('processing-evidence').open=true;const r=row.recognition;$('processing-detail').innerHTML=`<h3>${esc(row.mac)} · ${esc(row.ssid||r.label)}</h3><p>${esc(r.scoreMeaning||'结构识别')} · 证据分 ${esc(r.evidenceScore)} / ${esc(r.maxEvidenceScore||100)}</p>${scoreBreakdownHTML(r)}<ul>${r.evidence.map(e=>'<li>'+esc(e)+'</li>').join('')}</ul><p>${esc(r.identityStatus)}；${r.identitySkipped?'已检查协议与身份，未取得RID身份；对该疑似信源调度IQ测向。':'广播内容未经过身份真实性认证。'}</p>${r.messages?.length?'<pre>'+esc(JSON.stringify(r.messages,null,2))+'</pre>':''}`;}
 async function choose(key){if(state.mode!=='external'||state.signalsPaused){toast('请恢复实时列表后再选择测向目标');return;}try{await jsonFetch('/api/pipeline/target',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({sourceKey:key})});toast(key?'已选择该信源，两站等待同源IQ':'已恢复自动选择测向目标');await poll();}catch(e){toast(e.message);}}
 function render(){
  const live=state.mode==='external',latest=live?feed:null,value=live&&state.signalsPaused&&pausedEpoch===state.epoch?pausedFeed:latest;
  const now=state.signalsPaused&&pausedEpoch===state.epoch?pausedAt:Date.now();
  const counts=value?stageCounts(value):[0,0,0,0];
  const homeCounts=latest?stageCounts(latest):[0,0,0,0];$('processing-auto').disabled=!live||state.signalsPaused;
  const skipIdentity=value?.activeSource?.recognition?.identitySkipped===true;
  $('processing-stages').innerHTML=['检测采集','特征识别','身份解析','定位与跟踪'].map((name,i)=>`<div><small>0${i+1}${i===2&&skipIdentity?' · 无RID':''}</small><b>${name}</b><strong>${i===2&&skipIdentity?'无RID':counts[i]}</strong></div>`).join('');
  $('home-chain').textContent=latest?`检测 ${homeCounts[0]} → 候选 ${homeCounts[1]} → 身份 ${homeCounts[2]} → RID直显 / AOA ${homeCounts[3]}`:'检测采集 → 特征识别 → 身份解析 → RID直显 / AOA测向';
  $('processing-active').textContent=live?(value?.activeSource?`当前测向目标：${value.activeSource.mac}${value.selection==='manual'?'（手动指定）':''}`:'当前测向目标：等待可测候选'):'回放界面不控制实机';
  const frequency=value?.coverage?.frequencyMhz,frequencies=value?.coverage?.stationFrequenciesMhz||{};
  const channelLabel=Number.isFinite(frequency)?`${fmt(frequency,0)} MHz`:Object.entries(frequencies).map(([id,f])=>`${id} ${fmt(f,0)} MHz`).join(' / ')||'等待接收频率';
  const scan=value?.coverage?.channelScan;
  $('processing-coverage').textContent=live&&scan?`${scan.mode==='fixed'?'固定信道':'2.4 / 5 GHz逐信道检测'}：${scan.currentChannel?'信道 '+scan.currentChannel+' / '+scan.frequencyMhz+' MHz':'等待切频确认'} · ${scan.channels.length}个信道 · ${scan.state==='tuning'?'切频中':scan.error||'20 MHz被动接收'} · 轮扫期间存在接收间隙。`:live?`实时：${channelLabel} / 20 MHz · ${value?.coverage?.decodedPHY||'OFDM / HT20'} · 当前固定信道接收，尚未启用多频段轮扫。2.4 / 5 GHz及更高频率的历史记录保留在信源历史中。`:'历史/导入记录保留原始频率（包括2.4 / 5 GHz与更高频段）；不代表当前实时扫描';
  const rows=(value?.sources||[]).slice(0,30),active=value?.activeSource?.key;
  $('processing-sources').innerHTML=rows.map((s,i)=>{const r=s.recognition,d=s.direction,age=d?(now-d.timestamp)/1000:Infinity;
   const angles=Object.entries(d?.stations||{}).filter(([,o])=>now-o.timestamp<15000).map(([id,o])=>Number.isFinite(o.angleDeg)?`${id} ${fmt(o.angleDeg,1)}°`:`${id} 相位${fmt(o.phaseDeg,1)}°`).join(' / ');
   return `<tr class="${s.key===active?'active':''}"><td><button class="source-evidence" data-source="${i}">${esc(s.mac)}</button><small>${esc(s.frequencyMhz)} MHz · ${esc(s.ssid||s.receiverStations.join('/'))}${s.fresh?'':' · 过期'}</small></td><td><b>${esc(r.label)}</b><small>${esc([...(s.features?.phy||[]),...(s.features?.protocols||[])].join(' / ')||'PHY待确认 · 802.11')}</small><small>${r.kind==='rid'?'协议结构匹配':'证据分 '+r.evidenceScore+(r.maxEvidenceScore?' / '+r.maxEvidenceScore:'')}</small></td><td>${esc(r.identities.join(' / ')||r.identityStatus)}</td><td>${esc(s.positioning?.method==='rid'?directionStatus(s,now):angles&&age<15?angles+' · '+directionStatus(s,now):s.doaSupported===false?directionStatus(s,now):s.key===active?'AOA采样中':directionStatus(s,now))}</td><td>${s.positioning?.method==='rid'?'<a href="#/monitor">查看地图</a>':r.eligible&&s.fresh&&s.doaSupported!==false?`<button data-track="${i}">AOA测向</button>`:''}</td></tr>`;}).join('')||'<tr><td colspan="5">等待当前信道观测</td></tr>';
  for(const el of $('processing-sources').querySelectorAll('[data-source]'))el.onclick=()=>showDetail(rows[Number(el.dataset.source)]);
  for(const el of $('processing-sources').querySelectorAll('[data-track]')){el.disabled=!live||state.signalsPaused;el.onclick=()=>choose(rows[Number(el.dataset.track)].key);}
  $('resource-stations').innerHTML=(latest?.resources?.stations||[]).map(s=>`<section><h3>站 ${esc(s.id)} <small>${s.available?'在线':'不可用'}</small></h3>${bar('CPU',s.available?s.cpuPercent:null)}${bar('内存',s.available?s.memory?.percent:null)}<small>${s.available?`${s.cpuCount||'—'}核 · 采样间隔 ${fmt(s.sampleIntervalSeconds,1)} s`:'资源接口未接通或数据过期'}</small></section>`).join('')||'等待板端资源接口';
  const fpga=latest?.resources?.fpga;$('resource-fpga').innerHTML=fpgaBuildCards(fpga).map(({label,build})=>`<section class="fpga-build-card"><div><b>${esc(label)}</b><small title="原始Routed报告：${esc(build.reportDate)}">${esc(build.updatedDate||build.reportDate)}${build.updatedDate?' 更新 ·':''} Routed报告 · 静态占用，非实时负载</small></div>${build.metrics.map(m=>bar(m.name,m.percent)).join('')}<p class="muted">${esc(build.buildNote)}</p></section>`).join('');
  const roles=latest?.receiverSelection;
  for(const section of $('resource-stations').children){
   const id=section.querySelector('h3')?.textContent.match(/站 ([AB])/u)?.[1];
   if(!id)continue;const label=document.createElement('p');label.className='receiver-task';
   label.textContent=roles?.confirmed?(id==='A'&&latest?.recognition?.location==='board'?`${latest.recognition.state==='classifying'?'信源识别':'信源识别待命'}＋${roles.selectedStation==='A'?'完整解码＋':''}双RX测向`:(roles.selectedStation===id?'检测／解码＋双RX测向':'双RX测向待命 · 完整解码关闭')):'接收分工待确认';section.append(label);
  }
  if(selected&&!rows.some(s=>s.key===selected)){$('processing-detail').textContent='该信源已不在当前列表；重新选择查看';selected=null;}
 }
 async function poll(){if(busy)return;busy=true;try{feed=await jsonFetch('/api/pipeline');render();}catch(e){feed=null;render();}finally{busy=false;}}
 changes.addEventListener('signals-pause',()=>{pausedEpoch=state.epoch;pausedAt=Date.now();pausedFeed=state.signalsPaused&&feed?structuredClone(feed):null;render();});
 $('processing-auto').onclick=()=>choose(null);poll();setInterval(poll,1500);return {render,snapshot:()=>feed};
}

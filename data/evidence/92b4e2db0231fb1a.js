import {state,setSignalsPaused} from './data.js';
import {esc,fmt,time,jsonFetch,download} from './workspace-core.js';
export const packetKey=row=>`${row.station}:${row.session_id}:${row.id}`;
export function filterPackets(rows,query,protocol='all',station='all'){
 const words=query.trim().toLowerCase().split(/\s+/).filter(Boolean);
 return rows.filter(r=>(protocol==='all'||r.protocol===protocol)&&(station==='all'||r.station===station)&&words.every(q=>JSON.stringify([r.source_mac,r.destination_mac,r.bssid,r.ssid,r.protocol,r.frame_name,r.decoded]).toLowerCase().includes(q)));
}
export function setupSignals({setMode,toast}){
 const main=document.getElementById('app-main');
 const section=document.createElement('section');section.dataset.page='signals';section.className='page signals-page';section.hidden=true;
 section.innerHTML=`<div class="page-heading"><div><p class="kicker">空口数据</p><h1>信源检测</h1></div><div class="button-row"><button id="signals-history">历史采样</button><select id="signals-fcs" aria-label="导入校验格式"><option value="standard">标准抓包</option><option value="device">设备抓包</option></select><label class="button">导入PCAP<input id="signals-import" class="sr-only" type="file" accept=".pcap,.pcapng"></label><button id="signals-export">导出JSON</button><button id="signals-pause">暂停列表</button></div></div><div class="signals-toolbar"><div class="segmented"><button id="signals-packets-tab" aria-pressed="true">帧列表</button><button id="signals-sources-tab" aria-pressed="false">信源汇总</button></div><input id="signals-query" type="search" placeholder="MAC / SSID / IP / 关键字，多词以空格分隔" aria-label="筛选信源"><select id="signals-protocol" aria-label="协议"><option value="all">全部协议</option><option>802.11</option><option>UDP</option><option>TCP</option><option>IPv4</option><option>IPv6</option><option>ARP</option><option>RID</option><option>802.11 Protected</option><option>FCS错误</option></select><select id="signals-station" aria-label="接收站"><option value="all">全部接收站</option><option>A</option><option>B</option><option>文件</option></select></div><div class="signals-summary"><span id="signals-status">设备未连接</span><span id="signals-count">0帧 / 0信源</span></div><div class="signals-workspace"><div class="signals-table-wrap"><table class="signals-table"><thead id="signals-head"></thead><tbody id="signals-body"></tbody></table><p id="signals-empty" class="empty">等待接收数据，或载入历史采样</p></div><aside class="signals-details"><header><h2>帧详情</h2><button id="signals-copy">复制详情</button></header><div id="signals-details"><p class="empty">选择一帧查看解码字段</p></div></aside></div><div class="signals-pagination"><span id="signals-range">—</span><div class="button-row"><button id="signals-prev">上一页</button><span id="signals-page">1</span><button id="signals-next">下一页</button></div></div>`;
 main.append(section);const $=id=>document.getElementById(id);
 const empty=()=>({packets:[],sources:[],stations:[]});
 let live=empty(),archive=null,frozen=null,paused=false,view='packets',selected=null,page=0,sort='observed_at',ascending=false,lastEpoch=-1,active=false,request=null,resuming=false,lastKey='';
 function data(){return paused?frozen:state.mode==='external'?live:state.mode==='replay'?archive||empty():empty();}
 function cancelPoll(){if(request){const old=request;request=null;clearTimeout(old.timer);old.controller.abort();}}
 function load(value,label){if(value?.schema!=='airspace.signals'||value.version!==1||!Array.isArray(value.packets)||value.packets.length>2000||!Array.isArray(value.sources)||value.sources.length>1024)throw new Error('信源记录格式错误');
  if(value.packets.some(r=>!r||!Number.isFinite(r.id)||typeof r.protocol!=='string'||typeof r.frame_hex!=='string'||r.frame_hex.length>512||!/^[0-9a-f]*$/i.test(r.frame_hex))||value.sources.some(r=>!r||typeof r.mac!=='string'))throw new Error('信源记录字段无效');
  setMode('replay');archive=value;archive.label=label;selected=null;page=0;lastKey='';render();}
 async function poll(){
  if(request||paused||!active||state.mode!=='external')return;
  const current={epoch:state.epoch,controller:new AbortController(),timer:null,timedOut:false};request=current;
  const accepts=()=>request===current&&active&&!paused&&state.mode==='external'&&state.epoch===current.epoch;
  current.timer=setTimeout(()=>{if(request===current){current.timedOut=true;current.controller.abort();}},7000);current.timer?.unref?.();
  try{
   const value=await jsonFetch('/api/signals',{signal:current.controller.signal});
   if(!accepts())return;
   if(!Array.isArray(value?.packets)||!Array.isArray(value?.sources))throw new Error('信源快照格式错误');
   live={...value,packets:value.packets.slice(-800),sources:value.sources.slice(-1024)};resuming=false;render();
  }catch(e){if(accepts()&&(!current.controller.signal.aborted||current.timedOut)){resuming=false;live={...live,connected:false,error:current.timedOut?'读取快照超时，等待重试':e.message};render();}}
  finally{clearTimeout(current.timer);if(request===current)request=null;}
 }
 async function history(){try{load(await jsonFetch('records/signal_capture_20261102.json'),'历史空口采样 · 2026-11-02');toast('已载入真实历史抓包');}catch(e){toast(e.message);}}
 function render(){if(lastEpoch!==state.epoch){lastEpoch=state.epoch;cancelPoll();paused=false;frozen=null;resuming=false;live=empty();page=0;clearDetail();lastKey='';setSignalsPaused(false);$('signals-pause').textContent='暂停列表';$('signals-pause').setAttribute('aria-pressed','false');}
  const value=data()||{packets:[],sources:[]};const raw=value.packets||[],sources=value.sources||[];
  $('signals-status').textContent=paused?'列表已暂停 · 仅暂停查看，恢复时读取最新数据':resuming?'正在获取最新快照…':state.mode==='external'?(value.connected?(value.stations?.some(s=>s.mode==='replay')?'数据接口 · 含设备回放':'接收中'):value.error|| (value.stations?.some(s=>s.error?.includes('404'))?'设备接口待更新':'设备未连接')):value.label||'未载入信源记录';
  $('signals-count').textContent=`${raw.length}帧 / ${new Set(sources.map(s=>s.mac)).size}个发送MAC${value.total!=null?' · 累计 '+value.total+'帧':''}`;
  const query=$('signals-query').value,protocol=$('signals-protocol').value,station=$('signals-station').value;
  let rows=view==='packets'?filterPackets(raw,query,protocol,station):sources.filter(r=>(station==='all'||r.station===station)&&query.toLowerCase().trim().split(/\s+/).filter(Boolean).every(q=>JSON.stringify([r.mac,r.ssid,r.bssid]).toLowerCase().includes(q)));
  rows=[...rows].sort((a,b)=>{const x=a[sort]??'',y=b[sort]??'';return (typeof x==='number'&&typeof y==='number'?x-y:String(x).localeCompare(String(y)))*(ascending?1:-1);});
  page=Math.max(0,Math.min(page,Math.ceil(rows.length/100)-1));const slice=rows.slice(page*100,page*100+100);
  const headers=view==='packets'?[['id','序号'],['observed_at','捕获时间'],['station','站'],['frequency_mhz','频率/MHz'],['source_mac','发送MAC'],['destination_mac','接收MAC'],['protocol','协议'],['length','长度'],['frame_name','帧类型 / 摘要']]:[['station','站'],['mac','发送MAC'],['ssid','SSID'],['frequency_mhz','频率/MHz'],['frames','有效帧'],['data_frames','数据帧'],['beacons','Beacon'],['age_seconds','距上次观测/秒'],['mean_driver_rssi','RSSI']];
  const key=JSON.stringify([view,slice,selected,sort,ascending]);if(key!==lastKey){lastKey=key;$('signals-head').innerHTML='<tr>'+headers.map(([k,label])=>`<th><button data-sort="${k}">${label}${sort===k?(ascending?' ↑':' ↓'):''}</button></th>`).join('')+'</tr>';
   for(const button of $('signals-head').querySelectorAll('button'))button.onclick=()=>{ascending=sort===button.dataset.sort?!ascending:false;sort=button.dataset.sort;lastKey='';render();};
   $('signals-body').innerHTML=slice.map((r,index)=>`<tr tabindex="0" data-row="${index}" class="${view==='packets'?(r.fcs_valid===false?'packet-error':r.protocol==='UDP'?'packet-udp':r.frame_type===0?'packet-management':''):''} ${selected===(view==='packets'?packetKey(r):`${r.station}:${r.mac}:${r.frequency_mhz}`)?'selected':''}">${headers.map(([k])=>`<td>${esc(k==='observed_at'?time(r.observed_at):k==='age_seconds'?fmt(r[k],1):k==='frame_name'?`${r.frame_name}${r.decoded?.ip_source?' · '+r.decoded.ip_source+' → '+r.decoded.ip_destination:''}${r.ssid?' · '+r.ssid:''}`:r[k]??'—')}</td>`).join('')}</tr>`).join('');
   for(const row of $('signals-body').children){const select=()=>{const r=slice[Number(row.dataset.row)];selected=view==='packets'?packetKey(r):`${r.station}:${r.mac}:${r.frequency_mhz}`;detail(r);lastKey='';render();};row.onclick=select;row.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();select();}};}
  }
  $('signals-empty').hidden=rows.length>0;$('signals-range').textContent=rows.length?`${page*100+1}–${Math.min(page*100+100,rows.length)} / ${rows.length}`:'暂无匹配数据';$('signals-page').textContent=String(page+1);$('signals-prev').disabled=page===0;$('signals-next').disabled=(page+1)*100>=rows.length;
 }
 let detailValue=null;
 function clearDetail(){selected=null;detailValue=null;$('signals-details').innerHTML='<p class="empty">选择一帧查看解码字段</p>';}
 function detail(row){detailValue=row;const fields=view==='packets'? [['帧类型',row.frame_name],['发送MAC',row.source_mac],['接收MAC',row.destination_mac],['BSSID',row.bssid],['SSID',row.ssid],['频率 / MHz',row.frequency_mhz],['速率 / Mbps',row.rate_mbps],['RSSI（驱动）',row.rssi],['序列号',row.sequence],['重传',row.retry?'是':'否'],['加密',row.protected?'是':'否'],['校验',row.fcs_valid===true?'通过':row.fcs_valid===false?'失败':'未知']]:Object.entries(row);
   $('signals-details').innerHTML=`<dl>${fields.map(([k,v])=>`<div><dt>${esc(k)}</dt><dd>${esc(typeof v==='object'?JSON.stringify(v):v)}</dd></div>`).join('')}</dl>${row.decoded?'<details open><summary>协议解码</summary><pre>'+esc(JSON.stringify(row.decoded,null,2))+'</pre></details>':''}${row.frame_hex?'<details open><summary>帧字节'+(row.hex_truncated?' · 前256字节':'')+'</summary><pre class="frame-hex">'+esc((row.frame_hex.match(/.{1,32}/g)||[]).map((line,i)=>`${(i*16).toString(16).padStart(4,'0')}  ${line.match(/../g).join(' ')}`).join('\n'))+'</pre></details>':''}`;
 }
 $('signals-history').onclick=history;
 $('signals-import').accept='.pcap,.pcapng,.json';
 $('signals-import').onchange=async event=>{try{const file=event.target.files[0];if(!file||file.size>8*1024*1024)throw new Error('请选择8 MiB以内的PCAP/PCAPNG/JSON');const value=file.name.toLowerCase().endsWith('.json')?JSON.parse(await file.text()):await jsonFetch('/api/signals/import?fcs='+$('signals-fcs').value,{method:'POST',headers:{'Content-Type':'application/octet-stream'},body:await file.arrayBuffer(),signal:AbortSignal.timeout(35000)});load(value,file.name);}catch(e){toast(e.message);}finally{event.target.value='';}};
 $('signals-export').onclick=()=>download('空域知微-信源记录.json',data());
 $('signals-copy').onclick=async()=>{if(!detailValue){toast('请先选择一条记录');return;}try{await navigator.clipboard.writeText(JSON.stringify(detailValue,null,2));toast('已复制详情');}catch{toast('剪贴板不可用，可导出JSON');}};
 $('signals-pause').onclick=()=>{
  if(!paused){frozen=structuredClone(data()||empty());paused=true;resuming=false;cancelPoll();}
  else{paused=false;frozen=null;page=0;clearDetail();lastKey='';if(state.mode==='external'){live=empty();resuming=true;}}
  $('signals-pause').textContent=paused?'恢复列表':'暂停列表';$('signals-pause').setAttribute('aria-pressed',String(paused));
  setSignalsPaused(paused);render();if(!paused)poll();
 };
 for(const [id,target] of [['signals-packets-tab','packets'],['signals-sources-tab','sources']])$(id).onclick=()=>{view=target;sort=target==='packets'?'observed_at':'frames';page=0;lastKey='';selected=null;$('signals-packets-tab').setAttribute('aria-pressed',String(target==='packets'));$('signals-sources-tab').setAttribute('aria-pressed',String(target==='sources'));render();};
 for(const id of ['signals-query','signals-protocol','signals-station'])$(id).addEventListener(id==='signals-query'?'input':'change',()=>{page=0;render();});
 $('signals-prev').onclick=()=>{page--;render();};$('signals-next').onclick=()=>{page++;render();};
 setInterval(poll,1500);return {render,activate:value=>{active=value;if(active){render();poll();}else cancelPoll();}};
}

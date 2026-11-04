import {config} from './config.js';
import {updateDOATracks,compatibleDOAScene,recentTrackPoints} from './doa-tracks.js';

export const state = {mode: 'external', epoch: 0, paused: false, signalsPaused:false,replayClock:null, targets: new Map(), doa: null,
  events: [], samples:[], candidates:[], receivers:[], doaTracks:new Map(), doaTargets:new Map(), ridConnected: false, doaConnected: false, lastUpdate: null, ridFeed: null, doaFeed:null};
export const changes = new EventTarget();
export function notify() {changes.dispatchEvent(new Event('change'));}
export function setSignalsPaused(value){state.signalsPaused=value;changes.dispatchEvent(new Event('signals-pause'));}
export const hasPosition = item => Number.isFinite(item?.latitude) && Number.isFinite(item?.longitude)
  && Math.abs(item.latitude) <= 90 && Math.abs(item.longitude) <= 180;
const number = value => Number.isFinite(value) ? value : null;

export function log(kind, message, source) {
  state.events.unshift({time: Date.now(), kind, message, source});
  state.events.length = Math.min(state.events.length, 300);
}
function checkEnvelope(value) {
  if (!value || typeof value.source !== 'string' || typeof value.demo !== 'boolean'
      || !Number.isFinite(value.timestamp)) throw new Error('输入需包含 source、demo 和 Unix 毫秒 timestamp');
  if (value.demo !== false) throw new Error('输入数据的 demo 标记与当前模式不匹配');
}
export function ingestRID(value) {
  checkEnvelope(value);
  if (typeof value.id !== 'string' || !value.id.trim()) throw new Error('RID 需要设备 id');
  const first=state.targets.get(value.id),mac=value.sourceMac?.toLowerCase();
  const trackId=first?.sourceMac&&mac&&first.sourceMac.toLowerCase()!==mac?`${value.id}#${mac}`:value.id;
  if(!state.targets.has(trackId)&&state.targets.size>=500){const oldest=[...state.targets.entries()].reduce((a,b)=>a[1].timestamp<b[1].timestamp?a:b);state.targets.delete(oldest[0]);}
  const previous = state.targets.get(trackId);
  if (previous && value.timestamp < previous.timestamp) return; // Old packets must not rewind tracks.
  const target = {id: value.id,trackId, type: value.type || null, status: value.status || null,
    latitude: number(value.latitude), longitude: number(value.longitude),
    altitude: number(value.altitude), speed: number(value.speed),
    heading: Number.isFinite(value.heading) ? ((value.heading % 360) + 360) % 360 : null,
    timestamp: value.timestamp,positionTimestamp:number(value.positionTimestamp)??value.timestamp, source: value.source, demo: value.demo,
    replay: value.replay === true, sourceMac: value.sourceMac || null, rssi: number(value.rssi),
    rateMbps: number(value.rateMbps), frequencyMhz: number(value.frequencyMhz),
    fcsValid: value.fcsValid ?? null, packets: number(value.packets), observationId: value.observationId || null,
    positionStatus: value.positionStatus || null, referencePosition: value.referencePosition || null,
    receiverStations: value.receiverStations || [], receiver:value.receiver || null,
    history: previous?.history || [], lastLog: previous?.lastLog || 0};
  if (!hasPosition(target)) {target.latitude = null; target.longitude = null;}
  if (hasPosition(target)) {
    const last = target.history.at(-1);
    if (!last || target.latitude !== last.latitude || target.longitude !== last.longitude)
      target.history.push({latitude: target.latitude, longitude: target.longitude, timestamp: target.positionTimestamp,breakBefore:!!last&&target.positionTimestamp-last.timestamp>15000});
    else last.timestamp=Math.max(last.timestamp,target.positionTimestamp);
    target.history = target.history.slice(-config.maxHistory);
  }
  if (!previous) log('目标发现', target.id + ' · 外部输入', target.source);
  else if (hasPosition(target) && target.timestamp - target.lastLog >= 5000) {
    log('位置更新', `${target.id} · ${target.latitude.toFixed(5)}, ${target.longitude.toFixed(5)}`, target.source);
    target.lastLog = target.timestamp;
  }
  state.targets.set(trackId, target);
  remember('rid',value);
  if (!state.ridConnected) log('连接状态', '收到外部 RID 数据', target.source);
  state.ridConnected = true; state.lastUpdate = Math.max(state.lastUpdate || 0, target.timestamp); notify();
}
export function ingestDOA(value) {
  checkEnvelope(value);
  if (!Array.isArray(value.stations)) throw new Error('DOA 需要 stations 数组');
  if (state.doa && value.timestamp < state.doa.timestamp) return;
  const stations = value.stations.map(station => ({
    id: String(station.id), name: station.name || String(station.id),
    latitude: hasPosition(station) ? station.latitude : null, longitude: hasPosition(station) ? station.longitude : null,
    bearing: Number.isFinite(station.bearing) ? ((station.bearing % 360) + 360) % 360 : null,
    bearingCandidates:Array.isArray(station.bearingCandidates)?station.bearingCandidates.filter(p=>Number.isFinite(p.bearingDeg)).slice(0,2).map(p=>({...p,bearingDeg:((p.bearingDeg%360)+360)%360})):[],
    relativeAngle: number(station.relativeAngle),headingDeg:number(station.headingDeg),
    timestamp:number(station.timestamp) ?? value.timestamp,fresh:station.fresh !== false,
    ageSeconds:number(station.ageSeconds),quality:station.quality || null,error:station.error || null,
    rayLengthM:Number.isFinite(station.rayLengthM) ? station.rayLengthM : 4500,
    xM:number(station.xM),yM:number(station.yM),sessionId:station.sessionId || null,
    orientationSource:station.orientationSource || null,sourceVerified:station.sourceVerified === true,
    freshnessVerified:station.freshnessVerified === true,productionAccepted:station.productionAccepted === true,
    antennaSpacingM:number(station.antennaSpacingM),frequencyMhz:number(station.frequencyMhz),calibrationRequired:station.calibrationRequired===true,
    calibrationStatus:station.calibrationStatus||null,geometryVerified:station.geometryVerified===true,sourceMac:station.sourceMac||null,sourceClass:station.sourceClass||null,
    broadcastIdentities:Array.isArray(station.broadcastIdentities)?station.broadcastIdentities.slice(0,4):[],
    angleRejection:station.angleRejection||null,
    referenceError:station.referenceError||null,referenceMatched:typeof station.referenceMatched==='boolean'?station.referenceMatched:null,
    referencePolicy:station.referencePolicy||null,referenceCaptureSessionId:station.referenceCaptureSessionId||null,
    referenceReusedAcrossSessions:station.referenceReusedAcrossSessions===true,
    processingLocation:station.processingLocation||null,subcarrierConcentration:number(station.subcarrierConcentration),
    targetId:station.targetId || null,frameKey:station.frameKey || null,tsf:station.tsf??null,
    coherence:number(station.coherence),phaseDeg:number(station.phaseDeg),gainDifferenceDb:number(station.gainDifferenceDb),
    rawPhaseDeg:number(station.rawPhaseDeg),correctedPhaseDeg:number(station.correctedPhaseDeg),phaseBiasAppliedDeg:number(station.phaseBiasAppliedDeg),referenceKnownAngleDeg:number(station.referenceKnownAngleDeg),
    referenceRepeatabilityPassed:typeof station.referenceRepeatabilityPassed==='boolean'?station.referenceRepeatabilityPassed:null,
    clippedFraction:number(station.clippedFraction),calibrationHash:station.calibrationHash||null,referenceHash:station.referenceHash||null
  }));
  state.doa = {timestamp: value.timestamp, source: value.source, demo: value.demo,
    targetId: value.targetId || null, stations,
    intersection: hasPosition(value.intersection) || (Number.isFinite(value.intersection?.xM) && Number.isFinite(value.intersection?.yM)) ? {...value.intersection} : null,
    intersections:Array.isArray(value.intersections)?value.intersections.filter(p=>hasPosition(p)||(Number.isFinite(p?.xM)&&Number.isFinite(p?.yM))).slice(0,4).map(p=>({...p})):[],
    directionMode:value.directionMode==='full'?'full':'front',midpoint:value.midpoint?{...value.midpoint}:null,
    calibrationStatus:value.calibrationStatus||null,geometryVerified:value.geometryVerified===true,
    intersectionReason:value.intersectionReason || null,anchor:value.anchor || null,precisionValidated:value.precisionValidated === true};
  const observed=stations.filter(s=>s.fresh&&Number.isFinite(s.relativeAngle??s.bearing));
  if(observed.length){remember('doa',value);
    if (!state.doaConnected) log('测向输入', '收到外部测向结果', value.source);
    state.doaConnected = true;state.lastUpdate=Math.max(state.lastUpdate||0,...observed.map(s=>s.timestamp));
  } else state.doaConnected=false;
  for(const [key,saved] of state.doaTargets){if(!compatibleDOAScene(saved,state.doa)){
    state.doaTargets.delete(key);
    for(const [trackKey,track] of state.doaTracks)if(track.targetId===key)state.doaTracks.delete(trackKey);
  }}
  if(state.doa.targetId&&observed.length&&value.connected!==false){
    state.doaTargets.set(state.doa.targetId,structuredClone(state.doa));
    if(state.doaTargets.size>64){const oldest=[...state.doaTargets].sort((a,b)=>a[1].timestamp-b[1].timestamp)[0];
      state.doaTargets.delete(oldest[0]);for(const [key,track] of state.doaTracks)if(track.targetId===oldest[0])state.doaTracks.delete(key);}
  }
  updateDOATracks(state.doaTracks,state.doa,{mode:state.mode,connected:state.doaConnected&&value.connected!==false,now:state.replayClock??Date.now(),maxPoints:config.maxHistory});
  notify();
}
export function setConnection(value) {
  for (const [key, property] of [['rid', 'ridConnected'], ['doa', 'doaConnected']]) {
    if (typeof value[key] === 'boolean' && value[key] !== state[property]) {
      state[property] = value[key];
      log('连接状态', `${key.toUpperCase()} ${value[key] ? '连接建立' : '连接断开'}`, value.source || '外部适配器');
    }
  }
  notify();
}
export function reset(mode) {
  if (!['external','replay'].includes(mode)) throw new Error('未知数据模式');
  state.epoch++; state.replayClock=null;
  state.mode = mode; state.paused = false; state.targets.clear(); state.doa = null; state.doaTracks.clear();state.doaTargets.clear();
  state.events = []; state.ridConnected = false; state.doaConnected = false; state.lastUpdate = null;
  state.ridFeed = null;
  state.doaFeed=null;state.candidates=[];state.samples=[];state.receivers=[];
  log('模式切换', mode==='replay'?'进入历史回放，原始时间保留':'进入真实接入，已清除回放数据', '地面站');setSignalsPaused(false);notify();
}
export function pruneTracks(now=state.replayClock??Date.now()){
  for(const target of state.targets.values())target.history=recentTrackPoints(target.history,now,config.ridTrackRetentionMs);
  for(const [key,track] of state.doaTracks){track.points=recentTrackPoints(track.points,now,config.aoaTrackRetentionMs);if(!track.points.length)state.doaTracks.delete(key);}
  for(const [key,feed] of state.doaTargets)if(now-Math.max(...feed.stations.map(s=>s.timestamp??feed.timestamp))>=config.aoaTrackRetentionMs)state.doaTargets.delete(key);
}
function remember(type,data) {
  if (state.mode==='replay')return;
  state.samples.push({type,data:structuredClone(data)});
  if(state.samples.length>6000)state.samples.splice(0,state.samples.length-6000);
}

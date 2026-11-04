"""Local map server with an optional read-only Ethernet RID bridge."""
import argparse
import json
import os
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit
from rid_bridge import RIDBridge,RIDFleet
from computer_location import read_windows_location
from doa_bridge import DOABridge
from station_config import document as station_document,ConfigConflict
from signal_bridge import SignalBridge,parse_capture,station_urls
from board_recognition_client import BoardRecognitionPipeline,BoardRIDView
from channel_scan import ChannelScanner
from aoa_reference_manager import AOAReferenceManager
from receiver_selection import ReceiverSelection,ReceiverConflict,ReceiverUnavailable

ROOT = Path(__file__).resolve().parent
bridge = RIDBridge()
doa_bridge = DOABridge()
signal_bridge=SignalBridge()
pipeline=None
receiver_selection=None
channel_scanner=None
aoa_reference=None
location_lock = threading.Lock()


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def discard_small_body(self):
        # Drain ordinary rejected control requests before closing the socket;
        # otherwise Windows can reset the connection before the error arrives.
        try:
            pending=int(self.headers.get('Content-Length','0'))
            if 0<pending<=16384:self.rfile.read(pending)
        except ValueError:pass

    def end_headers(self):
        if not urlsplit(self.path).path.startswith(('/api/', '/runtime-config.js')):
            self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def do_GET(self):
        path = unquote(urlsplit(self.path).path)
        if any(part.startswith('.') for part in path.split('/') if part):
            self.send_error(404)
            return
        if path == '/api/health':
            body=b'{"service":"airspace-ground-station","version":1,"available":true}'
            self.send_response(200);self.send_header('Content-Type','application/json; charset=utf-8')
            self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(body)))
            self.end_headers();self.wfile.write(body);return
        if path=='/api/aoa-reference':
            try:
                if not aoa_reference:raise ValueError('AOA基准服务尚未启动')
                self.reply_scan(aoa_reference.snapshot())
            except (ValueError,OSError,KeyError) as exc:self.reply_scan(dict(error=str(exc)),400)
            return
        if path in ('/api/pipeline','/api/resources'):
            value=(pipeline.snapshot() if path=='/api/pipeline' else pipeline.resource_snapshot()) if pipeline else dict(available=False,sources=[],error='处理链尚未启动')
            body=json.dumps(value,ensure_ascii=False).encode('utf-8')
            self.send_response(200);self.send_header('Content-Type','application/json; charset=utf-8')
            self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(body)))
            self.end_headers();self.wfile.write(body);return
        if path == '/api/receivers':
            body=json.dumps(signal_bridge.status(),ensure_ascii=False).encode('utf-8')
            self.send_response(200);self.send_header('Content-Type','application/json; charset=utf-8')
            self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(body)))
            self.end_headers();self.wfile.write(body);return
        if path=='/api/receiver/config':
            value=receiver_selection.snapshot() if receiver_selection else dict(configured=False,selectedStation=None,stations=[])
            body=json.dumps(value,ensure_ascii=False).encode('utf-8')
            self.send_response(200);self.send_header('Content-Type','application/json; charset=utf-8')
            self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(body)))
            self.end_headers();self.wfile.write(body);return
        if path == '/api/channel-scan':
            self.reply_scan(channel_scanner.snapshot() if channel_scanner else dict(state='unavailable'));return
        if path == '/api/signals':
            value=signal_bridge.snapshot();value['channelScan']=channel_scanner.snapshot() if channel_scanner else None
            body=json.dumps(value,ensure_ascii=False).encode('utf-8')
            self.send_response(200);self.send_header('Content-Type','application/json; charset=utf-8')
            self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(body)))
            self.end_headers();self.wfile.write(body);return
        if path == '/runtime-config.js':
            public = {'maptilerKey': os.environ.get('MAPTILER_API_KEY', '').strip(), 'ridBridge': bool(bridge.url)}
            body = ('globalThis.GROUND_STATION_CONFIG = ' + json.dumps(public) + ';\n').encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/javascript; charset=utf-8')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if path == '/api/rid':
            body = json.dumps(bridge.snapshot(), ensure_ascii=False).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if path == '/api/doa':
            body=json.dumps(doa_bridge.snapshot(),ensure_ascii=False).encode('utf-8')
            self.send_response(200); self.send_header('Content-Type','application/json; charset=utf-8')
            self.send_header('Cache-Control','no-store'); self.send_header('Content-Length',str(len(body)))
            self.end_headers(); self.wfile.write(body); return
        if path == '/api/doa/config':
            body=json.dumps(station_document(doa_bridge.path),ensure_ascii=False).encode('utf-8')
            self.send_response(200);self.send_header('Content-Type','application/json; charset=utf-8')
            self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(body)))
            self.end_headers();self.wfile.write(body);return
        super().do_GET()

    def reply_scan(self,value,status=200):
        body=json.dumps(value,ensure_ascii=False).encode('utf8')
        self.send_response(status);self.send_header('Content-Type','application/json; charset=utf-8')
        self.send_header('Cache-Control','no-store')
        self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(body)))
        self.end_headers();self.wfile.write(body)

    def do_POST(self):
        route=urlsplit(self.path).path
        if route not in ('/api/computer-location','/api/doa/config','/api/signals/import','/api/pipeline/target','/api/receiver/config','/api/channel-scan','/api/aoa-reference'):
            self.send_error(404)
            return
        origin = self.headers.get('Origin')
        allowed = ('http://127.0.0.1:%d' % self.server.server_port,
                   'http://localhost:%d' % self.server.server_port)
        if origin and origin not in allowed:
            self.discard_small_body()
            self.send_error(403)
            return
        if route=='/api/aoa-reference':
            try:
                size=int(self.headers.get('Content-Length','0'))
                if not aoa_reference or not 0<size<=16384:raise ValueError('基准服务不可用或请求过大')
                self.reply_scan(aoa_reference.action(json.loads(self.rfile.read(size))))
            except (ValueError,TypeError,KeyError,OSError) as exc:self.reply_scan(dict(error=str(exc)),400)
            return
        if pipeline and getattr(pipeline,'reference_capture',False) and route in ('/api/channel-scan','/api/doa/config','/api/pipeline/target','/api/receiver/config'):
            self.discard_small_body()
            self.reply_scan(dict(error='正在采集或应用AOA基准，请完成或取消后再修改接收与布站'),409);return
        if route=='/api/channel-scan':
            try:
                size=int(self.headers.get('Content-Length','0'))
                if not channel_scanner or not 0<size<=512:raise ValueError('扫描配置不可用或请求过大')
                self.reply_scan(channel_scanner.configure(json.loads(self.rfile.read(size))))
            except (ValueError,TypeError,KeyError) as exc:self.reply_scan(dict(error=str(exc)),400)
            return
        if route=='/api/receiver/config':
            try:
                length=int(self.headers.get('Content-Length','0'))
                if not receiver_selection or not 0<length<=256:raise ValueError('接收控制不可用或请求过大')
                value=json.loads(self.rfile.read(length))
                if not isinstance(value,dict) or set(value)!={'selectedStation','revision'} or type(value['revision']) is not int:raise ValueError('Invalid receiver selection')
                result=receiver_selection.apply(value['selectedStation'],value['revision'])
                body=json.dumps(result,ensure_ascii=False).encode('utf-8')
            except ReceiverConflict as exc:self.send_error(409,'Receiver conflict',str(exc));return
            except ReceiverUnavailable as exc:self.send_error(503,'Receiver switch failed',str(exc));return
            except (ValueError,TypeError,KeyError) as exc:self.send_error(400,'Invalid receiver selection',str(exc));return
            self.send_response(200);self.send_header('Content-Type','application/json; charset=utf-8')
            self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body);return
        if route=='/api/pipeline/target':
            try:
                length=int(self.headers.get('Content-Length','0'))
                if not pipeline or not 0<length<=1024:raise ValueError('处理链不可用或请求过大')
                value=json.loads(self.rfile.read(length))
                if not isinstance(value,dict):raise ValueError('请求必须为对象')
                pipeline.choose(value.get('sourceKey'))
                body=json.dumps(dict(ok=True),ensure_ascii=False).encode('utf-8')
            except (ValueError,TypeError,KeyError) as exc:self.send_error(400,'Invalid target',str(exc));return
            self.send_response(200);self.send_header('Content-Type','application/json; charset=utf-8');self.send_header('Content-Length',str(len(body)))
            self.end_headers();self.wfile.write(body);return
        if route=='/api/signals/import':
            try:
                length=int(self.headers.get('Content-Length','0'))
                if not 0<length<=8*1024*1024:raise ValueError('抓包文件超过8 MiB或为空')
                from urllib.parse import parse_qs
                mode=parse_qs(urlsplit(self.path).query).get('fcs',['standard'])[0]
                if mode not in ('standard','device'):raise ValueError('未知校验格式')
                importer=pipeline.import_capture if pipeline and hasattr(pipeline,'import_capture') else parse_capture
                value=importer(self.rfile.read(length),openwifi=mode=='device')
                body=json.dumps(value,ensure_ascii=False).encode('utf-8')
            except (ValueError,TypeError,KeyError,IndexError) as exc:
                self.send_error(400,'Invalid capture',str(exc));return
            self.send_response(200);self.send_header('Content-Type','application/json; charset=utf-8')
            self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body);return
        if route=='/api/doa/config':
            try:
                length=int(self.headers.get('Content-Length','0'))
                if not 0<length<=16384: raise ValueError('配置大小不正确')
                value=doa_bridge.configure(json.loads(self.rfile.read(length)))
                body=json.dumps(value,ensure_ascii=False).encode('utf-8')
            except ConfigConflict as exc:
                self.send_error(409,'Configuration conflict',str(exc));return
            except (ValueError,TypeError,KeyError) as exc:
                self.send_error(400,'Invalid DOA configuration',str(exc)); return
            self.send_response(200); self.send_header('Content-Type','application/json; charset=utf-8')
            self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body); return
        if not location_lock.acquire(blocking=False):
            value = dict(available=False, error='正在读取系统位置，请稍后重试')
        else:
            try:
                value = read_windows_location()
            finally:
                location_lock.release()
        body = json.dumps(value, ensure_ascii=False).encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--board-url', default=os.environ.get('OPENWIFI_RID_URL'))
    parser.add_argument('--port', type=int, default=18770)
    parser.add_argument('--doa-config',type=Path,help='Optional isolated station configuration, e.g. for offline acceptance')
    args = parser.parse_args()
    if args.doa_config:doa_bridge=DOABridge(args.doa_config)
    urls=station_urls(doa_bridge.config(),args.board_url)
    selection_path=(args.doa_config.parent/'receiver_config.json') if args.doa_config else ROOT/'runtime/receiver_config.json'
    receiver_selection=ReceiverSelection(urls,selection_path)
    signal_bridge=SignalBridge(urls,receiver_selection)
    pipeline=BoardRecognitionPipeline(signal_bridge,doa_bridge)
    bridge=BoardRIDView(pipeline)
    channel_scanner=ChannelScanner(pipeline.url_by_station,selection_path.with_name('channel_scan.json'),receiver_selection)
    pipeline.scanner=channel_scanner
    aoa_reference=AOAReferenceManager(pipeline,channel_scanner,doa_bridge,ROOT)
    doa_bridge.set_diagnostic_target(None)
    server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    if bridge.url:
        threading.Thread(target=bridge.run, daemon=True).start()
    threading.Thread(target=doa_bridge.run,daemon=True).start()
    threading.Thread(target=signal_bridge.run,daemon=True).start()
    threading.Thread(target=pipeline.run,daemon=True).start()
    threading.Thread(target=receiver_selection.run,daemon=True).start()
    print('AEROSCOPE: http://127.0.0.1:%d/ (Ctrl+C to stop)' % args.port, flush=True)
    print('Map provider: ' + ('MapTiler' if os.environ.get('MAPTILER_API_KEY') else 'OpenStreetMap / Esri'), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        bridge.stop.set()
        doa_bridge.stop.set()
        signal_bridge.stop.set()
        pipeline.stop.set()
        receiver_selection.stop.set()
        server.server_close()

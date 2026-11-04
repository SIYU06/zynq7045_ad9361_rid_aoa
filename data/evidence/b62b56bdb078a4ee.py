import datetime
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import sys
import zlib

sys.dont_write_bytecode = True
root = Path(__file__).resolve().parent.parent
path = root / 'tmp' / 'esp32_gps(1).pcapng'
raw = path.read_bytes()
spec = importlib.util.spec_from_file_location('rid_decoder', root / 'rid_receiver' / 'decoder.py')
decoder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(decoder)
result = {'file': str(path), 'size': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(),
          'scapy_available': importlib.util.find_spec('scapy') is not None,
          'blocks': [], 'interfaces': [], 'packets': []}


def options(data):
    output = []
    offset = 0
    while offset + 4 <= len(data):
        code, length = struct.unpack_from('<HH', data, offset)
        offset += 4
        if code == 0:
            break
        value = data[offset:offset + length]
        output.append((code, value))
        offset += (length + 3) & ~3
    return output


offset = 0
while offset < len(raw):
    kind, length = struct.unpack_from('<II', raw, offset)
    assert length >= 12 and length % 4 == 0 and offset + length <= len(raw)
    assert struct.unpack_from('<I', raw, offset + length - 4)[0] == length
    body = raw[offset + 8:offset + length - 4]
    result['blocks'].append({'offset': offset, 'type': kind, 'length': length})
    if kind == 0x0a0d0d0a:
        assert body[:4] == bytes.fromhex('4d3c2b1a')
        result['section_options'] = {str(k): v.decode('utf-8', 'replace') for k, v in options(body[16:])}
    elif kind == 1:
        linktype, reserved, snaplen = struct.unpack_from('<HHI', body)
        opts = dict(options(body[8:]))
        resolution = opts.get(9, b'\x06')[0]
        unit = (2 ** -(resolution & 127)) if resolution & 128 else 10 ** -resolution
        result['interfaces'].append({'linktype': linktype, 'snaplen': snaplen,
                                     'name': opts.get(2, b'').decode(), 'timestamp_unit_seconds': unit})
    elif kind == 6:
        iface, hi, lo, caplen, origlen = struct.unpack_from('<IIIII', body)
        packet = body[20:20 + caplen]
        assert len(packet) == caplen
        ticks = (hi << 32) | lo
        seconds = ticks * result['interfaces'][iface]['timestamp_unit_seconds']
        parsed = {'interface': iface, 'captured_length': caplen, 'original_length': origlen,
                  'capture_time_utc': datetime.datetime.fromtimestamp(seconds, datetime.timezone.utc).isoformat(),
                  'capture_time_shanghai': datetime.datetime.fromtimestamp(seconds, datetime.timezone(datetime.timedelta(hours=8))).isoformat()}
        version, pad, rtlen = struct.unpack_from('<BBH', packet)
        assert version == 0
        bitmaps, cursor = [], 4
        while True:
            bitmap = struct.unpack_from('<I', packet, cursor)[0]
            bitmaps.append(bitmap)
            cursor += 4
            if not bitmap & 0x80000000:
                break
        # Decode only the initial standard fields present in this capture;
        # later namespace/extension fields are outside this inspection's scope.
        sizes = {0: (8, 8), 1: (1, 1), 2: (1, 1), 3: (2, 4), 5: (1, 1), 14: (2, 2)}
        rt = {'length': rtlen, 'present_words': [hex(v) for v in bitmaps]}
        for field in range(15):
            if not bitmaps[0] & (1 << field):
                continue
            alignment, size = sizes[field]
            cursor = (cursor + alignment - 1) & ~(alignment - 1)
            value = packet[cursor:cursor + size]
            cursor += size
            if field == 0:
                rt['tsft_us'] = int.from_bytes(value, 'little')
            elif field == 1:
                rt['flags_hex'] = value.hex()
                rt['fcs_included'] = bool(value[0] & 0x10)
                rt['bad_fcs_flag'] = bool(value[0] & 0x40)
            elif field == 2:
                rt['rate_mbps'] = value[0] * .5
            elif field == 3:
                freq, flags = struct.unpack('<HH', value)
                rt.update(frequency_mhz=freq, channel_flags_hex=hex(flags),
                          channel_ofdm=bool(flags & 0x40), channel_2ghz=bool(flags & 0x80))
            elif field == 5:
                rt['signal_dbm'] = int.from_bytes(value, 'little', signed=True)
            elif field == 14:
                rt['rx_flags_hex'] = value.hex()
        parsed['radiotap'] = rt
        frame = packet[rtlen:]
        if rt['fcs_included']:
            stored = struct.unpack('<I', frame[-4:])[0]
            frame = frame[:-4]
            computed = zlib.crc32(frame) & 0xffffffff
            parsed.update(fcs_stored_hex=hex(stored), fcs_computed_hex=hex(computed), fcs_valid=stored == computed)
        parsed['dot11_without_fcs_hex'] = frame.hex()
        parsed['dot11_length_without_fcs'] = len(frame)
        parsed['frame_control_hex'] = frame[:2].hex()
        for name, start in [('destination', 4), ('source', 10), ('bssid', 16)]:
            parsed[name] = ':'.join('%02x' % b for b in frame[start:start + 6])
        parsed['sequence_control'] = struct.unpack_from('<H', frame, 22)[0]
        tsf, interval, capability = struct.unpack_from('<QHH', frame, 24)
        parsed.update(beacon_timestamp_us=tsf, beacon_interval_tu=interval,
                      beacon_interval_seconds=interval * .001024, capability_hex=hex(capability))
        ies, pos = [], 36
        while pos + 2 <= len(frame):
            tag, size = frame[pos:pos + 2]
            pos += 2
            value = frame[pos:pos + size]
            assert len(value) == size
            pos += size
            entry = {'tag': tag, 'length': size, 'hex': value.hex()}
            if tag == 0:
                entry['ssid'] = value.decode('utf-8', 'replace')
            if tag == 1:
                entry['rates'] = [{'mbps': (b & 127) * .5, 'basic': bool(b & 128)} for b in value]
            ies.append(entry)
        assert pos == len(frame)
        parsed['information_elements'] = ies
        events = decoder.extract_frame(frame)
        for event in events:
            event['messages'] = decoder.decode_payload(event['payload'])
            event['payload'] = event['payload'].hex()
        parsed['rid_events'] = events
        result['packets'].append(parsed)
    elif kind == 5:
        result['interface_statistics_options'] = {str(k): v.hex() for k, v in options(body[12:])}
    offset += length
print(json.dumps(result, indent=2, ensure_ascii=False))

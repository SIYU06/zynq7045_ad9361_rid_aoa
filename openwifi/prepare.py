"""Prepare locked, disposable Windows build sources. Upstream checkouts stay intact."""
import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UP = ROOT / 'upstream'
STAGE = ROOT / 'ow'
HERE = Path(__file__).resolve().parent


def git(repo, *args):
    return subprocess.check_output(['git', '-c', 'safe.directory=' + repo.as_posix(),
                                    '-C', str(repo), *args], text=True).strip()


def main():
    lock = json.loads((HERE / 'sources.lock.json').read_text())
    for key, rel in [('openwifi_hw', 'openwifi-hw'), ('openwifi', 'openwifi'),
                     ('adi_hdl', 'openwifi-hw/adi-hdl'),
                     ('openofdm', 'openwifi-hw/ip/openofdm_rx')]:
        actual = git(UP / rel, 'rev-parse', 'HEAD')
        if actual != lock[key]['commit']:
            raise SystemExit('Version mismatch for {}: {}'.format(key, actual))
    if STAGE.exists():
        write_board()
        print('Refreshed board inputs; existing packaged IP retained.')
        return
    STAGE.mkdir()
    shutil.copytree(UP / 'openwifi-hw/ip', STAGE / 'ip',
                    ignore=shutil.ignore_patterns('.git', '*.png', '*.jpg', '*.pdf'))
    shutil.copytree(UP / 'openwifi-hw/adi-hdl/library', STAGE / 'adi-hdl/library')
    shutil.copytree(UP / 'openwifi-hw/adi-hdl/scripts', STAGE / 'adi-hdl/scripts')
    shutil.copytree(UP / 'openwifi-hw/adi-hdl/projects/scripts', STAGE / 'adi-hdl/projects/scripts')
    helper = STAGE / 'adi-hdl/library/scripts/adi_ip_xilinx.tcl'
    helper.write_text(helper.read_text().replace(
        'add_files -norecurse -scan_for_includes -fileset',
        'add_files -norecurse -fileset'))
    # ADI packaging resolves project version/environment through scripts/adi_env.tcl.
    for name in ['LICENSE', 'LICENSE_ADIBSD', 'LICENSE_GPL2']:
        p = UP / 'openwifi-hw/adi-hdl' / name
        if p.is_file():
            shutil.copy2(p, STAGE / 'adi-hdl' / name)
    for name in ['parse_board_name.tcl', 'openofdm_rx/parse_board_name.tcl']:
        p = STAGE / 'ip' / name
        s = p.read_text()
        # Keep Zynq-7000 large-FPGA defaults, add an explicit board identity.
        s = s.replace('if {$BOARD_NAME=="zed_fmcs2"}',
            'if {$BOARD_NAME=="an_xc7z045"} {\n'
            ' set ultra_scale_flag 0\n set part_string "xc7z045fbg676-1"\n'
            ' set board_part_string []\n set board_id_string []\n'
            ' set fpga_size_flag 1\n} elseif {$BOARD_NAME=="zed_fmcs2"}', 1)
        p.write_text(s)
    # Replace shell revision helpers only in generated sources; preserve real revisions.
    for p in (STAGE / 'ip').glob('*/*.tcl'):
        s = p.read_text()
        rev = lock['openofdm' if p.parent.name == 'openofdm_rx' else 'openwifi_hw']['commit'][:8]
        s = re.sub(r'set HASHCODE \[exec (?:bash )?[^\]\n]*get_git_rev\.sh\]',
                   'set HASHCODE ' + rev, s)
        p.write_text(s)
    write_board()


def write_board():
    b = STAGE / 'board'
    (b / 'src').mkdir(parents=True, exist_ok=True)
    ref = UP / 'openwifi-hw/boards/zc706_fmcs2/src/system.bd'
    d = json.loads(ref.read_text())
    d['design']['design_info']['device'] = 'xc7z045fbg676-1'
    (b / 'src/system.bd').write_text(json.dumps(d, indent=2))
    shutil.copy2(HERE / 'system_top.v', b / 'src/system_top.v')
    shutil.copy2(HERE / 'board.xdc', b / 'src/board.xdc')
    shutil.copy2(UP / 'openwifi-hw/boards/zc706_fmcs2/src/system.xdc', b / 'src/openwifi_timing.xdc')
    # PS board settings come from the user's RF project; AXI/clock fabric stays upstream.
    rf = ROOT.parent / 'ofdm_80211n_2r2t_v1/ofdm_80211n_2r2t_v1.srcs/sources_1/src/bd/system/system.bd'
    params = json.loads(rf.read_text())['design']['components']['processing_system7_0']['parameters']
    selected = {}
    for k, v in params.items():
        if (re.fullmatch(r'PCW_UIPARAM_DDR_(PARTNO|BUS_WIDTH|FREQ_MHZ|USE_INTERNAL_VREF|TRAIN_.*|DQS_TO_CLK_DELAY_[0-3]|BOARD_DELAY[0-3])', k) or
            re.fullmatch(r'PCW_MIO_[0-9]+_(IOTYPE|PULLUP|SLEW)', k) or
            k.startswith('PCW_PRESET_BANK') or k.startswith('PCW_SD0_') or
            k.startswith('PCW_UART1_') or k.startswith('PCW_ENET0_') or
            k.startswith('PCW_QSPI_') or k == 'PCW_CRYSTAL_PERIPHERAL_FREQMHZ'):
            selected[k] = v['value']
    # Schematic p12/p15: both PS banks 1.8V; p12: SD0 MIO40..45, UART1 48..49,
    # GEM0 RGMII 16..27, MDIO 52..53, PHY reset MIO8.
    selected.update({
        'PCW_PRESET_BANK0_VOLTAGE': 'LVCMOS 1.8V',
        'PCW_PRESET_BANK1_VOLTAGE': 'LVCMOS 1.8V',
        'PCW_PACKAGE_NAME': 'fbg676',
        'PCW_CRYSTAL_PERIPHERAL_FREQMHZ': '33.333333',
        'PCW_UART0_PERIPHERAL_ENABLE': '0',
        'PCW_UART1_PERIPHERAL_ENABLE': '1', 'PCW_UART1_UART1_IO': 'MIO 48 .. 49',
        'PCW_SD0_PERIPHERAL_ENABLE': '1', 'PCW_SD0_SD0_IO': 'MIO 40 .. 45',
        'PCW_SD0_GRP_WP_ENABLE': '0', 'PCW_SD0_GRP_CD_ENABLE': '0',
        'PCW_ENET0_PERIPHERAL_ENABLE': '1', 'PCW_ENET0_ENET0_IO': 'MIO 16 .. 27',
        'PCW_ENET0_GRP_MDIO_ENABLE': '1', 'PCW_ENET0_GRP_MDIO_IO': 'MIO 52 .. 53',
        'PCW_ENET0_PERIPHERAL_FREQMHZ': '1000 Mbps',
        'PCW_ENET_RESET_ENABLE': '0', 'PCW_ENET0_RESET_ENABLE': '0',
        'PCW_USB0_PERIPHERAL_ENABLE': '0', 'PCW_SPI1_PERIPHERAL_ENABLE': '0',
        'PCW_SPI0_PERIPHERAL_ENABLE': '1', 'PCW_SPI0_SPI0_IO': 'EMIO',
        'PCW_GPIO_EMIO_GPIO_ENABLE': '1', 'PCW_GPIO_EMIO_GPIO_IO': '64',
        'PCW_I2C0_PERIPHERAL_ENABLE': '0', 'PCW_I2C1_PERIPHERAL_ENABLE': '0',
    })
    # Generated setting list is Tcl data, never executable shell text.
    lines = ['set board_ps_settings {']
    lines += ['  CONFIG.{} {{{}}}'.format(k, v) for k, v in sorted(selected.items())]
    lines += ['}']
    (b / 'ps_settings.tcl').write_text('\n'.join(lines) + '\n')
    cfg = b / 'ip_config'
    cfg.mkdir(exist_ok=True)
    for name in ['xpu', 'tx_intf', 'rx_intf', 'openofdm_tx', 'openofdm_rx', 'side_ch']:
        (cfg / (name + '_pre_def.v')).write_text('`define an_xc7z045\n')
    # Backup the editable project inputs once, before any Vivado project mutation.
    backup = ROOT / 'baseline_before_openwifi'
    backup.mkdir(exist_ok=True)
    paths = ['dma_project.xpr', 'dma_project.srcs/sources_1/bd/system/system.bd']
    manifest = {}
    for rel in paths:
        src = ROOT / 'dma_project' / rel
        target = backup / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            shutil.copy2(src, target)
        manifest[rel] = hashlib.sha256(target.read_bytes()).hexdigest()
    (backup / 'sha256.json').write_text(json.dumps(manifest, indent=2))
    print('Prepared locked sources at', STAGE)


if __name__ == '__main__':
    main()

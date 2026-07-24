# Copyright 2026 NXP
#
# SPDX-License-Identifier: Apache-2.0
"""Board/device core-data resolver for west build/boards.

Core validity comes from device ``chip.yml`` ``core[].id``, not from
``example.yml`` ``boards:`` keys. Single- vs multi-core is the count of
``chip.yml`` ``core[]`` entries.
"""

import glob
import os
import sys

import yaml

_SDK_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__))))


def _warn(msg):
    print(f'core_data: warning: {msg}', file=sys.stderr)

# classify_core_id result codes
OK = 'ok'
SINGLE_CORE_HAS_COREID = 'single_core_has_coreid'
INVALID_COREID = 'invalid_coreid'
UNRESOLVED = 'unresolved'

_PARALLEL_MIN_FILES = 24


def _relpath(path, sdk_root):
    return os.path.relpath(path, sdk_root).replace(os.sep, '/')


def _parse_chip_file(path):
    """Parse one chip.yml -> (core_ids, [(part, folder)], full_name)."""
    folder = os.path.basename(os.path.dirname(path))
    try:
        with open(path, 'r', encoding='utf-8') as fh:
            data = yaml.safe_load(fh)
    except (OSError, yaml.YAMLError) as exc:
        _warn(f'failed to parse {path}: {exc}')
        return ([], [], None)
    core_ids = []
    full_name = None
    parts = []
    for dev in _devices(data):
        cores = [c.get('id') for c in (dev.get('core') or []) if c.get('id')]
        if cores and not core_ids:
            core_ids = cores
            full_name = dev.get('full_name') or dev.get('name') or folder
        for p in (dev.get('part') or []):
            if p.get('name'):
                parts.append((p['name'], folder))
    return (core_ids, parts, full_name)


def _index_chip_files(sdk_root):
    """Return {device_folder: chip.yml path}, devices_int overriding devices."""
    files_by_folder = {}
    for root in ('devices', 'devices_int'):
        base = os.path.join(sdk_root, root)
        if not os.path.isdir(base):
            continue
        for path in glob.glob(os.path.join(base, '**', 'chip.yml'), recursive=True):
            files_by_folder[os.path.basename(os.path.dirname(path))] = path
    return files_by_folder


def _map_parse(files, parallel, workers):
    if parallel and len(files) >= _PARALLEL_MIN_FILES:
        try:
            from concurrent.futures import ProcessPoolExecutor
            with ProcessPoolExecutor(max_workers=workers) as ex:
                return list(ex.map(_parse_chip_file, files, chunksize=16))
        except Exception:
            pass
    return [_parse_chip_file(f) for f in files]


def build_index(sdk_root=None, parallel=True, workers=None):
    """One-pass lookup index over all chip.yml files.

    Returns {'device_cores', 'device_root', 'device_full_name', 'part_to_device'}.
    Pass as ``index=`` to the per-board helpers to avoid re-scanning per board.
    """
    sdk_root = sdk_root or _SDK_ROOT
    files_by_folder = _index_chip_files(sdk_root)
    folders = list(files_by_folder.keys())
    paths = [files_by_folder[f] for f in folders]
    results = _map_parse(paths, parallel, workers)
    device_cores_map = {}
    device_root_map = {}
    device_full_name_map = {}
    part_to_device = {}
    for folder, path, (core_ids, parts, full_name) in zip(folders, paths, results):
        if core_ids:
            device_cores_map[folder] = core_ids
            device_root_map[folder] = _relpath(os.path.dirname(path), sdk_root)
            device_full_name_map[folder] = full_name or folder
        for part, fol in parts:
            part_to_device.setdefault(part, fol)
    return {'device_cores': device_cores_map,
            'device_root': device_root_map,
            'device_full_name': device_full_name_map,
            'part_to_device': part_to_device}


def _devices(item):
    try:
        return item['device.hardware_data']['contents']['devices'] or []
    except (KeyError, TypeError):
        return []


def _find_device_entry(device_id, sdk_root):
    """Return (dev_dict, chip_yml_path) for device_id, or (None, None)."""
    for root in ('devices_int', 'devices'):
        matches = glob.glob(os.path.join(sdk_root, root, '**', device_id, 'chip.yml'),
                            recursive=True)
        for path in matches:
            try:
                with open(path, 'r', encoding='utf-8') as fh:
                    data = yaml.safe_load(fh)
            except (OSError, yaml.YAMLError) as exc:
                _warn(f'failed to parse {path}: {exc}')
                continue
            devs = _devices(data)
            exact = [d for d in devs if d.get('id') == device_id]
            for dev in (exact or devs):
                core_ids = [c.get('id') for c in (dev.get('core') or []) if c.get('id')]
                if core_ids:
                    return dev, path
    return None, None


def device_cores(device_id, sdk_root=None, index=None):
    """Return {'single': bool, 'core_ids': [...]} for device_id, or None."""
    if index is not None:
        core_ids = index['device_cores'].get(device_id)
        if not core_ids:
            return None
        return {'single': len(core_ids) == 1, 'core_ids': core_ids}
    sdk_root = sdk_root or _SDK_ROOT
    dev, _path = _find_device_entry(device_id, sdk_root)
    if dev is None:
        return None
    core_ids = [c.get('id') for c in (dev.get('core') or []) if c.get('id')]
    return {'single': len(core_ids) == 1, 'core_ids': core_ids}


def device_meta(device_id, sdk_root=None, index=None):
    """Return {'root': relpath, 'full_name': str} for device_id, or None."""
    if index is not None:
        if device_id not in index['device_cores']:
            return None
        return {'root': index['device_root'].get(device_id),
                'full_name': index['device_full_name'].get(device_id)}
    sdk_root = sdk_root or _SDK_ROOT
    dev, path = _find_device_entry(device_id, sdk_root)
    if dev is None:
        return None
    full_name = dev.get('full_name') or dev.get('name') or device_id
    return {'root': _relpath(os.path.dirname(path), sdk_root), 'full_name': full_name}


def _marketing_data_roots(sdk_root):
    """Ordered board/device metadata roots to probe (first match wins)."""
    mir_root = os.path.join(sdk_root, 'MIR', 'marketing_data', '1.0')
    roots = [mir_root] if os.path.isdir(mir_root) else []
    roots.append(os.path.join(sdk_root, 'tool_data'))
    return roots


def _read_yaml_first(paths):
    """Return parsed YAML from the first readable path, or None."""
    for path in paths:
        try:
            with open(path, 'r', encoding='utf-8') as fh:
                return yaml.safe_load(fh) or {}
        except FileNotFoundError:
            continue
        except (OSError, yaml.YAMLError) as exc:
            _warn(f'failed to read {path}: {exc}')
            continue
    return None


def _device_from_marketing_data(board, sdk_root):
    paths = [os.path.join(r, 'boards', board + '.yml') for r in _marketing_data_roots(sdk_root)]
    data = _read_yaml_first(paths)
    if not data:
        return None
    for part in (data.get('parts') or []):
        dev = part.get('device')
        if dev:
            return dev
    return None


def _device_from_prj_conf(board, sdk_root, index=None):
    """Fallback: board prj.conf part -> chip.yml part[].name -> device id."""
    for root in ('examples', 'examples_int'):
        prj = os.path.join(sdk_root, root, '_boards', board, 'prj.conf')
        part = None
        try:
            with open(prj, 'r', encoding='utf-8') as fh:
                for line in fh:
                    line = line.strip()
                    if line.startswith('CONFIG_MCUX_HW_DEVICE_PART_') and line.endswith('=y'):
                        part = line[len('CONFIG_MCUX_HW_DEVICE_PART_'):-len('=y')]
                        break
        except OSError:
            continue
        if not part:
            continue
        dev = (index['part_to_device'].get(part) if index is not None
               else _device_for_part(part, sdk_root))
        if dev:
            return dev
    return None


def _device_for_part(part_name, sdk_root):
    for droot in ('devices_int', 'devices'):
        for path in glob.glob(os.path.join(sdk_root, droot, '**', 'chip.yml'), recursive=True):
            try:
                with open(path, 'r', encoding='utf-8') as fh:
                    data = yaml.safe_load(fh)
            except (OSError, yaml.YAMLError):
                continue
            for dev in _devices(data):
                names = [p.get('name') for p in (dev.get('part') or [])]
                if part_name in names:
                    return dev.get('id')
    return None


def scan_boards(sdk_root=None):
    """Return {board_name: relpath}, gated on variable.cmake presence."""
    sdk_root = sdk_root or _SDK_ROOT
    boards = {}
    for root in ('examples', 'examples_int'):
        for path in glob.glob(os.path.join(sdk_root, root, '_boards', '*')):
            if os.path.isfile(os.path.join(path, 'variable.cmake')):
                boards[os.path.basename(path)] = _relpath(path, sdk_root)
    return boards


def list_boards(sdk_root=None):
    return sorted(scan_boards(sdk_root or _SDK_ROOT).keys())


def _board_full_name(board, sdk_root):
    paths = [os.path.join(r, 'boards', board + '.yml') for r in _marketing_data_roots(sdk_root)]
    data = _read_yaml_first(paths)
    return (data or {}).get('name')


def board_meta(board, sdk_root=None, board_dirs=None):
    """Return {'root': relpath, 'full_name': str} for board, or None."""
    sdk_root = sdk_root or _SDK_ROOT
    if board_dirs is not None:
        root = board_dirs.get(board)
    else:
        root = None
        for r in ('examples', 'examples_int'):
            path = os.path.join(sdk_root, r, '_boards', board)
            if os.path.isfile(os.path.join(path, 'variable.cmake')):
                root = _relpath(path, sdk_root)
                break
    if root is None:
        return None
    return {'root': root, 'full_name': _board_full_name(board, sdk_root) or board}


def board_info(board, sdk_root=None, index=None, board_dirs=None):
    """Return board/device identity and core data for board.

    Keys: board, board_root, board_full_name, device, device_root,
    device_full_name, single, core_ids.
    """
    sdk_root = sdk_root or _SDK_ROOT
    device = resolve_device(board, sdk_root, index=index)
    dcores = device_cores(device, sdk_root, index=index) if device else None
    dmeta = device_meta(device, sdk_root, index=index) if device else None
    bmeta = board_meta(board, sdk_root, board_dirs=board_dirs)
    return {
        'board': board,
        'board_root': bmeta['root'] if bmeta else None,
        'board_full_name': bmeta['full_name'] if bmeta else None,
        'device': device,
        'device_root': dmeta['root'] if dmeta else None,
        'device_full_name': dmeta['full_name'] if dmeta else None,
        'single': dcores['single'] if dcores else None,
        'core_ids': dcores['core_ids'] if dcores else [],
    }


def resolve_device(board, sdk_root=None, index=None):
    """Resolve a board name to its device id, or None."""
    sdk_root = sdk_root or _SDK_ROOT
    board = board.split('@', 1)[0] if board else board
    if not board:
        return None
    if index is not None:
        return (_device_from_prj_conf(board, sdk_root, index=index)
                or _device_from_marketing_data(board, sdk_root))
    return (_device_from_marketing_data(board, sdk_root)
            or _device_from_prj_conf(board, sdk_root, index=index))


def classify_core_id(core_id, board=None, device=None, sdk_root=None):
    """Classify a user-supplied core_id against a board/device's core set.

    Returns (code, info): OK / SINGLE_CORE_HAS_COREID / INVALID_COREID / UNRESOLVED.
    """
    sdk_root = sdk_root or _SDK_ROOT
    if not device and board:
        device = resolve_device(board, sdk_root)
    if not device:
        return (UNRESOLVED, None)
    info = device_cores(device, sdk_root)
    if info is None:
        return (UNRESOLVED, None)
    if not core_id:
        return (OK, info)
    if info['single']:
        return (SINGLE_CORE_HAS_COREID, info)
    if core_id in info['core_ids']:
        return (OK, info)
    return (INVALID_COREID, info)

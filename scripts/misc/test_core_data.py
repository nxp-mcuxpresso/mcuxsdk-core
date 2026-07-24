# Copyright 2026 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
"""Tests for misc/core_data.py — the board/device core resolver."""

import os
import sys

script_dir = os.path.abspath(os.path.dirname(__file__))
sys.path.insert(0, script_dir)

import core_data as cd


class TestDeviceCores:
    """device_cores() classification against sampled devices."""

    def test_single_core_kinetis(self):
        info = cd.device_cores('MK22F51212')
        assert info is not None
        assert info['single'] is True
        assert info['core_ids'] == ['core0']

    def test_single_core_mcxw236(self):
        # The ticket device: single-core, but its core id is 'cm33_core0'.
        info = cd.device_cores('MCXW236')
        assert info == {'single': True, 'core_ids': ['cm33_core0']}

    def test_multi_core_rt1176(self):
        info = cd.device_cores('MIMXRT1176')
        assert info is not None
        assert info['single'] is False
        assert set(info['core_ids']) == {'cm4', 'cm7'}

    def test_multi_core_rt798s_five_cores(self):
        info = cd.device_cores('MIMXRT798S')
        assert info is not None
        assert info['single'] is False
        assert set(info['core_ids']) == {'ezhv', 'hifi1', 'hifi4',
                                         'cm33_core0', 'cm33_core1'}

    def test_unknown_device(self):
        assert cd.device_cores('NO_SUCH_DEVICE') is None


class TestResolveDevice:
    """resolve_device() board -> device mapping."""

    def test_single_core_board(self):
        assert cd.resolve_device('mcxw23evk') == 'MCXW236'
        assert cd.resolve_device('frdmk22f') == 'MK22F51212'

    def test_multi_core_board(self):
        assert cd.resolve_device('evkbmimxrt1170') == 'MIMXRT1176'
        assert cd.resolve_device('mimxrt700evk') == 'MIMXRT798S'

    def test_board_revision_suffix_is_stripped(self):
        assert cd.resolve_device('evkbmimxrt1170@foo') == 'MIMXRT1176'

    def test_unknown_board(self):
        assert cd.resolve_device('no-such-board') is None
        assert cd.resolve_device('') is None
        assert cd.resolve_device(None) is None


class TestClassifyCoreId:
    """classify_core_id() — the two validation rules (independent of example.yml)."""

    def test_ticket_case_single_core_with_core_id(self):
        # west build -b mcxw23evk -Dcore_id=cm33_core0  -> rejected.
        code, info = cd.classify_core_id('cm33_core0', board='mcxw23evk')
        assert code == cd.SINGLE_CORE_HAS_COREID
        assert info['single'] is True

    def test_single_core_any_core_id_rejected(self):
        code, _ = cd.classify_core_id('cm4', board='frdmk22f')
        assert code == cd.SINGLE_CORE_HAS_COREID

    def test_single_core_no_core_id_ok(self):
        code, _ = cd.classify_core_id(None, board='mcxw23evk')
        assert code == cd.OK
        code, _ = cd.classify_core_id('', board='frdmk22f')
        assert code == cd.OK

    def test_multi_core_valid(self):
        for core in ('cm4', 'cm7'):
            code, _ = cd.classify_core_id(core, board='evkbmimxrt1170')
            assert code == cd.OK

    def test_multi_core_invalid(self):
        # cm7_core0 is a common wrong guess for RT1170 (which uses cm7/cm4).
        code, info = cd.classify_core_id('cm7_core0', board='evkbmimxrt1170')
        assert code == cd.INVALID_COREID
        assert set(info['core_ids']) == {'cm4', 'cm7'}

    def test_unresolved_board(self):
        code, info = cd.classify_core_id('cm7', board='no-such-board')
        assert code == cd.UNRESOLVED
        assert info is None

    def test_classify_by_device_directly(self):
        code, _ = cd.classify_core_id('cm99', device='MIMXRT798S')
        assert code == cd.INVALID_COREID


class TestListBoards:
    def test_includes_sampled_boards(self):
        boards = cd.list_boards()
        assert isinstance(boards, list)
        for b in ('mcxw23evk', 'evkbmimxrt1170', 'mimxrt700evk', 'frdmk22f'):
            assert b in boards
        assert boards == sorted(boards)


class TestBoardInfo:
    def test_multi_core_board_info(self):
        rec = cd.board_info('evkbmimxrt1170')
        assert rec['device'] == 'MIMXRT1176'
        assert rec['single'] is False
        assert set(rec['core_ids']) == {'cm4', 'cm7'}
        assert rec['board_root'] == 'examples/_boards/evkbmimxrt1170'
        assert rec['board_full_name'] == 'MIMXRT1170-EVKB'
        assert rec['device_root'] == 'devices/RT/RT1170/MIMXRT1176'

    def test_single_core_board_info(self):
        rec = cd.board_info('mcxw23evk')
        assert rec['board'] == 'mcxw23evk'
        assert rec['device'] == 'MCXW236'
        assert rec['single'] is True
        assert rec['core_ids'] == ['cm33_core0']
        assert rec['board_root'] == 'examples/_boards/mcxw23evk'
        assert rec['board_full_name'] == 'MCXW23-EVK'
        assert rec['device_root'] == 'devices/MCX/MCXW/MCXW236'
        assert rec['device_full_name'] == 'MCXW236'

    def test_unresolvable_board_has_no_device_meta(self):
        rec = cd.board_info('no-such-board')
        assert rec['device'] is None
        assert rec['device_root'] is None
        assert rec['device_full_name'] is None
        assert rec['single'] is None
        assert rec['core_ids'] == []


class TestBuildIndex:
    """The one-pass index used by `west boards` for bulk resolution."""

    def test_index_matches_targeted_lookup(self):
        # Built serially to keep the test fast and deterministic.
        index = cd.build_index(parallel=False)
        assert index['device_cores']  # non-empty
        # Indexed device_cores must match the per-device tree-scan result.
        for dev, exp in (('MK22F51212', {'core_ids': ['core0'], 'single': True}),
                         ('MIMXRT1176', None),  # cores compared as a set below
                         ('MCXW236', {'core_ids': ['cm33_core0'], 'single': True})):
            got = cd.device_cores(dev, index=index)
            direct = cd.device_cores(dev)
            assert got == direct
            if exp is not None:
                assert got == exp

    def test_index_part_to_device(self):
        index = cd.build_index(parallel=False)
        # MCXW236's parts include MCXW236BIHNAR (from its chip.yml part[] list).
        assert index['part_to_device'].get('MCXW236BIHNAR') == 'MCXW236'

    def test_board_info_index_equivalence(self):
        index = cd.build_index(parallel=False)
        for b in ('mcxw23evk', 'evkbmimxrt1170', 'mimxrt700evk', 'frdmk22f'):
            assert cd.board_info(b, index=index) == cd.board_info(b)

    def test_device_meta_index_equivalence(self):
        index = cd.build_index(parallel=False)
        for dev in ('MK22F51212', 'MIMXRT1176', 'MCXW236'):
            assert cd.device_meta(dev, index=index) == cd.device_meta(dev)

    def test_dsc_device_single_core(self):
        # DSC parts (e.g. MC56F82316) use core id 'core0' with a dsp core type.
        assert cd.device_cores('MC56F82316') == {'single': True,
                                                 'core_ids': ['core0']}


class TestDeviceMeta:
    def test_multi_core_device_meta(self):
        meta = cd.device_meta('MIMXRT1176')
        assert meta == {'root': 'devices/RT/RT1170/MIMXRT1176',
                        'full_name': 'MIMXRT1176xxxxx'}

    def test_unknown_device_meta(self):
        assert cd.device_meta('NO_SUCH_DEVICE') is None


class TestScanBoardsAndBoardMeta:
    def test_scan_boards_matches_list_boards(self):
        dirs = cd.scan_boards()
        assert sorted(dirs.keys()) == cd.list_boards()
        assert dirs['mcxw23evk'] == 'examples/_boards/mcxw23evk'

    def test_board_meta_uses_precomputed_dirs(self):
        dirs = cd.scan_boards()
        assert cd.board_meta('mcxw23evk', board_dirs=dirs) == cd.board_meta('mcxw23evk')

    def test_board_meta_unknown_board(self):
        assert cd.board_meta('no-such-board') is None


class TestMarketingDataPriority:
    """MIR/marketing_data/1.0 is preferred over tool_data, per-lookup."""

    def test_mir_root_present_and_first(self):
        roots = cd._marketing_data_roots(cd._SDK_ROOT)
        assert roots[0] == os.path.join(cd._SDK_ROOT, 'MIR', 'marketing_data', '1.0')
        assert roots[-1] == os.path.join(cd._SDK_ROOT, 'tool_data')

    def test_missing_mir_falls_back_to_tool_data_only(self, tmp_path):
        roots = cd._marketing_data_roots(str(tmp_path))
        assert roots == [os.path.join(str(tmp_path), 'tool_data')]

    def test_board_only_in_tool_data_style_layout_resolves(self, tmp_path):
        mir_boards = tmp_path / 'MIR' / 'marketing_data' / '1.0' / 'boards'
        td_boards = tmp_path / 'tool_data' / 'boards'
        mir_boards.mkdir(parents=True)
        td_boards.mkdir(parents=True)
        (td_boards / 'fakeboard.yml').write_text(
            "name: 'FAKE-BOARD'\nparts:\n  - device: 'FAKEDEV'\n")
        assert cd._device_from_marketing_data('fakeboard', str(tmp_path)) == 'FAKEDEV'
        assert cd._board_full_name('fakeboard', str(tmp_path)) == 'FAKE-BOARD'

    def test_mir_entry_overrides_tool_data_entry(self, tmp_path):
        mir_boards = tmp_path / 'MIR' / 'marketing_data' / '1.0' / 'boards'
        td_boards = tmp_path / 'tool_data' / 'boards'
        mir_boards.mkdir(parents=True)
        td_boards.mkdir(parents=True)
        (mir_boards / 'fakeboard.yml').write_text(
            "name: 'FROM-MIR'\nparts:\n  - device: 'MIRDEV'\n")
        (td_boards / 'fakeboard.yml').write_text(
            "name: 'FROM-TOOL-DATA'\nparts:\n  - device: 'TDDEV'\n")
        assert cd._device_from_marketing_data('fakeboard', str(tmp_path)) == 'MIRDEV'
        assert cd._board_full_name('fakeboard', str(tmp_path)) == 'FROM-MIR'

    def test_real_board_resolved_only_via_mir(self):
        td_only = cd._read_yaml_first(
            [os.path.join(cd._SDK_ROOT, 'tool_data', 'boards', 'frdmk64f.yml')])
        assert td_only is None
        assert cd._device_from_marketing_data('frdmk64f', cd._SDK_ROOT) == 'MK64F12'

    def test_read_yaml_first_warns_on_corrupt_not_missing(self, tmp_path, capsys):
        broken = tmp_path / 'broken.yml'
        broken.write_text('key: [unterminated')
        result = cd._read_yaml_first([str(tmp_path / 'does-not-exist.yml'), str(broken)])
        assert result is None
        err = capsys.readouterr().err
        assert 'failed to read' in err
        assert 'does-not-exist' not in err  # the missing candidate must stay silent

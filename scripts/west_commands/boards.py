# Copyright 2026 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
"""``west boards`` — enumerate boards and their core ids (from chip.yml, not
example.yml)."""

import json
import os
import re
import sys

from west.commands import WestCommand

script_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)))
sys.path.append(script_dir)

from misc import core_data

BOARDS_USAGE = '''
Example:
  List every board with its device and valid core ids:
      west boards
  Show one or more boards:
      west boards -b mimxrt700evk evkbmimxrt1170
  Machine-readable output:
      west boards -b mcxw23evk --json
  Custom format (like `west list_repo -f`):
      west boards -f "{board} {device} {core_ids}"
      west boards -f "{board}@{core_ids}"

Boards whose device or core data cannot be resolved are omitted.

FORMAT FIELDS (for -f/--format, Python str.format):
  {board}             board name
  {board_root}        board directory, relative to the SDK root
  {board_full_name}   board commercial name, or the board name
  {device}            resolved device id
  {device_root}       device directory, relative to the SDK root
  {device_full_name}  device full name, or the device id
  {type}              "single" or "multi"
  {core_ids}          comma+space separated core ids (e.g. "cm4, cm7")
  {cores}             space separated core ids (e.g. "cm4 cm7")
'''


class Boards(WestCommand):
    def __init__(self):
        super().__init__(
            name='boards',
            help='List boards and their valid core ids',
            description='List boards with their resolved device and valid core_id values.'
        )

    def do_add_parser(self, parser_adder):
        parser = parser_adder.add_parser(
            self.name, help=self.help, description=self.description, usage=BOARDS_USAGE
        )
        parser.add_argument('-b', '--board', nargs='+', action='extend', type=str,
                            default=[],
                            help='Board(s) to show; default lists all boards. '
                                 'A board@rev suffix is accepted and ignored.')
        parser.add_argument('-n', '--name', dest='name_re', default=None,
                            help='Regular expression; only boards whose name '
                                 'matches are listed.')
        parser.add_argument('-f', '--format', dest='fmt', default=None,
                            help='Python format string to print each board; see '
                                 'FORMAT FIELDS. Mutually exclusive with --json.')
        parser.add_argument('--json', action='store_true', default=False,
                            help='Emit JSON instead of a table.')
        parser.add_argument('-j', '--jobs', type=int, default=None,
                            help='Worker processes for the device-data scan '
                                 '(default: CPU count). Use 1 to force serial.')
        return parser

    def do_run(self, args, unknown):
        board_dirs = core_data.scan_boards()

        if args.board:
            boards = [b.split('@', 1)[0] for b in args.board]
        else:
            boards = sorted(board_dirs.keys())

        if args.name_re is not None:
            pattern = re.compile(args.name_re)
            boards = [b for b in boards if pattern.search(b)]

        index = core_data.build_index(parallel=(args.jobs != 1), workers=args.jobs)
        records = [core_data.board_info(b, index=index, board_dirs=board_dirs)
                  for b in boards]
        records = [r for r in records if r['device'] is not None and r['single'] is not None]

        if args.json:
            print(json.dumps(records, indent=2))
            return

        if args.fmt is not None:
            self._print_formatted(records, args.fmt)
            return

        self._print_table(records)

    @staticmethod
    def _format_fields(r):
        return {
            'board': r['board'],
            'board_root': r['board_root'] or '',
            'board_full_name': r['board_full_name'] or '',
            'device': r['device'],
            'device_root': r['device_root'] or '',
            'device_full_name': r['device_full_name'] or '',
            'type': 'single' if r['single'] else 'multi',
            'core_ids': ', '.join(r['core_ids']),
            'cores': ' '.join(r['core_ids']),
        }

    def _print_formatted(self, records, fmt):
        for r in records:
            try:
                print(fmt.format(**self._format_fields(r)))
            except KeyError as exc:
                self.die(f'unknown format field {exc} in --format; valid fields: '
                         'board, board_root, board_full_name, device, device_root, '
                         'device_full_name, type, core_ids, cores')

    @staticmethod
    def _print_table(records):
        headers = ('BOARD', 'DEVICE', 'TYPE', 'CORE ID(S)')
        rows = [(r['board'], r['device'], 'single' if r['single'] else 'multi',
                 ', '.join(r['core_ids']))
                for r in records]

        widths = [len(h) for h in headers]
        for row in rows:
            for i, cell in enumerate(row):
                widths[i] = max(widths[i], len(cell))
        fmt = '  '.join('{:<%d}' % w for w in widths)
        print(fmt.format(*headers))
        print(fmt.format(*['-' * w for w in widths]))
        for row in rows:
            print(fmt.format(*row))

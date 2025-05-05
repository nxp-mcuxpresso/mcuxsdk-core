# Copyright 2025 NXP
# SPDX-License-Identifier: BSD-3-Clause

import sys
import pathlib
import datetime
import time

sys.path.append(f'{pathlib.Path(__file__).parent.resolve()}/../loaders')
import device as dl
import board as bl
import build_command as bcl
import example as el
import part as pl
import core as cl

sys.path.append(f'{pathlib.Path(__file__).parent.resolve()}/../gui')
import view as guiv
import model as guim
import controller as guic

sys.path.append(f'{pathlib.Path(__file__).parent.resolve()}/../database')
import database_sqlite as db_sql

__version__ = '0.0.1'

VISUALIZATION_TYPES = [
    [('board','name'),
     ('example','category'),
     ('example','name'),
     ('example','path'),
     ('config',),
     ('toolchain',),
     ('core','id'),
     ('core','type'),
     ('sysbuild',),
    ],
    [('device', 'platform'),
     ('device', 'series'),
     ('device', 'family'),
     ('device', 'subfamily'),
     ('device', 'id'),
     ('device', 'full_name'),
     ('device', 'name'),
     ('part', 'name'),
    ],
    ]

class RunExplorer():
    def __init__(self, manifest_root_path, core_root_path):

        database_file_path = pathlib.Path(manifest_root_path, '../data/mcux_sqlite.db')

        timestamp1 = time.time()
        self.database_sql = db_sql.DataBaseSQL()

        if not self.database_sql.exist(database_file_path):
            print('Loading data from repositories. Expected load time is 40 seconds.')

            self.build_command_data = bcl.BuildCommandDataLoader(manifest_root_path, core_root_path)
            build_command_data = self.build_command_data.load()
            timestamp2 = time.time()
            time_delta = str(datetime.timedelta(seconds=timestamp2 - timestamp1))
            print(f'build commands load time: {time_delta}')

            example_paths = []
            for x in build_command_data:
                example_paths.append(x[('example','path')])
            example_paths = list(sorted(set(example_paths)))

            self.device_data = dl.DeviceDataLoader(manifest_root_path, core_root_path)
            device_data = self.device_data.load()
            timestamp3 = time.time()
            time_delta = str(datetime.timedelta(seconds=timestamp3 - timestamp2))
            print(f'device data load time: {time_delta}')

            self.board_data = bl.BoardDataLoader(manifest_root_path, core_root_path)
            board_data = self.board_data.load()
            timestamp4 = time.time()
            time_delta = str(datetime.timedelta(seconds=timestamp4 - timestamp3))
            print(f'board data load time: {time_delta}')

            self.example_data = el.ExampleDataLoader(manifest_root_path, core_root_path)
            example_data = self.example_data.load(example_paths)
            timestamp5 = time.time()
            time_delta = str(datetime.timedelta(seconds=timestamp5 - timestamp4))
            print(f'example data load time: {time_delta}')

            self.part_data = pl.PartDataLoader(manifest_root_path, core_root_path)
            part_data = self.part_data.load()
            timestamp6 = time.time()
            time_delta = str(datetime.timedelta(seconds=timestamp6 - timestamp5))
            print(f'part data load time: {time_delta}')

            self.core_data = cl.CoreDataLoader(manifest_root_path, core_root_path)
            core_data = self.core_data.load()
            timestamp7 = time.time()
            time_delta = str(datetime.timedelta(seconds=timestamp7 - timestamp6))
            print(f'core data load time: {time_delta}')

            self.database_sql.initialize_database(database_file_path)

            cursor = self.database_sql.conn.cursor()
            cursor.execute('BEGIN TRANSACTION')

            for i, x in enumerate(build_command_data):
                self.database_sql.load_build_command_row(
                    idx = i,
                    raw_build_command = x[('raw_build_command',)],
                    example_path = x[('example','path')],
                    board_name = x[('board','name')],
                    device_name = x[('device','name')],
                    toolchain = x[('toolchain',)],
                    config = x[('config',)],
                    sysbuild = x[('sysbuild',)],
                    core_id = x[('core','id')],
                    cursor = cursor)

            for x in device_data:
                self.database_sql.load_device_row(
                    device_id = x[('device', 'id')],
                    device_full_name = x[('device', 'full_name')],
                    device_name = x[('device', 'name')],
                    device_platform = x[('device', 'platform')],
                    device_series = x[('device', 'series')],
                    device_family = x[('device', 'family')],
                    device_subfamily = x[('device', 'subfamily')],
                    cursor = cursor)

            for x in board_data:
                self.database_sql.load_board_row(
                    board_name = x[('board','name')],
                    part_name = x[('part','name')],
                    cursor = cursor)

            for x in example_data:
                self.database_sql.load_example_row(
                    example_name = x[('example','name')],
                    example_category = x[('example','category')],
                    example_path = x[('example','path')],
                    cursor = cursor)

            for x in part_data:
                self.database_sql.load_part_row(
                    part_name = x[('part','name')],
                    device_id = x[('device','id')],
                    cursor = cursor)

            for x in core_data:
                self.database_sql.load_core_row(
                    device_id = x[('device','id')],
                    core_id = x[('core','id')],
                    core_type = x[('core','type')],
                    cursor = cursor)

            cursor.execute('COMMIT')

            self.database_sql.create_supertable()

        else:
            print(f'Connecting to existing database file: {database_file_path}')
            print('For data refresh close application, delete '
                   'database file and start application again.')
            self.database_sql.connect(database_file_path)

        self.model = guim.GuiModel(self.database_sql, VISUALIZATION_TYPES)
        self.view = guiv.GuiView(self.model, VISUALIZATION_TYPES)

        img_path = pathlib.Path(core_root_path, 'scripts/mcuxsdk_explore/resources/nxp.png')
        self.view.register_favicon(img_path)
        self.controller = guic.GuiController(self.model, self.view)

        timestamp10 = time.time()
        print(f'total load time: {str(datetime.timedelta(seconds=timestamp10 - timestamp1))}')

        self.view.start_mainloop()

if __name__ == "__main__":
    current_dir = pathlib.Path().cwd()
    manifest_root_path = pathlib.Path(current_dir, '../../../../manifest')
    core_root_path = pathlib.Path(current_dir, '../../../../mcuxsdk')
    RunExplorer(manifest_root_path, core_root_path)

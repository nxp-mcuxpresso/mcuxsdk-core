# Copyright 2025 NXP
# SPDX-License-Identifier: BSD-3-Clause

import pathlib
import sqlite3

class DataBaseSQL():
    def __init__(self):
        self.conn = None
        self.sql_super_table_types = [
            'raw_build_command',
            'example_path',
            'board_name',
            'toolchain',
            'config',
            'sysbuild',
            'example_name',
            'example_category',
            'part_name',
            'device_id',
            'device_full_name',
            'device_name',
            'device_platform',
            'device_series',
            'device_family',
            'device_subfamily',
            'core_id',
            'core_type']

        self.db_file_path = None

    def initialize_database(self, database_file_path):
        db_path = pathlib.Path(database_file_path)
        if not db_path.parent.is_dir():
            db_path.parent.mkdir(parents=True, exist_ok=True)
        if db_path.exists():
            db_path.unlink()
        self.conn = sqlite3.connect(database_file_path)

        self.sqlite_build_command_table()
        self.sqlite_boards_table()
        self.sqlite_devices_table()
        self.sqlite_parts_table()
        self.sqlite_example_table()
        self.sqlite_cores_table()

    def exist(self, database_file_path):
        return pathlib.Path(database_file_path).is_file()

    def connect(self, database_file_path):
        self.conn = sqlite3.connect(database_file_path)

    def sqlite_build_command_table(self):
        self.conn.execute('''CREATE TABLE build_commands
                    (id TEXT PRIMARY KEY,
                    raw_build_command TEXT  NOT NULL,
                    example_path TEXT  NOT NULL,
                    board_name TEXT,
                    device_name TEXT,
                    toolchain TEXT  NOT NULL,
                    config TEXT  NOT NULL,
                    sysbuild TEXT  NOT NULL,
                    core_id TEXT
                    );''')
        self.conn.commit()

    def sqlite_example_table(self):
        self.conn.execute('''CREATE TABLE examples
                    (example_name TEXT  NOT NULL,
                    example_category TEXT  NOT NULL,
                    example_path TEXT  NOT NULL,
                    PRIMARY KEY (example_name, example_path)
                    );''')
        self.conn.commit()

    def sqlite_boards_table(self):
        self.conn.execute('''CREATE TABLE boards
                    (board_name TEXT PRIMARY KEY,
                    part_name TEXT  NOT NULL
                    );''')
        self.conn.commit()

    def sqlite_devices_table(self):
        self.conn.execute('''CREATE TABLE devices
                    (device_id TEXT PRIMARY KEY,
                    device_full_name TEXT  NOT NULL,
                    device_name TEXT  NOT NULL,
                    device_platform TEXT  NOT NULL,
                    device_series TEXT  NOT NULL,
                    device_family TEXT  NOT NULL,
                    device_subfamily TEXT  NOT NULL
                    );''')
        self.conn.commit()

    def sqlite_parts_table(self):
        self.conn.execute('''CREATE TABLE parts
                    (part_name TEXT  NOT NULL,
                    device_id  TEXT  NOT NULL,
                    PRIMARY KEY (part_name, device_id)
                    );''')
        self.conn.commit()

    def sqlite_cores_table(self):
        self.conn.execute('''CREATE TABLE cores
                    (device_id TEXT  NOT NULL,
                    core_id  TEXT  NOT NULL,
                    core_type  TEXT  NOT NULL,
                    PRIMARY KEY (device_id, core_id, core_type)
                    );''')
        self.conn.commit()

    def load_example_row(self, example_name,
                               example_category,
                               example_path,
                               cursor):
        cursor.execute(
            'INSERT INTO examples (example_name, example_category, example_path)\
             VALUES (?, ?, ?)',
            (example_name, example_category, example_path)
        )

    def load_part_row(self, part_name,
                            device_id,
                            cursor):
        cursor.execute(
            'INSERT INTO parts (part_name, device_id) VALUES (?, ?)',
            (part_name, device_id)
        )

    def load_core_row(self, device_id,
                            core_id,
                            core_type,
                            cursor):
        cursor.execute(
            'INSERT INTO cores (device_id, core_id, core_type)\
             VALUES (?, ?, ?)',
            (device_id, core_id, core_type)
        )

    def load_board_row(self, board_name,
                             part_name,
                             cursor):
        cursor.execute(
            'INSERT INTO boards (board_name, part_name) VALUES (?, ?)',
            (board_name, part_name)
        )

    def load_device_row(self, device_id,
                              device_full_name,
                              device_name,
                              device_platform,
                              device_series,
                              device_family,
                              device_subfamily,
                              cursor):
        cursor.execute(
            'INSERT INTO devices (device_id, device_full_name, device_name, device_platform, device_series, device_family, device_subfamily) \
             VALUES (?, ?, ?, ?, ?, ?, ?)',
            (device_id,
             device_full_name,
             device_name,
             device_platform,
             device_series,
             device_family,
             device_subfamily)
        )

    def load_build_command_row(self, idx,
                                     raw_build_command,
                                     example_path,
                                     board_name,
                                     device_name,
                                     toolchain,
                                     config,
                                     sysbuild,
                                     core_id,
                                     cursor):
        cursor.execute(
            'INSERT INTO build_commands (id, raw_build_command, example_path, board_name, device_name, toolchain, config, sysbuild, core_id)\
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            (idx,
             raw_build_command,
             example_path,
             board_name,
             device_name,
             toolchain,
             config,
             sysbuild,
             core_id)
        )

    def create_supertable(self):
        cursor = self.conn.cursor()
        sql = '''
        CREATE TABLE super_table AS
            SELECT bc.raw_build_command,
                   bc.example_path,
                   bc.board_name,
                   bc.toolchain,
                   bc.config,
                   bc.sysbuild,
                   e.example_name,
                   e.example_category,
                   p.part_name,
                   d.device_id,
                   d.device_full_name,
                   d.device_name,
                   d.device_platform,
                   d.device_series,
                   d.device_family,
                   d.device_subfamily,
                   c.core_id,
                   c.core_type
            FROM
                build_commands bc
            LEFT JOIN
                examples e ON e.example_path = bc.example_path
            LEFT JOIN
                boards b ON b.board_name = bc.board_name
            LEFT JOIN
                parts p ON p.part_name = b.part_name
            LEFT JOIN
                devices d ON d.device_id = p.device_id OR d.device_name = bc.device_name
            LEFT JOIN
                cores c ON c.device_id = d.device_id AND (c.core_id = bc.core_id OR bc.core_id IS NULL)
            ;'''
        cursor.execute(sql)
        return cursor.fetchall()

    def get_requested(self, requested_items, return_sql_types=None):
        where_conditions = str()
        select_types = '*'

        if requested_items:
            for mcux_type, value in requested_items.items():
                for x in value:
                    if x:
                        where_conditions += f"super_table.{mcux_type} = '{x}'"
                        where_conditions += r' AND '
            if where_conditions:
                where_conditions = where_conditions[:-4]

        if return_sql_types:
            for sql_type in return_sql_types:
              select_types = ', '.join(return_sql_types)

        return self.execute_supertable_query(where_conditions, select_types)

    def execute_supertable_query(self, where_conditions, select_types='*'):
        where = str()
        if where_conditions:
            where = 'WHERE '+ where_conditions
        cursor = self.conn.cursor()
        sql = f'''
        SELECT {select_types}
        FROM super_table
        {where}
        ;'''
        cursor.execute(sql)
        return cursor.fetchall()

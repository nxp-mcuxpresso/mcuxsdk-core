# Copyright 2025 NXP
# SPDX-License-Identifier: BSD-3-Clause

SQL_TYPE_TO_TUPLE_TYPE = {
    'raw_build_command': ('raw_build_command',),
    'example_path': ('example','path'),
    'board_name': ('board','name'),
    'toolchain': ('toolchain',),
    'config': ('config',),
    'sysbuild': ('sysbuild',),
    'example_name': ('example','name'),
    'example_category': ('example','category'),
    'part_name': ('part','name'),
    'device_id': ('device','id'),
    'device_full_name': ('device','full_name'),
    'device_name': ('device','name'),
    'device_platform': ('device','platform'),
    'device_series': ('device','series'),
    'device_family': ('device','family'),
    'device_subfamily': ('device','subfamily'),
    'core_id': ('core','id'),
    'core_type': ('core','type'),
    }

class GuiModel():
    def __init__(self, sql_database, visualization_types):
        self.visualization_types = visualization_types
        self.sql_database = sql_database
        self.controller_callback = None
        self.button_callback = None
        self.to_be_visible = dict()
        self.selected = dict()
        self.to_select = dict()
        self.to_unselect = dict()
        self.newly_selected = dict()
        self.newly_unselected = dict()
        self.filter_entry = dict()
        self.dependent_selection = dict()

        self.symbols = dict()
        self.load_symbols_superset()

        for t_tuple in SQL_TYPE_TO_TUPLE_TYPE.values():
            self.to_be_visible[t_tuple] =  self.symbols[t_tuple]
            self.selected[t_tuple] = list()
            self.to_select[t_tuple] = list()
            self.to_unselect[t_tuple] = list()
            self.newly_selected[t_tuple] = list()
            self.newly_unselected[t_tuple] = list()
            self.filter_entry[t_tuple] = list()

    def sql_type_to_tuple_type(self, sql_type):
        return SQL_TYPE_TO_TUPLE_TYPE[sql_type]

    def tuple_type_to_sql_type(self, tuple_type):
        return '_'.join(map(str,tuple_type))

    def test_selection(self):
        output = False
        for t_tuple in SQL_TYPE_TO_TUPLE_TYPE.values():
            if self.selected[t_tuple]:
                output = True
                break
        return output

    def update_model(self):
        for t_tuple in SQL_TYPE_TO_TUPLE_TYPE.values():
            self.to_select[t_tuple] = list()
            self.to_unselect[t_tuple] = list()
            self.to_be_visible[t_tuple] = list()
        # Load data from database query
        if self.test_selection():
            sql_data = self.get_requested_from_database()
            tuple_type_data = self.convert_to_column_lists(sql_data)
            for t_sql, t_tuple in SQL_TYPE_TO_TUPLE_TYPE.items():
                self.to_be_visible[t_tuple] = tuple_type_data[t_sql]
            self.update_visibility()
        # Load data from superset
        else:
            for t_tuple in SQL_TYPE_TO_TUPLE_TYPE.values():
                self.to_be_visible[t_tuple] = self.symbols[t_tuple]
            self.update_visibility()

    def get_all_data_from_database(self):
        sql_data = self.sql_database.get_requested([])
        for sql_row in sql_data:
            print(sql_row)
        return sql_data

    def load_symbols_superset(self):
        sql_data = self.sql_database.get_requested([])
        sql_symbols = self.convert_to_column_lists(sql_data)
        for t_sql, t_tuple in SQL_TYPE_TO_TUPLE_TYPE.items():
            self.symbols[t_tuple] = sql_symbols[t_sql]
        return self.symbols

    def get_requested_from_database(self):
        request = {}
        for t_sql, t_tuple in SQL_TYPE_TO_TUPLE_TYPE.items():
            if self.selected[t_tuple]:
                request[t_sql] = self.selected[t_tuple]
        sql_data = self.sql_database.get_requested(request)
        return sql_data

    def convert_to_column_lists(self, sql_data):
        database_types = SQL_TYPE_TO_TUPLE_TYPE.keys()
        sql_symbols = {}
        for t_sql in SQL_TYPE_TO_TUPLE_TYPE.keys():
            sql_symbols[t_sql] = []
        for row in sql_data:
            for i, t_sql in enumerate(database_types):
                if row[i]:
                    sql_symbols[t_sql].append(row[i])
        for t_sql in database_types:
            sql_symbols[t_sql] = list(sorted(set(sql_symbols[t_sql])))
        return sql_symbols

    def get_command_list_to_show(self):
        result_list = list(sorted(set(self.to_be_visible[('raw_build_command',)])))
        result = '\n'.join(result_list)
        return result, result_list

    def print_selection_status(self):
        print('--------------------------------------------')
        print(f'selected: \n {self.selected}')
        print(f'filter_entry: \n {self.filter_entry}')
        print(f'to_select: \n {self.to_select}')
        print(f'to_unselect: \n {self.to_unselect}')
        print(f'newly_selected: \n {self.newly_selected}')
        print(f'newly_unselected: \n {self.newly_unselected}')
        print('--------------------------------------------')

    def callback(self):
        self.controller_callback()

    def clear_selection_callback(self):
        for t_tuple in SQL_TYPE_TO_TUPLE_TYPE.values():
            self.selected[t_tuple] = list()
            self.to_select[t_tuple] = list()
            self.to_unselect[t_tuple] = list()
            self.to_be_visible[t_tuple] = self.symbols[t_tuple]
        self.button_callback()
        self.update_visibility()

    def filter_visible_items(self, data_type):
        filter_text = self.filter_entry[data_type]
        if filter_text:
            data_to_filter = self.to_be_visible[data_type]
            self.to_be_visible[data_type] = \
                [k for k in data_to_filter if filter_text.lower() in k.lower()]

    def update_visibility(self):
        for group in self.visualization_types:
            for mcux_data_type in group:
                self.filter_visible_items(mcux_data_type)
                self.to_be_visible[mcux_data_type].extend(self.to_select[mcux_data_type])
                self.to_be_visible[mcux_data_type].extend(self.selected[mcux_data_type])
                self.to_be_visible[mcux_data_type] = \
                    list(sorted(set(self.to_be_visible[mcux_data_type])))

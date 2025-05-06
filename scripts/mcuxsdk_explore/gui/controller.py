# Copyright 2025 NXP
# SPDX-License-Identifier: BSD-3-Clause

import tkinter as tk
import datetime
import time

class GuiController():
    def __init__(self, model, view):
        self.model = model
        self.view = view
        self.model.controller_callback = self.update_view
        self.model.button_callback = self.clean_view

    def timeit(self, func):
        def inner(self):
            t1 = time.time()
            func(self)
            t2 = time.time()
            print(f'update time: {str(datetime.timedelta(seconds=t2 - t1))}')
        return inner

#    @self.timeit
    def update_view(self):
        self.load_state_of_widgets()
        self.model.update_model()
        self.render_new_view()

    def clean_view(self):
        self.model.update_model()
        self.render_new_view()

    def load_state_of_widgets(self):
        for mcux_data_type in self.view.graphical_object['selector'].keys():
            g_object = self.view.graphical_object['selector'][mcux_data_type]
            selection = [g_object.listbox.get(i) for i in g_object.listbox.curselection()]
            self.model.newly_selected[mcux_data_type] = \
                list(set(selection) - set(self.model.selected[mcux_data_type]))
            self.model.newly_unselected[mcux_data_type] = \
                list(set(self.model.selected[mcux_data_type]) - set(selection))
            self.model.selected[mcux_data_type] = selection
            self.model.filter_entry[mcux_data_type] = g_object.entry_variable.get()

    def render_new_view(self):
        for mcux_data_type in self.view.graphical_object['selector'].keys():
            g_object = self.view.graphical_object['selector'][mcux_data_type]
            g_object.listbox_variable.set(self.model.to_be_visible[mcux_data_type])

            g_object.text.delete('1.0', tk.END)
            length_of_visible = len(self.model.to_be_visible[mcux_data_type])
            length_of_all = len(self.model.symbols[mcux_data_type])
            g_object.text.insert(tk.END, f'{length_of_visible}/{length_of_all}')
            g_object.text.update()
            g_object.text.see(tk.END)

        for mcux_data_type in self.view.graphical_object['selector'].keys():
            g_object = self.view.graphical_object['selector'][mcux_data_type]

            g_object.listbox.selection_clear(0, tk.END)

            if self.model.selected[mcux_data_type]:
                for entity in self.model.selected[mcux_data_type]:
                    i = self.model.to_be_visible[mcux_data_type].index(entity)
                    g_object.listbox.selection_set(i)

            if self.model.to_select[mcux_data_type]:
                for entity in self.model.to_select[mcux_data_type]:
                    i = self.model.to_be_visible[mcux_data_type].index(entity)
                    g_object.listbox.selection_set(i)

            if self.model.to_unselect[mcux_data_type]:
                for entity in self.model.to_unselect[mcux_data_type]:
                    if entity in self.model.to_be_visible[mcux_data_type]:
                        i = self.model.to_be_visible[mcux_data_type].index(entity)
                        g_object.listbox.selection_clear(i)

            if self.model.to_select[mcux_data_type] or self.model.to_unselect[mcux_data_type]:
                g_object.listbox.event_generate("<<ListboxSelect>>")

        resolved_command_text, resolved_command_list = self.model.get_command_list_to_show()

        t = self.view.graphical_object['greyedtext'].text
        t.delete('1.0', tk.END)
        t.insert(tk.END, resolved_command_text)
        t.update()
        t.see(tk.END)

        t = self.view.graphical_object['greyedtext'].text_statistics
        t.delete('1.0', tk.END)
        t.insert(tk.END,
                 f"{len(resolved_command_list)}/{len(self.model.symbols[('raw_build_command',)])}")
        t.update()
        t.see(tk.END)

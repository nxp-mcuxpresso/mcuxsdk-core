# Copyright 2025 NXP
# SPDX-License-Identifier: BSD-3-Clause

import tkinter as tk
from tkinter import ttk, Text, PhotoImage
import functools
import os

class GuiView():
    def __init__(self, model, visualization_types):
        self.model = model
        self.graphical_object = dict()
        self.graphical_object['selector'] = dict()
        self.graphical_object['greyedtext'] = dict()
        self.graphical_object['info_tab'] = dict()
        self.graphical_object['button'] = dict()

        self.parent =  tk.Tk()

        self.parent.title("MCUXpresso SDK explorer")

        self.tab_control = ttk.Notebook(self.parent)
        self.tab_control.pack(expand = 1, fill=tk.BOTH)

        self.tab1 = ttk.Frame(self.tab_control)
        self.tab_control.add(self.tab1, text ='build commands')

        self.main_frame = tk.PanedWindow(self.tab1, orient ='vertical')
        self.main_frame.pack(fill = tk.BOTH, expand = 1)

        ButtonRow(model, self.main_frame, self.graphical_object['button'])

        for types_group in visualization_types:
            SelectorRow(model, self.main_frame, types_group, self.graphical_object['selector'])

        self.f3 = tk.PanedWindow(self.main_frame, orient ='horizontal')
        self.f3.pack(fill = tk.BOTH, expand = 1, side="bottom")
        self.graphical_object['greyedtext'] = GreyedText(model, main=self.f3)

        self.main_frame.add(self.f3)

    def start_mainloop(self):
        print('starting main window')
        self.parent.mainloop()

    def register_favicon(self, img_path):
        img = PhotoImage(file = os.path.normpath(img_path))
        self.parent.iconphoto(False, img)


class ButtonRow():
    def __init__(self, model, main, graphical_object_button):
        self.f = tk.PanedWindow(main, orient ='horizontal')
        self.f.pack(fill = tk.BOTH, expand = 1, side="bottom")
        graphical_object_button = tk.Button(self.f,
                                            text="Clear selection",
                                            command=model.clear_selection_callback)
        graphical_object_button.pack(side=tk.LEFT , expand = 0, fill=tk.BOTH)
        main.add(self.f)

class SelectorRow():
    def __init__(self, model, main, types_group, graphical_object_selector):
        self.f = tk.PanedWindow(main, orient ='horizontal')
        self.f.pack(fill = tk.BOTH, expand = 1, side="bottom")
        for data_type in types_group:
            graphical_object_selector[data_type] = Selector(model,
                                                            data_type,
                                                            model.callback,
                                                            main=self.f)
        main.add(self.f)

class GreyedText():
    def __init__(self, model, main):
        self.model = model

        self.text_statistics = Text(main, height = 1, width = 2, bg='lightgrey')
        self.text_statistics.pack(side=tk.BOTTOM , expand = 0, fill=tk.BOTH)

        self.frame = tk.Frame(main)
        self.frame.pack(side=tk.BOTTOM, expand = 1, fill=tk.BOTH)

        self.text = Text(self.frame, height = 5, width = 100, bg='lightgrey')
        self.text.insert(tk.END, 'select something\n')
        self.text.pack(side=tk.LEFT , expand = 1, fill=tk.BOTH)

        self.scrollbar = ttk.Scrollbar(self.frame, orient=tk.VERTICAL, command=self.text.yview)
        self.scrollbar.pack(side=tk.RIGHT, expand = 0, fill=tk.BOTH)

        self.text['yscrollcommand'] = self.scrollbar.set
        self.text.bind('<<ListboxSelect>>', self.central_callback)

    def central_callback(self, event):
        self.model.callback(event)

class Selector():
    def __init__(self, model, mcux_data_type, callback, main):
        self.model = model

        self.frame = tk.Frame(main)
        self.frame.pack(side="top", expand = 1, fill=tk.BOTH)
        main.add(self.frame, stretch='always')

        self.label = ttk.Label(self.frame, text = mcux_data_type)
        self.label.pack(side=tk.TOP, expand = 0, fill=tk.X)

        self.entry_callback = functools.partial(self.selector_entry_callback,
                                                mcux_data_type = mcux_data_type)
        self.entry_variable = tk.StringVar()
        self.entry_variable.trace_add("write", self.entry_callback)
        self.entry = ttk.Entry(self.frame, textvariable = self.entry_variable)
        self.entry.pack(side=tk.TOP, expand = 0, fill=tk.X)

        self.frame2 = tk.Frame(self.frame)
        self.frame2.pack(side=tk.TOP, expand = 1, fill=tk.BOTH)

        self.listbox_variable = tk.Variable(value = self.model.to_be_visible[mcux_data_type])
        self.listbox = tk.Listbox(self.frame2,
                                  selectmode='multiple',
                                  listvariable = self.listbox_variable,
                                  exportselection=False)
        self.listbox.bind('<<ListboxSelect>>', self.central_callback)
        self.listbox.pack(side=tk.LEFT, expand = 1, fill=tk.BOTH)

        self.scrollbar = ttk.Scrollbar(self.frame2,
                                       orient=tk.VERTICAL,
                                       command = self.listbox.yview)
        self.listbox['yscrollcommand'] = self.scrollbar.set
        self.scrollbar.pack(side=tk.RIGHT, expand = 0, fill=tk.BOTH)

        self.text = Text(self.frame, height = 1, width = 2, bg='lightgrey')
        self.text.insert(tk.END, f'{len(self.listbox.get(0, tk.END))}')
        self.text.pack(side=tk.BOTTOM , expand = 0, fill=tk.BOTH)

    def selector_entry_callback(self, var, index, mode, mcux_data_type):
        self.model.callback()

    def central_callback(self, event):
        self.model.callback()

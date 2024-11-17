# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

1)  The purpose of these classes is to provide generic abstraction of projects and project files.
    The term "project" - is understood as a set of projects files (like iar project - ewp file, ewd file).
    The term "fsl-project" - is understood as freescale project (like MQX, MQX app or MQX lib, ...)
    with it's structure, source files and the way of distribution


2)  The PROJECT classes
    All directories named by tool (iar, uv4, ...) contains classes:
    * lib/project.rb file
    * app/project.rb file

    to provide basic set of methods/operations to modify a project template files:
    The common operations are:
    * initializer - to setup "project name", "output dir", "root dir" and "templates" list attributes
    * clear! - clear sources/include/macros/libraries
    * save         - 
    * clear/add sources
    * clear/add compiler include
    * clear/add assembler include
    * clear/add compiler defines
    * clear/add assembler defines
    * clear/add libraries
    * list of supported targets (by template file)

    If you are an owner of some simple fsl-project the "project" classes should satisfy all your requirements.
    If not, keep reading.


3)  The FILE classes
    Each project (as ide project so the classes) are made by some (project) files. The file classes 
    provide an API to modify the physical file (means the xml structure) - according GUI elements.
    So if you need some advance settings you should be able to do it by settings instances of
    project file classes.


4)  Common usage:

        project = Iar::App::Project.new(
            project_name    : 'my_project_name',
            output_dir      : './build',
            root_dir        : '../..',
            templates       : ['templates/dummy.ewp', 'templates/dummy.ewd']
        )
        project.some_metod(...)
        project.ewp_file.someTab.otherTab.some_method(...)
        project.save()

    project will be saved into 'output_dir' and file name 'project_name'

#TODO: log system


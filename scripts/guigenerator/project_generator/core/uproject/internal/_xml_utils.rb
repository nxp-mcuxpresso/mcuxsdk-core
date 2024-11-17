# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require 'fileutils'
require_relative '../../../../utils/_assert'


# Wrap often used asserted code to load/save xml file
module Internal
module XmlUtils

    # Save 'xml' content as 'path' file
    # ==== arguments
    # xml   - xml document
    # path  - string, path to output file
    def save(xml, inpath)
        path = inpath.gsub(%r{\\}){ "/" }
        Core.assert(path.is_a?(String) && !path.empty?) do
            "param must be non empty string"
        end
        directory = File.dirname(path)
        FileUtils.mkdir_p(directory) unless (File.directory?(directory))
        File.open(path, 'w') do |handler|
            handler.print(xml.to_xml)
            handler.close
        end
    end

    module_function :save


    # Load 'path' content as xml document
    # ==== arguments
    # path  - string, path to output file
    def load(inpath)
        path = inpath.gsub(%r{\\}){ "/" }
        Core.assert(path.is_a?(String) && !path.empty?) do
            "param must be non empty string"
        end
        Core.assert(File.exist?(path)) do
            "file does not exist '#{path}'"
        end
        xml = Nokogiri::XML(File.open(path)) {|x| x.noblanks }
        Core.assert(!xml.nil?) do
            "cannot open xml #{path}"
        end
        return xml
    end

    module_function :load


end
end

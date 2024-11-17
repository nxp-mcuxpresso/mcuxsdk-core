# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
module XmlFunction
  def self.included(base)
    if base.superclass <= XmlFunction
      base.instance_eval do
        @validation_methods = superclass.instance_variable_get(:@validation_methods).dup
        @xml_list = superclass.instance_variable_get(:@xml_list).dup
        @logger = superclass.instance_variable_get(:@logger).dup
      end
    else
      base.instance_eval do
        @validation_methods = {}
        @xml_list = []
        @logger ||= Logger.new(STDOUT)
      end
    end

    base.extend(ClassMethods)
  end

  module ClassMethods
    def xml(name)
      attr_reader name
      @xml_list << name
    end

    def xmls
      @xml_list
    end
  end


  # Creates XML, validates and saves to the disk
  # @param [XmlDocumentModelBase] xml_document: XML document model
  def generate_doc(xml_document)
    # convert generated document to xml string
    xml = xml_document.to_xml
    # validate XML using XSD
    validate_document(xml_document, xml)
    # save XML to disk to  doc_file_path
    save_xml(xml)
  end

  def validate_xml
    self.class.xmls.each do |xml_document|
      # convert generated document to xml string
      xml = send(xml_document).to_xml
      # validate XML using XSD
      validate_document(send(xml_document), xml)
    end
  end

  def generate_xml
    self.class.xmls.each do |xml_document|
      # convert generated document to xml string
      xml = send(xml_document).to_xml
      # validate XML using XSD
      validate_document(send(xml_document), xml)
      # save XML to disk to  doc_file_path
      save_xml(xml)
    end
  end

  # Saves supplied xml document into file returned from function doc_file_path
  # File will contain extension .INVALID if XSD validation failed
  # @param [String] xml: document that will be saved
  def save_xml(xml, quiet = false)
    # creates new document to specified output directory with predefined manifest file name
    file_path = doc_file_path
    file_path += '.INVALID' unless @validation_status
    file_path += '.NOT_VALIDATED' if @validation_status.nil?
    FileUtils.mkdir_p(File.dirname(file_path)) unless File.exist?(File.dirname(file_path))
    f = File.open(file_path, 'w:utf-8')
    f.write(xml)
    f.close
    puts "Generated: #{file_path}" unless quiet
  end

  # Validates XML document against XSD schema defined in document_instance and prints any errors if found
  # sets validation_status to return value of validation
  # @param [XmlDocumentModelBase] xml_document: instance of document containing validate method
  # @param [String] xml: XML content to be validated
  def validate_document(xml_document, xml)
    @logger.debug 'Starting XSD validation'
    @validation_status = xml_document.validate(xml)

    name = File.basename(doc_file_path)
    if @validation_status
      @logger.debug(name + ': Validation complete, no errors were found')
    else
      @logger.error('FAILED ' + name + ' validation against the XSD schema')
    end
  end

  # @return [String] absolute path of the generated file
  def doc_file_path
    Core.fail 'must be overriden in descendant'
  end
end
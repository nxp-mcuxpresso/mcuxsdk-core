# frozen_string_literal: true

# ********************************************************************
# Copyright 2026 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require 'yaml'

module Internal
  module Iar
    # Lookup of the version fields IAR writes into .ewp/.ewd, keyed by the
    # target Embedded Workbench version.
    #
    # The numbers live in iar_project_version.yml next to this file.
    module ProjectVersion
      TABLE_PATH = File.join(__dir__, 'iar_project_version.yml')

      class UnsupportedVersion < StandardError; end

      class << self
        # Resolve any IAR release onto the table row that covers it, or nil when
        # nothing covers it.
        #
        # IAR numbers minor releases in tens - 9.10, 9.20, 9.30, 9.40 - and the
        # project file schema does not move inside one of those families, so
        # 9.30, 9.30.2, 9.31 and 9.32.1 all resolve to the 9.32 row. A one-digit
        # minor names the same family, which is how 10.1 reaches 10.10: that
        # install reports itself as 10.1.1 even though IAR publishes it as 10.10.
        def normalize(version)
          return nil if version.nil?

          parts = version.to_s.strip.split('.')
          return nil if parts.length < 2

          families[family_of(parts[0], parts[1])]
        end

        def supported
          table.keys
        end

        def supported?(version)
          key = normalize(version)
          !key.nil? && table.key?(key)
        end

        # Version fields for one file kind, as xpath => value.
        # kind is 'ewp' or 'ewd'.
        def fields(version, kind)
          key = normalize(version)
          unless key && table.key?(key)
            raise UnsupportedVersion,
                  "IAR version '#{version}' is not supported. " \
                  "Supported versions: #{supported.join(', ')}. " \
                  "Each one covers its whole family, so 9.30, 9.31 and 9.32.1 all mean 9.32."
          end

          (table[key][kind] || {}).each_with_object({}) do |(field, value), result|
            result[to_xpath(field)] = value
          end
        end

        # '/project/fileVersion' sits outside any <configuration>, so callers
        # have to set it globally rather than per target.
        def global_xpath
          '/project/fileVersion'
        end

        # Options the target version does not know, as settings name => option
        # names. IAR reads the option list by position, so these have to go or
        # everything after them is read as the wrong option.
        def options_to_remove(version, kind)
          newer_than(version, option_table).each_with_object({}) do |entry, result|
            (entry[kind] || {}).each do |settings, options|
              (result[settings] ||= []).concat(options)
            end
          end
        end

        # Whole <settings> blocks the target version does not know.
        def settings_to_remove(version, kind)
          newer_than(version, settings_table).flat_map { |entry| entry[kind] || [] }
        end

        # BUILDACTION changed shape, not just version number, between 9.32 and
        # 9.40. archiveVersion 1 keeps one command each in <prebuild> and
        # <postbuild>; 2 uses a <buildActions> list with a <buildSequence> per
        # entry. True means the target wants the older shape.
        def legacy_build_actions?(version)
          fields(version, 'ewp')[to_xpath('BUILDACTION/archiveVersion')].to_s == '1'
        end

        # CUSTOM also changed shape across its archiveVersion bump: 3 carries a
        # <hasPrio> element between <cmdline> and <buildSequence>, 4 dropped it.
        # True means the target wants <hasPrio> present.
        def legacy_custom_block?(version)
          fields(version, 'ewp')[to_xpath('CUSTOM/archiveVersion')].to_s == '3'
        end

        private

        # Entries of `source` whose version is newer than the target.
        def newer_than(version, source)
          target = rank(version)
          return [] if target.nil? || !supported?(version)

          source.each_with_object([]) do |(introduced, entry), result|
            at = rank(introduced)
            result << entry if at && (at <=> target) == 1 && entry.is_a?(Hash)
          end
        end

        # Compare releases numerically: "10.1" sorts before "9.70" as a
        # string, and minors mix one and two digits.
        def rank(version)
          key = normalize(version)
          key.nil? ? nil : key.split('.').map(&:to_i)
        end

        def option_table
          @option_table ||= raw['options_added_in'] || {}
        end

        # [major, minor rounded down to its ten], the key a family is filed
        # under. A one-digit minor counts as that many tens, so 10.1 and 10.10
        # share a family.
        def family_of(major, minor)
          major = major.to_i
          minor = minor.to_i
          minor *= 10 if minor < 10
          [major, minor - (minor % 10)]
        end

        # family key => the one table row covering it
        def families
          @families ||= table.keys.each_with_object({}) do |key, map|
            major, minor = key.split('.')
            family = family_of(major, minor)
            if map.key?(family)
              raise "#{TABLE_PATH} has two rows for the same IAR family: " \
                    "#{map[family]} and #{key}"
            end

            map[family] = key
          end
        end

        def settings_table
          @settings_table ||= raw['settings_added_in'] || {}
        end

        def raw
          @raw ||= YAML.load_file(TABLE_PATH)
        end

        def table
          @table ||= begin
            data = raw['versions']
            raise "No 'versions' section in #{TABLE_PATH}" unless data.is_a?(Hash)

            data
          end
        end

        # See the notation block in iar_project_version.yml
        def to_xpath(field)
          return global_xpath if field == 'fileVersion'

          settings, rest = field.split('/', 2)
          case rest
          when 'archiveVersion'
            "./settings[name=\"#{settings}\"]/archiveVersion"
          when 'data/version'
            "./settings[name=\"#{settings}\"]/data/version"
          else
            option = rest.to_s.sub(%r{\Aoption/}, '')
            if option == rest.to_s || option.empty?
              raise "Unrecognised version field '#{field}' in #{TABLE_PATH}"
            end

            "./settings[name=\"#{settings}\"]/data/option[name=\"#{option}\"]/version"
          end
        end
      end
    end
  end
end

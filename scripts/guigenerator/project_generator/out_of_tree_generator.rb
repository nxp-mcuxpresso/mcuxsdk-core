# Copyright 2026 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
require 'fileutils'
require 'pathname'
require_relative './generator'
require_relative './out_of_tree_ninja_parser'
require_relative '../utils/utils'

module SDKGenerator
  module ProjectGenerator
    # Generator specialization for out-of-tree projects, paired with
    # OutOfTreeNinjaParser. The base Generator#copy_files only stages files
    # whose ['source'] entry is relative to the SDK root and lives inside the
    # SDK tree.
    # This subclass leaves the base behaviour intact for SDK sources, then
    # restages any file whose absolute location sits under
    # APPLICATION_SOURCE_DIR into <output_dir>/<toolchain>/, mirroring the
    # source layout relative to APPLICATION_SOURCE_DIR, and rewrites the
    # corresponding file entry so the generated project references the local
    # copy.
    class OutOfTreeGenerator < Generator
      def self.applicable?
        OutOfTreeNinjaParser.applicable?
      end

      def copy_files(data)
        super

        app_src = ENV['APPLICATION_SOURCE_DIR']&.tr('\\', '/')
        return if app_src.nil? || app_src.empty?

        toolchain = @generator_options[:toolchains].first
        sdk_root = @generator_options[:input_dir]
        output_dir = @generator_options[:output_dir]
        staging_root = File.join(output_dir, toolchain).tr('\\', '/')

        data.each_value do |set_data|
          set_data.each_value do |section_data|
            modules = section_data.dig('contents', 'modules')
            next unless modules

            modules.each_value do |content|
              files = content['files']
              if files.is_a?(Array)
                files.each_with_index do |file, index|
                  restage_out_of_tree_file(file, files, index, app_src, sdk_root, staging_root)
                end
              end

              %w[cc-include cx-include as-include].each do |key|
                items = content[key]
                next unless items.is_a?(Array)

                items.each_with_index do |item, idx|
                  restage_out_of_tree_include(item, items, idx, app_src, sdk_root, staging_root)
                end
              end
            end
          end
        end
      end

      private

      def restage_out_of_tree_file(file, files, index, app_src, sdk_root, staging_root)
        return if file.nil? || file['generated']

        source_value = file['source'].to_s
        return if source_value.empty?

        src_abs = File.expand_path(File.join(sdk_root, source_value)).tr('\\', '/')
        return unless File.file?(src_abs)
        return unless Utils.path_inside?(src_abs, app_src)

        clean_rel = Pathname.new(src_abs)
                            .relative_path_from(Pathname.new(app_src))
                            .to_s
                            .tr('\\', '/')
        dest_path = File.join(staging_root, clean_rel)

        FileUtils.cp_f(src_abs, dest_path) unless File.exist?(dest_path)

        # Preserve every original key (attribute, toolchains, targets, generated, …)
        # and rewrite only the path-related ones so that downstream consumers like
        # path_mod / linker_file see the staged copy under <staging_root>.
        rewritten = file.dup
        rewritten['source'] = clean_rel
        rewritten['package_path'] = File.dirname(clean_rel)
        rewritten['project_path'] = File.dirname(clean_rel)
        rewritten['repo_path'] = File.dirname(clean_rel)
        files[index] = rewritten
      end

      # Rewrite cc/cx/as-include entries so that paths pointing into
      # APPLICATION_SOURCE_DIR (or other out-of-tree directories) are expressed
      # relative to the staged project root, and the referenced header
      # directories are actually copied under <staging_root>/. Without this,
      # base copy_files leaves the entry alone with a path like
      # "../../external_helper" — which renders in the EWP as
      # "$PROJ_DIR$/../../external_helper" and breaks once the project is
      # relocated.
      def restage_out_of_tree_include(item, items, idx, app_src, sdk_root, staging_root)
        return unless item.is_a?(Hash)

        rel_path = item['path'].to_s.tr('\\', '/')
        return if rel_path.empty? || rel_path == './'

        abs = resolve_include_abs(rel_path, sdk_root, staging_root)
        return if abs.nil?
        return unless Dir.exist?(abs)

        # If the directory is already inside the staging tree, super has handled it.
        return if Utils.path_inside?(abs, staging_root) || abs == staging_root
        # SDK-internal includes are staged at <staging>/<sdk-relative> by super already.
        return if Utils.path_inside?(abs, NinjaParser::REPO_ROOT_PATH)

        # A sibling standalone project's build-output directory. In sysbuild
        # multi-image builds one project's INCLUDES can carry another image's
        # <build_root>/<image>/<toolchain> output dir so the compiler/linker
        # can reach that sibling's generated artifacts — e.g. a multicore
        # secondary-core image whose core1_image.bin is pulled into the primary
        # image via `.incbin`, or a TF-M secure image exposing its CMSE import
        # lib. In-tree the absolute -I to the sibling build dir makes this work;
        # the parser has already expressed it as a `../../<sibling>/<toolchain>`
        # path relative to this project's staging root. Keep that relative
        # reference verbatim instead of remapping it to a local
        # external/<toolchain> dir and copying only headers — the latter both
        # drops non-header artifacts (the .bin) and severs the cross-image
        # reference. This mirrors how the generated CMSE-lib link path is
        # emitted as ${ProjDirPath}/../../<sibling>/<toolchain>/....
        toolchain = File.basename(staging_root)
        build_root = File.dirname(File.dirname(staging_root))
        return if File.basename(abs) == toolchain &&
                  File.dirname(File.dirname(abs)) == build_root

        # Note: Utils.path_inside? uses fnmatch with `**` which yields false
        # when path_a == path_b. Handle the include-equals-APP_SRC case
        # explicitly (typical when the user writes `mcux_add_include(INCLUDES .)`),
        # otherwise it would fall through to the `external/<parent>/<basename>`
        # branch and produce a path that does not exist in the staged tree.
        # The `external/<parent>/<basename>` layout (rather than the
        # shorter `external/<basename>`) keeps unrelated dirs like
        # ~/vendor_a/include and ~/vendor_b/include from colliding by
        # construction.
        clean_rel =
          if abs == app_src || Utils.path_inside?(abs, app_src)
            Pathname.new(abs).relative_path_from(Pathname.new(app_src)).to_s.tr('\\', '/')
          else
            File.join('external', File.basename(File.dirname(abs)), File.basename(abs))
          end

        Dir.glob(File.join(abs, '*.{h,hpp,inc}')).each do |hdr|
          dest = File.join(staging_root, clean_rel, File.basename(hdr))
          FileUtils.cp_f(hdr, dest) unless File.exist?(dest)
        end

        items[idx] = {
          'path' => clean_rel,
          'package_path' => clean_rel,
          'project_path' => clean_rel
        }
      end

      # Two bases coexist for stored include paths in standalone mode:
      #   * SDK-internal entries (path.include? REPO_ROOT_PATH branch) are
      #     stored relative to REPO_ROOT_PATH (no leading ./ or ../).
      #   * Everything else (base parse_include_path standalone branch) is
      #     stored relative to <build>/<toolchain> (= staging_root) and
      #     therefore starts with ../ or ./.
      # Disambiguate by inspecting the prefix.
      def resolve_include_abs(rel_path, sdk_root, staging_root)
        return rel_path if rel_path.match?(/\A[A-Za-z]:\//) || rel_path.start_with?('/')

        base = rel_path.start_with?('./', '../') ? staging_root : NinjaParser::REPO_ROOT_PATH
        File.expand_path(File.join(base, rel_path)).tr('\\', '/')
      end
    end
  end
end

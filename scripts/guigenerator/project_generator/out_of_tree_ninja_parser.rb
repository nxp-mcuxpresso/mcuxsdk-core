# Copyright 2026 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
require 'pathname'
require_relative './ninja_parser'

# Parser specialization for out-of-tree projects, i.e. examples whose
# APPLICATION_SOURCE_DIR sits outside the SDK repository root.
#
# This subclass rewrites the offending branch to always store the source
# path relative to REPO_ROOT_PATH, matching what include-path handling
# already does for GUI projects.
class OutOfTreeNinjaParser < NinjaParser
  # Detect whether the current invocation targets an out-of-tree example.
  def self.applicable?
    app_src = ENV['APPLICATION_SOURCE_DIR']
    return false if app_src.nil? || app_src.empty?

    !Utils.path_inside?(app_src, REPO_ROOT_PATH)
  end

  def add_file(file_full_path, line, type, attribute = nil, exclude = false)
    abs_path = file_full_path.tr('\\', '/')

    unless File.exist?(abs_path)
      @non_existent_files.push_uniq abs_path
      return unless attribute == 'extra-libraries'
    end

    out_of_tree_source = false
    if abs_path.include? REPO_ROOT_PATH
      file_path = abs_path.split(REPO_ROOT_PATH)[-1].sub('/', '')
    elsif abs_path.include? "#{@name}.dir/"
      # Build artifacts live in <build>/CMakeFiles/<name>.dir/.... Reconstruct
      # the path as APPLICATION_SOURCE_DIR-relative, then express that relative
      # to REPO_ROOT_PATH so downstream path_mod can resolve it.
      tail = abs_path.split("#{@name}.dir/")[1]
      app_src = ENV['APPLICATION_SOURCE_DIR'].to_s.tr('\\', '/')
      reconstructed = File.join(app_src, tail)
      file_path = get_relative_path(REPO_ROOT_PATH, reconstructed)
      out_of_tree_source = true
    else
      # Includes the ${APPLICATION_BINARY_DIR}/.. case as well as anything
      # else outside the repo: always express paths relative to the SDK root
      # so they round-trip through path_mod cleanly.
      file_path = get_relative_path(REPO_ROOT_PATH, abs_path)
      out_of_tree_source = true
    end

    file_path = complete_path(file_path, line, attribute) if @toolchain == 'mdk'
    return if file_path.nil?

    # `source` must stay relative to the SDK root so path_mod can resolve it.
    # `project_path` drives the virtual-folder hierarchy shown inside the IDE
    # project browser; for out-of-tree sources we anchor it to
    # APPLICATION_SOURCE_DIR so the IDE displays a clean tree instead of a
    # chain of `..` parents climbing out of the SDK root.
    project_path = virtual_folder_path(file_path, abs_path, out_of_tree_source)

    source_hash = {
      'source' => file_path,
      'type' => type,
      'project_path' => project_path,
      'repo_path' => File.dirname(file_path),
      'package_path' => File.dirname(file_path)
    }
    source_hash['attribute'] = attribute if attribute
    source_hash['exclude'] = exclude if exclude

    if @toolchain == 'codewarrior' && source_hash['project_path'] == 'build'
      source_hash['project_path'] = 'build_dir'
    end
    @data[@name]['contents']['modules']['demo']['files'].push(source_hash)
  end

  # Drain ALL linker-script occurrences from LINK_FLAGS and keep the LAST one.
  #
  # The base parse_ld_script only sub!'s the first match, so for projects
  # whose LINK_FLAGS line carries more than one "--config <icf>" /
  # "--scatter <scf>" / "-T <ld>" pair (e.g. SDK default + user override that
  # the cmake-level remove-flag plumbing missed), every extra pair is left
  # behind. The IAR/MDK flag analyzers then mis-classify the bare script
  # path as IlinkConfigDefines / --predef, polluting the generated .ewp/.uvprojx.
  #
  # Why LAST wins: on the real link command line each subsequent --config
  # overrides the previous, so the EWP IlinkIcfFile setting should reflect
  # the last one specified — that matches what `mcux_add_iar_linker_script`
  # is supposed to express when called after the SDK default has already
  # been added.
  def parse_ld_script(all_flags)
    pattern =
      case @toolchain
      when 'iar' then /--config\s+(\S+)\s/
      when 'mdk' then /--scatter\s+(\S+)\s/
      when 'armgcc' then /-T\s+(\S+)\s/
      when 'codewarrior' then /(\S+Internal_PFlash_(SDM|LDM|HPM|LPM|SPM)\.cmd)/
      end
    return all_flags unless pattern

    scripts = []
    while (result = all_flags.match(pattern))
      scripts << result[1]
      all_flags.sub!(result[0], '')
    end

    chosen = scripts.last
    if chosen
      path = get_relative_path(REPO_ROOT_PATH, chosen.tr('\\', '/'))
      tmp = {
        'source' => path,
        'attribute' => 'linker-file',
        'toolchains' => @toolchain,
        'targets' => @config,
        'type' => 'linker',
        'project_path' => File.dirname(path),
        'repo_path' => File.dirname(path),
        'package_path' => File.dirname(path)
      }
      tmp['generated'] = true unless File.exist?(chosen)
      @data[@name]['contents']['modules']['demo']['files'].push(tmp)
    end
    all_flags
  end

  # Override parse_include_path to recover malformed paths that show up when
  # the cmake-level `mcux_add_include` is fed an already-absolute path: it
  # unconditionally joins with CMAKE_CURRENT_LIST_DIR/BASE_PATH and emits
  # paths like "C:/test_temp/5_22_2/C:/test_temp/external_lib" into
  # build.ninja's INCLUDES line. The base parse_include_path runs that
  # through Pathname.cleanpath which silently drops the second colon,
  # producing the garbage "$PROJ_DIR$/../../C/test_temp/external_lib" form.
  #
  # We pre-clean the raw path: if it contains more than one Windows drive
  # root (`<letter>:/`), we keep only the portion starting at the LAST
  # drive root, which is the user's actual intended absolute path.
  def parse_include_path(source_pattern, type)
    find_source_obj = false
    @content.each do |line|
      if line.match(source_pattern)
        find_source_obj = true
        next
      end
      next unless find_source_obj

      inc_match = line.match(/INCLUDES\s=\s*([\S\s]+)\s*/)
      next unless inc_match

      inc_match[1].scan(/-I(?:"([^"]+)"|(\S+))/) do |quoted, unquoted|
        include_dir = (quoted || unquoted)
        path = recover_malformed_drive_path(include_dir.tr('\\', '/'))
        next if path.nil? || path.empty?

        include_path = compute_include_entry_path(path)
        next if include_path.nil?

        @data[@name]['contents']['modules']['demo']["#{type}-include"].push(
          'path' => include_path,
          'package_path' => include_path,
          'project_path' => include_path
        )
      end
      break
    end
  end

  # Translate an absolute compile-flag path (e.g. the operand of -include) into
  # something downstream consumers can join with ${ProjDirPath} / $PROJ_DIR$.
  #
  # The base implementation, when standalone is active, does
  #   path = abs_path.split(REPO_ROOT_PATH)[-1]
  #   Pathname.new(File.join('.', path)).cleanpath.to_s
  # which assumes abs_path lives under the SDK repo. For an out-of-tree
  # example whose APPLICATION_SOURCE_DIR is *outside* REPO_ROOT_PATH, the
  # split is a no-op (returns the original absolute path), then the
  # File.join('.', 'C:/...') + cleanpath collapses the drive colon, producing
  # garbage like ${ProjDirPath}/C/git_repo/.../app_preinclude.h.
  #
  # Override: when the input is an out-of-tree absolute path that resolves
  # inside APPLICATION_SOURCE_DIR, return its path relative to
  # APPLICATION_SOURCE_DIR. OutOfTreeGenerator stages those files into
  # <project>/<APP_SRC-relative-path>, so the resulting ${ProjDirPath}/<rel>
  # points at the staged copy.
  def translate_project_relative_path(abs_path, path_from_other_project = false)
    if ENV['standalone'] == 'true'
      abs_norm = abs_path.tr('\\', '/')
      app_src = ENV['APPLICATION_SOURCE_DIR'].to_s.tr('\\', '/')
      relative_to_outdir = Pathname.new(abs_norm).relative_path_from(Pathname.new(@outdir)).to_s

      # Only intervene when the base logic would otherwise corrupt the path:
      # the file lives in APPLICATION_SOURCE_DIR (so it's inside the staged
      # project after OutOfTreeGenerator copies it), is *outside* REPO_ROOT_PATH
      # (so split(REPO_ROOT_PATH) is a no-op), and is *outside* the build dir
      # (so relative_to_outdir starts with `..` and the broken branch kicks in).
      if !app_src.empty? &&
         Utils.path_inside?(abs_norm, app_src) &&
         !Utils.path_inside?(abs_norm, REPO_ROOT_PATH) &&
         relative_to_outdir.start_with?('..')
        rel = Pathname.new(abs_norm)
                      .relative_path_from(Pathname.new(app_src))
                      .to_s
                      .tr('\\', '/')
        return Pathname.new(File.join('.', rel)).cleanpath.to_s
      end
    end

    super
  end

  private

  # Strip duplicated Windows drive roots: keep everything from the LAST
  # `<letter>:/` onward. For well-formed paths (zero or one drive root)
  # the input is returned unchanged.
  def recover_malformed_drive_path(path)
    positions = []
    path.scan(/[A-Za-z]:\//) { positions << Regexp.last_match.begin(0) }
    return path if positions.length <= 1

    path[positions.last..-1]
  end

  # Same selection logic the base parse_include_path uses, factored out so
  # the override above can apply our malformed-path recovery before this
  # decision is made.
  def compute_include_entry_path(path)
    if path.include?(REPO_ROOT_PATH)
      return './' if path == REPO_ROOT_PATH

      return path.split(REPO_ROOT_PATH)[-1].sub('/', '')
    end

    begin
      if ENV['standalone'] == 'true'
        return './' if Pathname.new(path).cleanpath == Pathname.new(@outdir).cleanpath

        return Pathname.new(path)
                       .relative_path_from(Pathname.new(File.join(@outdir, @toolchain)))
                       .to_s
                       .tr('\\', '/')
      end
      Pathname.new(path)
              .relative_path_from(Pathname.new(REPO_ROOT_PATH))
              .cleanpath
              .to_s
              .tr('\\', '/')
    rescue StandardError
      @logger.warn("OutOfTreeNinjaParser: cannot compute relative include path for #{path}, dropping")
      nil
    end
  end

  def virtual_folder_path(file_path, abs_path, out_of_tree_source)
    return File.dirname(file_path) unless out_of_tree_source

    app_src = ENV['APPLICATION_SOURCE_DIR'].to_s.tr('\\', '/')
    return File.dirname(file_path) if app_src.empty?
    return File.dirname(file_path) unless Utils.path_inside?(abs_path, app_src)

    rel = Pathname.new(abs_path).relative_path_from(Pathname.new(app_src)).to_s.tr('\\', '/')
    File.dirname(rel)
  end
end

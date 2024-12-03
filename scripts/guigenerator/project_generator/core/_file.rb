# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require 'fileutils'


# Extend standard File class
class File

    # If path consists of "direct/ory/file.ext"
    # return "direct/ory/file"
    def self.filebase(path)
        ext = File.extname(path)
        base = File.basename(path, ext)
        dir = File.dirname(path)
        return File.join(dir, base)
    end

    # return extension without leading dot
    def self.extension(path)
        extension = File.extname(path)
        extension.gsub!('.', '')
        return extension
    end

    # convert common slash-separated path 
    # to windows backslash-separated
    def self.to_backslash(path)
        return path.gsub('/','\\')
    end

    def self.to_slashpath(path)
        return path.gsub('\\','/')
    end

    def self.force_write(filepath, content)
        filedir = dirname(filepath)
        unless File.directory?(filedir)
            FileUtils.mkdir_p(filedir)
        end
        File.write(filepath, content)
    end

    def self.no_currentdir(path)
        path = to_slashpath(path)
        path = path.gsub(/^.\//, '')
        path = path.gsub(/\/.\/$/, '')
        return path
    end

    def self.relpath(from_path, to_path)
        from_path = no_dots(from_path)
        to_path = no_dots(to_path)
        # puts "basepath: #{from_path}"
        # puts "fullpath: #{to_path}"
        basepath_parts = from_path.split('/')
        fullpath_parts = to_path.split('/')
        restpath = ''
        count = basepath_parts.count < fullpath_parts.count ? fullpath_parts.count : basepath_parts.count
        (0..(count - 1)).each do | index |
            if (
                !(restpath.empty?) || fullpath_parts[ index ] != basepath_parts[ index ]
            )
                # preppend dots
                if (basepath_parts[ index ])
                    restpath = restpath.empty? ? '..' : '../' + restpath
                end
                # append parts
                if (fullpath_parts[ index ])
                    restpath = restpath.empty? ? fullpath_parts[ index ] : restpath + '/' + fullpath_parts[ index ]
                end
            end
        end
        # puts "restpath: #{restpath}"
        return restpath
    end

    def self.backpath(path)
        path = path.gsub(/[^\/]+\//, '../')
        path = path.gsub(/[^\/]+$/, '..')
        return path
    end

    # evaluate useless dots in path
    # path is not verified on filesystem
    def self.no_dots(path)
        path = to_slashpath(path)
        inparts = path.split('/')
        outparts, skip_count = [], 0
        inparts.reverse_each do | part |
            if (part == '..')
                # parent directory - increase the 'skip' number
                skip_count += 1
            elsif (part == '.')
                # same directory - do nothing
            elsif (skip_count > 0)
                # skip directory
                skip_count -=1 
            else
                # add directory
                outparts.push(part)
            end
        end
        if (skip_count >= 1)
            # add leading dots which cannot be eliminated
            (1..skip_count).each do | part |
                outparts.push('..')
            end
        end
        outparts.reverse!
        return outparts.join('/')
    end

    def self.double_quote(path)
        # check whether path was already 'quoted'
        # if yes do nothing
        return path if (path =~ /^".*"$/)
        return "\"#{path}\""
    end

    def self.single_quote(path)
        # check whether path was already 'quoted'
        # if yes do nothing
        return path if (path =~ /^'.*'$/)
        return "'#{path}'"
    end

    def self.quote(path)
        return double_quote(path)
    end

    def self.no_leading_dots(path)
        path = path.sub(/^[\.\/]+/, '')
        return path
    end

end


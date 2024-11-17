# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************


# Extend standard array functionality
class Array

    # Return first item matched by regex or nil
    def first_by_regex(regex)
        result = nil
        each do | item | 
            if (item =~ regex)
                result = item
                break
            end
        end
        return result
    end

    # Return list of matched elements by regex
    def all_by_regex(regex)
        result = []
        each do | item | 
            result.push(item) if (item =~ regex)
        end
        return result
    end

    # emulate python's list comprehetion
    def comprehend(&block)
        return self if block.nil?
        self.collect(&block).compact
    end

end


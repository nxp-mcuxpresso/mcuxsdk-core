# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../utils/_assert'

class Hook

    def initialize()
        @table = {}
        @chained_callback = method(:_chained_method)
    end

    def attach(connection)
        unless (@table.has_key?(connection.__id__))
            @table[ connection.__id__ ] = connection
        end
    end

    def detach(connection)
        if (@table.has_key?(connection.__id__))
            @table.delete(connection.__id__)
        end
    end

    def notify(*args, **kwargs)
        @table.each do | id, function |
            if (kwargs.empty?)
                # to keep backward compatibility
                function.call(*args)
            else
                function.call(*args, **kwargs)
            end
        end
    end

    def is_used?
        return !@table.empty?
    end

    def is_present?(connection)
        return @table.has_key?(connection.__id__)
    end

    # purpose of this function is to chain
    # process flow of 'hook_to_chain'
    # and current hook (itself)
    def _chained_method(*args, **kwargs)
        notify(*args, **kwargs)
    end

    # behaviour of previous implementation was wrong
    # the chain MUST reflect every update of 
    # 'hook_to_chain' and current hook (itself)
    def chain_hook(hook_to_chain)
        Core.assert(hook_to_chain.is_a?(Hook)) do
            "'hook_to_chain' has #{hook_to_chain.class.name} instead 'Hook' "
        end
        hook_to_chain.attach(@chained_callback)
    end

    # current implementation allows also detach
    # of chained hooks
    def unchain_hook(hook_to_chain)
        Core.assert(hook_to_chain.is_a?(Hook)) do
            "'hook_to_chain' has #{hook_to_chain.class.name} instead 'Hook' "
        end
        hook_to_chain.detach(@chained_callback)
    end
end



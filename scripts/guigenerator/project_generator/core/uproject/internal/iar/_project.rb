# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../../uproject/internal/_project'


# Provide for purpose to check whether 
# instance is a uv4 project "instance.is_a?(Internal::Iar::Project)"
module Internal
module Iar

    class UProject < Internal::Project
    end

end
end



# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
module SDKGenerator
  class SDKGENException < StandardError; end

  class CommandLineError < SDKGENException; end

  class OptionError < SDKGENException; end

  class InternalError < SDKGENException; end

  class YmlLoadError < SDKGENException; end

  class DataDefinitionError < SDKGENException; end

  class UnexpectedStepResult < SDKGENException; end

  class DataCleanError < SDKGENException; end

  class DataProcessError < SDKGENException; end

  class GeneratorRunFailed < SDKGENException; end

  class ManifestValidationException < SDKGENException; end

  class ManifestRuntimeError < SDKGENException; end
end

# frozen_string_literal: true

require_relative('../modulation')

# Kernel extensions - mock up the Modulation API with nop methods, so
# requiring a gem would work. Sample usage:
#
#   require 'modulation/gem'
#   export_default :MyGem
#
#   module MyGem
#     MyClass = import('my_class')
#     MyOtherClass = import('my_other_class')
#   end
module Kernel
  # Stub for export method, does nothing in the context of a required gem
  def export(*args); end

  # Stub for export_default method, does nothing in the context of a required
  # gem
  def export_default(value); end
end

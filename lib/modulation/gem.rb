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
  def export(*args); end
  def export_default(v); end
end
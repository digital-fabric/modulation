# frozen_string_literal: true

module Modulation
  # Functionality related to export from receiver
  module ExportFromReceiver
    class << self
      def from_const(mod, name)
        receiver = mod.singleton_class.const_get(name)

        methods = create_forwarding_methods(mod, receiver)
        consts = copy_constants(mod, receiver)
        methods + consts
      end

      # @return [Array] list of receiver methods
      def create_forwarding_methods(mod, receiver)
        receiver_methods(receiver).each do |m|
          mod.singleton_class.define_method(m) do |*args, &block|
            receiver.send(m, *args, &block)
          end
        end
      end

      def receiver_methods(receiver)
        ignored_klass = case receiver
                        when Class, Module then receiver.class
                        else Object
                        end
        
        methods = receiver.methods.select { |m| m !~ /^__/ }
        methods - ignored_klass.instance_methods
      end

      # @return [Array] list of receiver constants
      def copy_constants(mod, receiver)
        receiver.constants(false).each do |c|
          mod.singleton_class.const_set(c, receiver.const_get(c))
        end
      end
    end
  end
end

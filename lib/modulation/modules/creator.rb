# frozen_string_literal: true

export :from_block,
       :from_hash,
       :from_string

RE_ATTR   = /^@(.+)$/.freeze

def from_block(block)
  Module.new.tap { |m| m.instance_eval(&block) }
end

# Creates a module from a prototype hash
# @param hash [Hash] prototype hash
# @return [Module] created object
def from_hash(hash)
  Module.new.tap do |m|
    s = m.singleton_class
    hash.each do |k, v|
      if k =~ Modulation::RE_CONST
        m.const_set(k, v)
      elsif k =~ RE_ATTR
        m.instance_variable_set(k, v)
      elsif v.respond_to?(:to_proc)
        s.send(:define_method, k) { |*args| instance_exec(*args, &v) }
      else
        s.send(:define_method, k) { v }
      end
    end
  end
end

def from_string(str)
  m = Modulation::Builder.make(source: str)
end

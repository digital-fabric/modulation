# frozen_string_literal: true

export :from_block,
       :from_hash,
       :from_string

RE_ATTR = /^@(.+)$/.freeze

def from_block(block)
  Module.new.tap { |m| m.instance_eval(&block) }
end

# Creates a module from a prototype hash
# @param hash [Hash] prototype hash
# @return [Module] created object
def from_hash(hash)
  Module.new.tap do |m|
    s = m.singleton_class
    hash.each { |k, v| process_hash_entry(k, v, m, s) }
  end
end

def process_hash_entry(key, value, mod, singleton)
  if key =~ Modulation::RE_CONST
    mod.const_set(key, value)
  elsif key =~ RE_ATTR
    mod.instance_variable_set(key, value)
  elsif value.respond_to?(:to_proc)
    singleton.send(:define_method, key) { |*args| instance_exec(*args, &value) }
  else
    singleton.send(:define_method, key) { value }
  end
end

def from_string(str)
  Modulation::Builder.make(source: str)
end

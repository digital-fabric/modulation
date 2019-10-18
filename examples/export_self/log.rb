# frozen_string_literal: true

export_default -> { MODULE }

def log(level, msg)
  puts "#{Time.now} #{level} #{msg}"
end

def debug(msg)
  log :D, msg
end

def warn(msg)
  log :W, msg
end

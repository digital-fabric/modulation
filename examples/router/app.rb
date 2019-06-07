require_relative '../../lib/modulation'

API = import_map('./handlers') { |fn| fn.to_sym }

def api_call(params)
  handler = API[params[:kind]]
  raise "Handler not found for #{params[:kind]}" unless handler
  handler.(params)
end

puts "add(2, 3): #{api_call(kind: :add, x: 2, y: 3)}"
puts "mul(2, 3): #{api_call(kind: :mul, x: 2, y: 3)}"
puts "sub(2, 3): #{api_call(kind: :sub, x: 2, y: 3)}"


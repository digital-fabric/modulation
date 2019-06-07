default:
	ruby -e"Dir.glob('./test/test_*.rb').each { |file| require file}"

test: lib/**/*.rb 
	ruby -e"Dir.glob('./test/test_*.rb').each { |file| require file}"

default:
	echo "Dir.glob('./test/test_*.rb').each { |file| require file}" | ruby

test: lib/**/*.rb 
	echo "Dir.glob('./test/test_*.rb').each { |file| require file}" | ruby

# frozen_string_literal: true

require_relative '../lib/modulation'

# This will fail because the redis gem does not use Modulation
import('redis')

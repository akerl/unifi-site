#!/usr/bin/env ruby

require 'yaml'
require 'ipaddr'

CONFIG_FILE = 'data.yaml'

data = YAML.load_file(CONFIG_FILE)

data['lans'] = data['lans'].sort_by do |_, v|
  IPAddr.new(v['subnet']).to_i
end.to_h

data['clients'] = data['clients'].sort_by do |k, _|
  IPAddr.new(k).to_i
end.to_h

File.open(CONFIG_FILE, 'w') do |fh|
  fh << data.to_yaml
end

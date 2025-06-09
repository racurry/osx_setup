#!/usr/bin/env ruby

require_relative '../lib/macos_setup'

puts "Testing migrated MacOSSetup methods..."

begin
  setup = MacOSSetup.new
  puts "✅ MacOSSetup initialized successfully"
  
  # Test that all migrated methods exist
  methods_to_test = [
    :update_to_latest,
    :manual_todos,
    :system_hygiene,
    :sync_dotfiles,
    :setup_app_configs,
    :setup_macos,
    :create_folders,
    :install_apps,
    :manage_packages,
    :setup_everything
  ]
  
  methods_to_test.each do |method|
    if setup.respond_to?(method)
      puts "✅ #{method} method exists"
    else
      puts "❌ #{method} method missing"
      exit 1
    end
  end
  
  puts "✅ All migrated methods are available"
  puts "✅ Migration tests passed"
  
rescue => e
  puts "❌ Test failed: #{e.message}"
  puts e.backtrace.first(3)
  exit 1
end
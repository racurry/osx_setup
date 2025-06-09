require 'json'
require_relative '../terminal_helpers'

class MacOSSetup::PackageManager::GlobalPackageManager
  include MacOSSetup::TerminalHelpers
  PACKAGE_CONFIGS = {
    npm: {
      file: 'data/package.json',
      parser: :parse_package_json,
      installer: :install_npm_package,
      checker: ->(pkg) { system("npm list -g #{pkg} > /dev/null 2>&1") },
      name: 'npm global packages'
    },
    gems: {
      file: 'data/Gemfile',
      parser: nil, # Uses bundler directly
      installer: :install_gem_packages,
      checker: nil,
      name: 'gem packages'
    },
    pip: {
      file: 'data/requirements.txt',
      parser: :parse_requirements_txt,
      installer: :install_pip_package,
      checker: nil,
      name: 'pip packages'
    }
  }

  def install_all_packages(options)
    success = true
    PACKAGE_CONFIGS.each do |type, config|
      success &= install_packages(type, options)
    end
    success
  end

  def install_packages(type, options)
    config = PACKAGE_CONFIGS[type]
    return true unless config

    update_mode = options[:update]
    verbose_mode = options[:verbose]

    unless File.exist?(config[:file])
      pputs "No #{File.basename(config[:file])} found, skipping #{config[:name]}", indent: 1, color: :yellow
      return true
    end

    case type
    when :gems
      install_gem_packages(update_mode, verbose_mode, config[:file])
    else
      install_individual_packages(type, config, update_mode, verbose_mode)
    end
  end

  private

  def install_individual_packages(type, config, update_mode, verbose_mode)
    packages = send(config[:parser], config[:file])
    
    if packages.empty?
      pputs "No packages found in #{File.basename(config[:file])}, skipping #{config[:name]}", indent: 1, color: :yellow
      return true
    end

    action = update_mode ? "Updating" : "Installing"
    pputs "#{action} #{config[:name]}...", style: :bold

    success = true
    packages.each do |package, version|
      pprint "#{action} #{package}", indent: 1

      # Check if already installed (only in install mode)
      if !update_mode && config[:checker] && config[:checker].call(package)
        print_column_fill("  #{action} #{package}", indent: 1, color: :green)
        pputs " already installed", color: :green
      else
        if send(config[:installer], package, version, verbose_mode)
          print_column_fill("  #{action} #{package}", indent: 1, color: :green)
          pputs " completed", color: :green
        else
          print_column_fill("  #{action} #{package}", indent: 1, color: :red)
          pputs " failed", color: :red
          success = false
        end
      end
    end

    success
  end

  def parse_package_json(file_path)
    package_data = JSON.parse(File.read(file_path))
    package_data['dependencies'] || {}
  end

  def parse_requirements_txt(file_path)
    content = File.read(file_path).strip
    packages = {}
    
    content.lines.each do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#')
      
      # Handle package==version or just package
      if line.include?('==')
        package, version = line.split('==', 2)
        packages[package] = version
      else
        packages[line] = nil
      end
    end
    
    packages
  end

  def install_npm_package(package, version, verbose_mode)
    npm_command = "npm install -g #{package} --silent --no-fund"
    npm_command += " > /dev/null 2>&1" unless verbose_mode
    system(npm_command)
  end

  def install_pip_package(package, version, verbose_mode)
    pip_command = if version
                    "pip install #{package}==#{version}"
                  else
                    "pip install #{package}"
                  end
    pip_command += " > /dev/null 2>&1" unless verbose_mode
    system(pip_command)
  end

  def install_gem_packages(update_mode, verbose_mode, gemfile_path)
    action = update_mode ? "Updating" : "Installing"
    pputs "#{action} gem packages...", style: :bold

    if update_mode
      pprint "Running bundle update", indent: 1
      if verbose_mode
        command = "cd data && bundle config set --local path.system true && bundle update"
      else
        command = "cd data && bundle config set --local path.system true > /dev/null 2>&1 && bundle update > /dev/null 2>&1"
      end
      success_msg = "  Running bundle update"
    else
      pprint "Running bundle install", indent: 1
      if verbose_mode
        command = "cd data && bundle config set --local path.system true && bundle install"
      else
        command = "cd data && bundle config set --local path.system true > /dev/null 2>&1 && bundle install > /dev/null 2>&1"
      end
      success_msg = "  Running bundle install"
    end

    if system(command)
      print_column_fill(success_msg, indent: 1, color: :green)
      pputs " completed", color: :green
      true
    else
      print_column_fill(success_msg, indent: 1, color: :red)
      pputs " failed", color: :red
      false
    end
  end
end
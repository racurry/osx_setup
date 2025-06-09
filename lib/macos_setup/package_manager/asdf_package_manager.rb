require_relative '../terminal_helpers'

class MacOSSetup::PackageManager::AsdfPackageManager
  include MacOSSetup::TerminalHelpers
  
  def initialize
  end

  def install_packages(options)
    update_mode = options[:update]
    verbose_mode = options[:verbose]
    
    if update_mode
      check_asdf_versions
      return true
    end
    
    unless check_tool_versions_file
      exit 1
    end
    
    # Install/update asdf packages first (provides language runtimes)
    tool_versions_file = File.exist?('data/dotfiles/.tool-versions') ? 'data/dotfiles/.tool-versions' : nil
    unless install_asdf_packages(update_mode, verbose_mode, tool_versions_file)
      action = update_mode ? "update" : "install"
      pputs "Failed to #{action} asdf packages. Check output above for details.", color: :red
      exit 1
    end
    
    true
  end

  def upgrade_tool_versions(verbose_mode = false)
    section_header "Upgrading Development Package Versions"
    
    unless check_tool_versions_file
      exit 1
    end
    
    # Upgrade .tool-versions file (installs packages during upgrade process)
    unless upgrade_tool_versions_internal(verbose_mode)
      pputs "Failed to upgrade .tool-versions file", color: :red
      exit 1
    end
    
    section_footer "Package Version Upgrade Complete"
  end

  private

  def check_tool_versions_file
    tool_versions_path = File.expand_path('~/.tool-versions')
    
    unless File.exist?(tool_versions_path)
      pputs "⚠️  ~/.tool-versions file not found", color: :yellow, style: :bold
      pputs "This file specifies which tool versions to install with asdf", indent: 1, color: :yellow
      pputs "Create one or symlink your dotfiles first", indent: 1, color: :yellow
      return false
    end
    
    true
  end

  def get_managed_tools
    # Get the actual file path, not the symlink
    tool_versions_symlink = File.expand_path('~/.tool-versions')
    if File.symlink?(tool_versions_symlink)
      tool_versions_path = File.readlink(tool_versions_symlink)
      # Handle relative symlinks
      unless tool_versions_path.start_with?('/')
        tool_versions_path = File.expand_path(tool_versions_path, File.dirname(tool_versions_symlink))
      end
    else
      tool_versions_path = tool_versions_symlink
    end
    
    unless File.exist?(tool_versions_path)
      return nil, tool_versions_path
    end
    
    # Parse .tool-versions to get only the tools we're managing
    managed_tools = {}
    File.readlines(tool_versions_path).each do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#')
      parts = line.split(' ', 2)
      if parts.length >= 2
        managed_tools[parts[0]] = parts[1]
      end
    end
    
    return managed_tools, tool_versions_path
  end

  def check_asdf_versions
    pputs "Checking asdf tool versions...", style: :bold
    
    managed_tools, tool_versions_path = get_managed_tools
    
    if managed_tools.nil?
      pputs "~/.tool-versions not found", indent: 1, color: :yellow
      return
    end
    
    if managed_tools.empty?
      pputs "No tools found in ~/.tool-versions", indent: 1, color: :yellow
      return
    end
    
    managed_tools.each do |plugin, current_version|
      # Get latest stable version (filter out pre-releases with letters)
      latest_version = `asdf list all #{plugin} 2>/dev/null | grep -E '^[0-9]+\\.[0-9]+\\.[0-9]+$' | tail -1`.strip
      
      pprint "#{plugin}", indent: 1
      
      if latest_version.empty?
        print_column_fill("  #{plugin}", indent: 1, color: :yellow)
        pputs " #{current_version} (can't check latest)", color: :yellow
      elsif current_version == latest_version
        print_column_fill("  #{plugin}", indent: 1, color: :green)
        pputs " #{current_version} (latest)", color: :green
      else
        print_column_fill("  #{plugin}", indent: 1, color: :yellow)
        pputs " #{current_version} → #{latest_version} available", color: :yellow
      end
    end
    
    pputs ""
  end

  def install_asdf_packages(update_mode = false, verbose_mode = false, tool_versions_file = nil)
    # Use specified file or fall back to symlinked ~/.tool-versions
    if tool_versions_file && File.exist?(tool_versions_file)
      pputs "Installing asdf packages from #{tool_versions_file}...", style: :bold
      pprint "Running asdf install", indent: 1
      
      # Change to the directory containing the tool-versions file and unset env vars
      tool_versions_dir = File.dirname(File.expand_path(tool_versions_file))
      install_command = "cd #{tool_versions_dir} && unset ASDF_RUBY_VERSION ASDF_NODEJS_VERSION ASDF_PYTHON_VERSION LDFLAGS CPPFLAGS && asdf plugin update ruby && asdf install"
      # install_command += " > /dev/null 2>&1" unless verbose_mode  # Temporarily force verbose
      if system(install_command)
        print_column_fill("  Running asdf install", indent: 1, color: :green)
        pputs " completed", color: :green
        pputs ""
        true
      else
        print_column_fill("  Running asdf install", indent: 1, color: :red)
        pputs " failed", color: :red
        pputs ""
        false
      end
    else
      pputs "Installing asdf packages from ~/.tool-versions...", style: :bold
      pprint "Running asdf install", indent: 1
      
      install_command = "asdf install"
      install_command += " > /dev/null 2>&1" unless verbose_mode
      if system(install_command)
        print_column_fill("  Running asdf install", indent: 1, color: :green)
        pputs " completed", color: :green
        pputs ""
        true
      else
        print_column_fill("  Running asdf install", indent: 1, color: :red)
        pputs " failed", color: :red
        pputs ""
        false
      end
    end
  end

  def upgrade_tool_versions_internal(verbose_mode = false)
    pputs "Upgrading .tool-versions to latest stable versions...", style: :bold
    
    managed_tools, tool_versions_path = get_managed_tools
    
    if managed_tools.nil?
      pputs "~/.tool-versions not found", indent: 1, color: :red
      return false
    end
    
    if managed_tools.empty?
      pputs "No tools found in ~/.tool-versions", indent: 1, color: :yellow
      return false
    end
    
    updates_needed = []
    
    # Check what needs updating
    managed_tools.each do |plugin, current_version|
      latest_version = `asdf list all #{plugin} 2>/dev/null | grep -E '^[0-9]+\\.[0-9]+\\.[0-9]+$' | tail -1`.strip
      
      if !latest_version.empty? && current_version != latest_version
        updates_needed << {plugin: plugin, current: current_version, latest: latest_version}
      end
    end
    
    if updates_needed.empty?
      pputs "All tools are already at latest stable versions", indent: 1, color: :green
      return true
    end
    
    # Show what will be updated and check community compatibility
    pputs "The following updates will be attempted:", indent: 1, style: :bold
    updates_needed.each do |update|
      pputs "- #{update[:plugin]}: #{update[:current]} → #{update[:latest]}", indent: 2, color: :cyan
      check_community_compatibility(update[:plugin], update[:latest])
    end
    
    # Confirm with user
    print "\nProceed with updating ~/.tool-versions and testing installs? [y/N]: "
    response = STDIN.gets.chomp.downcase
    
    unless response == 'y' || response == 'yes'
      pputs "Upgrade cancelled", indent: 1, color: :yellow
      return false
    end
    
    # Create backup of the actual file (not symlink)
    backup_dir = "data/.meta/backups"
    system("mkdir -p #{backup_dir}")
    backup_filename = ".tool-versions.backup.#{Time.now.strftime('%Y%m%d_%H%M%S')}"
    backup_path = "#{backup_dir}/#{backup_filename}"
    system("cp \"#{tool_versions_path}\" \"#{backup_path}\"")
    pputs "Backup created: #{backup_path}", indent: 1, color: :cyan
    pputs ""
    
    # Store original versions for rollback
    original_versions = managed_tools.dup
    successful_upgrades = []
    failed_upgrades = []
    
    # Try each upgrade individually
    updates_needed.each do |update|
      plugin = update[:plugin]
      current_version = update[:current]
      latest_version = update[:latest]
      
      pputs "Upgrading #{plugin}: #{current_version} → #{latest_version}", indent: 1, style: :bold
      
      # Update .tool-versions for this plugin
      updated_content = File.readlines(tool_versions_path).map do |line|
        line = line.strip
        if line.empty? || line.start_with?('#')
          line + "\n"
        else
          parts = line.split(' ', 2)
          if parts.length >= 2 && parts[0] == plugin
            "#{plugin} #{latest_version}\n"
          else
            line + "\n"
          end
        end
      end
      
      File.write(tool_versions_path, updated_content.join)
      
      # Try to install the new version
      pputs "Installing #{plugin} #{latest_version}...", indent: 2
      install_command = "asdf install #{plugin} #{latest_version}"
      install_command += " > /dev/null 2>&1" unless verbose_mode
      if system(install_command)
        pputs "✅ Successfully upgraded #{plugin} to #{latest_version}", indent: 2, color: :green
        successful_upgrades << update
      else
        pputs "❌ Failed to install #{plugin} #{latest_version}", indent: 2, color: :red
        failed_upgrades << update
        
        # Revert this plugin to original version
        pputs "Reverting #{plugin} to #{current_version}", indent: 2, color: :yellow
        reverted_content = File.readlines(tool_versions_path).map do |line|
          line = line.strip
          if line.empty? || line.start_with?('#')
            line + "\n"
          else
            parts = line.split(' ', 2)
            if parts.length >= 2 && parts[0] == plugin
              "#{plugin} #{current_version}\n"
            else
              line + "\n"
            end
          end
        end
        
        File.write(tool_versions_path, reverted_content.join)
        pputs "Reverted #{plugin} to #{current_version} in .tool-versions", indent: 2, color: :yellow
      end
      
      pputs ""
    end
    
    # Summary
    if successful_upgrades.any?
      pputs "✅ Successful upgrades:", indent: 1, style: :bold, color: :green
      successful_upgrades.each do |update|
        pputs "- #{update[:plugin]}: #{update[:current]} → #{update[:latest]}", indent: 2, color: :green
      end
    end
    
    if failed_upgrades.any?
      pputs "❌ Failed upgrades (reverted):", indent: 1, style: :bold, color: :red
      failed_upgrades.each do |update|
        pputs "- #{update[:plugin]}: #{update[:current]} → #{update[:latest]} (compilation failed)", indent: 2, color: :red
      end
      pputs "Failed versions may have known compatibility issues with your system", indent: 1, color: :yellow
    end
    
    # Return success if at least some upgrades worked
    successful_upgrades.any? || updates_needed.empty?
  end

  def check_community_compatibility(plugin, version)
    pputs "Checking community compatibility for #{plugin} #{version}...", indent: 2, color: :cyan
    
    case plugin
    when "python"
      # Check GitHub issues for known problems
      search_query = "#{version}+macOS+Apple+Silicon+BUILD+FAILED"
      response = `curl -s "https://api.github.com/search/issues?q=#{search_query}+repo:pyenv/pyenv" 2>/dev/null`
      
      if response.include?('"total_count":0') || response.empty?
        pputs "No known community issues found", indent: 3, color: :green
        return true
      else
        pputs "Found community reports of build issues", indent: 3, color: :yellow
        return false
      end
    when "ruby"
      # Check for Ruby build issues
      search_query = "#{version}+macOS+Apple+Silicon+failed"
      response = `curl -s "https://api.github.com/search/issues?q=#{search_query}+repo:rbenv/ruby-build" 2>/dev/null`
      
      if response.include?('"total_count":0') || response.empty?
        pputs "No known community issues found", indent: 3, color: :green
        return true
      else
        pputs "Found community reports of build issues", indent: 3, color: :yellow
        return false
      end
    else
      pputs "Community check not implemented for #{plugin}", indent: 3, color: :yellow
      return true
    end
  end
end
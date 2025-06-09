require_relative '../terminal_helpers'
require_relative 'asdf_package_manager'
require_relative 'global_package_manager'

class MacOSSetup::PackageManager::PackageCoordinator
  include MacOSSetup::TerminalHelpers

  def initialize
    @asdf_manager = MacOSSetup::PackageManager::AsdfPackageManager.new
    @global_manager = MacOSSetup::PackageManager::GlobalPackageManager.new
  end

  def install_packages(options)
    action = options[:update] ? "Updating" : "Installing"
    section_header "#{action} Development Packages"
    
    # Install asdf packages first (provides language runtimes)
    @asdf_manager.install_packages(options)
    
    pputs ""
    
    # Check for package managers (after asdf install)
    unless check_package_managers
      pputs "Some package managers missing - global packages may be skipped", color: :yellow
    end
    
    pputs ""
    
    # Install/update global packages for each language
    success = @global_manager.install_all_packages(options)
    
    unless success
      pputs "Some global packages failed to #{action.downcase}. Check output above for details.", color: :yellow
    end
    
    section_footer "Development Packages #{action} Complete"
  end

  def upgrade_packages(options)
    @asdf_manager.upgrade_tool_versions(options[:verbose])
  end

  private

  def check_package_managers
    missing_tools = []
    
    unless system("which npm > /dev/null 2>&1")
      missing_tools << "npm (install Node.js via asdf)"
    end
    
    unless system("which bundle > /dev/null 2>&1")
      missing_tools << "bundler (install Ruby via asdf, then: gem install bundler)"
    end
    
    unless system("which pip > /dev/null 2>&1")
      missing_tools << "pip (install Python via asdf)"
    end
    
    if missing_tools.any?
      pputs "⚠️  Some package managers are missing:", color: :yellow, style: :bold
      missing_tools.each { |tool| pputs "- #{tool}", indent: 1, color: :yellow }
      pputs "Install missing tools first, then run this script again.", indent: 1, color: :yellow
    end
    
    missing_tools.empty?
  end
end
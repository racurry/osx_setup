require_relative '../terminal_helpers'
require_relative '../sudo_manager'

class MacOSSetup::AppInstaller::BrewAppManager
  include MacOSSetup::TerminalHelpers

  DEFAULT_BREWFILE = 'data/Brewfile'

  def initialize(brewfile: DEFAULT_BREWFILE)
    @brewfile = brewfile
  end

  def install_all
    section_header "📦 Installing Brew and App Store apps"
    
    # Ensure sudo is available for apps that require it
    sudo_manager = MacOSSetup::SudoManager.new
    unless sudo_manager.ensure_sudo_available
      pprint "❌ Sudo authentication failed - skipping apps that require admin privileges", 
             style: :bold, color: :red, indent: 1
      return
    end
    
    success = system("arch -arm64 brew bundle --file=#{@brewfile}")
    
    if success
      pprint "✅ All apps installed successfully!", style: :bold, color: :green, indent: 1
    else
      # Check actual installation status (brew bundle may fail due to Rosetta errors even when apps install)
      if system("brew bundle check --file=#{@brewfile} > /dev/null 2>&1")
        pprint "✅ All apps installed successfully (despite some warnings)!", 
               style: :bold, color: :green, indent: 1
      else
        pprint "⚠️ Some apps failed to install", style: :bold, color: :yellow, indent: 1
      end
    end
    
    section_footer "Done installing Brew and App Store apps"
  end
end
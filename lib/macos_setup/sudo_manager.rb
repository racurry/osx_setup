require_relative 'terminal_helpers'

class MacOSSetup::SudoManager
  include MacOSSetup::TerminalHelpers

  def initialize
    @sudo_helper = SudoHelper.new
  end

  def ensure_sudo_available
    # If SUDO_ASKPASS is already set, we assume password is already handled
    return true if ENV['SUDO_ASKPASS']
    @sudo_helper.ensure_sudo_available
  end

  def run(command)
    @sudo_helper.run(command)
  end

  class SudoHelper
    include MacOSSetup::TerminalHelpers

    def ensure_sudo_available
      # Check if we already have a valid temp file
      existing_file = Dir.glob("/tmp/macos_setup_*").first
      if existing_file && File.exist?(existing_file) && test_sudo_with_file(existing_file)
        setup_askpass_env
        return true
      end

      # Need to create new sudo session
      section_header "🔐 Administrator Authentication Required"
      print "Password: "
      system("stty -echo")  # Hide password input
      password = STDIN.gets.chomp
      system("stty echo")   # Restore echo
      puts  # Add newline after hidden input
      
      # Test the password
      unless system("echo '#{password}' | sudo -S true > /dev/null 2>&1")
        puts "Invalid password."
        return false
      end

      # Store password in secure temp file
      temp_file = "/tmp/macos_setup_#{Process.pid}"
      File.write(temp_file, password)
      File.chmod(0600, temp_file)  # Read/write for owner only
      
      # Set up signal handlers for cleanup on interruption
      setup_cleanup_handlers(temp_file)
      
      # Set up environment for sudo operations
      setup_askpass_env
      
      # Set up cleanup at exit
      at_exit { File.delete(temp_file) if File.exist?(temp_file) }
      
      true
    end

    def run(command)
      if ENV['SUDO_ASKPASS']
        system("sudo -A #{command}")
      else
        system("sudo #{command}")
      end
    end

    private

    def test_sudo_with_file(temp_file)
      password = File.read(temp_file).chomp rescue ""
      system("echo '#{password}' | sudo -S true > /dev/null 2>&1")
    end

    def setup_askpass_env
      askpass_script = File.join(Dir.pwd, "bin", "sudo_helper")
      ENV['SUDO_ASKPASS'] = askpass_script
    end

    def setup_cleanup_handlers(temp_file)
      cleanup = -> { 
        File.delete(temp_file) if File.exist?(temp_file)
        puts "\nOperation interrupted - cleaning up..."
        exit 1
      }
      ['INT', 'TERM', 'QUIT', 'HUP'].each { |sig| Signal.trap(sig, cleanup) }
    end
  end
end
require 'json'
require_relative '../terminal_helpers'

class MacOSSetup::AppInstaller::ShellAppManager
  include MacOSSetup::TerminalHelpers

  DEFAULT_SHELL_APPS_FILE = 'data/install_shell_apps.json'

  def initialize(shell_apps_file: DEFAULT_SHELL_APPS_FILE)
    @shell_apps_file = shell_apps_file
  end

  def install_all
    section_header "🛠️ Installing shell apps"

    shell_apps.each do |app|
      install_shell_app(
        name: app[:name],
        test: app[:test],
        command: app[:command]
      )
    end
    
    section_footer "Done installing shell apps"
  end

  private

  def install_shell_app(name:, test:, command:)
    initial_text = "#{name}..."
    pprint initial_text, indent: 1, style: :bold

    if system("#{test} > /dev/null 2>&1")
      final_text = "Already installed! "
      text_opts = { style: :italic }
      emoji = "🆗"
    elsif system(command)
      final_text = "Successfully installed!"
      text_opts = { style: :bold, color: :green }
      emoji = "✅"
    else
      final_text = "Something went wrong!"
      text_opts = { style: :bold, color: :red }
      emoji = "⛔"
    end

    print_column_fill final_text + emoji + initial_text, indent: 1
    pprint final_text, text_opts
    puts emoji
  end

  def shell_apps
    json_file = File.read(@shell_apps_file)
    parsed = JSON.parse(json_file, symbolize_names: true)
    parsed[:apps]
  end
end
require 'io/console'
require 'fileutils'

class MacOSSetup
  module AppInstaller
  end
  
  module PackageManager
  end
end

require_relative 'macos_setup/terminal_helpers'
require_relative 'macos_setup/sudo_manager'
require_relative 'macos_setup/app_installer/shell_app_manager'
require_relative 'macos_setup/app_installer/brew_app_manager'
require_relative 'macos_setup/package_manager/package_coordinator'

class MacOSSetup
  include MacOSSetup::TerminalHelpers

  def initialize
    @shell_manager = MacOSSetup::AppInstaller::ShellAppManager.new
    @brew_manager = MacOSSetup::AppInstaller::BrewAppManager.new
    @package_coordinator = MacOSSetup::PackageManager::PackageCoordinator.new
    @sudo_manager = nil  # Will be initialized after password collection
  end

  def partial_setup(*types)
    types.each do |type|
      case type.to_sym
      when :shell
        @shell_manager.install_all
      when :brew
        @brew_manager.install_all
      else
        raise ArgumentError, "Unknown app type: #{type}. Valid types: :shell, :brew"
      end
    end
  end

  def install_apps(*types)
    if types.empty?
      # Install all types if no specific type is provided
      @shell_manager.install_all
      @brew_manager.install_all
    else
      # Install specific types
      types.each do |type|
        case type.to_sym
        when :shell, :shell_apps
          @shell_manager.install_all
        when :brew, :brew_apps, :brewfile
          @brew_manager.install_all
        else
          raise ArgumentError, "Unknown app type: #{type}. Valid types: :shell, :brew"
        end
      end
    end
  end

  def manage_packages(*args)
    options = parse_package_options(args)
    
    if options[:upgrade]
      upgrade_packages(options)
    else
      install_packages(options)
    end
  end

  def update_to_latest
    repo_directory = File.dirname(File.dirname(File.realpath(__FILE__)))
    
    section_header "🔄 Pulling latest config"
    Dir.chdir(repo_directory) do
      system 'git pull --rebase'
    end
    section_footer "Done"
  end

  def system_hygiene
    section_header("System Hygiene & Updates")
    
    pputs "Keeping your development environment fresh and up-to-date", indent: 1, color: :cyan
    
    hygiene_update_repository
    installed_plugins = hygiene_update_asdf_plugins
    hygiene_check_tool_versions(installed_plugins)
    hygiene_update_oh_my_zsh
    hygiene_update_homebrew_packages
    hygiene_verify_brewfile_packages
    hygiene_sync_app_configurations
    hygiene_cleanup_system
    hygiene_run_health_checks
    
    section_footer("System hygiene complete")
  end

  def sync_dotfiles(*args)
    skip_conflicts = args.include?('--skip_conflicts')
    
    section_header "⚙️ Syncing dotfiles"
    
    home_dir = File.expand_path('~')
    dotfiles_path = '/data/dotfiles'
    ignored_files = %w{.DS_Store .. .}
    local_dotfiles_dir = "#{Dir.pwd}#{dotfiles_path}"
    
    all_files = Dir.entries(local_dotfiles_dir)
    dotfiles = all_files - ignored_files
    
    dotfiles.each do |dotfile|
      sync_dotfile(dotfile, home_dir, local_dotfiles_dir, skip_conflicts)
    end
  end

  def setup_app_configs(*args)
    export_mode = args.include?('--export')
    import_mode = args.include?('--import')
    
    if export_mode
      section_header "Exporting App Configurations to iCloud"
    elsif import_mode
      section_header "Importing App Configurations from iCloud"
    else
      section_header "App-Specific Configuration Setup"
    end
    
    # Path constants
    icloud_drive_path = '~/Library/Mobile Documents/com~apple~CloudDocs'
    app_settings_subdir = 'App settings sync'
    icloud_base = File.join(icloud_drive_path, app_settings_subdir)
    
    # Verify iCloud Drive exists before proceeding
    expanded_icloud_path = File.expand_path(icloud_drive_path)
    unless File.exist?(expanded_icloud_path)
      pputs "iCloud Drive not found at: #{expanded_icloud_path}", color: :red
      pputs "This computer may not be syncing with iCloud Drive", color: :red
      exit 1
    end
    
    if export_mode
      app_config_export_stream_deck(icloud_base)
      app_config_export_moom(icloud_base)
    elsif import_mode
      app_config_import_stream_deck(icloud_base)
      app_config_import_moom(icloud_base)
    else
      app_config_setup_karabiner(icloud_base)
      app_config_setup_iterm2(icloud_base)
    end
    
    if export_mode
      section_footer "App configuration export complete"
    elsif import_mode
      section_footer "App configuration import complete"
    else
      section_footer "App configuration setup complete"
    end
  end

  def setup_macos
    section_header "Setting up macOS"
    
    setup_global_settings
    setup_keyboard_preferences
    setup_trackpad
    setup_dock
    fix_screenshots
    setup_finder
    setup_screensaver
    setup_sound_preferences
    setup_menubar_preferences
    setup_spotlight_preferences
    
    restart_running_apps
    
    section_footer "macOS setup complete"
    pputs "Note: Key repeat and press-and-hold settings require logout/restart to take effect.", color: :yellow
    pputs "Other settings (trackpad, keyboard brightness) may also need a restart.", color: :yellow
  end

  def manual_todos
    done_file_name = 'data/.meta/.todone'
    manual_todos_file = 'data/manual_todos.txt'
    
    section_header "✅ Do it!"

    things_to_do = get_remaining_todos(done_file_name, manual_todos_file)
    
    things_to_do.each do |todo|
      print "    ❏ #{todo} "
      pprint "(d=done,s=skip)  ", color: :cyan, style: :italic
      reply = STDIN.getch
      if reply == 'd'
        mark_todo_as_done(done_file_name, todo)
        puts "✅"
      else
        puts "❌"
      end
    end

    # Recalculate remaining todos after marking some as done
    remaining_todos = get_remaining_todos(done_file_name, manual_todos_file)
    left_to_do = remaining_todos.count
    
    if left_to_do == 0
      pputs "You don't have anything left to do!", style: :bold, color: :green, indent: 1
    elsif left_to_do == 1
      pprint "Still 1 to do.  ", style: :bold
      pputs "Run bin/manual_todos any time to finish it", indent: 1
    else
      pprint "Still #{left_to_do} things to do.  ", style: :bold
      pputs "Run bin/manual_todos any time to finish them", indent: 1
    end
  end

  def create_folders
    # Path constants
    documents_path = "~/Documents"
    screen_shots_path = "~/Screen Shots"
    workspace_symlink_path = "~/workspace"
    icloud_symlink_path = "~/iCloud"
    icloud_source_path = "~/Library/Mobile Documents/com~apple~CloudDocs"

    # Individual folder name constants
    essential_folders = [
      "@auto",
      "000. 📥 Inbox",
      "100. 🚶 People",
      "110. 👥 Groups",
      "120. 🏢️ Companies",
      "200. 🗓️ Time",
      "300. 🎨 Areas",
      "320. 🏆 Goals",
      "330. 🚧 Projects",
      "400. 🤔 Topics",
      "700. 📚️ Libraries",
      "700. 🧠 Resources",
      "900. 📰️ Output",
      "910. ✍️ Stories",
      "950. 💻 Workspace"
    ]

    create_essential_folders(documents_path, essential_folders, screen_shots_path)
    create_essential_symlinks(documents_path, workspace_symlink_path, icloud_symlink_path, icloud_source_path)
  end

  def setup_everything(*args)
    # Collect password at the beginning with proper cleanup
    collect_sudo_password unless ENV['SUDO_ASKPASS']
    
    # Initialize sudo manager after password collection
    @sudo_manager = MacOSSetup::SudoManager.new
    
    # Parse arguments for force flag and pass through other options
    force = args.include?('--force')
    update = args.include?('--update')
    
    # Variables for tracking and execution
    bin_path = "./bin"
    data_path = "./data"
    tracking_files_path = "#{data_path}/.meta/last_run"
    data_file_extensions = %w{txt json}
    
    if update
      section_header "Running system hygiene..."
      system_hygiene
      return
    end
    
    # Handle force flag - clear tracking data to force complete re-run
    if force
      if Dir.exist?(tracking_files_path)
        section_header "🗑️ Clearing tracking data for forced re-run..."
        FileUtils.rm_rf(tracking_files_path)
      end
    end
    
    FileUtils.mkdir_p(tracking_files_path)
    
    horizontal_rule(:cyan)
    pputs "👾 Setting up this bad boy here", style: :bold, color: :cyan
    horizontal_rule(:cyan)
    
    # Make sure we have the latest
    update_to_latest
    
    # Execute all setup components in order
    run_setup_component('create_folders', force, args, tracking_files_path, data_path, data_file_extensions)
    run_setup_component('setup_macos', force, args, tracking_files_path, data_path, data_file_extensions)
    run_setup_component('sync_dotfiles', force, args, tracking_files_path, data_path, data_file_extensions)
    run_setup_component('install_apps', force, args, tracking_files_path, data_path, data_file_extensions)
    run_setup_component('manage_packages', force, args, tracking_files_path, data_path, data_file_extensions)
    run_setup_component('setup_app_configs', force, args, tracking_files_path, data_path, data_file_extensions)
    run_setup_component('manual_todos', force, args, tracking_files_path, data_path, data_file_extensions)
    
    add_executable_to_path
    
    horizontal_rule(:cyan)
    pputs "🍻 All done!  This thing is good to go", style: :bold, color: :green
    horizontal_rule(:cyan)
  end

  def sudo_manager
    @sudo_manager ||= MacOSSetup::SudoManager.new
  end

  private

  def collect_sudo_password
    section_header "🔐 Administrator Authentication Required"
    print "Password: "
    password = STDIN.noecho(&:gets).chomp
    puts
    puts
    
    # Validate sudo access
    unless system("echo '#{password}' | sudo -S -v > /dev/null 2>&1")
      pputs "❌ Invalid password. Exiting.", color: :red
      exit 1
    end
    
    # Create temporary password file with secure permissions
    temp_password_file = "/tmp/macos_setup_#{Process.pid}"
    File.write(temp_password_file, password)
    File.chmod(0600, temp_password_file)
    
    # Set up environment for passwordless sudo
    ENV['SUDO_ASKPASS'] = "#{Dir.pwd}/bin/sudo_helper"
    
    # Set up cleanup
    at_exit { File.delete(temp_password_file) if File.exist?(temp_password_file) }
  end

  def run_setup_component(component_name, force, args, tracking_files_path, data_path, data_file_extensions)
    tracking_filepath = "#{tracking_files_path}/#{component_name}"
    data_file_path = find_data_file(component_name, data_path, data_file_extensions)
    
    verbose = args.include?('--verbose')
    
    if verbose
      pputs("Running #{component_name}", color: :yellow, style: :italic)
      pputs("    data file: #{data_file_path ? data_file_path : 'None'}", color: :yellow, style: :italic)
      pputs("    data file modified: #{data_file_path ? File.mtime(data_file_path) : 'n/a'}", color: :yellow, style: :italic)
      pputs("    last executed: #{File.exist?(tracking_filepath) ? File.mtime(tracking_filepath) : 'never'}", color: :yellow, style: :italic)
    end
    
    # File modification detection logic
    tracking_file_exists = File.exist?(tracking_filepath)
    tracking_file_modified_on = tracking_file_exists ? File.mtime(tracking_filepath) : nil
    data_file_modified_on = data_file_path ? File.mtime(data_file_path) : nil
    data_file_is_newer = data_file_path && tracking_file_exists && (data_file_modified_on > tracking_file_modified_on)
    
    # Check if lib file itself was modified (simulate bin file check)
    lib_file_path = __FILE__
    lib_file_modified_on = File.mtime(lib_file_path)
    lib_file_is_newer = tracking_file_exists && (lib_file_modified_on > tracking_file_modified_on)
    
    file_needs_to_run = force || !tracking_file_exists || lib_file_is_newer || data_file_is_newer
    
    if file_needs_to_run
      pputs("    Executing #{component_name}", color: :yellow, style: :italic) if verbose
      
      # Call the appropriate method based on component name
      case component_name
      when 'create_folders'
        create_folders
      when 'setup_macos'
        setup_macos
      when 'sync_dotfiles'
        sync_dotfiles(*args)
      when 'install_apps'
        install_apps
      when 'manage_packages'
        manage_packages(*args)
      when 'setup_app_configs'
        setup_app_configs(*args)
      when 'manual_todos'
        manual_todos
      end
      
      FileUtils.touch(tracking_filepath)
    elsif verbose
      pputs("    Skipping #{component_name}", color: :yellow, style: :italic)
    end
  end
  
  def find_data_file(filename, data_path, extensions)
    extensions.each do |extension|
      filepath = "#{data_path}/#{filename}.#{extension}"
      return filepath if File.exist?(filepath)
    end
    nil
  end
  
  def add_executable_to_path
    unless File.symlink?("/usr/local/bin/macoscfg")
      @sudo_manager.run("ln -s ~/workspace/osx_setup/macos_setup /usr/local/bin/macoscfg")
    end
    unless File.symlink?("/usr/local/bin/machygiene")
      @sudo_manager.run("ln -s ~/workspace/osx_setup/bin/hygiene /usr/local/bin/machygiene")
    end
  end

  def parse_package_options(args)
    {
      upgrade: args.include?('--upgrade'),
      update: args.include?('--update'),
      verbose: args.include?('--verbose')
    }
  end

  def upgrade_packages(options)
    @package_coordinator.upgrade_packages(options)
  end

  def install_packages(options)
    @package_coordinator.install_packages(options)
  end


  def create_essential_folders(documents_path, essential_folders, screen_shots_path)
    section_header "Creating Essential Folders"
    
    home_documents = File.expand_path(documents_path)
    
    pputs "Creating #{essential_folders.length} essential folders", indent: 1
    
    # Create each folder if it doesn't exist
    essential_folders.each do |folder_name|
      folder_path = File.join(home_documents, folder_name)
      
      if File.directory?(folder_path)
        pprint "#{folder_name}", indent: 1
        print_column_fill("    #{folder_name}", indent: 1, color: :green)
        pputs " exists", color: :green
      else
        Dir.mkdir(folder_path)
        pprint "#{folder_name}", indent: 1
        print_column_fill("    #{folder_name}", indent: 1, color: :green)
        pputs " created", color: :green
      end
    end
    
    # Create Screen Shots folder in home directory
    screen_shots_full_path = File.expand_path(screen_shots_path)
    
    if File.directory?(screen_shots_full_path)
      pprint "Screen Shots", indent: 1
      print_column_fill("    Screen Shots", indent: 1, color: :green)
      pputs " exists", color: :green
    else
      Dir.mkdir(screen_shots_full_path)
      pprint "Screen Shots", indent: 1
      print_column_fill("    Screen Shots", indent: 1, color: :green)
      pputs " created", color: :green
    end
    
    section_footer "Essential folders are ready"
  end

  def create_essential_symlinks(documents_path, workspace_symlink_path, icloud_symlink_path, icloud_source_path)
    section_header "Creating Essential Symlinks"
    
    home_documents = File.expand_path(documents_path)
    
    # Create symlink to workspace folder
    workspace_source = File.join(home_documents, "950. 💻 Workspace")
    workspace_symlink = File.expand_path(workspace_symlink_path)
    
    create_symlink("~/workspace", workspace_source, workspace_symlink)
    
    # Create iCloud Drive symlink
    icloud_source = File.expand_path(icloud_source_path)
    icloud_symlink = File.expand_path(icloud_symlink_path)
    
    create_symlink("~/iCloud", icloud_source, icloud_symlink)
    
    section_footer "Essential symlinks are ready"
  end

  def create_symlink(display_name, source_path, symlink_path)
    if File.symlink?(symlink_path)
      if File.readlink(symlink_path) == source_path
        pprint display_name, indent: 1
        print_column_fill("    #{display_name}", indent: 1, color: :green)
        pputs " exists", color: :green
      else
        # Remove incorrect symlink and create new one
        File.unlink(symlink_path)
        File.symlink(source_path, symlink_path)
        pprint display_name, indent: 1
        print_column_fill("    #{display_name}", indent: 1, color: :green)
        pputs " updated", color: :green
      end
    elsif File.exist?(symlink_path)
      pputs "Warning: #{display_name} exists but is not a symlink", indent: 1, color: :yellow
    else
      File.symlink(source_path, symlink_path)
      pprint display_name, indent: 1
      print_column_fill("    #{display_name}", indent: 1, color: :green)
      pputs " created", color: :green
    end
  end

  def get_already_done_todos(done_file_name)
    if File.exist?(done_file_name)
      donezo = File.open(done_file_name)
      donezo.read.split(/\n/)
    else
      File.open(done_file_name, "w")
      []
    end
  end

  def get_all_todos(manual_todos_file)
    File.open(manual_todos_file).read.split(/\n/)
  end

  def get_remaining_todos(done_file_name, manual_todos_file)
    get_all_todos(manual_todos_file) - get_already_done_todos(done_file_name)
  end

  def mark_todo_as_done(done_file_name, todo)
    File.write(done_file_name, "\n#{todo}", mode: "a")
  end

  def hygiene_update_repository
    pputs "Updating osx_setup repository...", indent: 1, style: :bold

    pprint "Running git pull --rebase", indent: 2
    if system("git pull --rebase > /dev/null 2>&1")
      print_column_fill("  Running git pull --rebase", indent: 2, color: :green)
      pputs " completed", color: :green
    else
      print_column_fill("  Running git pull --rebase", indent: 2, color: :yellow)
      pputs " up-to-date or failed", color: :yellow
    end

    pputs ""
  end

  def hygiene_update_asdf_plugins
    pputs "Updating asdf plugins...", indent: 1, style: :bold

    # Get list of installed asdf plugins
    installed_plugins = `asdf plugin list`.strip.split("\n")

    if installed_plugins.empty?
      pputs "No asdf plugins installed", indent: 2, color: :yellow
    else
      pputs "Found #{installed_plugins.length} asdf plugins", indent: 2
      
      installed_plugins.each do |plugin|
        pprint "#{plugin}", indent: 2
        
        if system("asdf plugin update #{plugin} > /dev/null 2>&1")
          print_column_fill("  #{plugin}", indent: 2, color: :green)
          pputs " updated", color: :green
        else
          print_column_fill("  #{plugin}", indent: 2, color: :yellow)
          pputs " failed", color: :yellow
        end
      end
    end

    pputs ""
    return installed_plugins
  end

  def hygiene_check_tool_versions(installed_plugins)
    return if installed_plugins.empty?
    
    pputs "Checking for newer versions of installed tools...", indent: 1, style: :bold
    
    installed_plugins.each do |plugin|
      current_version = `asdf current #{plugin} 2>/dev/null | awk '{print $2}'`.strip
      latest_version = `asdf latest #{plugin} 2>/dev/null`.strip
      
      if current_version != "" && latest_version != "" && current_version != latest_version
        pprint "#{plugin}: #{current_version} -> #{latest_version} available", indent: 2, color: :yellow
        pputs ""
      end
    end
    
    pputs ""
  end

  def hygiene_update_oh_my_zsh
    pputs "Updating oh-my-zsh...", indent: 1, style: :bold

    pprint "Updating oh-my-zsh", indent: 2
    if system("cd ~/.oh-my-zsh && git pull > /dev/null 2>&1")
      print_column_fill("  Updating oh-my-zsh", indent: 2, color: :green)
      pputs " completed", color: :green
    else
      print_column_fill("  Updating oh-my-zsh", indent: 2, color: :yellow)
      pputs " up-to-date or failed", color: :yellow
    end

    pputs ""
  end

  def hygiene_update_homebrew_packages
    pputs "Updating Homebrew packages...", indent: 1, style: :bold

    pprint "Running brew upgrade", indent: 2
    if system("brew upgrade")
      print_column_fill("  Running brew upgrade", indent: 2, color: :green)
      pputs " completed", color: :green
    else
      print_column_fill("  Running brew upgrade", indent: 2, color: :red)
      pputs " failed", color: :red
    end

    pputs ""
  end

  def hygiene_verify_brewfile_packages
    pputs "Verifying Brewfile packages...", indent: 1, style: :bold

    pprint "Checking Brewfile compliance", indent: 2
    if system("brew bundle check --file=data/Brewfile > /dev/null 2>&1")
      print_column_fill("  Checking Brewfile compliance", indent: 2, color: :green)
      pputs " all packages installed", color: :green
    else
      print_column_fill("  Checking Brewfile compliance", indent: 2, color: :yellow)
      pputs " missing packages found", color: :yellow
      pputs "Run 'brew bundle --file=data/Brewfile' to install missing packages", indent: 3, color: :cyan
    end

    pputs ""
  end

  def hygiene_sync_app_configurations
    pputs "Syncing app configurations...", indent: 1, style: :bold

    pprint "Running setup_app_configs", indent: 2
    if system("bin/setup_app_configs > /dev/null 2>&1")
      print_column_fill("  Running setup_app_configs", indent: 2, color: :green)
      pputs " completed", color: :green
    else
      print_column_fill("  Running setup_app_configs", indent: 2, color: :yellow)
      pputs " failed", color: :yellow
    end

    pputs ""
  end

  def hygiene_cleanup_system
    pputs "Cleaning up...", indent: 1, style: :bold

    pprint "Running brew cleanup", indent: 2
    if system("brew cleanup > /dev/null 2>&1")
      print_column_fill("  Running brew cleanup", indent: 2, color: :green)
      pputs " completed", color: :green
    else
      print_column_fill("  Running brew cleanup", indent: 2, color: :yellow)
      pputs " failed", color: :yellow
    end

    pputs ""
  end

  def hygiene_run_health_checks
    pputs "Running health checks...", indent: 1, style: :bold

    critical_tools = ["ruby", "node", "python", "git"]
    critical_tools.each do |tool|
      pprint "#{tool}", indent: 2
      version_output = `#{tool} --version 2>/dev/null`.strip
      if $?.success? && !version_output.empty?
        print_column_fill("  #{tool}", indent: 2, color: :green)
        pputs " #{version_output.split("\n").first}", color: :green
      else
        print_column_fill("  #{tool}", indent: 2, color: :red)
        pputs " not found or error", color: :red
      end
    end
  end

  def sync_dotfile(dotfile_name, home_dir, local_dotfiles_dir, skip_conflicts)
    home_dir_dotfile_path = "#{home_dir}/#{dotfile_name}"
    local_dotfile_path = "#{local_dotfiles_dir}/#{dotfile_name}"

    if !File.exist?(local_dotfile_path)
      raise "WHAT ARE YOU DOING IDIOT??  There is no #{local_dotfile_path}"
    end

    if File.exist?(home_dir_dotfile_path) || File.symlink?(home_dir_dotfile_path)
      pprint "    #{dotfile_name} already exists!", style: :bold
      if skip_conflicts
        skip_dotfile(dotfile_name)
      else
        handle_dotfile_conflict(dotfile_name, local_dotfile_path, home_dir_dotfile_path)
      end
    else
      print "    #{dotfile_name} doesn't exist. Adding..."
      File.symlink(local_dotfile_path, home_dir_dotfile_path)
      pputs "Done!", color: :green, style: :bold
    end
  end

  def skip_dotfile(dotfile_name)
    pputs " Skipping #{dotfile_name}", color: :yellow, style: :italic
  end

  def handle_dotfile_conflict(dotfile_name, local_dotfile_path, home_dir_dotfile_path)
    print " What should I do?"
    pprint " (s=skip,r=replace,b=back up existing then replace): ", color: :cyan, style: :italic

    response = STDIN.getch

    case response
    when 's'
      skip_dotfile(dotfile_name)
    when 'r'
      print " Replacing #{dotfile_name}..."
      if File.directory?(home_dir_dotfile_path)
        FileUtils.rm_rf(home_dir_dotfile_path)
      else
        File.delete(home_dir_dotfile_path)
      end
      File.symlink(local_dotfile_path, home_dir_dotfile_path)
      pputs "Done!", color: :green, style: :bold
    when 'b'
      backup_and_replace_dotfile(dotfile_name, local_dotfile_path, home_dir_dotfile_path)
    else
      pputs "That was gibberish, I am skipping", color: :red
    end
  end

  def backup_and_replace_dotfile(dotfile_name, local_dotfile_path, home_dir_dotfile_path)
    print " Backing up #{dotfile_name}..."
    if File.directory?(home_dir_dotfile_path)
      FileUtils.mv(home_dir_dotfile_path, "#{home_dir_dotfile_path}.backup")
    else
      File.rename(home_dir_dotfile_path, "#{home_dir_dotfile_path}.backup")
    end
    pputs "Done!", color: :green, style: :bold
    print "    Linking #{dotfile_name}..."
    File.symlink(local_dotfile_path, home_dir_dotfile_path)
    pprint "Done!", color: :green, style: :bold
    pputs " The back up file is at #{home_dir_dotfile_path}.backup", style: :italic
  end

  # App Config Helper Methods
  def app_config_setup_karabiner(icloud_base)
    pputs "Setting up Karabiner Elements configuration", color: :cyan, style: :bold
    
    karabiner_local_path = '~/.config/karabiner'
    karabiner_subdir = 'karabiner'
    
    local_config_path = File.expand_path(karabiner_local_path)
    expanded_icloud_base = File.expand_path(icloud_base)
    icloud_config_path = File.join(expanded_icloud_base, karabiner_subdir)
    
    unless File.exist?(icloud_config_path)
      pputs "Karabiner config not found at: #{icloud_config_path}", color: :red
      return
    end
    
    # Check existing config and handle appropriately
    if File.exist?(local_config_path)
      if File.symlink?(local_config_path)
        current_target = File.readlink(local_config_path)
        if current_target == icloud_config_path
          pputs "Symlink already points to correct target: #{local_config_path} → #{icloud_config_path}", color: :green
          return
        else
          pputs "Removing symlink pointing to wrong target: #{local_config_path} → #{current_target}", color: :yellow
          File.unlink(local_config_path)
        end
      else
        pputs "Removing existing directory: #{local_config_path}", color: :yellow
        FileUtils.rm_rf(local_config_path)
      end
    end
    
    # Create parent directory if needed
    config_dir = File.dirname(local_config_path)
    FileUtils.mkdir_p(config_dir) unless File.exist?(config_dir)
    
    # Create symlink
    File.symlink(icloud_config_path, local_config_path)
    pputs "Created symlink: #{local_config_path} → #{icloud_config_path}", color: :green
  end

  def app_config_setup_iterm2(icloud_base)
    pputs "Setting up iTerm2 configuration", color: :cyan, style: :bold
    
    iterm2_subdir = 'iTerm2'
    expanded_icloud_base = File.expand_path(icloud_base)
    iterm_sync_dir = File.join(expanded_icloud_base, iterm2_subdir)
    
    unless File.exist?(iterm_sync_dir)
      pputs "iTerm2 config not found at: #{iterm_sync_dir}", color: :red
      return
    end
    
    # Check current settings
    load_prefs_current = `defaults read com.googlecode.iterm2 LoadPrefsFromCustomFolder 2>/dev/null`.strip
    prefs_folder_current = `defaults read com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null`.strip
    no_sync_current = `defaults read com.googlecode.iterm2 NoSyncNeverRemindPrefsChangesLostForFile 2>/dev/null`.strip
    
    # Check if settings are already correct
    settings_correct = (
      load_prefs_current == "1" &&
      prefs_folder_current == iterm_sync_dir &&
      no_sync_current == "1"
    )
    
    if settings_correct
      pputs "iTerm2 preferences already configured correctly", color: :green
      return
    end
    
    # Quit iTerm2 if running
    if system("pgrep -q iTerm2")
      pputs "Quitting iTerm2...", color: :yellow
      system("osascript -e 'tell application \"iTerm2\" to quit'")
      sleep 2  # Give iTerm2 time to fully quit
    end
    
    # Set preferences
    pputs "Configuring iTerm2 preferences...", indent: 1
    
    if load_prefs_current != "1"
      system("defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true")
      pputs "Set LoadPrefsFromCustomFolder to true", indent: 2, color: :green
    end
    
    if prefs_folder_current != iterm_sync_dir
      system("defaults write com.googlecode.iterm2 PrefsCustomFolder -string \"#{iterm_sync_dir}\"")
      pputs "Set PrefsCustomFolder to #{iterm_sync_dir}", indent: 2, color: :green
    end
    
    if no_sync_current != "1"
      system("defaults write com.googlecode.iterm2 NoSyncNeverRemindPrefsChangesLostForFile -bool true")
      pputs "Set NoSyncNeverRemindPrefsChangesLostForFile to true", indent: 2, color: :green
    end
    
    pputs "iTerm2 configuration complete. Restart iTerm2 to apply changes.", color: :green
  end

  def app_config_export_stream_deck(icloud_base)
    pputs "Exporting Stream Deck configuration", color: :cyan, style: :bold
    
    stream_deck_subdir = 'Stream deck (export)'
    local_profiles_dir = File.expand_path("~/Library/Application Support/com.elgato.StreamDeck/ProfilesV2")
    
    unless File.exist?(local_profiles_dir)
      pputs "Local Stream Deck profiles not found at: #{local_profiles_dir}", color: :red
      pputs "Stream Deck may not be installed or never configured", color: :red
      return
    end
    
    if Dir.empty?(local_profiles_dir)
      pputs "No Stream Deck profiles found to export", color: :yellow
      return
    end
    
    expanded_icloud_base = File.expand_path(icloud_base)
    stream_deck_sync_dir = File.join(expanded_icloud_base, stream_deck_subdir)
    
    # Create iCloud sync directory if needed
    unless File.exist?(stream_deck_sync_dir)
      FileUtils.mkdir_p(stream_deck_sync_dir)
      pputs "Created iCloud sync directory: #{stream_deck_sync_dir}", indent: 1, color: :cyan
    end
    
    # Quit Stream Deck if running
    if system("pgrep -q 'Stream Deck'")
      pputs "Quitting Stream Deck...", color: :yellow
      system("osascript -e 'tell application \"Elgato Stream Deck\" to quit' 2>/dev/null || pkill -f 'Stream Deck'")
      sleep 2
    end
    
    pputs "Copying Stream Deck profiles to iCloud...", indent: 1
    
    # Backup existing iCloud profiles first
    if File.exist?(stream_deck_sync_dir) && !Dir.empty?(stream_deck_sync_dir)
      backup_dir = "#{stream_deck_sync_dir}.backup.#{Time.now.strftime('%Y%m%d_%H%M%S')}"
      system("cp -R \"#{stream_deck_sync_dir}\" \"#{backup_dir}\"")
      pputs "Backed up existing iCloud profiles to: #{backup_dir}", indent: 2, color: :cyan
    end
    
    # Copy from local to iCloud
    system("rsync -av --delete \"#{local_profiles_dir}/\" \"#{stream_deck_sync_dir}/\"")
    pputs "Exported Stream Deck profiles to iCloud", indent: 2, color: :green
    
    pputs "Stream Deck export complete. Configuration is now synced to iCloud.", color: :green
  end

  def app_config_import_stream_deck(icloud_base)
    pputs "Importing Stream Deck configuration", color: :cyan, style: :bold
    
    stream_deck_subdir = 'Stream deck (export)'
    expanded_icloud_base = File.expand_path(icloud_base)
    stream_deck_sync_dir = File.join(expanded_icloud_base, stream_deck_subdir)
    
    unless File.exist?(stream_deck_sync_dir)
      pputs "Stream Deck config not found at: #{stream_deck_sync_dir}", color: :red
      pputs "Run with --export flag first to create initial backup", color: :yellow
      return
    end
    
    local_profiles_dir = File.expand_path("~/Library/Application Support/com.elgato.StreamDeck/ProfilesV2")
    
    unless File.exist?(local_profiles_dir)
      pputs "Local Stream Deck profiles not found at: #{local_profiles_dir}", color: :yellow
      pputs "Stream Deck may not be installed or never configured", color: :yellow
      return
    end
    
    # Check if already synced
    if File.exist?(local_profiles_dir) && !Dir.empty?(local_profiles_dir)
      synced_profiles = Dir.glob("#{stream_deck_sync_dir}/*")
      if synced_profiles.any?
        pputs "Stream Deck profiles appear to be synced already", color: :green
        return
      end
    end
    
    # Quit Stream Deck if running
    if system("pgrep -q 'Stream Deck'")
      pputs "Quitting Stream Deck...", color: :yellow
      system("osascript -e 'tell application \"Elgato Stream Deck\" to quit' 2>/dev/null || pkill -f 'Stream Deck'")
      sleep 2
    end
    
    pputs "Restoring Stream Deck profiles from iCloud...", indent: 1
    
    # Backup existing local profiles first
    if File.exist?(local_profiles_dir) && !Dir.empty?(local_profiles_dir)
      backup_dir = "#{local_profiles_dir}.backup.#{Time.now.strftime('%Y%m%d_%H%M%S')}"
      system("cp -R \"#{local_profiles_dir}\" \"#{backup_dir}\"")
      pputs "Backed up existing profiles to: #{backup_dir}", indent: 2, color: :cyan
    end
    
    # Copy from iCloud to local
    system("rsync -av \"#{stream_deck_sync_dir}/\" \"#{local_profiles_dir}/\"")
    pputs "Restored Stream Deck profiles from iCloud", indent: 2, color: :green
    
    pputs "Stream Deck configuration complete. Restart Stream Deck to apply changes.", color: :green
  end

  def app_config_export_moom(icloud_base)
    pputs "Exporting Moom configuration", color: :cyan, style: :bold
    
    moom_subdir = 'Moom (export)'
    moom_local_path = '~/Library/Preferences/com.manytricks.Moom.plist'
    local_plist_path = File.expand_path(moom_local_path)
    
    unless File.exist?(local_plist_path)
      pputs "Local Moom preferences not found at: #{local_plist_path}", color: :red
      pputs "Moom may not be installed or never configured", color: :red
      return
    end
    
    expanded_icloud_base = File.expand_path(icloud_base)
    moom_sync_dir = File.join(expanded_icloud_base, moom_subdir)
    
    # Create iCloud sync directory if needed
    unless File.exist?(moom_sync_dir)
      FileUtils.mkdir_p(moom_sync_dir)
      pputs "Created iCloud sync directory: #{moom_sync_dir}", indent: 1, color: :cyan
    end
    
    # Quit Moom if running
    if system("pgrep -q Moom")
      pputs "Quitting Moom...", color: :yellow
      system("osascript -e 'tell application \"Moom\" to quit'")
      sleep 2
    end
    
    pputs "Copying Moom preferences to iCloud...", indent: 1
    
    # Backup existing iCloud plist first
    icloud_plist_path = File.join(moom_sync_dir, "com.manytricks.Moom.plist")
    if File.exist?(icloud_plist_path)
      backup_plist_path = "#{icloud_plist_path}.backup.#{Time.now.strftime('%Y%m%d_%H%M%S')}"
      system("cp \"#{icloud_plist_path}\" \"#{backup_plist_path}\"")
      pputs "Backed up existing iCloud preferences to: #{backup_plist_path}", indent: 2, color: :cyan
    end
    
    # Copy plist file to iCloud
    system("cp \"#{local_plist_path}\" \"#{icloud_plist_path}\"")
    pputs "Exported Moom preferences to iCloud", indent: 2, color: :green
    
    pputs "Moom export complete. Configuration is now synced to iCloud.", color: :green
  end

  def app_config_import_moom(icloud_base)
    pputs "Importing Moom configuration", color: :cyan, style: :bold
    
    moom_subdir = 'Moom (export)'
    moom_local_path = '~/Library/Preferences/com.manytricks.Moom.plist'
    expanded_icloud_base = File.expand_path(icloud_base)
    moom_sync_dir = File.join(expanded_icloud_base, moom_subdir)
    icloud_plist_path = File.join(moom_sync_dir, "com.manytricks.Moom.plist")
    
    unless File.exist?(icloud_plist_path)
      pputs "Moom config not found at: #{icloud_plist_path}", color: :red
      pputs "Run with --export flag first to create initial backup", color: :yellow
      return
    end
    
    local_plist_path = File.expand_path(moom_local_path)
    
    # Check if files are identical
    if File.exist?(local_plist_path)
      if system("diff -q \"#{local_plist_path}\" \"#{icloud_plist_path}\" > /dev/null 2>&1")
        pputs "Moom preferences already match iCloud version", color: :green
        return
      end
    end
    
    # Quit Moom if running
    if system("pgrep -q Moom")
      pputs "Quitting Moom...", color: :yellow
      system("osascript -e 'tell application \"Moom\" to quit'")
      sleep 2
    end
    
    pputs "Restoring Moom preferences from iCloud...", indent: 1
    
    # Backup existing local preferences first
    if File.exist?(local_plist_path)
      backup_path = "#{local_plist_path}.backup.#{Time.now.strftime('%Y%m%d_%H%M%S')}"
      system("cp \"#{local_plist_path}\" \"#{backup_path}\"")
      pputs "Backed up existing preferences to: #{backup_path}", indent: 2, color: :cyan
    end
    
    # Copy from iCloud to local
    system("cp \"#{icloud_plist_path}\" \"#{local_plist_path}\"")
    pputs "Restored Moom preferences from iCloud", indent: 2, color: :green
    
    pputs "Moom configuration complete. Restart Moom to apply changes.", color: :green
  end

  # macOS Setup Helper Methods
  def setup_global_settings
    pputs "Setting up global preferences", style: :bold
    
    pprint "Configuring global settings", indent: 1
    
    # Always show scrollbars
    run_defaults("write NSGlobalDomain AppleShowScrollBars -string \"Always\"")
    
    # Expand save panel by default
    run_defaults("write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true")
    run_defaults("write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true")
    
    # Expand print panel by default
    run_defaults("write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true")
    run_defaults("write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true")
    
    # Automatically quit printer app once the print jobs complete
    run_defaults("write com.apple.print.PrintingPrefs \"Quit When Finished\" -bool true")
    
    # Don't automatically adjust the brightness of the screen
    @sudo_manager.run("defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor \"Automatic Display Enabled\" -bool false")
    
    # Disable "close windows when quitting an app"
    run_defaults("write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool true")
    
    # Enable dark mode
    run_defaults("write NSGlobalDomain AppleInterfaceStyle -string \"Dark\"")
    
    print_column_fill("  Configuring global settings", indent: 1, color: :green)
    pputs " completed", color: :green
    pputs ""
  end

  def setup_keyboard_preferences
    pputs "Setting up keyboard preferences", style: :bold
    
    pprint "Configuring keyboard settings", indent: 1
    
    # Fast key repeats
    run_defaults("write -g InitialKeyRepeat -int 15")
    run_defaults("write -g KeyRepeat -int 2")
    
    # Disable press-and-hold for special characters (requires logout/restart)
    run_defaults("write NSGlobalDomain ApplePressAndHoldEnabled -bool false")
    
    # Enable full keyboard access for all controls
    run_defaults("write NSGlobalDomain AppleKeyboardUIMode -int 3")
    
    # Disable automatic keyboard brightness
    run_defaults("write com.apple.BezelServices kDim -bool false")
    
    # Disable autocorrect
    run_defaults("write -g NSAutomaticSpellingCorrectionEnabled -bool false")
    
    # Disable auto-capitalize
    run_defaults("write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false")
    
    # Disable auto period insert
    run_defaults("write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false")
    
    # Disable smart quotes (useful for developers)
    run_defaults("write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false")
    
    # Disable smart dashes (useful for developers)
    run_defaults("write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false")
    
    # Enable text replacement everywhere
    run_defaults("write -g WebAutomaticTextReplacementEnabled -bool true")
    
    print_column_fill("  Configuring keyboard settings", indent: 1, color: :green)
    pputs " completed", color: :green
    pputs ""
  end

  def setup_dock
    pputs "Setting up the dock", style: :bold
    
    pprint "Configuring dock preferences", indent: 1
    
    # Remove all default apps from the dock
    run_defaults("write com.apple.dock persistent-apps -array")
    
    # Only show active things in the dock
    run_defaults("write com.apple.dock static-only -bool true")
    
    # Autohide the dock
    run_defaults("write com.apple.dock autohide -bool true")
    
    # Put it on the left
    run_defaults("write com.apple.Dock orientation -string \"left\"")
    
    # Hot corners - bottom left corner starts screen saver
    run_defaults("write com.apple.dock wvous-bl-corner -int 5")
    run_defaults("write com.apple.dock wvous-bl-modifier -int 0")
    
    # No dock bouncing, ever
    run_defaults("write com.apple.dock no-bouncing -bool TRUE")
    
    # Set icon size
    run_defaults("write com.apple.dock tilesize -int 36")
    
    # Don't automatically rearrange Spaces based on most recent use
    run_defaults("write com.apple.dock mru-spaces -bool false")
    
    # Speed up Mission Control animations
    run_defaults("write com.apple.dock expose-animation-duration -float 0.1")
    
    print_column_fill("  Configuring dock preferences", indent: 1, color: :green)
    pputs " completed", color: :green
    pputs ""
  end

  def setup_trackpad
    pputs "Setting up the trackpad", style: :bold
    
    pprint "Configuring trackpad settings", indent: 1
    
    # Enable one-click taps
    run_defaults("write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true")
    run_defaults("write com.apple.AppleMultitouchTrackpad Clicking -bool true")
    run_defaults("-currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1")
    run_defaults("write NSGlobalDomain com.apple.mouse.tapBehavior -int 1")
    
    # Trackpad: enable right click with two fingers
    run_defaults("write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true")
    run_defaults("write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true")
    run_defaults("-currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true")
    run_defaults("write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true")
    
    # Enable Force Click and haptic feedback
    run_defaults("write NSGlobalDomain com.apple.trackpad.forceClick -bool true")
    run_defaults("write com.apple.AppleMultitouchTrackpad ForceSuppressed -bool false")
    
    # Sequoia has trackpad issues - refresh Bluetooth trackpad connections if needed
    if system("system_profiler SPBluetoothDataType | grep -q \"Trackpad\"")
      @sudo_manager.run("killall -HUP bluetoothd 2>/dev/null || true")
    end
    
    print_column_fill("  Configuring trackpad settings", indent: 1, color: :green)
    pputs " completed", color: :green
    pputs ""
  end

  def fix_screenshots
    pputs "Fixing screenshot behavior", style: :bold
    
    pprint "Configuring screenshot settings", indent: 1
    
    # Set screenshot location (folder created by create_folders script)
    run_defaults("write com.apple.screencapture location \"#{File.expand_path('~/Screen Shots')}\"")
    
    # To hell with preview thumbnails
    run_defaults("write com.apple.screencapture show-thumbnail -bool FALSE")
    
    # Use PNG format for screenshots
    run_defaults("write com.apple.screencapture type -string \"png\"")
    
    print_column_fill("  Configuring screenshot settings", indent: 1, color: :green)
    pputs " completed", color: :green
    pputs ""
  end

  def setup_finder
    pputs "Setting up the finder", style: :bold
    
    pprint "Configuring Finder preferences", indent: 1
    
    # Show all extensions
    run_defaults("write NSGlobalDomain AppleShowAllExtensions -bool true")
    
    # Default new windows to column view
    run_defaults("write com.apple.Finder FXPreferredViewStyle clmv")
    
    # Allow quitting finder with cmd+Q
    run_defaults("write com.apple.finder QuitMenuItem -bool true")
    
    # Finder: show hidden files by default
    run_defaults("write com.apple.finder AppleShowAllFiles -bool true")
    
    # Finder: show status bar
    run_defaults("write com.apple.finder ShowStatusBar -bool true")
    
    # Finder: show path bar
    run_defaults("write com.apple.finder ShowPathbar -bool true")
    
    # Disable the warning when changing a file extension
    run_defaults("write com.apple.finder FXEnableExtensionChangeWarning -bool false")
    
    # Disable the warning before emptying the Trash
    run_defaults("write com.apple.finder WarnOnEmptyTrash -bool false")
    
    # Empty Trash securely by default
    run_defaults("write com.apple.finder EmptyTrashSecurely -bool true")
    
    # Set Desktop as the default location for new Finder windows
    run_defaults("write com.apple.finder NewWindowTarget -string \"PfDe\"")
    run_defaults("write com.apple.finder NewWindowTargetPath -string \"file://#{ENV['HOME']}/Desktop/\"")
    
    # Show icons for hard drives, servers, and removable media on the desktop
    run_defaults("write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true")
    run_defaults("write com.apple.finder ShowHardDrivesOnDesktop -bool true")
    run_defaults("write com.apple.finder ShowMountedServersOnDesktop -bool true")
    run_defaults("write com.apple.finder ShowRemovableMediaOnDesktop -bool true")
    
    # Show the ~/Library folder
    system("chflags nohidden ~/Library")
    
    # Enable spring loading for directories
    run_defaults("write NSGlobalDomain com.apple.springing.enabled -bool true")
    
    # Remove the spring loading delay for directories
    run_defaults("write NSGlobalDomain com.apple.springing.delay -float 0")
    
    print_column_fill("  Configuring Finder preferences", indent: 1, color: :green)
    pputs " completed", color: :green
    pputs ""
  end

  def setup_screensaver
    pputs "Setting up the screensaver", style: :bold
    
    pprint "Configuring screensaver settings", indent: 1
    
    # Use Flurry screensaver
    run_defaults("-currentHost write com.apple.screensaver moduleDict -dict path -string \"/System/Library/Screen Savers/Flurry.saver\" moduleName -string \"Flurry\" type -int 0")
    
    # Never start it
    run_defaults("-currentHost write com.apple.screensaver idleTime -int 0")
    
    print_column_fill("  Configuring screensaver settings", indent: 1, color: :green)
    pputs " completed", color: :green
    pputs ""
  end

  def setup_sound_preferences
    pputs "Setting up sound preferences", style: :bold
    
    pprint "Configuring sound settings", indent: 1
    
    # Set alert sound to submarine
    run_defaults("write .GlobalPreferences com.apple.sound.beep.sound /System/Library/Sounds/Submarine.aiff")
    
    print_column_fill("  Configuring sound settings", indent: 1, color: :green)
    pputs " completed", color: :green
    pputs ""
  end

  def setup_menubar_preferences
    pputs "Setting up menu bar preferences", style: :bold
    
    pprint "Configuring menu bar settings", indent: 1
    
    # Show battery percentage in menu bar
    run_defaults("-currentHost write com.apple.controlcenter BatteryShowPercentage -bool true")
    
    print_column_fill("  Configuring menu bar settings", indent: 1, color: :green)
    pputs " completed", color: :green
    pputs ""
  end

  def setup_spotlight_preferences
    pputs "Setting up spotlight preferences", style: :bold
    
    pprint "Configuring Spotlight hotkey", indent: 1
    
    plist = "#{ENV['HOME']}/Library/Preferences/com.apple.symbolichotkeys.plist"
    
    # Ensure the plist exists
    unless File.exist?(plist)
      run_defaults("write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict")
    end
    
    # Disable conflicting input source shortcuts that use Control+Space
    system("/usr/libexec/PlistBuddy \"#{plist}\" -c \"Set :AppleSymbolicHotKeys:60:enabled false\" 2>/dev/null || true")
    
    # Remove existing Spotlight entry if it exists (prevents conflicts)
    system("/usr/libexec/PlistBuddy \"#{plist}\" -c \"Delete :AppleSymbolicHotKeys:64\" 2>/dev/null || true")
    
    # Add the new Control+Space configuration for Spotlight
    plistbuddy_commands = [
      "Add :AppleSymbolicHotKeys:64 dict",
      "Add :AppleSymbolicHotKeys:64:enabled bool true",
      "Add :AppleSymbolicHotKeys:64:value dict",
      "Add :AppleSymbolicHotKeys:64:value:parameters array",
      "Add :AppleSymbolicHotKeys:64:value:parameters: integer 65535",
      "Add :AppleSymbolicHotKeys:64:value:parameters: integer 49",
      "Add :AppleSymbolicHotKeys:64:value:parameters: integer 262144",
      "Add :AppleSymbolicHotKeys:64:value:type string standard"
    ]
    
    plistbuddy_commands.each do |command|
      system("/usr/libexec/PlistBuddy \"#{plist}\" -c \"#{command}\" 2>/dev/null || true")
    end
    
    # Force refresh of system preferences without logout
    system("/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true")
    
    print_column_fill("  Configuring Spotlight hotkey", indent: 1, color: :green)
    pputs " completed", color: :green
    pputs ""
  end

  def restart_running_apps
    pputs "Restarting system components", style: :bold
    
    pprint "Restarting affected applications", indent: 1
    
    # Kill apps that need to restart to pick up changes
    apps_to_restart = [
      "Dock",
      "Notification Center", 
      "Finder",
      "SystemUIServer",
      "cfprefsd",
      "TextInputMenuAgent",
      "Print Center"
    ]
    
    apps_to_restart.each do |app|
      system("killall \"#{app}\" 2>/dev/null || true")
    end
    
    # Restart processes for keyboard/trackpad settings
    @sudo_manager.run("pkill -f \"/System/Library/CoreServices/RemoteManagement/ARDAgent.app\" 2>/dev/null || true")
    
    # Force refresh of trackpad/keyboard preferences
    run_defaults("-currentHost delete -globalDomain com.apple.mouse.tapBehavior 2>/dev/null || true")
    run_defaults("-currentHost write -globalDomain com.apple.mouse.tapBehavior -int 1")
    
    # Clear the font cache (in case any font-related changes were made)
    @sudo_manager.run("atsutil databases -remove >/dev/null 2>&1 || true")
    
    print_column_fill("  Restarting affected applications", indent: 1, color: :green)
    pputs " completed", color: :green
    pputs ""
  end

  def run_defaults(command)
    system("defaults #{command}")
  end
end
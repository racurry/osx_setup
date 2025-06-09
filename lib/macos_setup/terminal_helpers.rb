module MacOSSetup::TerminalHelpers
  COLORS = {
    black: 30,
    red: 31,
    green: 32,
    yellow: 33,
    blue: 34,
    pink: 35,
    cyan: 36,
    white: 37
  }

  STYLES = {
    bold: 1,
    italic: 3,
    underline: 4
  }

  COLUMN_WIDTH = 80
  INDENT_SPACES = 4

  def print_column_fill(existing_strings, opts={})
    used_chars = existing_strings.length

    indent_level = opts.delete(:indent) || 0
    indent_chars = indent_level * INDENT_SPACES
    chars_left = COLUMN_WIDTH - used_chars - indent_chars

    pprint('.' * chars_left, opts)
  end

  def horizontal_rule(color=:yellow)
    pputs "-" * COLUMN_WIDTH, style: :bold, color: color
  end

  def section_header(text)
    pputs ""
    pputs text, style: :bold, color: :yellow
    horizontal_rule(:yellow)
  end

  def section_footer(text)
    pputs ""
    pputs text, style: :bold, color: :green, indent: 1
  end

  def pprint(text, opts={})
    color = opts[:color]
    style = opts[:style]
    indent_level = opts[:indent] || 0

    indent = (" " * INDENT_SPACES) * indent_level
    string = indent + text
    string = "\e[#{STYLES[style]}m#{string}\e[0m" if style && STYLES[style]
    string = "\e[#{COLORS[color]}m#{string}\e[0m" if color && COLORS[color]

    print string
  end

  def pputs(text, opts={})
    pprint(text, opts)
    print "\n"
  end
end
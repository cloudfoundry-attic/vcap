module VcapStringExtensions

  def red
    colorize("\e[0m\e[31m")
  end

  def green
    colorize("\e[0m\e[32m")
  end

  def yellow
    colorize("\e[0m\e[33m")
  end

  def bold
    colorize("\e[0m\e[1m")
  end

  def colorize(color_code)
    unless $nocolor
      "#{color_code}#{self}\e[0m"
    else
      self
    end
  end
end

class String
  include VcapStringExtensions
end

module Gnuplot
  module Settings
    MIN_GNUPLOT_VERSION = 5.0
    ##
    # ==== Overview
    # Get path that should be used to run gnuplot executable.
    # Default value: 'gnuplot'
    def self.gnuplot_path
      self.gnuplot_path = 'gnuplot' unless defined?(@@gnuplot_path)
      @@gnuplot_path
    end

    ##
    # ==== Overview
    # Set path to gnuplot executable.
    def self.gnuplot_path=(path)
      validate_version(path)
      opts = { stdin_data: "set term\n" }
      @@available_terminals = Open3.capture2e(path, **opts)
                                  .first
                                  .scan(/[:\n] +([a-z][^ ]+)/)
                                  .map(&:first)
      @@gnuplot_path = path
    end

    ##
    # ==== Overview
    # Get list of terminals available for that gnuplot.
    def self.available_terminals
      @@available_terminals
    end

    ##
    # ==== Overview
    # Get gnuplot version. Uses #gnuplot_path to find
    # gnuplot executable.
    # ==== Arguments
    # * *path* - path to gnuplot executable; #gnuplot_path used as default.
    def self.version
      self.gnuplot_path = 'gnuplot' unless defined?(@@gnuplot_path)
      @@version
    end

    ##
    # ==== Overview
    # Validates gnuplot version. Compares current gnuplot's
    # version with ::MIN_GNUPLOT_VERSION.
    # ==== Arguments
    # * *path* - path to gnuplot executable.
    def self.validate_version(path)
      @@version = IO.popen("#{path} --version")
                    .read
                    .match(/gnuplot ([^ ]+)/)[1]
                    .to_f
      message = "Your Gnuplot version is #{@@version}, please update it to at least 5.0"
      fail(ArgumentError, message) if @@version < MIN_GNUPLOT_VERSION
    end
  end
end
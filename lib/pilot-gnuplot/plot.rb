module Gnuplot
  ##
  # === Overview
  # Plot correspond to simple 2D visualisation
  class Plot
    attr_reader :terminal
    attr_reader :datasets
    ##
    # ==== Parameters
    # * *datasets* are either instances of Dataset class or
    # [data, **dataset_options] arrays
    # * *options* will be considered as 'settable' options of gnuplot
    # ('set xrange [1:10]' for { xrange: 1..10 }, "set title 'plot'" for { title: 'plot' } etc)
    def initialize(*datasets, **options)
      @datasets = if datasets[0].is_a? Hamster::Vector
                    datasets[0]
                  else
                    Hamster::Vector.new(datasets).map { |ds| convert_to_dataset(ds) }
                  end
      @options = Hamster.hash(options)
      @already_plotted = false
      @cmd = 'plot '
      @terminal = Terminal.new
      OptionsHelper.validate_terminal_options(@options)
      yield(self) if block_given?
    end

    ##
    # ==== Overview
    # This outputs plot to term (if given) or to last used term (if any)
    # or just builds its own Terminal with plot and options
    # ==== Parameters
    # * *term* - Terminal to plot to
    # * *options* - will be considered as 'settable' options of gnuplot
    # ('set xrange [1:10]', 'set title 'plot'' etc);
    # options passed here have priority above already given to ::new
    def plot(term = @terminal, **options)
      opts = @options.merge(options)
      full_command = @cmd + @datasets.map { |dataset| dataset.to_s(term) }.join(' , ')
      plot_command(term, full_command, opts)
      @already_plotted = true
      self
    end

    ##
    # ==== Overview
    # Method which outputs plot to specific terminal (possibly some file).
    # Explicit use should be avoided. This method is called from #method_missing
    # when it handles method names like #to_png(options).
    # ==== Parameters
    # * *terminal* - string corresponding to terminal type (png, html, jpeg etc)
    # * *path* - path to output file, if none given it will output to temp file
    # and then read it and return binary data with contents of file
    # * *options* - used in 'set term <term type> <options here>'
    # ==== Examples
    #   plot.to_png('./result.png', size: [300, 500])
    #   contents = plot.to_svg(size: [100, 100])
    #   plot.to_dumb('./result.txt', size: [30, 15])
    def to_specific_term(terminal, path = nil, **options)
      if path
        result = plot(term: [terminal, options], output: path)
      else
        path = Dir::Tmpname.make_tmpname(terminal, 0)
        plot(term: [terminal, options], output: path)
        result = File.binread(path)
        File.delete(path)
      end
      result
    end

    ##
    # ==== Overview
    # In this gem #method_missing is used both to handle
    # options and to handle plotting to specific terminal.
    #
    # ==== Options handling
    # ===== Overview
    # You may set options using #option_name(option_value) method.
    # A new object will be constructed with selected option set.
    # And finally you can get current value of any option using
    # #options_name without arguments.
    # ===== Examples
    #   new_plot = plot.title('Awesome plot')
    #   plot.title # >nil
    #   new_plot.title # >'Awesome plot'
    #   plot.title # >'One more awesome plot'
    #
    # ==== Plotting to specific term
    # ===== Overview
    # Gnuplot offers possibility to output graphics to many image formats.
    # The easiest way to to so is to use #to_<plot_name> methods.
    # ===== Parameters
    # * *options* - set of options related to terminal (size, font etc).
    # ===== Examples
    #   # options specific for png term
    #   plot.to_png('./result.png', size: [300, 500], font: ['arial', 12])
    #   # options specific for svg term
    #   content = plot.to_svg(size: [100, 100], fname: 'Arial', fsize: 12)
    def method_missing(meth_id, *args)
      meth = meth_id.id2name
      if meth[0..2] == 'to_'
        term = meth[3..-1]
        super unless OptionsHelper.valid_terminal?(term)
        to_specific_term(term, *args)
      else
        if args.empty?
          value = @options[meth.to_sym]
          value = value[0] if value && value.size == 1
          value
        else
          options(meth.to_sym => args)
        end
      end
    end

    ##
    # ==== Overview
    # Create new Plot object where dataset at *position* will
    # be replaced with the new one created from it by updating.
    # ==== Parameters
    # * *position* - position of dataset which you need to update
    # (by default first dataset is updated)
    # * *data* - data to update dataset with
    # * *options* - options to update dataset with
    # ==== Example
    #   TODO add examples (and specs!)
    def update_dataset(position = 0, data: nil, **options)
      old_ds = @datasets[position]
      new_ds = old_ds.update(data, options)
      new_ds.equal?(old_ds) ? self : replace_dataset(position, new_ds)
    end

    ##
    # ==== Overview
    # Create new Plot object where dataset at *position* will
    # be replaced with the given one.
    # ==== Parameters
    # * *position* - position of dataset which you need to update
    # (by default first dataset is replaced)
    # * *dataset* - dataset to replace the old one
    # ==== Example
    #   TODO add examples (and specs!)
    def replace_dataset(position = 0, dataset)
      self.class.new(@datasets.set(position, dataset), @options)
    end

    ##
    # ==== Overview
    # Create new Plot object where given dataset will
    # be appended to dataset list.
    # ==== Parameters
    # * *dataset* - dataset to add
    # ==== Example
    #   TODO add examples (and specs!)
    def add_dataset(dataset)
      self.class.new(@datasets.add(convert_to_dataset(dataset)), @options)
    end

    alias_method :<<, :add_dataset

    ##
    # ==== Overview
    # Create new Plot object where given dataset will
    # be appended to dataset list.
    # ==== Parameters
    # * *position* - position of dataset that should be
    # removed (by default last dataset is removed)
    # ==== Example
    #   TODO add examples (and specs!)
    def remove_dataset(position = -1)
      self.class.new(@datasets.delete_at(position), @options)
    end

    ##
    # ==== Overview
    # Replot self. Usable is cases then Plot contains
    # datasets which store data in files. Replot may be
    # used in this case to update plot after data update.
    # # ==== Example
    #   TODO add examples (and specs!)
    def replot
      @already_plotted ? plot_command(@terminal, 'replot', @options) : plot
    end

    ##
    # ==== Overview
    # Create new Plot object where current Plot's
    # options are merged with given. If no options
    # given it will just return existing set of options.
    # ==== Parameters
    # * *options* - options to add
    # ==== Example
    #   sin_graph = Plot.new(['sin(x)', title: 'Sin'], title: 'Sin on [0:3]', xrange: 0..3)
    #   sin_graph.plot
    #   sin_graph_update = sin_graph.options(title: 'Sin on [-10:10]', xrange: -10..10)
    #   sin_graph_update.plot
    #   # you may also consider this as
    #   # sin_graph.title(...).xrange(...)
    def options(**options)
      if options.empty?
        @options
      else
        self.class.new(@datasets, @options.merge(options))
      end
    end

    ##
    # ==== Overview
    # Get a dataset number *position*
    def [](*args)
      @datasets[*args]
    end

    def convert_to_dataset(source)
      source.is_a?(Dataset) ? source.clone : Dataset.new(*source)
    end

    ##
    # TODO: docs here
    def plot_command(term, full_command, options)
      output = options[:output]
      File.delete(output) if output && File.file?(output)
      term.set(options)
          .puts(full_command)
          .unset(options.keys)
      sleep 0.001 until File.file?(output) && File.size(output) > 100 if output
    end
  end
end

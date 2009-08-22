class ReportTable
  ObservedSelect = Struct.new(:form_url_options, :form_html_options, :select_name, :select_id, :select_options, :selected, :remote, :object)

  attr_accessor(:columns, :identifier, :title, :subtitle, :explanatory_text, :format_before, 
                :render_first, :render_after_title, :link_after_title, :controller,
                :link_after, :show_footer, :format_after, :table_class, :show_csv, :clickable_row,
                :empty_title, :empty_link, :model)

  attr_writer(:date_format, :time_format, :datetime_format, :currency_unit)

  def self.link_to(options={})
    text = options.delete(:link_text)
    lambda { |x|
      [
        (if text.is_a?(Symbol) then x.send(text) else text end),
        { :controller => x.class.name.titleize.downcase.pluralize.gsub(/\s+/, '_'), :action => :show, :id => x.id }.merge(options) 
      ]
    }
  end
  
  def currency_unit
    @currency_unit || '$'
  end

  def date_format
    @date_format || "%m/%d/%Y"
  end

  def time_format
    @time_format || "%l:%M%p"
  end

  def datetime_format
    @datetime_format || date_format + " " + time_format
  end

  def id_column
    columns.detect { |c| c.options[:use_as_id] }
  end

  def class_columns
    columns.select { |c| c.options[:use_as_class] }
  end
  
  def identifier=(i)
    @identifier = i
  end
  
  def identifier
    @identifier.blank? ? 'report' : @identifier
  end
  
  def html_options
    @html_options ||= { }
  end
  
  def html_options=(h)
    @html_options = h
  end

  def initialize(cols=nil, records=nil, options = { })
    record_klass = options[:model]  
    options.each { |k,v| self.send("#{k}=", v) }
    
    unless cols.nil?
      self.columns = []
      cols.each do |col| self.add_column(col) end
    end
    
    self.data = records
  end

  def add_column(c)
    col = infer_column(c, model)
    col.index = columns.length
    col.report = self
    columns << col
  end

  
  def each_data_segment
    return unless @data_segments
    @data_segments.each do |ds|
      yield data_to_output(ds)
    end
  end
  
  def data
    data_to_output(raw_data)
  end
  
  def data=(d)
    @data_segments = [d].compact
  end

  def raw_data
    data_segments.inject { |a,b| a + b } || []
  end
  
  def data_segments
    @data_segments || []
  end

  def data_to_output(d)
    d.map { |row| 
      columns.map { |c| 
        case c.data_proc 
        when Symbol:  row.send(c.data_proc)
        when Proc:    c.data_proc.call(row)
        else          nil
        end || c.default_value 
      }
    }
  end

  
  def data_segments=(ds)
    raise "Mangled data segments" unless ds.is_a?(Array) and (ds.empty? or ds.first.is_a?(Array))
    @data_segments = ds
  end
  
  def column_groups
    visible_columns.partition_by { |c| c.options[:column_group] }
  end
  
  def visible_columns
    columns.reject { |c| c.options[:hidden] }
  end

  def csv(params)
    require 'fastercsv'
    FasterCSV.generate(&csv_proc(params))
  end

  def csv_proc(params = { })
    order, direction = get_sort_criteria(params)

    lambda { |csv| 
      csv << self.visible_columns.map(&:name)
      self.each_data_segment do |records|        
        self.sort_data(records, order, direction).each do |row|
          csv << self.visible_columns.map { |col| format_text(col.type, row[col.index]) }
        end
      end
    }
  end

  def empty?
    record_count == 0
  end
  
  def record_count
    @data_segments.map(&:length).sum
  end

  def sort_data(data, order, direction)
    if index = columns.map(&:column_id).index(order)
      nils, non_nil = data.partition { |e| columns[index].sort_value(e[index]).nil? }
      
      sorted = non_nil.sort { |a,b| columns[index].compare(a[index], b[index]) }
      
      sorted = direction == 'asc' ? sorted : sorted.reverse
      (columns[index].options[:sort_reverse] ? sorted.reverse : sorted) + nils
    else
      data
    end
  end
  
  def sorted_data(params)
    order, direction = get_sort_criteria(params)
    sort_data(data_to_output(raw_data), order, direction)    
  end
  
  private
  
  def get_sort_criteria(params)
    params['_reports'] ||= { }
    params['_reports'][identifier] ||= { }      
    current_order, current_direction = params['_reports'][identifier]["order"], params['_reports'][identifier]["direction"]
    default_column = columns.detect { |c| c.options[:sorted_by_default] } || columns.first
    return (current_order || (default_column ? default_column.column_id : nil)), (current_direction || 'asc')
  end

  def format_text(type, data=nil, options={ })
    return type.to_s if (!type.is_a?(Symbol)) && data.nil?
    case type
    when :date     : data.maybe.strftime(date_format)
    when :time     : data.maybe.strftime(time_format)
    when :datetime : data.maybe.strftime(datetime_format)
    when :boolean  : data ? "Yes" : "No"
    when :int      : data.to_i.to_s
    when :float    : data.to_f.to_s
    when :links    : data.map { |l| l[0] }.join(", ")
    when :format   : format_text(data[0], data[1])
    when :formats  : data[1].map { |d| format_text(*d) }.join(data[0])
    else 
      case data
      when Array: data.first.to_s
      else data.to_s
      end
    end
  end
  
  def infer_column(col, record_klass)
    case col
    when Symbol
      if record_klass.report_columns.has_key? col.to_sym
        record_klass.report_columns[col.to_sym].clone
      elsif col == :edit or col == :show
        Column.new('', false, :link, self.class.link_to(:link_text => col.to_s.capitalize, :action => col))
      else
        Column.new(col.to_s.humanize, true, :text, col)
      end
    when Array
      col[4] ||= { }
      Column.new(*col)
    when Hash
      Column.new_from_hash(col)
    when Column
      col.clone
    else
      raise "Unknown column type: " + col.inspect
    end
  end  
end

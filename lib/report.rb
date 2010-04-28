class ReportTable
  ObservedSelect = Struct.new(:form_url_options, :form_html_options, :select_name, :select_id, :select_options, :selected, :remote, :object)

  attr_accessor(:columns, :identifier, :title, :subtitle, :explanatory_text, :format_before, 
                :render_first, :render_after_title, :link_after_title, :controller, :i18n,
                :link_after, :show_footer, :format_after, :table_class, :show_csv, :clickable_row,
                :empty_title, :empty_link, :model, :sql_options, :never_sort)

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

  def date(d)
    if d && i18n
      I18n.l(d.to_date, :format => @date_format || 'default')      
    elsif d
      d.to_date.strftime(@date_format || "%m/%d/%Y")
    end
  end

  def time(t)
    if t && i18n
      I18n.l(t, :format => @time_format || 'time_of_day')      
    elsif t
      t.strftime(@time_format || "%l:%M%p")
    end
  end

  def datetime(dt)
    if dt && i18n
      I18n.l(dt, :format => @datetime_format || 'default')     
    elsif dt
      dt.strftime(@datetime_format || "%m/%d/%Y %l:%M%p")
    end
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
    sort_by = options.delete(:sort_by)
    options.each { |k,v| self.send("#{k}=", v) }
    
    unless cols.nil?
      self.columns = []
      cols.each do |col| self.add_column(col, sort_by) end
    end
    
    self.data = records
  end

  def add_column(c, sort_by)
    col = infer_column(c, model, sort_by)
    col.index = columns.length
    col.report = self
    columns << col
  end

  def raw_data
    @data
  end
  
  def data
    data_to_output(@data)
  end
  
  def data=(d)
    @data = d
  end

  def data_to_output(d)
    d.map { |row| 
      columns.map { |c| 
        case c.data_proc 
        when Symbol:  row.send(c.data_proc)
        when Proc:    c.data_proc.arity == 1 ? c.data_proc.call(row) : c.data_proc.call(row, c)
        else          nil
        end || c.default_value 
      }
    }
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
      data_to_output(self.sort_data(@data, order, direction)).each do |row|
        csv << self.visible_columns.map { |col| format_text(col.type, row[col.index]) }
      end
    }
  end

  def empty?
    record_count == 0
  end
  
  def record_count
    if @data.respond_to?(:count)
      @data.count
    else
      @data.length
    end
  end

  def sort_data(data, order, direction)
    if index = columns.map(&:column_id).index(order)
      column = columns[index]
      if column.sort_by_sql?
        conditions = { :order => column.sql_sort + ' ' + direction }
        
        data_to_output(data.all((sql_options || {}).merge(conditions)))
      else
        data = data_to_output(if data.respond_to?(:all) then data.all(sql_options || {}) else data end)
        nils, non_nil = data.partition { |e| column.sort_value(e[index]).nil? }
        
        sorted = non_nil.sort { |a,b| column.compare(a[index], b[index]) }
        
        sorted = direction == 'asc' ? sorted : sorted.reverse
        (column.options[:sort_reverse] ? sorted.reverse : sorted) + nils
      end
    else
      data
    end
  end
  
  def sorted_data(params)
    if never_sort
      data_to_output(@data)
    else
      order, direction = get_sort_criteria(params)
      sort_data(@data, order, direction)
    end
  end
  
  def get_sort_criteria(params)
    params['_reports'] ||= { }
    params['_reports'][identifier] ||= { }      
    current_order, current_direction = params['_reports'][identifier]["order"], params['_reports'][identifier]["direction"]
    
    if current_order
      column = columns.detect { |c| c.column_id == current_order }
    else
      column = columns.detect { |c| c.options[:sorted_by_default] } || columns.first
    end    

    direction = current_direction || column.default_sort_direction
    
    return column.column_id, direction
  end

  
  private
  def format_text(type, data=nil, options={ })
    return type.to_s if (!type.is_a?(Symbol)) && data.nil?
    case type
    when :ago      : controller.helpers.time_ago_in_words(data)
    when :date     : date(data)
    when :time     : time(data)
    when :datetime : datetime(data)
    when :boolean  : data ? "Yes" : "No"
    when :int      : data.to_i.to_s
    when :float    : data.to_f.to_s
    when :percentage : "%0.2f%%" % data
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
  
  def infer_column(col, record_klass, sort_by)
    clm = nil
    srt = nil
    case col
    when Symbol
      clm = if record_klass.report_columns.has_key? col.to_sym
              record_klass.report_columns[col.to_sym].clone
            elsif col == :edit or col == :show
              Column.new('', false, :link, self.class.link_to(:link_text => col.to_s.capitalize, :action => col))
            else
              Column.new(col.to_s, true, :text, col)
            end

      srt = if sort_by == col then true elsif sort_by then false else nil end
    when Array
      col[4] ||= { }
      clm = Column.new(*col)

      srt = if sort_by == col[0] then true elsif sort_by then false else nil end
    when Hash
      clm = Column.new_from_hash(col)
      srt = if sort_by == clm.name then true elsif sort_by then false else nil end
    when Column
      clm = col.clone
      srt = if sort_by == clm.name then true elsif sort_by then false else nil end
    else
      raise "Unknown column type: " + col.inspect
    end

    clm.options[:sorted_by_default] = srt if !srt.nil?

    return clm
  end  
end

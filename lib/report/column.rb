class ReportTable
  Column = Struct.new(:name, :sortable, :type, :data_proc, :option_hash, :index, :report) do
    include ActionView::Helpers::TagHelper

    def self.new_from_hash(options)
      def self.default(v1,v2)
        if v1.nil? then v2 else v1 end
      end
      label = options.delete(:label)
      options[:header] ||= maybe(label) { |l| l.to_s.humanize }
      
      Column.new(options.delete(:header),
                  default(options.delete(:sortable), true),
                  default(options.delete(:type),     :text),
                  default(options.delete(:data_proc),label),
                  options)
    end
    
    def promoted_to_column_group
      column = self.clone
      column.options[:column_group] = column.name
      column.name = ""
      return column
    end

    def class
      [options[:class], options[:title] ? "title-column" : ""].reject(&:blank?).join(" ")
    end
    
    def options
      self.option_hash ||= { }
    end
    
    def sort_column
      if options[:sort_using]
        report.columns.detect { |c| c.name == options[:sort_using] }
      end || self
    end
    
    def column_id
      [group_name, name].reject(&:blank?).join("_") || ""
    end
    
    def group_name
      self.options[:column_group] || ""
    end
   
    def format_html_header(params, identifier)
      if sortable
        [:link, sortable_html_header(params, identifier)]
      elsif name.is_a? Array
        [:format, name]
      else
        [:text, name]
      end
    end

    def format_html_footer(raw_data)
      if options[:footer]
        [options[:footer_type] || type, options[:footer].call(raw_data)]
      else
        [""]
      end
    end
 
    def sort_value(val)
      sv(type, val)
    end

    def compare(val1, val2)
      def self.c(type1, val1, type2, val2)
        return val1.to_s.downcase <=> val2.to_s.downcase unless type1 == type2
        case type1
        when :format  : c(*(val1 + val2))
        when :formats : 
          (0..[val1[1].length-1, val2[1].length-1].min).each do |i|
            n = c(*(val1[1][i] + val2[1][i]))
            return n if n != 0
          end
          return 0
        else sv(type1,val1) <=> sv(type2,val2)
        end
      end
      
      c(type, val1, type, val2)
    end
    
    def default_value
      case type
      when :text : nil
      when :html : ""
      else         nil
      end
    end

    def html_class(params, identifier)
      current_order, current_direction = order_and_direction(params, identifier)
      
      if sortable
        if sort_column.column_id == current_order.to_s
        then "sortable-header current #{ current_direction }"
        else "sortable-header"
        end
      else
        ""
      end
    end
    
    private

    def order_and_direction(params, identifier)
      params['_reports'] ||= { }
      params['_reports'][identifier] ||= { }
      
      current_order, current_direction = params['_reports'][identifier]["order"], params['_reports'][identifier]["direction"]
      current_direction ||= 'desc'

      return current_order, current_direction
    end
    

    def sortable_html_header(params, identifier)
      current_order, current_direction = order_and_direction(params, identifier)
      sc = sort_column
      
      if current_order == sc.column_id
        direction_to_link_to = (current_direction == 'desc') ? 'asc' : 'desc'
      else
        direction_to_link_to = 'asc'
      end
      
      if sc.column_id == current_order.to_s
        [name.blank? ? "-" : name, 
         { :overwrite_params => { "_reports" => params["_reports"].merge({ identifier => { "order" => sc.column_id, 
                                                                             "direction" => direction_to_link_to  }}) } }] 
      else         
        [name.blank? ? "-" : name, 
         { :overwrite_params => { "_reports" => params["_reports"].merge({ identifier => { "order" => sc.column_id, 
                                                                             "direction" => direction_to_link_to  }}) } }, 
        ]
      end
    end
    
    def sv(tp, val)
      case tp
      when :boolean  : val ? 1 : 0
      when :int, :float, :time, :date, :datetime : val
      else             val.nil? ? nil : val.to_s.downcase
      end
    end

    
  end
end

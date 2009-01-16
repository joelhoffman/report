class Report
  Column = Struct.new(:name, :sortable, :type, :data_proc, :option_hash, :index, :report) do
    include ActionView::Helpers::TagHelper

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
        return val1.to_s <=> val2.to_s unless type1 == type2
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
    
    private

    def sortable_html_header(params, identifier)
      params['_reports'] ||= { }
      params['_reports'][identifier] ||= { }
      
      current_order, current_direction = params['_reports'][identifier]["order"], params['_reports'][identifier]["direction"]
      current_direction ||= 'desc'
      
      if current_order == column_id
        direction_to_link_to = (current_direction == 'desc') ? 'asc' : 'desc'
      else
        direction_to_link_to = 'asc'
      end
      
      img = "<img src='/images/sort-#{direction_to_link_to}.gif' width='8' height='6' />"
   
      if column_id == current_order.to_s
        [img + " " + name, 
         { :overwrite_params => { "_reports" => params["_reports"].merge({ identifier => { "order" => column_id, 
                                                                             "direction" => direction_to_link_to  }}) } }, 
         { :class => "sortable-header current" } ]
      else
        [name.blank? ? "-" : name, 
         { :overwrite_params => { "_reports" => params["_reports"].merge({ identifier => { "order" => column_id, 
                                                                             "direction" => direction_to_link_to  }}) } }, 
         { :class => "sortable-header" }]
      end
    end
    
    def sv(tp, val)
      case tp
      when :time     : val
      when :date     : val
      when :datetime : val
      when :boolean  : val ? 1 : 0
      else             val.nil? ? nil : val.to_s
      end
    end

    def default_value
      case type
      when :text : nil
      when :html : ""
      else         nil
      end
    end
    
  end
end

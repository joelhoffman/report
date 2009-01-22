# Include hook code here
require File.dirname(__FILE__) + '/lib/report'
require File.dirname(__FILE__) + '/lib/report/format_html'
require File.dirname(__FILE__) + '/lib/report/column'

ActiveRecord::Base.class_eval do
  def self.report_columns
    #beware of unknown unknowns
    @report_columns
  end
  
  def self.report_column(label, options = {})
    def self.default(v1,v2)
      if v1.nil? then v2 else v1 end
    end
    
    @report_columns ||= { }
    @report_columns[label] = Report::Column.new(default(options.delete(:header),   label.to_s.humanize),
                                                default(options.delete(:sortable), true),
                                                default(options.delete(:type),     :text),
                                                default(options.delete(:data_proc),label),
                                                options)
  end
end

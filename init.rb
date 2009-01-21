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
    @report_columns ||= { }
    @report_columns[label] = Report::Column.new(label.to_s.humanize, 
                                                options[:sortable] || true,
                                                options[:type] || :text,
                                                options[:data_proc],
                                                options[:options] || {})
  end
end
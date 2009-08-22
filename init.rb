# Include hook code here
require File.dirname(__FILE__) + '/lib/report'
require File.dirname(__FILE__) + '/lib/report/format_html'
require File.dirname(__FILE__) + '/lib/report/column'

ActiveRecord::Base.class_eval do
  def self.report_columns
    #beware of unknown unknowns
    rc = { }
    (self.ancestors - [self]).each do |a|
      if a.respond_to? :report_columns
        rc.merge! (a.report_columns || {})
      end
    end

    rc.merge(@report_columns || {})
  end
  
  def self.report_column(label, options = {})
    @report_columns ||= { }
    @report_columns[label] = ReportTable::Column.new_from_hash({:label => label}.merge(options))
  end
end

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
  
  def self.report_column(label, options = {}, &block)
    @report_columns ||= { }
    @report_columns[label] = ReportTable::Column.new_from_hash({:label => label}.merge(options))
    @report_columns[label].data_proc = block if block
  end
end

unless [].respond_to?(:partition_by) 
  module Enumerable
    def partition_by(&block)
      self.inject([]) do |partitions, i|
        p = yield i
        if !partitions.empty? && p == partitions[-1][0]
          partitions[-1][1] << i        
        else
          partitions << [p, [i]]
        end
        partitions
      end
    end
  end
end  

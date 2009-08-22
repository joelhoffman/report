# -*- coding: utf-8 -*-
require 'test/unit'
require File.dirname(__FILE__) + '/test_helper'
require 'rubygems'
require 'active_record'
require 'action_controller'
require 'action_view'
require File.dirname(__FILE__) + "/../init"

class ReportTableTest < Test::Unit::TestCase
  
  def test_columns
    # array declaration
    col1 = ["col 1", true, :text, lambda { }, { :column_group => 'c1' }]
    
    #hash declaration
    col2 = { 
      :name => "col 2", 
      :sortable => true, 
      :type => :text, 
      :data_proc => lambda { }, 
      :options => { :column_group => 'c1' } 
    }
    
    #direct declaration
    col3 = ReportTable::Column.new("col 3", true, :text, lambda { })
    
    r = ReportTable.new([ col1, col2, col3 ],
                   [])
    
    assert_equal 3, r.columns.length

    r.columns.each { |c| assert_kind_of(ReportTable::Column, c) }
    
    assert_equal [ [ 'c1', r.columns[0..1] ], [ nil, r.columns[2..2] ] ], r.column_groups
    
    assert_equal({ }, r.columns[2].options)
  end

  class MockController
    def url_for(args = { })
      def hash_to_string(prefix, hash)
        hash.map { |k,v|
          pfx = prefix ? "#{prefix}[#{k}]" : k
          case v
          when Hash: hash_to_string(pfx, v)
          else       "#{pfx}=#{v}"
          end
        }.sort.join("&")
      end

      args = args[:overwrite_params] if args.has_key?(:overwrite_params)

      'http://hello/world?' + hash_to_string(nil, args.except(:only_path))
    end
  end

  def test_mock_controller
    m = MockController.new
    assert_equal("http://hello/world?", m.url_for())
    assert_equal("http://hello/world?k2=v2&k=v", m.url_for( :k => 'v', :k2 => 'v2'  ))
    assert_equal("http://hello/world?k2=v2&k[k1]=v", m.url_for( :k => { :k1 => 'v' }, :k2 => 'v2' ))

  end

  def test_format
    r = ReportTable.new([], [], 
                   :date_format => "%d-%b-%Y", :time_format => "%H:%M", :currency_unit => "£",
                   :controller => MockController.new)
    
    assert(r.empty?)

    assert_equal("a",                                                r.format_html("a"))
    assert_equal("&",                                                r.format_html("&"))
    assert_equal("&",                                                r.format_html(:html, "&"))
    assert_equal("a",                                                r.format_html(:text, "a"))
    assert_equal("&amp;",                                            r.format_html(:text, "&"))
    assert_equal('<div style="white-space: pre">&amp;</div>',        r.format_html(:preformatted_text, '&'))
    assert_equal('<div style="text-align: right">0.02</div>',        r.format_html(:float, 0.0201))
    assert_equal('<div style="text-align: right">0</div>',           r.format_html(:int, 0.1))
    assert_equal("06-May-1978",                                      r.format_html(:date, Date.parse("May 6, 1978")))
    assert_equal("14:00",                                            r.format_html(:time, Time.parse("2pm")))
    assert_equal("06-May-1978 14:00",                                r.format_html(:datetime, Time.parse("May 6, 1978 2pm")))
    assert_equal("Yes",                                              r.format_html(:boolean, true))
    assert_equal("£0.05",                                            r.format_html(:currency, 0.05))
    assert_equal('<a href="http://hello/world?a=b&amp;c=d">YES</a>', r.format_html(:link, ["YES", { :a => 'b', :c => 'd' }]))
    assert_equal('<a href="http://hello/world?a=b&amp;c=d">YES</a>, ' +
                 '<a href="http://hello/world?a=d&amp;c=b">NO</a>' , r.format_html(:links, [["YES", { :a => 'b', :c => 'd' }],
                                                                                            ["NO",  { :a => 'd', :c => 'b' }]]))
    assert_equal('<a href="mailto:kittens@are.driving.me.crazy">kittens@are.driving.me.crazy</a>',     r.format_html(:mailto, "kittens@are.driving.me.crazy"))
    assert_equal('<ul class="num"><li>One</li><li>£2.00</li></ul>',  r.format_html(:ul, ["One", [:currency, "2"]], { :class => 'num'}))
    assert_equal('<span class="x">X</span>',                         r.format_html(:span, "X", { :class => 'x'}))
    assert_equal('£0.05',                                            r.format_html(:format,  [:currency, 1.0/20]))
    assert_equal('£0.05 at 14:00',                                   r.format_html(:formats, [" ", [ [:currency, 1.0/20],
                                                                                                     "at",
                                                                                                     [:time, Time.parse("2pm")]]]))
  end

  def test_csv
    r = ReportTable.new([["Value", true, :text, lambda { |a| a[0] }],
                    ["Date",  true, :date, lambda { |a| a[1] }]], 

                   [["Val2", Date.parse("June 3, 1922")],
                    ["val1", Date.parse("May 1, 1969")],
                    ["val3", Date.parse("October 14, 2011")]])

    assert_equal_ignoring_whitespace_and_quote_style(<<EOD, r.csv({ }))
Value, Date
val1,  05/01/1969
Val2,  06/03/1922
val3,  10/14/2011
EOD
  end

  def test_basic_html
    r = ReportTable.new([["Value", false, :text, lambda { |a| a[0] }],
                    ["Date",  false, :date, lambda { |a| a[1] }]], 

                   [["Val2", Date.parse("June 3, 1922")],
                    ["val1", Date.parse("May 1, 1969")],
                    ["val3", Date.parse("October 14, 2011")]])

    assert_equal_ignoring_whitespace_and_quote_style(<<EOD, r.html_table({ }))
<table class="report-table report" style="width: auto;">
  <thead>
    <tr><th class=""><span>Value</span></th>
        <th class=""><span>Date</span></th></tr>
  </thead>
  <tbody>
    <tr class="odd"><td>val1</td>
        <td>05/01/1969</td></tr>
    <tr class="even"><td>Val2</td>
        <td>06/03/1922</td></tr>
    <tr class="odd"><td>val3</td>
        <td>10/14/2011</td></tr>
  </tbody>
</table>
EOD
  end

  def test_advanced_html
    r = ReportTable.new([[nil,     true, :int,  lambda { |a| a[0] }, { :hidden => true, :use_as_id => true}],
                    ["Value", true, :text, lambda { |a| a[1] }, { :column_group => "Column 1" }],
                    ["Date",  true, :date, lambda { |a| a[2] }, { :footer => lambda { |rows| rows.map(&:last).max }}]], 
                   nil, # data records
                   :data_segments => [[[0, "val1", Date.parse("May 1, 1969")],
                                       [1, "Val2", Date.parse("June 3, 1968")]],
                                      [[2, "val3", Date.parse("October 14, 2011")]]],
                   :controller => MockController.new,
                   :show_footer => true,
                   :identifier => "xyz",
                   :html_options => { :width => "100%" })

    # this is a sortable report with multiple table bodies, column groups,
    # a distinct identifier, a specified width, IDs on rows from a hidden
    # column, a footer containing the maximum date, and sorted by date

    assert_equal_ignoring_whitespace_and_quote_style(<<EOD, r.html_table({ '_reports' => { 'xyz' => { 'order' => 'Date', 'direction' => 'asc' }}}))
<table class="report-table xyz" style="width: 100%;">
  <colgroup span="1"></colgroup>
  <colgroup span="1"></colgroup>
  <thead>
    <tr><th colspan="1">Column 1</th>
        <th colspan="1"></th></tr>
    <tr>
      <th class="sortable-header"><span><a href="http://hello/world?_reports[xyz][direction]=asc&amp;_reports[xyz][order]=Column 1_Value">Value</a></span></th>
      <th class="sortable-header current asc">
        <span>
          <a href="http://hello/world?_reports[xyz][direction]=desc&amp;_reports[xyz][order]=Date">
            Date
          </a>
        </span>
      </th>
    </tr>
  </thead>
  <tfoot>
    <tr><td></td><td>10/14/2011</td></tr>
  </tfoot>
  <tbody>
    <tr class="odd" id="xyz:1"><td>Val2</td>
        <td>06/03/1968</td></tr>
    <tr class="even" id="xyz:0"><td>val1</td>
        <td>05/01/1969</td></tr>
  </tbody>
  <tbody>
    <tr class="odd" id="xyz:2"><td>val3</td>
        <td>10/14/2011</td></tr>
  </tbody>
</table>
EOD
  end
end

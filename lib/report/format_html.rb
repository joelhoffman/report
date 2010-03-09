class ReportTable
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::NumberHelper
  
  def html_page(items, params={}, options = {})
    content_tag(:table,
      (title ? content_tag(:caption, title) : '') + 
        html_thead(params, options) + html_tfoot + html_table_body(items, params), 
                :id => identifier,
                :class => ["report-table", identifier].reject(&:blank?).join(" "),
                :style => html_options[:width] ? "width: #{ html_options[:width] };" : "")
  end
  
  def html_table(params = { }, options = {})
    content_tag(:table,
      (title ? content_tag(:caption, title) : '') + 
      html_thead(params, options) + html_tfoot + html_table_bodies(params), 
                :id => identifier,
                :class => ["report-table", identifier, options[:table_class]].reject(&:blank?).join(" "),
                :style => html_options[:width] ? "width: #{ html_options[:width] };" : "")
  end
  
  def protect_against_forgery?
    @controller.send(:protect_against_forgery?)
  end
  
  def request_forgery_protection_token
    @controller.request_forgery_protection_token
  end

  def form_authenticity_token
    @controller.send(:form_authenticity_token)
  end

  def polymorphic_path(*args)
    @controller.send(:polymorphic_path, *args)
  end

  def format_html(type, data=nil, options={ })
    return type if (!type.is_a?(Symbol)) && data.nil?
    case type
    when :text              : h(data)
    when :preformatted_text : content_tag(:div, h(data), :style => "white-space: pre")
    when :html              : data
    when :content_tag       : data ? content_tag(*data) : nil
    when :float             : data.present? ? "%0.2f" % data : nil
    when :pct               : data.present? ? "%0.#{options[:precision] || 0}f" % data : nil
    when :int               : data.present? ? data.to_i : nil
    when :currency          : number_to_currency(data, :unit => @currency_unit)
    when :link              : link_to(*data)
    when :links             : data.map { |l| format_html(:link, l) }.join(", ")
    when :mailto            : mail_to(*data)
    when :ul                : content_tag(:ul, data.map { |d| content_tag(:li, format_html(*d)) }.join(""), options)
    when :span              : content_tag(:span, format_html(*data), options)
    when :ratio             : data && !data[1].to_i.zero? ? begin d = data.map(&:to_i); '<span class="n">%d</span> / <span class="d">%d</span> (<span class="p">%d</span>%%)' % (d + [d[0]*100.0/d[1]]) end : nil
    when :interval          : data ? if data.is_a?(Array) then '<span class="l">%d</span>&ndash;<span class="u">%d</span>' % data else data end : nil
    when :date_period       : data ? I18n.l(Date.from_date_period(data), :format => :month_of_year) : nil
    when :format            : format_html(*data)
    when :formats           : data[1].map { |d| format_html(*d) }.join(data[0])
    else format_text(type, data)
    end
  end  

  private

  def url(data)
    case(data)
    when Hash : controller.url_for(data)
    when String: data
    else raise "Unknown URL: #{data.inspect}"
    end
  end
  
  def html_thead(params, options)
    groups = column_groups
    (groups.length > 1 ? groups.map { |name, cols| content_tag(:colgroup, nil, :span => cols.length) }.join("") : "") +
      content_tag(:thead,
                  (groups.length > 1 ? content_tag(:tr, groups.map { |name, cols| content_tag(:th, name, :colspan => cols.length) }.join("")) : "") +
                  content_tag(:tr, visible_columns.map { |c| html_th(c, params, options) }.join("")))
  end

  def html_th(col, params, options)
    html_class = [col.html_class(params, identifier), col.options[:class]].reject(&:blank?).join(" ")
    content_tag(:th, 
                content_tag(:span, format_html(*col.format_html_header(params, identifier, options))),
                col.options.slice(:style, :title).merge({
                  :class => html_class
                }))
  end

  def html_tfoot
    return "" unless show_footer
    content_tag(:tfoot, 
                content_tag(:tr,
                            visible_columns.map { |col| 
                              content_tag(:td, format_html(*col.format_html_footer(raw_data))) 
                            }.join("")))
  end

  def html_table_row(row, idc, classcs, index)
    tr_options = { }
    tr_options[:id] = identifier + '--' + row[idc.index].to_s if idc
    tr_options[:class] = if index.even? then 'even' else 'odd' end

    if classcs
      tr_options[:class] = ([tr_options[:class]] + classcs.map { |c| row[c.index].to_s }).join(' ')
    end
    
    content_tag(:tr,
                visible_columns.map { |col|
                  content = if col.options[:format_html] && row[col.index].respond_to?(col.options[:format_html])
                              row[col.index].send(col.options[:format_html])
                            else
                              format_html(col.type, row[col.index], col.options)
                            end
                  content_tag(col.options[:th] ? :th : :td, content.to_s, :class => [if content.nil? then 'nil' end, col.type_for_class(row[col.index]), col.options[:class]].compact.join(" ") ) 
                }.join(""),
                tr_options)
  end

  def html_table_bodies(params)
    html_table_body(sorted_data(params), params)
  end
  
  def html_table_body(items, params)
    idc = id_column
    classcs = class_columns
    content_tag(:tbody, 
                items.zip((1..items.length).to_a)\
                  .map { |row, index| html_table_row(row, idc, classcs, index) }.join(""))
  end
end

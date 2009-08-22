class ReportTable
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::NumberHelper
  
  def html_page(items, params={})
    content_tag(:table,
      html_thead(params) + html_tfoot + html_table_body(items, params), 
                :class => ["report-table", identifier].reject(&:blank?).join(" "),
                :style => "width: #{ html_options[:width] || 'auto' };")
  end
  
  def html_table(params = { })
    content_tag(:table,
                html_thead(params) + html_tfoot + html_table_bodies(params), 
                :class => ["report-table", identifier].reject(&:blank?).join(" "),
                :style => "width: #{ html_options[:width] || 'auto' };")
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

  def format_html(type, data=nil, options={ })
    return type if (!type.is_a?(Symbol)) && data.nil?
    case type
    when :text              : h(data)
    when :preformatted_text : content_tag(:div, h(data), :style => "white-space: pre")
    when :html              : data
    when :content_tag       : data ? content_tag(*data) : ''
    when :float             : data ? content_tag(:div, "%0.2f" % [data], :style => "text-align: right") : ''
    when :int               : data ? content_tag(:div, data.to_i, :style => "text-align: right") : ''
    when :currency          : number_to_currency(data, :unit => @currency_unit)
    when :link              : link_to(*data)
    when :links             : data.map { |l| format_html(:link, l) }.join(", ")
    when :mailto            : mail_to(*data)
    when :ul                : content_tag(:ul, data.map { |d| content_tag(:li, format_html(*d)) }.join(""), options)
    when :span              : content_tag(:span, format_html(*data), options)
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
  
  def html_thead(params)
    groups = column_groups
    (groups.length > 1 ? groups.map { |name, cols| content_tag(:colgroup, nil, :span => cols.length) }.join("") : "") +
      content_tag(:thead,
                  (groups.length > 1 ? content_tag(:tr, groups.map { |name, cols| content_tag(:th, name, :colspan => cols.length) }.join("")) : "") +
                  content_tag(:tr, visible_columns.map { |c| html_th(c, params) }.join("")))
  end

  def html_th(col, params)
    html_class = [col.html_class(params, identifier), col.options[:class]].reject(&:blank?).join(" ")
    content_tag(:th, 
                content_tag(:span, format_html(*col.format_html_header(params, identifier))),
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
    tr_options[:id] = identifier.underscore + ':' + row[idc.index].to_s.underscore if idc
    tr_options[:class] = if index.even? then 'even' else 'odd' end

    if classcs
      tr_options[:class] += ' ' + classcs.map { |c| row[c.index].to_s.underscore }.join(' ')
    end
    
    content_tag(:tr,      
                visible_columns.map { |col|                   
                  content = if col.options[:format_html] && row[col.index].respond_to?(col.options[:format_html])
                              row[col.index].send(col.options[:format_html])
                            else 
                              format_html(col.type, row[col.index])
                            end
                            
                  content_tag(:td, content, :class => col.options[:class]) 
                }.join(""),
                tr_options)
  end

  def html_table_bodies(params)
    idc = id_column
    classcs = class_columns
    order, direction = get_sort_criteria(params)
    data_segments.map { |records| 
      content_tag(:tbody, 
                  sort_data(data_to_output(records), order, direction)\
                    .zip((1..records.length).to_a)\
                    .map { |row, index| html_table_row(row, idc, classcs, index) }.join(""))
    }.join("")
  end
  
  def html_table_body(items, params)
    idc = id_column
    classcs = class_columns
    content_tag(:tbody, 
                items.zip((1..items.length).to_a)\
                  .map { |row, index| html_table_row(row, idc, classcs, index) }.join(""))
  end
end

class Report
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::NumberHelper

  def html_table(params = { })
    content_tag(:table,
                html_thead(params) + html_tfoot + html_table_bodies(params), 
                :class => ["report-table", identifier].reject(&:blank?).join(" "),
                :style => "width: #{ html_options[:width] || '100%' };")
  end

  def format_html(type, data=nil, options={ })
    return type if (!type.is_a?(Symbol)) && data.nil?
    case type
    when :text              : h(data)
    when :preformatted_text : content_tag(:div, h(data), :style => "white-space: pre")
    when :html              : data
    when :float             : content_tag(:div, "%0.2f" % [data], :style => "text-align: right")
    when :int               : content_tag(:div, data.to_i, :style => "text-align: right")
    when :currency          : number_to_currency(data, :unit => @currency_unit)
    when :link              : link_to(format_html(*data.first), data[1], data[2])
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

  def html_thead(params)
    groups = column_groups
    (groups.length > 1 ? groups.map { |name, cols| content_tag(:colgroup, nil, :span => cols.length) }.join("") : "") +
      content_tag(:thead,
                  (groups.length > 1 ? content_tag(:tr, groups.map { |name, cols| content_tag(:th, name, :colspan => cols.length) }.join("")) : "") +
                  content_tag(:tr, visible_columns.map { |c| html_th(c, params) }.join("")))
  end

  def html_th(col, params)
    content_tag(:th, 
                content_tag(:span, format_html(*col.format_html_header(params, identifier))),
                col.options.slice(:style, :title, :class))
  end

  def html_tfoot
    return "" unless show_footer
    content_tag(:tfoot, 
                content_tag(:tr,
                            visible_columns.map { |col| 
                              content_tag(:td, format_html(*col.format_html_footer(raw_data))) 
                            }.join("")))
  end

  def html_table_row(row, idc)                   
    tr_options = { }
    tr_options[:id] = identifier.underscore + ':' + row[idc.index].to_s.underscore if idc

    content_tag(:tr,
                visible_columns.map { |col| 
                  content_tag(:td, format_html(col.type, row[col.index]), :class => col.options[:class]) 
                }.join(""),
                tr_options)
  end

  def html_table_bodies(params)
    idc = id_column
    order, direction = get_sort_criteria(params)
    data_segments.map { |records| 
      content_tag(:tbody, 
                  sort_data(data_to_output(records), order, direction)\
                    .map { |row| html_table_row(row, idc) }.join(""))
    }.join("")
  end
end

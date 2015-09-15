# Methods added to this helper will be available to all templates in the application
module ApplicationHelper
  include HomeHelper

  # Add autogenerated html data-id attribute if not present (prefixed with "aid_")
  def link_to(*args, &block)
    if block_given?
      super(*args)
    else
      options = args[1] || {}
      html_options = args[2] || {}
      unless html_options.has_key?(:'data-id') || (options.is_a?(String) and options.starts_with?("mailto:"))
        begin
          path = URI.split(url_for(options) || html_options['href'])[5].split(/\//).select {|x| !x.empty?}
          if path.size > 0
            max = path.size <= 3 ? path.size : 3
            id = path.last(max).join('_')
          else
            id = 'not_defined'
          end
        rescue => e
          Foreman::Logging.exception("Failed generating link using #{ args.inspect }", e)
          id = 'not_parseable'
        end
        html_options.merge!(:'data-id' => "aid_#{id}")
      end
      if html_options[:confirm]
        html_options[:data] ||= {}
        html_options[:data][:confirm] = html_options.delete(:confirm)
      end
      super(args[0], args[1], html_options)
    end
  end

  def link_to_function(name, function, html_options = {})
    onclick = "#{"#{html_options[:onclick]}; " if html_options[:onclick]}#{function}; return false;"
    href = html_options[:href] || '#'

    content_tag(:a, name, html_options.merge(:href => href, :onclick => onclick))
  end

  protected

  def contract(model)
    model.to_label
  end

  def show_habtm(associations)
    render :partial => 'common/show_habtm', :collection => associations, :as => :association
  end

  def edit_habtm(klass, association, prefix = nil, options = {})
    render :partial => 'common/edit_habtm', :locals =>{:prefix => prefix, :klass => klass, :options => options,
                                                       :associations => association.all.sort.delete_if{|e| e == klass}}
  end

  def link_to_remove_fields(name, f, options = {})
    f.hidden_field(:_destroy) + link_to_function(icon_text("remove", name), "remove_fields(this)", options.merge(:title => _("Remove Parameter")))
  end

  # Creates a link to a javascript function that creates field entries for the association on the web page
  # +name+       : String containing links's text
  # +f+          : FormBuiler object
  # +association : The field are created to allow entry into this association
  # +partial+    : String containing an optional partial into which we render
  def link_to_add_fields(name, f, association, partial = nil, options = {})
    new_object = f.object.class.reflect_on_association(association).klass.new
    fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render((partial.nil? ? association.to_s.singularize + "_fields" : partial), :f => builder)
    end
    link_to_function(name, ("add_fields(this, \"#{association}\", \"#{escape_javascript(fields)}\")").html_safe, add_html_classes(options, "btn btn-success") )
  end

  def link_to_remove_puppetclass(klass, type)
    options = options_for_puppetclass_selection(klass, type)
    text = remove_link_to_function(truncate(klass.name, :length => 28), options)
    content_tag(:span, text).html_safe +
        remove_link_to_function('', options.merge(:class => 'glyphicon glyphicon-minus-sign'))
  end

  def remove_link_to_function(text, options)
    options.delete_if { |key, value| !options[key].to_s } # otherwise error during template render
    title = (_("Click to remove %s") % options[:"data-class-name"])
    link_to_function(text, "remove_puppet_class(this)", options.merge!(:'data-original-title'=> title))
  end

  def link_to_add_puppetclass(klass, type)
    options = options_for_puppetclass_selection(klass, type)
    text = add_link_to_function(truncate(klass.name, :length => 28), options)
    content_tag(:span, text).html_safe +
        add_link_to_function('', options.merge(:class => 'glyphicon glyphicon-plus-sign'))
  end

  def add_link_to_function(text, options)
    link_to_function(text, "add_puppet_class(this)",
        options.merge(:'data-original-title' => _("Click to add %s") % options[:"data-class-name"]))
  end

  def add_html_classes(options, classes)
    options = options.dup unless options.nil?
    options ||= {}
    options[:class] = options[:class].dup if options.has_key? :class
    options[:class] ||= []
    options[:class] = options[:class].split /\s+/ if options[:class].is_a? String
    classes = classes.split /\s+/ if classes.is_a? String
    options[:class] += classes
    options
  end

  # Return true if user is authorized for controller/action, otherwise false
  # +options+ : Hash containing
  #             :controller : String or symbol for the controller, defaults to params[:controller]
  #             :action     : String or symbol for the action
  #             :id         : Id parameter
  #             :auth_action: String or symbol for the action, this has higher priority that :action
  #             :auth_object: Specific object on which we may verify particular permission
  #             :authorizer : Specific authorizer to perform authorization on (handy to inject authorizer with base collection)
  #             :permission : Specific permission to check authorization on (handy on custom permission names)
  def authorized_for(options)
    action          = options.delete(:auth_action) || options[:action]
    object          = options.delete(:auth_object)
    user            = User.current
    controller      = options[:controller] || params[:controller]
    controller_name = controller.to_s.gsub(/::/, "_").underscore
    id              = options[:id]
    permission      = options.delete(:permission) || [action, controller_name].join('_')

    if object.nil?
      user.allowed_to?({ :controller => controller_name, :action => action, :id => id }) rescue false
    else
      authorizer = options.delete(:authorizer) || Authorizer.new(user)
      authorizer.can?(permission, object) rescue false
    end
  end

  # Display a link if user is authorized, otherwise a string
  # +name+    : String to be displayed
  # +options+ : Hash containing options for authorized_for and link_to
  # +html_options+ : Hash containing html options for the link or span
  def link_to_if_authorized(name, options = {}, html_options = {})
    enable_link = authorized_for(options)
    if enable_link
      link_to name, options, html_options
    else
      link_to_function name, nil, html_options.merge!(:class => "#{html_options[:class]} disabled", :disabled => true)
    end
  end

  def display_delete_if_authorized(options = {}, html_options = {})
    options = {:auth_action => :destroy}.merge(options)
    html_options = { :data => { :confirm => _('Are you sure?') }, :method => :delete, :class => 'delete' }.merge(html_options)
    display_link_if_authorized(_("Delete"), options, html_options)
  end

  # Display a link if user is authorized, otherwise nothing
  # +name+    : String to be displayed
  # +options+ : Hash containing options for authorized_for and link_to
  # +html_options+ : Hash containing html options for the link or span
  def display_link_if_authorized(name, options = {}, html_options = {})
    enable_link = html_options.has_key?(:disabled) ? !html_options[:disabled] : true
    if enable_link and authorized_for(options)
      link_to(name, options, html_options)
    else
      ""
    end
  end

  def authorized_edit_habtm(klass, association, prefix = nil, options = {})
    if authorized_for :controller => params[:controller], :action => params[:action]
      return edit_habtm(klass, association, prefix, options)
    end
    show_habtm klass.send(association.name.pluralize.downcase)
  end

  # renders a style=display based on an attribute properties
  def display?(attribute = true)
    "style=#{display(attribute)}"
  end

  def display(attribute)
    "display:#{attribute ? 'none' : 'inline'};"
  end

  # return our current model instance type based on the current controller
  # i.e. HostsController would return "host"
  def type
    controller_name.singularize
  end

  def checked_icon(condition)
    image_tag("toggle_check.png") if condition
  end

  def locked_icon(condition, hovertext)
    ('<span class="glyphicon glyphicon-lock" title="%s"/>' % hovertext).html_safe if condition
  end

  def searchable?
    return false if (SETTINGS[:login] && !User.current) || @welcome
    if (controller.action_name == "index") or (defined?(SEARCHABLE_ACTIONS) and (SEARCHABLE_ACTIONS.include?(controller.action_name)))
      controller.respond_to?(:auto_complete_search)
    end
  end

  def auto_complete_controller_name
    controller.respond_to?(:auto_complete_controller_name) ? controller.auto_complete_controller_name : controller_name
  end

  def auto_complete_search(name, val, options = {})
    path = options[:full_path]
    path ||= (options[:path] || send("#{auto_complete_controller_name}_path")) + "/auto_complete_#{name}"
    options.merge!(:class => "autocomplete-input form-control", :'data-url' => path )
    text_field_tag(name, val, options)
  end

  def help_path
    link_to _("Help"), :action => "welcome" if File.exist?("#{Rails.root}/app/views/#{controller_name}/welcome.html.erb")
  end

  def method_path(method)
    send("#{method}_#{controller_name}_path")
  end

  def edit_textfield(object, property, options = {})
    edit_inline(object, property, options.merge({:type => "edit_textfield"}))
  end

  def edit_textarea(object, property, options = {})
    edit_inline(object, property, options.merge({:type => "edit_textarea"}))
  end

  def edit_select(object, property, options = {})
    edit_inline(object, property, options.merge({:type => "edit_select"}))
  end

  def flot_pie_chart(name, title, data, options = {})
    data = data.map { |k,v| {:label=>k.to_s.humanize, :data=>v} } if  data.is_a?(Hash)
    data.map{|element| element[:label] = truncate(element[:label],:length => 16)}
    header = content_tag(:h4,(options[:show_title]) ? title : '', :class=>'ca pie-title', :'data-original-title'=>_("Expand the chart"), :rel=>'twipsy')
    link_to_function(header, "expand_chart(this)")+
        content_tag(:div, nil,
                    { :id    => name,
                      :class => 'statistics-pie',
                      :data  => {
                        :'title'  => title,
                        :'series' => data,
                        :'url'    => options[:search] ? "#{request.script_name}/hosts?search=#{URI.encode(options.delete(:search))}" : "#"
                      }
                    }.merge(options))
  end

  def flot_chart(name, xaxis_label, yaxis_label, data, options = {})
    data = data.map { |k,v| {:label=>k.to_s.humanize, :data=>v} } if  data.is_a?(Hash)
    content_tag(:div, nil,
                { :id    => name,
                  :class => 'statistics-chart',
                  :data  => {
                    :'legend-options' => options.delete(:legend),
                    :'xaxis-label'    => xaxis_label,
                    :'yaxis-label'    => yaxis_label,
                    :'series'         => data
                  }
                }.merge(options))
  end

  def flot_bar_chart(name, xaxis_label, yaxis_label, data, options = {})
    i=0
    ticks = nil
    if data.is_a?(Array)
      data = data.map do |kv|
        ticks ||=[]
        ticks << [i+=1,kv[0].to_s.humanize ]
        [i,kv[1]]
      end
    elsif  data.is_a?(Hash)
      data = data.map do |k,v|
        ticks ||=[]
        ticks << [i+=1,k.to_s.humanize ]
        [i,v]
      end
    end

    content_tag(:div, nil,
                { :id   => name,
                  :data => {
                    :'xaxis-label' => xaxis_label,
                    :'yaxis-label' => yaxis_label,
                    :'chart'   => data,
                    :'ticks'   => ticks
                  }
                }.merge(options))
  end

  def action_buttons(*args)
    toolbar_action_buttons args
  end

  def select_action_button(title, options = {}, *args)
    # the no-buttons code is needed for users with less permissions
    return unless args
    args = args.flatten.map{|arg| arg unless arg.blank?}.compact
    return if args.length == 0

    #single button
    return content_tag(:span, args[0].html_safe, options.merge(:class=>'btn btn-default')) if args.length == 1

    #multiple options
    content_tag(:div, options.merge(:class=>'btn-group')) do
      link_to((title +" " +content_tag(:i, '', :class=>'caret')).html_safe,'#', :class=>"btn btn-default dropdown-toggle", :'data-toggle'=>'dropdown') +
          content_tag(:ul,:class=>"dropdown-menu pull-right") do
            args.map{|option| content_tag(:li,option)}.join(" ").html_safe
          end
    end
  end

  def toolbar_action_buttons(*args)
    # the no-buttons code is needed for users with less permissions
    return unless args
    args = args.flatten.map{|arg| arg unless arg.blank?}.compact
    return if args.length == 0

    #single button
    return content_tag(:span, args[0].html_safe, :class=>'btn btn-sm btn-default') if args.length == 1

    #multiple buttons
    primary =  args.delete_at(0).html_safe
    primary = content_tag(:span, primary, :class=>'btn btn-sm btn-default') if primary !~ /btn/

    content_tag(:div,:class => "btn-group") do
      primary + link_to(content_tag(:i, '', :class=>'caret'),'#', :class=>"btn btn-default #{'btn-sm' if primary =~ /btn-sm/} dropdown-toggle", :'data-toggle'=>'dropdown') +
      content_tag(:ul,:class=>"dropdown-menu pull-right") do
        args.map{|option| content_tag(:li,option)}.join(" ").html_safe
      end
    end
  end

  def avatar_image_tag(user, html_options = {})
    if user.avatar_hash.nil?
      default_image = path_to_image("user.jpg")
      if Setting["use_gravatar"]
        image_url = gravatar_url(user.mail, default_image)
        html_options.merge!(:onerror=>"this.src='#{default_image}'", :alt => _('Change your avatar at gravatar.com'))
      else
        image_url = default_image
      end
    else
      image_url = path_to_image("avatars/#{user.avatar_hash}.jpg")
    end
    image_tag(image_url, html_options)
  end

  def gravatar_url(email, default_image)
    return default_image if email.blank?
    "#{request.protocol}secure.gravatar.com/avatar/#{Digest::MD5.hexdigest(email.downcase)}?d=mm&s=30"
  end

  def readonly_field(object, property, options = {})
    name       = "#{type}[#{property}]"
    helper     = options[:helper]
    value      = helper.nil? ? object.send(property) : self.send(helper, object)
    klass      = options[:type]
    title      = options[:title]

    opts = { :title => title, :class => klass.to_s, :name => name, :value => value}

    content_tag_for :span, object, opts do
      h(value)
    end
  end

  def blank_or_inherit_f(f, attr)
    return true unless f.object.respond_to?(:parent_id) && f.object.parent_id
    inherited_value   = f.object.send(attr).try(:name_method)
    inherited_value ||= _("no value")
    _("Inherit parent (%s)") % inherited_value
  end

  def obj_type(obj)
    obj.class.model_name.to_s.tableize.singularize
  end

  def class_in_environment?(environment,puppetclass)
    return false unless environment
    environment.puppetclasses.map(&:id).include?(puppetclass.id)
  end

  def show_parent?(obj)
    (obj.new_record? && obj.class.count > 0) || (!obj.new_record? && obj.class.count > 1)
  end

  def documentation_button(section = nil)
    url = if section
            "http://www.theforeman.org/manuals/#{SETTINGS[:version].short}/index.html##{section}"
          else
            "http://www.theforeman.org/documentation.html##{SETTINGS[:version].short}"
          end

    link_to(icon_text('question-sign', _('Documentation'), :class => 'icon-white'),
      url, :rel => 'external', :class => 'btn btn-info', :target => '_blank')
  end

  private

  def edit_inline(object, property, options = {})
    name       = "#{type}[#{property}]"
    helper     = options[:helper]
    value      = helper.nil? ? object.send(property) : self.send(helper, object)
    klass      = options[:type]
    update_url = options[:update_url] || url_for(object)

    opts = { :title => _("Click to edit"), "data-url" => update_url, :class => "editable #{klass}",
      :name => name, "data-field" => property, :value => value, :select_values => options[:select_values]}

    content_tag_for :span, object, opts do
      h(value)
    end
  end

  def options_for_puppetclass_selection(klass, type)
    {
      :'data-class-id'   => klass.id,
      :'data-class-name' => klass.name,
      :'data-type'       => type,
      :'data-url'        => parameters_puppetclass_path(:id => klass.id),
      :rel               => 'twipsy'
    }
  end
end

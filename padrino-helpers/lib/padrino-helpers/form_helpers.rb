require 'securerandom'
require 'padrino-helpers/form_options_helpers'

module Padrino
  module Helpers
    ##
    # Helpers related to producing form related tags and inputs into templates.
    #
    module FormHelpers
      def self.included(base)
        base.send(:include, FormOptionsHelpers) unless base.method_defined?(:extract_option_tags!)
      end

      ##
      # Constructs a form for object using given or default form_builder.
      #
      # @param [Object] object
      #   The object for which the form is being built.
      # @param [String] URL
      #   The url this form will submit to.
      # @param [Hash] options
      #   The settings associated with this form.
      #   Accepts a :namespace option that will be prepended to the id attributes of the form's elements.
      #   Also accepts HTML options.
      # @option settings [String] :builder ("StandardFormBuilder")
      #   The FormBuilder class to use such as StandardFormBuilder.
      # @option settings [Symbol] :as
      #   Sets custom form object name.
      # @param [Proc] block
      #   The fields and content inside this form.
      #
      # @yield [AbstractFormBuilder] The form builder used to compose fields.
      #
      # @return [String] The html object-backed form with the specified options and input fields.
      #
      # @example
      #   form_for :user, '/register' do |f| ... end
      #   form_for @user, '/register', :id => 'register' do |f| ... end
      #   form_for @user, '/register', :as => :customer do |f| ... end
      #
      def form_for(object, url, options={}, &block)
        instance = builder_instance(object, options)
        html = capture_html(instance, &block)
        options = { :multipart => instance.multipart }.update(options.except(:namespace, :as))
        form_tag(url, options) { html }
      end

      ##
      # Constructs form fields for an object using given or default form_builder.
      # Used within an existing form to allow alternate objects within one form.
      #
      # @param [Object] object
      #   The object for which the fields are being built.
      # @param [Hash] options
      #   The settings associated with these fields. Accepts HTML options.
      # @param [Proc] block
      #   The content inside this set of fields.
      #
      # @return [String] The html fields with the specified options.
      #
      # @example
      #   fields_for @user.assignment do |assignment| ... end
      #   fields_for :assignment do |assigment| ... end
      #
      def fields_for(object, options={}, &block)
        instance = builder_instance(object, options)
        fields_html = capture_html(instance, &block)
        fields_html << instance.hidden_field(:id) if instance.send(:nested_object_id)
        concat_content fields_html
      end

      ##
      # Constructs a form without object based on options.
      #
      # @param [String] url
      #   The URL this form will submit to.
      # @param [Hash] options
      #   The html options associated with this form.
      # @param [Proc] block
      #   The fields and content inside this form.
      #
      # @return [String] The HTML form with the specified options and input fields.
      #
      # @example
      #   form_tag '/register', :class => "registration_form" do ... end
      #
      def form_tag(url, options={}, &block)
        options = {
          :action => url,
          :protect_from_csrf => is_protected_from_csrf?,
          'accept-charset' => 'UTF-8'
        }.update(options)
        options[:enctype] = 'multipart/form-data' if options.delete(:multipart)

        if (desired_method = options[:method]) =~ /get/i
          options.delete(:protect_from_csrf)
        else
          options[:method] = 'post'
        end
        inner_form_html = hidden_form_method_field(desired_method)
        inner_form_html << csrf_token_field if options[:protect_from_csrf]
        concat_content content_tag(:form, inner_form_html << capture_html(&block), options)
      end

      ##
      # Returns the hidden method field for 'put' and 'delete' forms.
      # Only 'get' and 'post' are allowed within browsers;
      # 'put' and 'delete' are just specified using hidden fields with form action still 'put'.
      #
      # @param [String] desired_method
      #   The method this hidden field represents (i.e put or delete).
      #
      # @return [String] The hidden field representing the +desired_method+ for the form.
      #
      # @example
      #   # Generate: <input name="_method" value="delete" />
      #   hidden_form_method_field('delete')
      #
      def hidden_form_method_field(desired_method)
        return ActiveSupport::SafeBuffer.new if desired_method.blank? || desired_method.to_s =~ /get|post/i
        hidden_field_tag(:_method, :value => desired_method)
      end

      ##
      # Constructs a field_set to group fields with given options.
      #
      # @overload field_set_tag(legend=nil, options={}, &block)
      #   @param [String] legend  The legend caption for the fieldset
      #   @param [Hash]   options The html options for the fieldset.
      #   @param [Proc]   block   The content inside the fieldset.
      # @overload field_set_tag(options={}, &block)
      #   @param [Hash]   options The html options for the fieldset.
      #   @param [Proc]   block   The content inside the fieldset.
      #
      # @return [String] The html for the fieldset tag based on given +options+.
      #
      # @example
      #   field_set_tag(:class => "office-set") { }
      #   field_set_tag("Office", :class => 'office-set') { }
      #
      def field_set_tag(*args, &block)
        options = args.extract_options!
        legend_text = args.first
        legend_html = legend_text.blank? ? ActiveSupport::SafeBuffer.new : content_tag(:legend, legend_text)
        concat_content content_tag(:fieldset, legend_html << capture_html(&block), options)
      end

      ##
      # Constructs list HTML for the errors for a given symbol.
      #
      # @overload error_messages_for(*objects, options = {})
      #   @param [Array<Object>]  object   Splat of objects to display errors for.
      #   @param [Hash]           options  Error message display options.
      #   @option options [String] :header_tag ("h2")
      #     Used for the header of the error div.
      #   @option options [String] :id ("field-errors")
      #     The id of the error div.
      #   @option options [String] :class ("field-errors")
      #     The class of the error div.
      #   @option options [Array<Object>]  :object
      #     The object (or array of objects) for which to display errors,
      #     if you need to escape the instance variable convention.
      #   @option options [String] :object_name
      #     The object name to use in the header, or any text that you prefer.
      #     If +:object_name+ is not set, the name of the first object will be used.
      #   @option options [String] :header_message ("X errors prohibited this object from being saved")
      #     The message in the header of the error div. Pass +nil+ or an empty string
      #     to avoid the header message altogether.
      #   @option options [String] :message ("There were problems with the following fields:")
      #     The explanation message after the header message and before
      #     the error list.  Pass +nil+ or an empty string to avoid the explanation message
      #     altogether.
      #
      # @return [String] The html section with all errors for the specified +objects+
      #
      # @example
      #   error_messages_for :user
      #
      def error_messages_for(*objects)
        options = objects.extract_options!.symbolize_keys
        objects = objects.map{ |obj| resolve_object(obj) }.compact
        count   = objects.inject(0){ |sum, object| sum + object.errors.count }
        return ActiveSupport::SafeBuffer.new if count.zero?

        object_name = options[:object_name] || objects.first.class.to_s.underscore.gsub(/\//, ' ')

        contents = ActiveSupport::SafeBuffer.new
        contents << error_header_tag(options, object_name, count)
        contents << error_body_tag(options)
        contents << error_list_tag(objects, object_name)
        content_tag(:div, contents, error_html_attributes(options))
      end

      ##
      # Returns a string containing the error message attached to the
      # +method+ on the +object+ if one exists.
      #
      # @param [Object] object
      #   The object to display the error for.
      # @param [Symbol] field
      #   The field on the +object+ to display the error for.
      # @param [Hash] options
      #   The options to control the error display.
      # @option options [String] :tag ("span")
      #   The tag that encloses the error.
      # @option options [String] :prepend ("")
      #   The text to prepend before the field error.
      # @option options [String] :append ("")
      #   The text to append after the field error.
      #
      # @example
      #   # => <span class="error">can't be blank</div>
      #   error_message_on :post, :title
      #   error_message_on @post, :title
      #
      #   # => <div class="custom" style="border:1px solid red">can't be blank</div>
      #   error_message_on :post, :title, :tag => :id, :class => :custom, :style => "border:1px solid red"
      #
      #   # => <div class="error">This title can't be blank (or it won't work)</div>
      #   error_message_on :post, :title, :prepend => "This title", :append => "(or it won't work)"
      #
      # @return [String] The html display of an error for a particular +object+ and +field+.
      #
      # @api public
      def error_message_on(object, field, options={})
        error = Array(resolve_object(object).errors[field]).first
        return ActiveSupport::SafeBuffer.new unless error
        options = { :tag => :span, :class => :error }.update(options)
        tag   = options.delete(:tag)
        error = [options.delete(:prepend), error, options.delete(:append)].compact.join(" ")
        content_tag(tag, error, options)
      end

      ##
      # Constructs a label tag from the given options.
      #
      # @param [String] name
      #   The name of the field to label.
      # @param [Hash] options
      #   The html options for this label.
      # @option options :caption
      #   The caption for this label.
      # @param [Proc] block
      #   The content to be inserted into the label.
      #
      # @return [String] The html for this label with the given +options+.
      #
      # @example
      #   label_tag :username, :class => 'long-label'
      #   label_tag :username, :class => 'long-label' do ... end
      #
      def label_tag(name, options={}, &block)
        options = { :caption => "#{name.to_s.humanize}: ", :for => name }.update(options)
        caption_text = ActiveSupport::SafeBuffer.new << options.delete(:caption)
        caption_text << "<span class='required'>*</span> ".html_safe if options.delete(:required)

        if block_given?
          concat_content content_tag(:label, caption_text << capture_html(&block), options)
        else
          content_tag(:label, caption_text, options)
        end
      end

      ##
      # Creates a text field input with the given name and options.
      #
      # @macro [new] text_field
      #   @param [Symbol] name
      #     The name of the input to create.
      #   @param [Hash] options
      #     The HTML options to include in this field.
      #
      #   @option options [String] :id
      #     Specifies a unique identifier for the field.
      #   @option options [String] :class
      #     Specifies the stylesheet class of the field.
      #   @option options [String] :name
      #     Specifies the name of the field.
      #   @option options [String] :accesskey
      #     Specifies a shortcut key to access the field.
      #   @option options [Integer] :tabindex
      #     Specifies the tab order of the field.
      #   @option options [Integer] :maxlength
      #     Specifies the maximum length, in characters, of the field.
      #   @option options [Integer] :size
      #     Specifies the width, in characters, of the field.
      #   @option options [String] :placeholder
      #     Specifies a short hint that describes the expected value of the field.
      #   @option options [Boolean] :hidden
      #     Specifies whether or not the field is hidden from view.
      #   @option options [Boolean] :spellcheck
      #     Specifies whether or not the field should have it's spelling and grammar checked for errors.
      #   @option options [Boolean] :draggable
      #     Specifies whether or not the field is draggable. (true, false, :auto).
      #   @option options [String] :pattern
      #     Specifies the regular expression pattern that the field's value is checked against.
      #   @option options [Symbol] :autocomplete
      #     Specifies whether or not the field should have autocomplete enabled. (:on, :off).
      #   @option options [Boolean] :autofocus
      #     Specifies whether or not the field should automatically get focus when the page loads.
      #   @option options [Boolean] :required
      #     Specifies whether or not the field is required to be completed before the form is submitted.
      #   @option options [Boolean] :readonly
      #     Specifies whether or not the field is read only.
      #   @option options [Boolean] :disabled
      #     Specifies whether or not the field is disabled.
      #
      #   @return [String]
      #     Generated HTML with specified +options+.
      #
      # @example
      #   text_field_tag :first_name, :maxlength => 40, :required => true
      #   # => <input name="first_name" maxlength="40" required type="text" />
      #
      #   text_field_tag :last_name, :class => 'string', :size => 40
      #   # => <input name="last_name" class="string" size="40" type="text" />
      #
      #   text_field_tag :username, :placeholder => 'Your Username'
      #   # => <input name="username" placeholder="Your Username" type="text" />
      #
      def text_field_tag(name, options={})
        input_tag(:text, { :name => name }.update(options))
      end

      ##
      # Creates a number field input with the given name and options.
      #
      # @macro [new] number_field
      #   @param [Symbol] name
      #     The name of the input to create.
      #   @param [Hash] options
      #     The HTML options to include in this field.
      #
      #   @option options [String] :id
      #     Specifies a unique identifier for the field.
      #   @option options [String] :class
      #     Specifies the stylesheet class of the field.
      #   @option options [String] :name
      #     Specifies the name of the field.
      #   @option options [String] :accesskey
      #     Specifies a shortcut key to access the field.
      #   @option options [Integer] :tabindex
      #     Specifies the tab order of the field.
      #   @option options [Integer] :min
      #     Specifies the minimum value of the field.
      #   @option options [Integer] :max
      #     Specifies the maximum value of the field.
      #   @option options [Integer] :step
      #     Specifies the legal number intervals of the field.
      #   @option options [Boolean] :hidden
      #     Specifies whether or not the field is hidden from view.
      #   @option options [Boolean] :spellcheck
      #     Specifies whether or not the field should have it's spelling and grammar checked for errors.
      #   @option options [Boolean] :draggable
      #     Specifies whether or not the field is draggable. (true, false, :auto).
      #   @option options [String] :pattern
      #     Specifies the regular expression pattern that the field's value is checked against.
      #   @option options [Symbol] :autocomplete
      #     Specifies whether or not the field should have autocomplete enabled. (:on, :off).
      #   @option options [Boolean] :autofocus
      #     Specifies whether or not the field should automatically get focus when the page loads.
      #   @option options [Boolean] :required
      #     Specifies whether or not the field is required to be completeled before the form is submitted.
      #   @option options [Boolean] :readonly
      #     Specifies whether or not the field is read only.
      #   @option options [Boolean] :disabled
      #     Specifies whether or not the field is disabled.
      #
      #   @return [String]
      #     Generated HTML with specified +options+.
      #
      # @example
      #   number_field_tag :quantity, :class => 'numeric'
      #   # => <input name="quantity" class="numeric" type="number" />
      #
      #   number_field_tag :zip_code, :pattern => /[0-9]{5}/
      #   # => <input name="zip_code" pattern="[0-9]{5}" type="number" />
      #
      #   number_field_tag :credit_card, :autocomplete => :off
      #   # => <input name="credit_card" autocomplete="off" type="number" />
      #
      #   number_field_tag :age, :min => 18, :max => 120, :step => 1
      #   # => <input name="age" min="18" max="120" step="1" type="number" />
      #
      def number_field_tag(name, options={})
        input_tag(:number, { :name => name }.update(options))
      end

      ##
      # Creates a telephone field input with the given name and options.
      #
      # @macro text_field
      #
      # @example
      #   telephone_field_tag :phone_number, :class => 'string'
      #   # => <input name="phone_number" class="string" type="tel" />
      #
      #  telephone_field_tag :cell_phone, :tabindex => 1
      #  telephone_field_tag :work_phone, :tabindex => 2
      #  telephone_field_tag :home_phone, :tabindex => 3
      #
      #  # => <input name="cell_phone" tabindex="1" type="tel" />
      #  # => <input name="work_phone" tabindex="2" type="tel" />
      #  # => <input name="home_phone" tabindex="3" type="tel" />
      #
      def telephone_field_tag(name, options={})
        input_tag(:tel, { :name => name }.update(options))
      end
      alias_method :phone_field_tag, :telephone_field_tag

      ##
      # Creates an email field input with the given name and options.
      #
      # @macro text_field
      #
      # @example
      #   email_field_tag :email, :placeholder => 'you@example.com'
      #   # => <input name="email" placeholder="you@example.com" type="email" />
      #
      #   email_field_tag :email, :value => 'padrinorb@gmail.com', :readonly => true
      #   # => <input name="email" value="padrinorb@gmail.com" readonly type="email" />
      #
      def email_field_tag(name, options={})
        input_tag(:email, { :name => name }.update(options))
      end

      ##
      # Creates a search field input with the given name and options.
      #
      # @macro text_field
      #
      # @example
      #  search_field_tag :search, :placeholder => 'Search this website...'
      #  # => <input name="search" placeholder="Search this website..." type="search" />
      #
      #  search_field_tag :search, :maxlength => 15, :class => ['search', 'string']
      #  # => <input name="search" maxlength="15" class="search string" />
      #
      #  search_field_tag :search, :id => 'search'
      #  # => <input name="search" id="search" type="search" />
      #
      #  search_field_tag :search, :autofocus => true
      #  # => <input name="search" autofocus type="search" />
      #
      def search_field_tag(name, options={})
        input_tag(:search, { :name => name }.update(options))
      end

      ##
      # Creates a URL field input with the given name and options.
      #
      # @macro text_field
      #
      # @example
      #  url_field_tag :favorite_website, :placeholder => 'http://padrinorb.com'
      #  <input name="favorite_website" placeholder="http://padrinorb.com." type="url" />
      #
      #  url_field_tag :home_page, :class => 'string url'
      #  <input name="home_page" class="string url", type="url" />
      #
      def url_field_tag(name, options={})
        input_tag(:url, { :name => name }.update(options))
      end

      ##
      # Constructs a hidden field input from the given options.
      #
      # @example
      #   hidden_field_tag :session_key, :value => "__secret__"
      #
      def hidden_field_tag(name, options={})
        input_tag(:hidden, { :name => name }.update(options))
      end

      ##
      # Constructs a text area input from the given options.
      #
      # @example
      #   text_area_tag :username, :class => 'long', :value => "Demo?"
      #
      def text_area_tag(name, options={})
        inner_html = options.delete(:value).to_s
        options = { :name => name, :rows => "", :cols => "" }.update(options)
        content_tag(:textarea, inner_html, options)
      end

      ##
      # Constructs a password field input from the given options.
      #
      # @example
      #   password_field_tag :password, :class => 'long'
      #
      # @api public
      def password_field_tag(name, options={})
        input_tag(:password, { :name => name }.update(options))
      end

      ##
      # Constructs a check_box from the given options.
      #
      # @example
      #   check_box_tag :remember_me, :value => 'Yes'
      #
      def check_box_tag(name, options={})
        input_tag(:checkbox, { :name => name, :value => '1' }.update(options))
      end

      ##
      # Constructs a radio_button from the given options.
      #
      # @example
      #   radio_button_tag :remember_me, :value => 'true'
      #
      def radio_button_tag(name, options={})
        input_tag(:radio, { :name => name }.update(options))
      end

      ##
      # Constructs a file field input from the given options.
      #
      # @example
      #   file_field_tag :photo, :class => 'long'
      #
      # @api public
      def file_field_tag(name, options={})
        name = "#{name}[]" if options[:multiple]
        input_tag(:file, { :name => name }.update(options))
      end

      ##
      # Constructs a select from the given options.
      #
      # @example
      #   options = [['caption', 'value'], ['Green', 'green1'], ['Blue', 'blue1'], ['Black', "black1"]]
      #   options = ['option', 'red', 'yellow' ]
      #   select_tag(:favorite_color, :options => ['red', 'yellow'], :selected => 'green1')
      #   select_tag(:country, :collection => @countries, :fields => [:name, :code], :include_blank => 'None')
      #
      #   # Optgroups can be generated using :grouped_options => (Hash or nested Array)
      #   grouped_options = [['Friends',['Yoda',['Obiwan',1]]],['Enemies',['Palpatine',['Darth Vader',3]]]]
      #   grouped_options = {'Friends' => ['Yoda',['Obiwan',1]],'Enemies' => ['Palpatine',['Darth Vader',3]]}
      #   select_tag(:color, :grouped_options => [['warm',['red','yellow']],['cool',['blue', 'purple']]])
      #
      #   # Optgroups can be generated using :grouped_options => (Hash or nested Array)
      #   grouped_options = [['Friends',['Yoda',['Obiwan',1]]],['Enemies',['Palpatine',['Darth Vader',3]]]]
      #   grouped_options = {'Friends' => ['Yoda',['Obiwan',1]],'Enemies' => ['Palpatine',['Darth Vader',3]]}
      #   select_tag(:color, :grouped_options => [['warm',['red','yellow']],['cool',['blue', 'purple']]])
      #
      # @param [String] name
      #   The name of the input field.
      # @param [Hash] options
      #   The html options for the input field.
      # @option options [Array<String, Array>] :options
      #  Explicit options to display in the select. Can be strings or string tuples.
      # @option options [Array<Array>] :grouped_options
      #   List of options for each group in the select. See examples for details.
      # @option options [Array<Object>] :collection
      #   Collection of objects used as options in the select.
      # @option options [Array<Symbol>] :fields
      #   The attributes used as "label" and "value" for each +collection+ object.
      # @option options [String] :selected (nil)
      #   The option value initially selected.
      # @option options [Boolean] :include_blank (false)
      #   Include a blank option in the select.
      # @option options [Boolean] :multiple (false)
      #   Allow multiple options to be selected at once.
      #
      # @return [String] The HTML input field based on the +options+ specified.
      #
      def select_tag(name, options={})
        options = { :name => name }.merge(options)
        options[:name] = "#{options[:name]}[]" if options[:multiple]
        content_tag(:select, extract_option_tags!(options), options)
      end

      ##
      # Constructs a button input from the given options.
      #
      # @param [String] caption
      #   The caption for the button.
      # @param [Hash] options
      #   The html options for the input field.
      #
      # @return [String] The html button based on the +options+ specified.
      #
      # @example
      #   button_tag "Cancel", :class => 'clear'
      #
      def button_tag(caption, options = {})
        input_tag(:button, { :value => caption }.update(options))
      end

      ##
      # Constructs a submit button from the given options.
      #
      # @param [String] caption (defaults to: +Submit+)
      #   The caption for the submit button.
      # @param [Hash] options
      #   The html options for the input field.
      #
      # @return [String] The html submit button based on the +options+ specified.
      #
      # @example
      #   submit_tag "Create", :class => 'success'
      #   submit_tag :class => 'btn'
      #
      def submit_tag(*args)
        options = args.extract_options!
        caption = args.length >= 1 ? args.first : "Submit"
        input_tag(:submit, { :value => caption }.merge(options))
      end

      ##
      # Constructs a submit button from the given options.
      #
      # @param [String] source
      #   The source image path for the button.
      # @param [Hash] options
      #   The html options for the input field.
      #
      # @return [String] The html image button based on the +options+ specified.
      #
      # @example
      #   image_submit_tag 'form/submit.png'
      #
      def image_submit_tag(source, options={})
        input_tag(:image, { :src => image_path(source) }.update(options))
      end

      ##
      # Constructs a hidden field containing a CSRF token.
      #
      # @param [String] token
      #   The token to use. Will be read from the session by default.
      #
      # @return [String] The hidden field with CSRF token as value.
      #
      # @example
      #   csrf_token_field
      #
      def csrf_token_field
        hidden_field_tag csrf_param, :value => csrf_token
      end

      ##
      # Constructs meta tags `csrf-param` and `csrf-token` with the name of the
      # cross-site request forgery protection parameter and token, respectively.
      #
      # @return [String] The meta tags with the CSRF token and the param your app expects it in.
      #
      # @example
      #   csrf_meta_tags
      #
      def csrf_meta_tags
        if is_protected_from_csrf?
          meta_tag(csrf_param, :name => 'csrf-param') <<
          meta_tag(csrf_token, :name => 'csrf-token')
        end
      end

      ##
      # Creates a form containing a single button that submits to the URL.
      #
      # @overload button_to(name, url, options={})
      #   @param [String]  caption  The text caption.
      #   @param [String]  url      The url href.
      #   @param [Hash]    options  The html options.
      # @overload button_to(name, options={}, &block)
      #   @param [String]  url      The url href.
      #   @param [Hash]    options  The html options.
      #   @param [Proc]    block    The button content.
      #
      # @option options [Boolean] :multipart
      #   If true, this form will support multipart encoding.
      # @option options [String] :remote
      #   Instructs ujs handler to handle the submit as ajax.
      # @option options [Symbol] :method
      #   Instructs ujs handler to use different http method (i.e :post, :delete).
      # @option options [Hash] :submit_options
      #   Hash of any options, that you want to pass to submit_tag (i.e :id, :class)
      #
      # @return [String] Form and button html with specified +options+.
      #
      # @example
      #   button_to 'Delete', url(:accounts_destroy, :id => account), :method => :delete, :class => :form
      #   # Generates:
      #   # <form class="form" action="/admin/accounts/destroy/2" method="post">
      #   #   <input type="hidden" value="delete" name="_method" />
      #   #   <input type="submit" value="Delete" />
      #   # </form>
      #
      def button_to(*args, &block)
        options   = args.extract_options!.dup
        name, url = *args
        options['data-remote'] = 'true' if options.delete(:remote)
        block ||= proc { submit_tag(name, options.delete(:submit_options) || {}) }
        form_tag(url || name, options, &block)
      end

      ##
      # Constructs a range tag from the given options.
      #
      # @example
      #   range_field_tag('ranger_with_min_max', :min => 1, :max => 50)
      #   range_field_tag('ranger_with_range', :range => 1..5)
      #
      # @param [String] name
      #   The name of the range field.
      # @param [Hash] options
      #   The html options for the range field.
      # @option options [Integer] :min
      #  The min range of the range field.
      # @option options [Integer] :max
      #  The max range of the range field.
      # @option options [range] :range
      #  The range, in lieu of :min and :max.  See examples for details.
      # @return [String] The html range field
      #
      def range_field_tag(name, options = {})
        options = { :name => name }.update(options)
        if range = options.delete(:range)
          options[:min], options[:max] = range.min, range.max
        end
        input_tag(:range, options)
      end

      protected

      ##
      # Returns whether the application is being protected from CSRF. Defaults to true.
      #
      def is_protected_from_csrf?
        defined?(settings) ? settings.protect_from_csrf : true
      end

      ##
      # Returns the current CSRF token (based on the session). If it doesn't exist,
      # it will create one and assign it to the session's `csrf` key.
      #
      def csrf_token
        session[:csrf] ||= SecureRandom.hex(32) if defined?(session)
      end

      ##
      # Returns the param/field name in which your CSRF token should be expected by your
      # controllers. Defaults to `authenticity_token`.
      #
      # Set this in your application with `set :csrf_param, :something_else`.
      #
      def csrf_param
        defined?(settings) && settings.respond_to?(:csrf_param) ?
          settings.csrf_param : :authenticity_token
      end

      private

      ##
      # Returns an initialized builder instance for the given object and settings.
      #
      # @example
      #   builder_instance(@account, :nested => { ... }) => <FormBuilder>
      #
      def builder_instance(object, settings={})
        default_builder = self.respond_to?(:settings) && self.settings.default_builder || 'StandardFormBuilder'
        builder_class = settings.delete(:builder) || default_builder
        builder_class = "Padrino::Helpers::FormBuilder::#{builder_class}".constantize if builder_class.is_a?(String)
        builder_class.new(self, object, settings)
      end

      def error_list_tag(objects, object_name)
        errors = objects.inject({}){ |all,object| all.update(object.errors) }
        error_messages = errors.inject(ActiveSupport::SafeBuffer.new) do |all, (field, message)|
          field_name = I18n.t(field, :default => field.to_s.humanize, :scope => [:models, object_name, :attributes])
          all << content_tag(:li, "#{field_name} #{message}")
        end
        content_tag(:ul, error_messages)
      end

      def error_header_tag(options, object_name, count)
        header_message = options[:header_message] || begin
          model_name = I18n.t(:name, :default => object_name.humanize, :scope => [:models, object_name], :count => 1)
          I18n.t :header, :count => count, :model => model_name, :locale => options[:locale], :scope => [:models, :errors, :template]
        end
        content_tag(options[:header_tag] || :h2, header_message) if header_message.present?
      end

      def error_body_tag(options)
        body_message = options[:message] || I18n.t(:body, :locale => options[:locale], :scope => [:models, :errors, :template])
        content_tag(:p, body_message) if body_message.present?
      end

      def error_html_attributes(options)
        [:id, :class, :style].each_with_object({}) do |key,all|
          if options.include?(key)
            value = options[key]
            all[key] = value unless value.blank?
          else
            all[key] = 'field-errors' unless key == :style
          end
        end
      end

      def resolve_object(object)
        object.is_a?(Symbol) ? instance_variable_get("@#{object}") : object
      end
    end
  end
end

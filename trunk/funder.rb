require 'fields'
require 'actions'

class Array
	def append_or_replace(val, &block)
		self.length.times do |i|
			if block.call(self[i])
				self[i] = val
				return
			end
		end
		self.insert(-1, val)
	end
end

class PreField
	attr_accessor :name, :klass, :value, :options, :parent_class
	def initialize(name, klass, value=nil, options={}, parent_class=nil)
		@name = name
		@klass = klass
		@options = options
		@value = value
		@parent_class = parent_class
	end
	def clone
		result_name = @name
		result_klass = @klass
		result_value = @value.clone rescue @value
		result_options = @options.clone
		result = PreField.new(result_name, result_klass, result_value, result_options, @parent_class)
		result
	end
	def create
		@value = @value.create if @value.respond_to?(:create)
		if @options[:mult]
			MultField.new(@klass, @name, @value, @options)
		else
			@klass.new(@name, @value, @options)
		end
	end
end

class PreAction
	def initialize(klass, *args)
		@klass = klass
		@args = args
	end
	def create
		new_args = []
		@args.each do |arg|
			if arg.respond_to?(:create)
				new_args << arg.create
			else
				new_args << arg
			end
		end
		@klass.new(*new_args)
	end
end

class Funder < Str
	class << self
		attr_accessor :order
		def field(name, klass, value=nil, options={})
			@order ||= []
			pf = PreField.new(name, klass, value, options, self)
			@order.append_or_replace(pf) {|field| field.name == name}
		end
		def unfield(name, klass, val=nil, options={})
			@unfields ||= []
			pf = PreField.new(name, klass, val, options, self)
			@unfields.append_or_replace(pf) {|field| field.name == name}
		end
		def section(name, action=nil, options={}, &block)
			options[:action] = action
			@order ||= []
			new_class = name.to_s
			new_class[0,1] = new_class[0,1].upcase
			class_eval "class #{new_class} < Section ; end"
			klass = class_eval new_class
			klass.class_eval &block
			field(name, klass, nil, options)
		end
		def action(klass, *args)
			PreAction.new(klass, *args)
		end
		def inherited(klass)
			@order ||= []
			@unfields ||= []
			klass.class_eval{class << self ; attr_accessor :order, :unfields ; end}
			klass.unfields = []
			klass.order = []
			@order.each {|f| klass.order << f.clone ; klass.order.last.parent_class = klass }
			@unfields.each {|uf| klass.unfields << uf.clone ; klass.unfields.last.parent_class = klass }
		end
	end
	attr_accessor :order, :unfields
	def initialize(*args)
		super(*args) if args.length == 3
		@order = []
		@unfields = []
		self.class.order.each {|f| create_field(f.clone, @order) }
		self.class.unfields.each {|uf| create_field(uf.clone, @unfields)}
	end
	def create_field(pre_field, dest)
		self.class.class_eval { attr_accessor pre_field.name }
		field = pre_field.create
		field.parent = self
		dest << field
		instance_variable_set("@#{pre_field.name}", field)
	end
	def gen_val(*args)
		return @value if @value
		res = ""
		@order.map {|f|	res << f.to_out }
		res
	end
	def reset
		super
		@order.each {|f| f.reset }
	end
end

class Section < Funder
	def initialize(name, value, options)
		super(name, value, options)
		@action = options[:action]
		@action = @action.create if @action && @action.respond_to?(:create)
		@action.parent = @parent if @action
	end
	def parent=(val)
		@parent = val
		@action.parent = @parent if @action
	end
	def gen_val(*args)
		out = super
		out = @action.do_it_once(out) if @action
		out
	end
end

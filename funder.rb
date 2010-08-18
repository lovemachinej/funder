#  Copyright (c) 2010, Nephi Johnson
#  All rights reserved.
#  
#  Redistribution and use in source and binary forms, with or without modification, are permitted
#  provided that the following conditions are met:
#  
#      * Redistributions of source code must retain the above copyright notice, this list of
#        conditions and the following disclaimer.
#      * Redistributions in binary form must reproduce the above copyright notice, this list of
#        conditions and the following disclaimer in the documentation and/or other materials
#        provided with the distribution.
#      * Neither the name of the <ORGANIZATION> nor the names of its contributors may be used to
#        endorse or promote products derived from this software without specific prior written
#        permission.
#  
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
#  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
#  AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
#  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
#  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#  POSSIBILITY OF SUCH DAMAGE.

require 'fields'
require 'actions'
require 'syntactic_sugar'

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
		include SyntacticSugar

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
		nil
	end
	def inspect(level=0)
		if level == 0
			res = "#<#{self.class.to_s} "
			fields_str = @order.map do |field|
				"#{field.name}=#{field.inspect(level+1)}"
			end.join(" ")
			res += fields_str + ">"
			return res
		elsif level == 1
			return "#<#{self.class.to_s}>"
		elsif level == 2
			return self.class.to_s
		else
			return ""
		end
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

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
#      * Neither the name of Funder nor the names of its contributors may be used to
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

require 'funder'
require 'values'
require 'actions'
require 'events'

class Field
	include EventDispatcher
	attr_accessor :name, :value, :parent, :options, :cache, :action, :root, :binding, :owner
	def initialize(name, value, options={})
		@name = name
		@value = value
		@value.owner = self if @value.respond_to?(:owner=)
		@options = options || {}
		@parent = nil
		@inited = false
		@binding = nil
		@owner = nil
		pull_options()
	end
	# subclasses should override this and implement their own init code
	# (don't forget to call super() though)
	def init
		set_val_parent
		@inited = true
		@order.each {|f| f.init } if @order
	end
	# inheriting classes need to implement this as well (and call super)
	def pull_options
		if (p = (@options[:parent]))
			@parent = p
		end
		if (act = (@options[:action] || @options[:a]))
			@action = act.create
		end
		if (binding = (@options[:b] || @options[:bind]))
			@binding = binding
		end
	end
	def set_val_parent
		@value.parent = @parent if @value.respond_to?(:parent=)
		@binding.parent = @parent if @binding
	end
	def parent=(val)
		@parent = val
		set_val_parent
	end
	# walk up the tree to the root, resetting along the way
	def tree_shoot_reset
		reset
		tmp = @parent
		return unless tmp
		while true
			tmp.reset
			break unless tmp.parent
			tmp = tmp.parent
		end
	end
	def value=(new_val)
		tree_shoot_reset
		@value = new_val
	end
	def value
		if @value.kind_of? Proc
			@parent.instance_eval &@value
		else
			@value
		end
	end
	def root
		@root ||= begin
			tmp = @parent
			while true
				break if tmp.parent == nil
				tmp = tmp.parent
			end
			tmp
		end
		@root
	end
	def length_up_to(field)
		res = 0
		@order.each do |child|
			break if child == field
			if child.has_child(field)
				res += child.length_up_to(field)
				break
			else
				res += child.result_length
			end
		end
		res
	end
	def has_child(child)
		return true if child == self
		return false unless @order
		@order.each do |field|
			return true if field.has_child(child)
		end
		return false
	end
	def offset
		base = root
		base.length_up_to(self)
	end
	def to_out
		return @cache.clone if @cache
		res = @value
		while ([Proc, Action, Value] & res.class.ancestors).length > 0
			if res.kind_of? Proc
				res = @parent.instance_eval &res
			elsif res.kind_of? Action
				res = res.do_it
			elsif res.kind_of? Value
				res = res.resolve
			end
		end
		res = gen_val(res)
		if @action
			res = @action.do_it_once(res)
		end
		@cache = res
		return @cache.clone
	end
	def gen_val(v)
		v
	end
	def result_length
		raise "Inheriting classes should define this method (result_length), current class: #{self.class.to_s}"
	end
	def reset
		@cache = nil
	end
	def full_name
		names = []
		names << @name
		curr_parent = @parent
		while true
			break unless curr_parent && curr_parent.parent
			names << curr_parent.name
			curr_parent = curr_parent.parent
		end
		names.reverse.join(".")
	end
	def <=>(other)
		return full_name <=> other.full_name if other.respond_to?(:full_name)
		full_name <=> other.to_s
	end
	def detail_inspect(level=0)
		return ""
	end
	def inspect_value(level=0)
		return @value.inspect(level+1)
	end
	def inspect(level=0)
		if level == 0
			res = "#<#{self.class.to_s} name=#{@name.to_s.inspect} value=#{inspect_value}"
			if @cache
				res << " cache=#{(@cache.length > 20 ? @cache.slice(0, 17) + "..." : @cache).inspect}"
			else
				res << " cache=nil"
			end
			if @action
				res << " action=#{@action.desc}"
			end
			res << "#{detail_inspect()}>"
		elsif level == 1 || level == 2
			if @action
				"#{@action.desc}(#{inspect_value(level)})"
			else
				inspect_value(level)
			end
		else
			return ""
		end
	end
end

class Str < Field
	attr_accessor :charset, :min, :max
	def pull_options
		super()
		@min = @options[:min] || rand(10)
		@max = @options[:max] || rand(10)
		@min,@max = @max,@min if @min > @max
		@max = @min + 1 if @min == @max
		@charset = @options[:charset] || "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	end
	def gen_rand
		(rand(@max - @min)+@min).times.map{@charset[rand(@charset.length),1]}.join
	end
	def gen_val(v)
		val = v || gen_rand
		val.to_s
	end
	def result_length
		self.to_out.length
	end
	def detail_inspect(level=0)
		charset_out = (@charset.length > 20 ? @charset.slice(0, 17) + "..." : @charset).inspect
		return " charset=#{charset_out} min=#{@min} max=#{@max}"
	end
	def inspect_value(level=0)
		out = ""
		if @value.kind_of? String
			out = gen_val(@value)
			out = (out.length > 20 ? out.slice(0, 17) + "..." : out).inspect
		elsif @value.kind_of? Action
			out = @value.inspect(level + 1)
		elsif @value.kind_of? Proc
			out = "lambda{..}"
		else
			out = @value
		end
		out
	end
end

class MultiField < Str
	include Enumerable

	attr_accessor :order

	def initialize(klass, name, value, options)
		@order = []
		@klass = klass
		create_listener(:length_changed)
		super(name, value, options)
	end
	def init(pick_one=false)
		@inited = true
		num_fields = @length || rand(@mult_max - @mult_min) + @mult_min
		if @binding && !pick_one && !@length
			bound_to = @binding.resolve
			if bound_to.kind_of? MultiField
				num_fields = bound_to.length
			end
		end
		create_fields(num_fields)
		super()
	end
	def pull_options
		super()
		@length = @options[:l] || @options[:length]
		@mult_min = @options[:mult_min] || 1
		@mult_max = @options[:mult_max] || rand(10) + 2
		@mult_min,@mult_max = @mult_max,@mult_min if @mult_min > @mult_max
	end
	def create_fields(num)
		@order = []
		num.times do |i|
			new_field = @klass.new("#{name}[#{i}]".to_sym, value, {:parent=>self}.merge(@options))
			new_field.owner = self
			new_field.parent = @parent
			@order << new_field
		end
		@binding.bind_fields(@order) if @binding
	end
	# in this case, we don't want the default inspect function
	def inspect(level=0)
		if level==0 || level == 1
			return "#<#{@klass.to_s}[#{length}]>"
		elsif level==2
			return "#{@klass.to_s}[#{length}]"
		else
			return ""
		end
	end
	def [](int)
		@order[int]
	end
	def length=(num)
		tree_shoot_reset
		create_fields(num) unless @order.length == num
		dispatch_event(:length_changed)
	end
	# if someone is trying to get the length and we haven't been inited yet, it's
	# because we're stuck in a loop with both sides trying to get the length of
	# eachother, so we'll init() now if not done already
	def length
		init(true) unless @inited
		@order.length
	end
	def result_length
		res = 0
		@order.each do |field|
			res += field.result_length
		end
		res
	end
	def set_val_parent
		@order.each {|f| f.parent = @parent}
		@binding.parent = @parent if @binding
	end
	def gen_val(v)
		@order.map{|f| f.to_out}.join
	end
	def each
		@order.each{|i| yield(i) }
	end
	def reset
		super
		@order.each{|f| f.reset}
	end
end

class Int < Field
	attr_accessor :pack
	def gen_val(v)
		val = v || rand(@max - @min) + @min
		[val].pack(@pack)
	end
	def result_length
		res = 0
		if %w{D d E G Q q}.include? @pack
			res = 8 # 64 bit
		elsif %w{w}.include? @pack
			res = 5 # 40 bit
		elsif %w{e F f g I i L l N V}.include? @pack
			res = 4 # 32 bit
		elsif %w{n S s v}.include? @pack
			res = 2 # 16 bit
		elsif %w{C c}.include? @pack
			res = 1 # 8 bit
		end
		res
	end
	def pull_options
		super()
		@min = @options[:min] || 0
		@max = @options[:max] || 0xffff
		@pack ||= @options[:p] || "N"
	end
	def detail_inspect(level=0)
		return " pack=#{@pack.inspect}"
	end
	def inspect_value(level=0)
		out = ""
		if @value.kind_of? Numeric
			out = @value.to_s
			out = (out.length > 10 ? out.slice(0, 7) + "..." : out)
		elsif @value.kind_of? Action
			out = @value.inspect(level + 1)
		elsif @value.kind_of? Proc
			out = "lambda{..}"
		else
			out = @value.inspect
		end
		out
	end
end


class Bool < Field
end

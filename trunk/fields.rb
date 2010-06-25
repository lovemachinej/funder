require 'funder'
require 'actions'

class Field
	attr_accessor :name, :value, :parent, :options
	def initialize(name, value, options)
		@name = name
		@value = value
		@options = options
		@parent = nil
		set_val_parent
	end
	def set_val_parent
		@value.parent = @parent if @value.respond_to?(:parent=)
	end
	def parent=(val)
		@parent = val
		set_val_parent
	end
	def value
		if @value.kind_of? Proc
			@parent.instance_eval &@value
		else
			@value
		end
	end
	def to_out
		return @cache if @cache
		res = ""
		if @value.kind_of? Proc
			res = @parent.instance_eval &@value
		elsif @value.kind_of? Action
			res = @value.do_it
		else
			res = @value
		end
		@cache ||= gen_val(res)
	end
	def gen_val(v)
		v
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
end

class Str < Field
	def gen_rand
		min = @options[:min] || rand(10)
		max = @options[:max] || rand(10)
		charset = @options[:charset] || "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
		min,max = max,min if min > max
		max = min + 1 if min == max
		(rand(max - min)+min).times.map{charset[rand(charset.length),1]}.join
	end
	def gen_val(v)
		val = v || gen_rand
		val.to_s
	end
end


class MultField < Str
	include Enumerable

	attr_accessor :order

	def initialize(klass, name, value, options)
		@order = []
		@klass = klass
		super(name, value, options)

		min = @options[:mult_min] || 1
		max = @options[:mult_max] || rand(10) + 1
		min,max = max,min if min > max
		create_fields(rand(max-min+1) + min)
	end
	def create_fields(num)
		@order = []
		num.times do |i|
			@order << @klass.new("#{name}[#{i}]".to_sym, value, options)
		end
	end
	def [](int)
		@order[int]
	end
	def length=(num)
		create_fields(num) unless @order.length == num
	end
	def length
		@order.length
	end
	def set_val_parent
		@order.each {|f| f.parent = @parent}
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
	def gen_val(v)
		pack = @options[:p] || "N"
		min = @options[:min] || 0
		max = @options[:max] || (1<<32)-1
		val = v || rand(max - min) + min
		[val].pack(pack)
	end
end


class Bool < Field
end

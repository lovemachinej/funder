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

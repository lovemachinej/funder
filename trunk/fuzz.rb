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

class Funder < Str
	class << self
		alias :original_field :field
		def field(name, klass, value=nil, options={})
			original_field(name, klass, value, options)
			make_class_accessor(name, @order.find{|f| f.name == name})
		end
		alias :original_section :section
		def section(name, action=nil, options={}, &block)
			original_section(name, action, options, &block)
			make_class_accessor(name, @order.find{|f| f.name == name})
		end
		alias :original_unfield :unfield
		def unfield(name, klass, val=nil, options={})
			original_unfield(name, klass, val, options)
			make_class_accessor(name, @unfields.find{|f| f.name == name})
		end
		def make_class_accessor(name, val)
			self.class_eval <<-RUBY
				class << self ; attr_accessor :#{name} ; end
			RUBY
			instance_variable_set("@#{name}", val)
		end

		attr_accessor :descendants
		alias :original_inherited :inherited
		def inherited(klass)
			original_inherited(klass)
			@descendants ||= []
			@descendants << klass

			@order.each do |f|
				klass.make_class_accessor(f.name, klass.order.find{|kf| kf.name == f.name})
			end
			@unfields.each do |uf|
				klass.make_class_accessor(uf.name, klass.unfields.find{|kuf| kuf.name == uf.name})
			end
		end
	end
end

class PreField
	def setfuzzopt(opts={})
		@fuzz_options = opts
		recurse_descendants_set(opts) if @parent_class.descendants
	end
	def recurse_descendants_set(opts={})
		@parent_class.descendants.each do |desc|
			desc_field = desc.instance_eval("@#{@name}")
			desc_field.setfuzzopt(opts)
		end
	end
	alias :original_create :create
	def create
		res = original_create
		res.fuzz_options = (@fuzz_options || {}).clone
		res
	end
	alias :original_clone :clone
	def clone
		res = original_clone
		res.send(:instance_variable_set, "@fuzz_options", (@fuzz_options || {}).clone)
		res
	end
end

class Field
	attr_accessor :fuzz_options
end

class Str < Field
	def get_fuzz_vals
		@fuzz_options ||= {}
		return @fuzz_options[:values] if @fuzz_options[:values]
		max_length = @fuzz_options[:max_length] || ((1<<15) + 60)
		#res = [16.times.map{|i| 3.times.map{|j|"A"*((2**i)+(20*j))}}, ""].flatten
		res = [17.times.map{|i| "A"*(2**i)}, ""].flatten
		res.reject!{|v| v.length > max_length}
		res.concat(@fuzz_options[:concat_values]) if @fuzz_options[:concat_values]
		res.uniq
	end
end

class Bool < Field
	def get_fuzz_vals
		[true, false]
	end
end

class Int < Field
	def get_fuzz_vals
		return @fuzz_options[:values] if @fuzz_options && @fuzz_options[:values]
		mask = 0xffff
		pack = @options[:p] || "N"
		if %w{D d E G Q q}.include? pack
			mask = (1<<64)-1 # 64 bit
		elsif %w{w}.include? pack
			mask = (1<<40)-1 # 40 bit
		elsif %w{e F f g I i L l N V}.include? pack
			mask = (1<<32)-1 # 32 bit
		elsif %w{n S s v}.include? pack
			mask = (1<<16)-1 # 16 bit
		elsif %w{C c}.include? pack
			mask = (1<<8)-1 # 8 bit
		else
			mask = (1<<16)-1
		end
		res = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17]
		curr_num = 1
		while curr_num <= mask
			res << curr_num
			3.times do |i|
				tmp = curr_num + (20 * (i+1))
				tmp_2 = curr_num - (20 * (i+1))
				res << tmp_2
				res << tmp if tmp <= mask
			end
			curr_num <<= 1
		end
		res.concat(@fuzz_options[:concat_values]) if @fuzz_options[:concat_values]
		res.uniq
	end
end

#      FIELD OPTIONS
#:fuzz_me=>(true|false)
#:values=>[..]
class Fuzz
	attr_accessor :start_num
	def initialize(field)
		@field = field
		@field.fuzz_options ||= {}
		@field.fuzz_options[:fuzz_me] = true
		@start_num = 0
	end
	def fuzz(min, max)
		raise "A block is needed for fuzzing" if not block_given?
		fuzz_fields = get_fuzzable_fields(@field)
		fuzzed = {}
		saved_vals = save_values(fuzz_fields)
		counter = @start_num
		((max - min)+1).times do |i|
			fuzz_fields.combination(i + min) do |fields|
				fuzzing_str = fields.each.map{|f| f.full_name}.sort.join("--")
				next if fuzzed[fuzzing_str]
				puts "# #{counter.to_s.rjust(10)} - #{fuzzing_str}"
				fuzzed[fuzzing_str] = true
				vals = []
				fields.each do |f|
					vals << f.get_fuzz_vals
				end
				m = Mapper.new(*vals)
				m.permutation do |*vals|
					vals.each_with_index do |v, i|
						fields[i].value = v
					end
					yield(@field)
					counter += 1
					restore_values(fuzz_fields, saved_vals)
					@field.reset
				end
			end
		end
		puts "total: #{counter}"
	end
	def save_values(fields)
		res = {}
		fields.each do |f|
			res[f.full_name] = f.send(:instance_variable_get, "@value")
		end
		res
	end
	def restore_values(fields, saved_values)
		fields.each do |f|
			f.send(:instance_variable_set, "@value", saved_values[f.full_name])
		end
	end
	def get_fuzzable_fields(field)
		if !field.respond_to?(:order)
			return [field] unless field.fuzz_options && field.fuzz_options[:fuzz_me] == false
			return []
		end
		res = []
		# res << field unless field == @field
		return res if field.fuzz_options && field.fuzz_options[:fuzz_me] == false
		field.order.each do |child_field|
			res << get_fuzzable_fields(child_field)
		end
		if field.respond_to?(:unfields)
			field.unfields.each do |uf|
				res << get_fuzzable_fields(uf)
			end
		end
		res.flatten
	end
end

class Mapper
	def initialize(*arrays)
		@arrays = arrays
	end
	def permutation(&block)
		counters = @arrays.map{ 0 }
		while true
			last=at_end?(counters)
			vals = counters.each_with_index.map {|c, i| @arrays[i][c]}
			yield(*vals)
			increment_counters(counters)
			break if last
		end
	end
	def increment_counters(counters)
		counters.each_with_index {|c,i| return if c >= @arrays[i].length}
		pos = counters.length - 1
		counters[pos] += 1
		if counters[pos] == @arrays[pos].length
			counters[pos] = 0
			counters[pos-1] += 1
			pos -= 1
		else
			return
		end
		while pos != 0
			if counters[pos] == @arrays[pos].length
				counters[pos] = 0
				counters[pos-1] += 1
				pos -= 1
			else
				break
			end
		end
	end
	def at_end?(counters)
		counters.each_with_index do |c, index|
			return false if c != (@arrays[index].length - 1)
		end
		true
	end
end

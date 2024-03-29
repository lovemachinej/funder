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
require 'fields'

class Action
	attr_accessor :parent, :block, :fields, :owner
	def initialize(block=nil, do_it_once_str=nil)
		@block = block
		@do_it_once_str = do_it_once_str
		@owner = nil
	end
	def get_fields
		if @do_it_once_str
			if @do_it_once_str.kind_of? Proc
				[Field.new(nil, (instance_eval &(@do_it_once_str)), nil)]
			elsif @do_it_once_str.kind_of? String
				[Field.new(nil, @do_it_once_str, nil)]
			else
				raise "Unknown type of do_it_once_str"
			end
		elsif @block
			@parent.instance_eval &block
		elsif @owner
			[@owner]
		end
	end
	def self.action
		raise "this should be implemented by inherited classes"
	end
	def do_it
		raise "this should be done by inherited classes"
	end
	def do_it_once(str)
		# need to do some fu here so it works as an action with a section
		self.class.class_eval { alias :real_get_fields :get_fields }
		self.class.send(:define_method, :get_fields) { [Field.new(nil,str,nil)] }
		result = do_it
		self.class.class_eval { alias :get_fields :real_get_fields }
		result
	end
	def desc
		"Action:#{self.class.to_s}"
	end
	def inspect(level=0)
		@fields ||= get_fields() || []
		fields_str = @fields.map do |field|
			field.name
		end.join(", ")
		if level == 0
			return "#<#{desc} fields=[#{fields_str}]>"
		elsif level == 1
			return "#{desc}(#{fields_str})"
		elsif level == 2
			return "#{desc}(#{fields_str})"
		else
			return ""
		end
	end
end

class ReversibleAction < Action
	def self.reverse_it(data)
		raise "this should be implemented by inherited classes"
	end
end

class Length < Action
	def self.action(data)
		data.length
	end
	def do_it
		Length.action(get_fields.map{|f| f.to_out }.join)
	end
end

class Crc32 < Action
	def self.action(data)
		require 'zlib'
		Zlib::crc32(data)
	end
	def do_it
		res = get_fields.map{|f|f.to_out}.join
		Crc32.action(res)
	end
end

class Reverse < ReversibleAction
	def self.action(data)
		data.reverse
	end
	def self.reverse_it(data)
		data.reverse
	end
	def do_it
		Reverse.action(get_fields.map{|f| f.to_out }.join)
	end
end

class ZlibDeflate < ReversibleAction
	def self.action(data)
		require 'zlib'
		Zlib::Deflate.deflate(data)
	end
	def self.reverse_it(data)
		require 'zlib'
		Zlib::Inflate.inflate(data)
	end
	def do_it
		ZlibDeflate.action(get_fields.map{|f| f.to_out }.join)
	end
end

class Base64Encode < ReversibleAction
	def self.reverse_it(data)
		require 'base64'
		Base64.decode64(data)
	end
	def self.action(data)
		require 'base64'
		# need the chomp b/c it has an extra \n
		Base64.encode64(data).chomp
	end
	def do_it
		Base64Encode.action(get_fields.map{|f| f.to_out }.join)
	end
end

class Unicode < ReversibleAction
	def self.action(data)
		res = ""
		data.each_byte do |b|
			res << b.chr + "\x00"
		end
		res
	end
	def self.reverse_it(data)
		res = ""
		tmp = data.clone
		while tmp.length > 0
			char, null = tmp.unpack("ac")
			return data if null != 0 || null == ""
			res << char
		end
		res
	end
	def do_it
		Unicode.action(get_fields.map{|f| f.to_out }.join)
	end
end

class NullTerminate < ReversibleAction
	def self.action(data)
		data + "\x00"
	end
	def self.reverse_it(data)
		return data.slice(0, data.length - 1) if data[-1, 1] == "\x00"
		data
	end
	def do_it
		NullTerminate.action(get_fields.map{|f| f.to_out }.join)
	end
end

class Offset < Action
	def do_it
		fields = get_fields
		raise "this action can only be done on _one_ field" if fields.length > 1
		fields[0].offset
	end
end

#Default Action
class DA < Action
	def do_it
		get_fields.map{|f| f.to_out }.join
	end
end

class CustomAction < Action
	attr_accessor :custom_proc
	def initialize(custom_proc, block=nil, do_it_once_str=nil)
		super(block, do_it_once_str)
		@custom_proc = custom_proc
	end
	def do_it
		@custom_proc.call(get_fields)
	end
end

# ---------------- CONDITIONAL ACTIONS ----------------------

class ConditionalAction < Action
	def initialize(*args)
		@ifs = []
		@else = nil
		i = 0
		raise "need at least to args for this to work!" if args.length < 2
		while i < args.length
			if i == args.length - 1
				@else = args[i]
				@else.parent = @parent
				i += 1
			else
				args[i+1].parent = @parent
				@ifs << [args[i], args[i+1]]
				i += 2
			end
		end
	end
	def parent=(val)
		super(val)
		@ifs.each do |iif, tthen|
			tthen.parent = val
		end
		@else.parent = val
	end
	def do_it_once(val)
		resolve_it(:do_it_once, val)
	end
	def do_it
		resolve_it(:do_it)
	end
	def resolve_it(method, *args)
		res = nil
		counter = 0
		@ifs.each do |iif, tthen|
			if @parent.instance_eval &iif
				return tthen.send(method, *args)
			end
		end
		return @else.send(method, *args) if @else
		""
	end
	def inspect(level=0)
		if level == 0
			return "#<CondAction:#{self.class.to_s}>"
		elsif level == 1
			return "CondAction:#{self.class.to_s}"
		elsif level == 2
			return "CondAction:#{self.class.to_s}"
		else
			return ""
		end
	end
end

class If < ConditionalAction
end

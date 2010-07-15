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
require 'fields'

class Action
	attr_accessor :parent, :block
	def initialize(block=nil)
		@block = block
	end
	def get_fields
		@parent.instance_eval &block
	end
	def do_it
		raise "this should be done by inherited classes"
	end
	def do_it_once(str)
		self.class.class_eval { alias :real_get_fields :get_fields }
		self.class.send(:define_method, :get_fields) { [Field.new(nil,str,nil)] }
		result = do_it
		self.class.class_eval { alias :get_fields :real_get_fields }
		result
	end
	def inspect
		"Action:#{self.class.to_s}"
	end
end

class Length < Action
	def do_it
		get_fields.map{|f| f.to_out }.join.length
	end
end

class Crc32 < Action
	def do_it
		require 'zlib'
		res = get_fields.map{|f|f.to_out}.join
		Zlib::crc32(res)
	end
end

class Reverse < Action
	def do_it
		get_fields.map{|f| f.to_out }.join.reverse
	end
end

class ZlibDeflate < Action
	def do_it
		require 'zlib'
		Zlib::Deflate.deflate(get_fields.map{|f| f.to_out }.join)
	end
end

#Default Action
class DA < Action
	def do_it
		get_fields.map{|f| f.to_out }.join
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
	def inspect
		"CondAction:#{self.class.to_s}"
	end
end

class If < ConditionalAction
end

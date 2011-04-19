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

class AncestorField
	attr_accessor :name, :ancestor_class, :multiple
	def initialize(name, ancestor_class, multiple=false)
		@name = name
		@ancestor_class = ancestor_class
		@multiple = multiple
	end
end

module FunderParser
	attr_accessor :parse_data
	def parse_info(&block)
		class_eval "class ParseInfo < Funder ; end"
		klass = class_eval "ParseInfo"
		klass.class_eval &block
		@parse_data = klass
	end
	def desc_of(name, ancestor_class)
		AncestorField.new(name, ancestor_class)
	end
	def list_desc_of(name, ancestor_class)
		AncestorField.new(name, ancestor_class, true)
	end

	def parse(data)
		parse_data = data.clone
		template_class = @parse_data || self
		class_eval "class Parsed_#{self} < Funder ; end"
		parsed_class = class_eval "Parsed_#{self}"
		template_class.order.each do |template_field|
			pre_field = parse_template_field(template_field, parse_data)
			parsed_class.order.append_or_replace(pre_field){|f| f.name == pre_field.name}
			make_class_accessor(pre_field.name, pre_field)
		end
		parsed_class.new
	end
	def parse_template_field(t_field, data)
		value = begin
			if t_field.klass.ancestors.include? Funder
				""
			else
				parse_atomic_field(t_field, data)
			end
		end
		PreField.new(t_field.name, t_field.klass, value, t_field.options)
	end
	def parse_atomic_field(t_field, data)
		puts "parsing atomic field"
		name = t_field.name
		klass = t_field.klass
		read_length = t_field.read_length
		field_data = data.slice!(0, read_length)
		t_field.parse(field_data)
	end
end

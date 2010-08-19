require 'fields'
require 'actions'

$BIG_ENDIAN = true

module SyntacticSugar
#	def field(name, klass, value=nil, options={})
#		@order ||= []
#		pf = PreField.new(name, klass, value, options, self)
#		@order.append_or_replace(pf) {|field| field.name == name}
#	end

	# integer sugar

	def byte(name, value=nil, options={})
		pack = 'c'
		field(name, Int, value, {:p=>pack}.merge(options))
	end
	def int16(name, value=nil, options={})
		pack = 'n'
		pack = 'v' unless $BIG_ENDIAN
		field(name, Int, value, {:p=>pack}.merge(options))
	end
	def short(name, value=nil, options={})
		int16(name, value, options)
	end
	def int32(name, value=nil, options={})
		pack = 'N'
		pack = 'V' unless $BIG_ENDIAN
		field(name, Int, value, {:p=>pack}.merge(options))
	end
	def long(name, value=nil, options={})
		int32(name, value, options)
	end
	def double(name, value=nil, options={})
		pack = 'G'
		pack = 'E' unless $BIG_ENDIAN
		field(name, Int, value, {:p=>pack}.merge(options))
	end
	def float(name, value=nil, options={})
		pack = 'g'
		pack = 'e' unless $BIG_ENDIAN
		field(name, Int, value, {:p=>pack}.merge(options))
	end

	# string sugar

	def str(name, value=nil, options={})
		field(name, Str, value, options)
	end
	def char(name, value=nil, options={})
		field(name, Str, value, {:min=>1, :max=>1}.merge(options))
	end
	def base64_str(name, value=nil, options={})
		field(name, Str, value, {:action=>action(Base64Encode)}.merge(options))
	end
	# note - an extra byte will be added to this str (keep in mind for null-terminated lengths)
	def c_str(name, value=nil, options={})
		field(name, Str, value, {:action=>action(NullTerminate)}.merge(options))
	end
	def unicode_str(name, value=nil, options={})
		field(name, Str, value, {:action=>action(Unicode)}.merge(options))
	end
end

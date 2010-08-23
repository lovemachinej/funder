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

require 'fields'
require 'actions'

$BIG_ENDIAN = true

module SyntacticSugar

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
 
 	# misc sugar
 
 	def array(name, klass, options={})
 		field(name, klass, nil, {:mult=>true}.merge(options))
 	end
end

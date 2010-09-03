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

class Png < Funder
	COLOR_TYPE_GREYSCALE = 0
	COLOR_TYPE_TRUECOLOR = 2
	COLOR_TYPE_INDEXED_COLOR = 3
	COLOR_TYPE_GREYSCALE_WITH_ALPHA = 4
	COLOR_TYPE_TRUECOLOR_WITH_ALPHA = 6
end

class Chunk < Funder
	int32 :length, action(Length, lambda{[data]})
	str :type_code, nil, :min=>4
	str :data
	int32 :crc, action(Crc32, lambda{[type_code,data]})
end

class IHDR < Chunk
	str :type_code, "IHDR"
	section :data do
		int32 :width
		int32 :height 
		byte :bit_depth, 8
		byte :color_type, Png::COLOR_TYPE_TRUECOLOR
		byte :comp_method, 0
		byte :filter_method, 0
		byte :interlace_method, 0
	end
end

class IDAT < Chunk
	str :type_code, "IDAT"
	section(:data, action(ZlibDeflate)) do
		unfield :height, Int, nil, :p=>'c'
		unfield :width, Int, nil, :p=>'c'
		unfield :alpha, Int, 255
		unfield :red, Int, 255
		unfield :green, Int, 255
		unfield :blue, Int, 255
		unfield :color_type, Int

		str :pixel_data, lambda {
			w = width.value || @parent.parent.ihdr.data.width.value || rand(10)+1
			h = height.value || @parent.parent.ihdr.data.height.value || rand(10)+1
			c_type = color_type.value || @parent.parent.ihdr.data.color_type.value || 2
			case c_type
			when Png::COLOR_TYPE_TRUECOLOR # (no alpha)
				h.times.map do
					"\x00" +
					w.times.map do
						r = red.value || rand(256)
						g = green.value || rand(256)
						b = blue.value || rand(256)
						r.chr + g.chr + b.chr
					end.join
				end.join
			when Png::COLOR_TYPE_TRUECOLOR_WITH_ALPHA
				h.times.map do
					"\x00" +
					w.times.map do
						r = red.value || rand(256)
						g = green.value || rand(256)
						b = blue.value || rand(256)
						a = alpha.value || rand(255)
						r.chr + g.chr + b.chr + a.chr
					end.join
				end.join
			else
				h.times.map do
					"\x00" +
					w.times.map do
						r = red.value || rand(256)
						g = green.value || rand(256)
						b = blue.value || rand(256)
						r.chr + g.chr + b.chr
					end.join
				end.join
			end
		}
	end
end

class SRGB < Chunk
	str :type_code, "sRGB"
	section :data do
		byte :rend_intent, 0
	end
end

class TEXT < Chunk
	str :type_code, "tEXt"
	section :data do
		c_str :keyword, "Comment", :max=>79
		str :text, "tEXT text"
	end
end

class ZTXT < Chunk
	str :type_code, "zTXt"
	section :data do
		c_str :keyword, "Comment", :max=>79
		byte :comp_meth, 0
		section(:compressed_text, action(ZlibDeflate)) do
			str :text, "zTXt text"
		end
	end
end

class ITXT < Chunk
	str :type_code, "iTXt"
	section :data do
		c_str :keyword, "Comment", :max=>79
		byte :comp_flag, 1
		byte :comp_method, 0
		c_str :language_tag, "en-us"
		c_str :translated_text, "translated text"

		unfield :comp_text, Bool, lambda { comp_flag.value == 1 }
		section(:text, action(If, lambda{comp_text.value}, 
								action(ZlibDeflate),
								action(DA))) do
			str :actual_text, "ACTUAL TEXT"
		end
	end
end

class TRNS < Chunk
	str :type_code, "tRNS"
	section :data do
		# assuming color type == 2
		int32 :red_sample_value, 200, :max=>255
		int32 :blue_sample_value, 100, :max=>255
		int32 :green_sample_value, 50, :max=>255
	end
end

class CHRM < Chunk
	str :type_code, "cHRM"
	section :data do
		int32 :white_point_x, 5000, :min=>10, :max=>10000
		int32 :white_point_y,  5000, :min=>10, :max=>10000
		int32 :red_x, 5000, :min=>10, :max=>10000
		int32 :red_y, 5000, :min=>10, :max=>10000
		int32 :green_x, 5000, :min=>10, :max=>10000
		int32 :green_y, 5000, :min=>10, :max=>10000
		int32 :blue_x, 5000, :min=>10, :max=>10000
		int32 :blue_y, 5000, :min=>10, :max=>10000
	end
end

class SBIT < Chunk
	str :type_code, "sBIT"
	section :data do
		byte :sig_red_bits, 200
		byte :sig_green_bits, 100
		byte :sig_blue_bits, 50
	end
end

class GAMA < Chunk
	str :type_code, "gAMA"
	section :data do
		int32 :image_gama, 1000
	end
end

class BKGD < Chunk
	str :type_code, "bKGD"
	section :data do
		int32 :red, 200
		int32 :green, 100
		int32 :blue, 50
	end
end

class HIST < Chunk
	str :type_code, "hIST"
	section :data do
		unfield :num_entries, Int, lambda { @parent.parent.plte.data.entries.length }
		str :entries, lambda {
			num = num_entries.value || 10 
			num.times.map{"CCCC"}.join
		}
	end
end

class PlteEntry < Funder
	byte :red, 61
	byte :green, 51
	byte :blue, 41
end

class PLTE < Chunk
	str :type_code, "PLTE"
	section :data do
		field :entries, PlteEntry, nil, :mult=>true, :mult_min=>1, :mult_max=>256
	end
end

class PHYS < Chunk
	str :type_code, "pHYs"
	section :data do
		int32 :pixels_per_unit_x, 1
		int32 :pixels_per_unit_y, 1
		byte :unit_specifier, 1
	end
end

class SpltEntry < Funder
	int32 :red, 200
	int32 :green, 100
	int32 :blue, 50
	int32 :alpha, 150
	int32 :frequency, 100
end

class SPLT < Chunk
	str :type_code, "sPLT"
	section :data do
		c_str :palette_name, "palette name", :min=>1, :max=>79
		byte :sample_depth, 16
		field :palette_entries, SpltEntry, nil, :mult=>true, :mult_min=>1
	end
end

class TIME < Chunk
	str :type_code, "tIME"
	section :data do
		int32 :year, 2010
		byte :month, 5, :min=>1, :max=>12
		byte :day, 10, :min=>1, :max=>31
		byte :hour, 6, :min=>0, :max=>23
		byte :minute, 30, :min=>0, :max=>59
		byte :second, 15, :min=>0, :max=>60
	end
end

class IEND < Chunk
	str :type_code, "IEND"
	str :data, ""
end

class Png < Funder
	parse_info do
		str :png_header, "\211PNG\r\n\032\n"
		field :ihdr, IHDR
		list_desc_of :chunks, Chunk
		field :iend, IEND
	end

	str :png_header, "\211PNG\r\n\032\n"
	field :ihdr, IHDR
	# field :chrm, CHRM
	field :srgb, SRGB
	# field :sbit, SBIT
	# field :trns, TRNS
	# field :gama, GAMA
	# array :splt, SPLT, :mult_max=>2
	# field :bkgd, BKGD
	# field :plte, PLTE
	# field :hist, HIST
	# field :phys, PHYS
	# field :time, TIME
	field :idat, IDAT
	array :text, TEXT, :mult_max=>2
	# array :ztxt, ZTXT, :mult_max=>2
	# array :itxt, ITXT, :mult_max=>2
	field :iend, IEND
end

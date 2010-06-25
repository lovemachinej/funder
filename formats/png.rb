require 'funder'

class Chunk < Funder
	field :length, Int, action(Length, lambda{[data]})
	field :type_code, Str, nil, :min=>4
	field :data, Str, nil
	field :crc, Int, action(Crc32, lambda{[type_code,data]})
end

class IHDR < Chunk
	field :type_code, Str, "IHDR"
	section :data do
		field :width, Int
		field :height, Int
		field :bit_depth, Int, 8, :p=>'c'
		field :color_type, Int, 2, :p=>'c'
		field :comp_method, Int, 0, :p=>'c'
		field :filter_method, Int, 0, :p=>'c'
		field :interlace_method, Int, 0, :p=>'c'
	end
end

class IDAT < Chunk
	field :type_code, Str, "IDAT"
	section(:data, action(ZlibDeflate)) do
		unfield :height, Int, nil, :p=>'c'
		unfield :width, Int, nil, :p=>'c'
		unfield :alpha, Int, 255
		unfield :red, Int, 255
		unfield :green, Int, 255
		unfield :blue, Int, 255
		unfield :color_type, Int

		field :pixel_data, Str, lambda {
			c_type = color_type.value || @parent.parent.ihdr.data.color_type.value || 2
			case c_type
			when 2 # true color
				w = width.value || rand(10)+1
				h = height.value || rand(10)+1
				h.times.map do
					"\x00" +
					w.times.map do
						r = red.value || rand(256)
						g = green.value || rand(256)
						b = blue.value || rand(256)
						r.chr + g.chr + b.chr
					end.join
				end.join
			when 6 # true color w/ alpha
				w = width.value || rand(10)+1
				h = height.value || rand(10)+1
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
				w = width.value || rand(10)+1
				h = height.value || rand(10)+1
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
	field :type_code, Str, "sRGB"
	section :data do
		field :rend_intent, Int, 0, :p=>'c'
	end
end

class TEXT < Chunk
	field :type_code, Str, "tEXt"
	section :data do
		field :keyword, Str, "Comment", :max=>79
		field :null, Str, "\x00"
		field :text, Str, "tEXT text"
	end
end

class ZTXT < Chunk
	field :type_code, Str, "zTXt"
	section :data do
		field :keyword, Str, "Comment", :max=>79
		field :null, Str, "\x00"
		field :comp_meth, Int, 0, :p=>'c'
		section(:compressed_text, action(ZlibDeflate)) do
			field :text, Str, "zTXt text"
		end
	end
end

class ITXT < Chunk
	field :type_code, Str, "iTXt"
	section :data do
		field :keyword, Str, "Comment", :max=>79
		field :null_1, Str, "\x00"
		field :comp_flag, Int, 1, :p=>'c'
		field :comp_method, Int, 0, :p=>'c'
		field :language_tag, Str, "en-us"
		field :null_2, Str, "\x00"
		field :translated_text, Str, "translated text"
		field :null_3, Str, "\x00"

		unfield :comp_text, Bool, lambda { comp_flag.value == 1 }
		section(:text, action(If, lambda{comp_text.value}, 
								action(ZlibDeflate),
								action(DA))) do
			field :actual_text, Str, "ACTUAL TEXT"
		end
	end
end

class TRNS < Chunk
	field :type_code, Str, "tRNS"
	section :data do
		# assuming color type == 2
		field :red_sample_value, Int, 200, :p=>'n', :max=>255
		field :blue_sample_value, Int, 100, :p=>'n', :max=>255
		field :green_sample_value, Int, 50, :p=>'n', :max=>255
	end
end

class CHRM < Chunk
	field :type_code, Str, "cHRM"
	section :data do
		field :white_point_x, Int, 5000, :min=>10, :max=>10000
		field :white_point_y, Int,  5000, :min=>10, :max=>10000
		field :red_x, Int, 5000, :min=>10, :max=>10000
		field :red_y, Int, 5000, :min=>10, :max=>10000
		field :green_x, Int, 5000, :min=>10, :max=>10000
		field :green_y, Int, 5000, :min=>10, :max=>10000
		field :blue_x, Int, 5000, :min=>10, :max=>10000
		field :blue_y, Int, 5000, :min=>10, :max=>10000
	end
end

class SBIT < Chunk
	field :type_code, Str, "sBIT"
	section :data do
		field :sig_red_bits, Int, 200, :p=>'c'
		field :sig_green_bits, Int, 100, :p=>'c'
		field :sig_blue_bits, Int, 50, :p=>'c'
	end
end

class GAMA < Chunk
	field :type_code, Str, "gAMA"
	section :data do
		field :image_gama, Int, 1000
	end
end

class BKGD < Chunk
	field :type_code, Str, "bKGD"
	section :data do
		field :red, Int, 200, :p=>'n'
		field :green, Int, 100, :p=>'n'
		field :blue, Int, 50, :p=>'n'
	end
end

class HIST < Chunk
	field :type_code, Str, "hIST"
	section :data do
		unfield :num_entries, Int, lambda { @parent.parent.plte.data.entries.length }
		field :entries, Str, lambda {
			num = num_entries.value || 10 
			num.times.map{"CCCC"}.join
		}
	end
end

class PlteEntry < Funder
	field :red, Int, 61, :p=>'c'
	field :green, Int, 51, :p=>'c'
	field :blue, Int, 41, :p=>'c'
end

class PLTE < Chunk
	field :type_code, Str, "PLTE"
	section :data do
		field :entries, PlteEntry, nil, :mult=>true, :mult_min=>1, :mult_max=>256
	end
end

class PHYS < Chunk
	field :type_code, Str, "pHYs"
	section :data do
		field :pixels_per_unit_x, Int, 1
		field :pixels_per_unit_y, Int, 1
		field :unit_specifier, Int, 1, :p=>'c'
	end
end

class SpltEntry < Funder
	field :red, Int, 200, :p=>'n'
	field :green, Int, 100, :p=>'n'
	field :blue, Int, 50, :p=>'n'
	field :alpha, Int, 150, :p=>'n'
	field :frequency, Int, 100, :p=>'n'
end

class SPLT < Chunk
	field :type_code, Str, "sPLT"
	section :data do
		field :palette_name, Str, "palette name", :min=>1, :max=>79
		field :null_sep, Str, "\x00"
		field :sample_depth, Int, 16, :p=>'c'
		field :palette_entries, SpltEntry, nil, :mult=>true, :mult_min=>1
	end
end

class TIME < Chunk
	field :type_code, Str, "tIME"
	section :data do
		field :year, Int, 2010, :p=>'n'
		field :month, Int, 5, :p=>'c', :min=>1, :max=>12
		field :day, Int, 10, :p=>'c', :min=>1, :max=>31
		field :hour, Int, 6, :p=>'c', :min=>0, :max=>23
		field :minute, Int, 30, :p=>'c', :min=>0, :max=>59
		field :second, Int, 15, :p=>'c', :min=>0, :max=>60
	end
end

class IEND < Chunk
	field :type_code, Str, "IEND"
	field :data, Str, ""
end

class Png < Funder
	field :png_header, Str, "\211PNG\r\n\032\n"
	field :ihdr, IHDR
	field :chrm, CHRM
	field :srgb, SRGB
	field :sbit, SBIT
	field :trns, TRNS
	field :gama, GAMA
	field :splt, SPLT, nil, :mult=>true, :mult_max=>2
	field :bkgd, BKGD
	field :plte, PLTE
	field :hist, HIST
	field :phys, PHYS
	field :time, TIME
	field :idat, IDAT
	field :text, TEXT, nil, :mult=>true, :mult_max=>2
	field :ztxt, ZTXT, nil, :mult=>true, :mult_max=>2
	field :itxt, ITXT, nil, :mult=>true, :mult_max=>2
	field :iend, IEND
end

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

class Value
	attr_accessor :parent, :owner
	def initialize
		@parent = nil
	end
	def resolve
		raise "I can't think of a generic use case for this class, so don't use it"
	end
	def inspect
		"#<#{self.class}>"
	end
end

class BoundValue < Value
	# the lambda passed in here should be very specific (eg, field.value instead of just field)
	def initialize(bind_lambda)
		super()
		@bind_lambda = bind_lambda
	end
	def resolve
		@parent.instance_eval &(@bind_lambda)
	end
end

class MultiBoundValue < BoundValue
	def initialize(bind_lambda, fields_map)
		super(bind_lambda)
		@fields_map = fields_map
		@added_listener = false
	end
	def bind_fields(items)
		return if items.length == 0
		bound_multi_field = items[0].owner
		src_multi_field = resolve
		unless @added_listener
			src_multi_field.add_event_listener(:length_changed, lambda{
					bound_multi_field.init
			})
			# make sure we only add the listener once
			@added_listener = true
		end
		items.each_with_index do |item, index|
			@fields_map.each do |item_field, to_field|
				bound_field = item.instance_eval(item_field.to_s)
				bound_field.value = BoundValue.new(lambda{src_multi_field[index].instance_eval(to_field.to_s)})
			end
		end
	end
end

class Counter < Value
	# keeps track of counters values based on a unique name and the obj_id of the root class
	module CounterManager
	class << self
		def reset(obj_id)
		end
		def create_counter(obj_id, name, start_num, incrementor)
			@counters ||= {}
			@counters[obj_id] ||= {}
			# don't clobber existing counters
			return if @counters[obj_id][name]
			@counters[obj_id][name] = {}
			@counters[obj_id][name][:start_num] = start_num
			@counters[obj_id][name][:incrementor] = incrementor
			@counters[obj_id][name][:next_val] = start_num
		end
		def next_number(obj_id, name)
			res = @counters[obj_id][name][:next_val]
			@counters[obj_id][name][:next_val] += @counters[obj_id][name][:incrementor]
			res
		end
	end # class << self
	end # CounterManager

	attr_accessor :start_num, :incrementor, :my_number
	def initialize(name, start_num=0, incrementor=1, replace=true)
		@start_num = start_num
		@my_number = nil
		@name = name
		@incrementor = incrementor
		@replace = replace
	end
	def parent=(val)
		@parent = val
		# at this point, we can find the root field and create a counter in Counter_Manager
		@root_obj_id = @owner.root.object_id
		CounterManager.create_counter(@root_obj_id, @name, @start_num, @incrementor)
		val = CounterManager.next_number(@root_obj_id, @name)
		if @replace
			@owner.value = val
		else
			@my_number = val
		end
		val
	end
	def resolve
		# @my_number should have been set by now
		@my_number
	end
end

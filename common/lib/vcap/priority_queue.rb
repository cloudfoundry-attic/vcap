#a priority queue with the added twist of FIFO behavior for elements with equal priorities
#implementation using binary max-heap on top of a ruby array.
#the FIFO behavior is implemented by storing a FIFO bucket of same-priority values

#The implementation is not meant to be high-performance, just decent, with two goals:
#1. clean interface
#2. proper time/space complexity of a binary heap
#3. no silly memory leaks (Ah, three weapons of the Spanish Inquisition)

#additionally, we implement a PrioritySet, that is a PriorityQueue
#into which an element can only be inserted once. This PrioritySet
#allows specifying identity for the object with a separate object.
#The identity is for determining whether an object being inserted is a
#duplicate, e.g.

#     q.insert("boo", 1, "key")
#     q.insert("zah", 1, "key")

#will result in just one object in the queue, "boo"
#
#See spec/unit/priority_queue_set for
#other examples

require 'set'
require 'pp'

module VCAP
  class PriorityQueueFIFO

    attr_reader :size

    def initialize
      @heap_arr = []
      @p2b = {} #hash mapping priorities to buckets
      @size = 0
    end

    def empty?
      size == 0
    end

    def insert(item, priority = 0)
      raise ArgumentError, "priority can not be negative: #{priority}" if priority < 0

      unless append_to_existing_priority_bucket(item, priority)
        add_bucket_at_the_end_and_shift_up(item, priority)
      end
      @size += 1
    end

    def remove
      return nil if empty?
      bucket = top_bucket
      priority = top_priority
      elem = bucket.shift
      @size -= 1
      if empty?
        @heap_arr.clear
        @p2b.clear
      elsif bucket.empty?
        @heap_arr[0] = @heap_arr.pop
        @p2b.delete(priority)
        shift_down
      else
        #do nothing, we just shifted a value from a bucket and it still isn't empty, so no rearrangement is needed
      end
      elem
    end

    private

    def add_bucket_at_the_end_and_shift_up(item, priority)
      bucket = [item]
      @p2b[priority] = bucket

      #normal binary heap operation
      @heap_arr.push priority
      shift_up
    end

    def append_to_existing_priority_bucket(item, priority)
      return false unless @p2b[priority]
      @p2b[priority] << item
      return true
    end

    def top_bucket
      @p2b[top_priority]
    end

    def top_priority
      priority_at(0)
    end

    def priority_at(index)
      return -1 if index >= @heap_arr.size
      @heap_arr[index]
    end

    def parent_index(index)
      (index+1) / 2 - 1
    end

    def left_child_index(index)
      (index+1) * 2 - 1
    end

    def right_child_index(index)
      (index+1) * 2
    end

    def any_children_at?(index)
      left_child_index(index) < @heap_arr.length
    end

    def shift_up
      cur_index = @heap_arr.length - 1
      while cur_index > 0 && priority_at(cur_index) > priority_at(parent_index(cur_index)) do
        next_cur_index = parent_index cur_index
        swap_at(cur_index, next_cur_index)
        cur_index = next_cur_index
      end
    end

    def index_of_max_priority_child_at(index)
      #raise(ArgumentError, "no children at #{index}") unless any_children_at?(index)
      l = left_child_index(index)
      r = right_child_index(index)
      return r if priority_at(r) > priority_at(l) #this is safe since priority will return -1 for non-existent right child
      return l
    end

    def shift_down
      cur_index = 0
      while any_children_at?(cur_index) && priority_at(cur_index) < priority_at(index_of_max_priority_child_at(cur_index)) do
        next_cur_index = index_of_max_priority_child_at cur_index
        swap_at(cur_index, next_cur_index)
        cur_index = next_cur_index
      end
    end

    def swap_at(i,j)
      @heap_arr[i], @heap_arr[j] = @heap_arr[j], @heap_arr[i]
    end
  end


  class PrioritySet < PriorityQueueFIFO
    def initialize
      super
      @set = Set.new #the set is used to check for duplicates
    end

    def insert(elem, priority = 0, key = nil)
      super([elem,key], priority) if @set.add?(key || elem)
    end

    def remove
      elem, key = super
      @set.delete(key || elem)
      elem
    end
  end
end

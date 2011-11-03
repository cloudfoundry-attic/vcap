#simple priority queue implementation using binary max-heap on top of a ruby array.
#this implementation is not meant to be high-performance, just decent, with two goals:
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

module VCAP
  class PriorityQueue
    def initialize
      @heap_arr = []
    end

    def size
      @heap_arr.size
    end

    def empty?
      @heap_arr.empty?
    end

    def insert(item, priority = 0)
      raise ArgumentError, "priority can not be negative: #{priority}" if priority < 0
      @heap_arr.push [item, priority]
      shift_up
    end

    def remove
      return nil if empty?
      elem = @heap_arr[0][0]
      if size > 1
        @heap_arr[0] = @heap_arr.pop
        shift_down
      else
        @heap_arr.clear
      end
      elem
    end

    private
    def priority_at(index)
      return -1 if index >= @heap_arr.size
      @heap_arr[index][1]
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


  class PrioritySet < PriorityQueue
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

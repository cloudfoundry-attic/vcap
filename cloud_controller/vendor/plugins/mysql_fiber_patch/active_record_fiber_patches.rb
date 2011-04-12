# These patches are required to make our version of ActiveRecord (included w/ rails3)
# compatible with em_mysql2
#
# NB: Only require this file if your adapter is em_mysql2!
#
#
module ActiveRecord
  module ConnectionAdapters
    class ConnectionPool

      # This method is called when there are no connections available and one is requested.
      # The original method attempts to return reserved connections to the connection pool as follows:
      #   1. S1 = The connection ids of all reserved connections (where connection id is actually a thread id)
      #   2. S2 = The set of alive thread ids
      #   3. S3 = S1 - S2 = The set of connection ids that belong to inactive threads
      #   4. Return all connections with ids in S3 to the connection pool
      # However, the em_mysql2 adapter remaps connection ids to fiber ids (as we typically have many fibers per thread).
      # This means that when the method is called S2 can *never* be a subset of S1 (since we are using fiber ids
      # instead of thread ids), and *all* connections will be returned to the pool.
      def clear_stale_cached_connections!
        # This calls out to the patched version introduced by em_mysql2, which checks with registered
        # fiber pools to determine which which connections belong to inactive fibers.
        remove_stale_cached_threads!(@reserved_connections) {|c_id, c| checkin c}
      end
    end
  end
end

module StrongMigrations
  module AlphabetizeColumns
    def columns(*args)
      if @master_pool
        @master_pool.provide do |conn|
          conn.columns(*args).sort_by(&:name)
        end
      else
        super.sort_by(&:name)
      end
    end

    def extensions(*args)
      if @master_pool
        @master_pool.provide do |conn|
          conn.extensions(*args).sort
        end
      else
        super.sort
      end
    end
  end
end

module StrongMigrations
  module AlphabetizeColumns
    def columns(*args)
      super.sort_by(&:name)
    end

    def extensions(*args)
      super.sort
    end
  end
end

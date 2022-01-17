class Version < TestMigration
  def change
    change_column_null :users, :city, false, "San Francisco"
  end

  def version
    20170101000001
  end
end

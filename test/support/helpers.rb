module Helpers
  def postgresql?
    $adapter == "postgresql"
  end

  def mysql?
    ($adapter == "mysql2" || $adapter == "trilogy") && !ActiveRecord::Base.connection.mariadb?
  end

  def mariadb?
    ($adapter == "mysql2" || $adapter == "trilogy") && ActiveRecord::Base.connection.mariadb?
  end

  def postgresql_version
    ActiveRecord::Base.connection.execute("SHOW server_version_num").first["server_version_num"].to_i / 10000
  end

  def transaction_timeout?
    postgresql? && postgresql_version >= 17
  end
end

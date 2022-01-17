class CheckTimeouts < TestMigration
  include Helpers

  def change
    safety_assured { execute "SELECT 1" }

    $statement_timeout =
      if postgresql?
        connection.select_all("SHOW statement_timeout").first["statement_timeout"]
      elsif mysql?
        connection.select_all("SHOW VARIABLES LIKE 'max_execution_time'").first["Value"].to_i / 1000.0
      else
        connection.select_all("SHOW VARIABLES LIKE 'max_statement_time'").first["Value"].to_f
      end

    $lock_timeout =
      if postgresql?
        connection.select_all("SHOW lock_timeout").first["lock_timeout"]
      else
        connection.select_all("SHOW VARIABLES LIKE 'lock_wait_timeout'").first["Value"].to_i
      end
  end
end

class CheckLockTimeout < TestMigration
  def change
    safety_assured { execute "SELECT 1" }
  end
end

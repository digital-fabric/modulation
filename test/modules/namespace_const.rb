export  :SQL

module SQL
  export :sql, :SQL

  def sql
    self::SQL
  end

  self::SQL = "select 1"

  self::SECRET = "secreet"
end

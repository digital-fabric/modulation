export :SQL

module Settings
  export :the_answer

  def the_answer
    SECRET
  end

  def secret
    "secret"
  end

  SECRET = 42
end

module SQL
  export :format,
         :access_secret_method,
         :access_secret_const

  def format
    "select #{Settings.the_answer}"
  end

  def access_secret_method
    Settings.secret
  end

  def access_secret_const
    Settings::SECRET
  end

  def secret
    "secret"
  end
end

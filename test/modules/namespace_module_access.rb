export :the_answer, :SQL

def the_answer
  42
end

module SQL
  export :format

  def format
    "select #{MODULE.the_answer}"
  end
end

export :get, :set, :name, :name=

def get
  @var
end

def set(v)
  @var = v
end

attr_accessor :name
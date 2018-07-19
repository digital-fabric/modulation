export(
  :ExportedConstant,
  :exported_method,
  :access_private_class
)

class PrivateClass
end

ExportedConstant = 42

def access_private_class
  PrivateClass
end

def exported_method
  private_method
end

def private_method
  "private"
end


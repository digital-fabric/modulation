export  :PublicNamespace,
        :access_public_namespace_public_method,
        :access_public_namespace_private_method,        
        :access_private_namespace

module PublicNamespace
  export :greeting

  def greeting
    "Hello"
  end

  def secret
    "secret"
  end
end

module PrivateNamespace
  export :sql

  def sql
    "select 1"
  end

  def secret
    "secret"
  end
end

def access_public_namespace_public_method
  PublicNamespace.greeting
end

def access_public_namespace_private_method
  PublicNamespace.secret
end

def access_private_namespace
  PrivateNamespace
end
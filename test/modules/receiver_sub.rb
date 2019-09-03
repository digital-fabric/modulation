export_from_receiver :Sub

class Sub < import('./receiver_super')
  def self.bar
    :bar
  end
end
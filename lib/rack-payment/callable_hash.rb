# A Hash that you can call, like an OpenStruct, but you can still 
# call [] on it.
#
#   >> hash = CallableHash.new :foo => 'bar'
#
#   >> hash.foo
#   => 'bar'
#
#   >> hash[:foo]
#   => 'bar'
class CallableHash < Hash

  def initialize hash
    hash.each {|key, value| self[key] = value }
  end

  def method_missing name, *args
    if self[name]
      self[name]
    else
      super
    end
  end

  # Override type so, if there's a :type or 'type' key in this Hash, we 
  # return that value.  Else we return the actual object type.
  def type
    return self[:type]  if self[:type]
    return self['type'] if self['type']
    super
  end

  # Override zip so, if there's a :zip or 'zip' key in this Hash, we 
  # return that value.  Else we return the actual object zip.
  def zip
    return self[:zip]  if self[:zip]
    return self['zip'] if self['zip']
    super
  end

end

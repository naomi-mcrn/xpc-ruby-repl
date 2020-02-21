require 'objspace'

unless defined?(Jounouchi)
class Jounouchi
  class << self
    def finalizer(kls)
      kls ||= self.to_s
      proc { |oid| puts "#{kls}<#{oid}>: iwaaaaaaaaaaaaaaaaaaaaaaaaaaaak!!" }
    end
  end
  
  def foo
    @foo
  end
  
  def initialize
    @foo = "a" * 1048576 * 50
    ObjectSpace.define_finalizer(self,Jounouchi.finalizer(self.class.to_s.dup))   
  end
  def inspect
    "#<#{self.class}:#{self.object_id}>"
  end
end
end

unless defined?(Duel)
class Duel
  def standby
    puts "Duel standby!"
    lambda{10.times{Jounouchi.new}}.call;GC.start
    nil
  end
end
end

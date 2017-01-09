require 'spec_helper'

describe RedisResourceLocking do

  before :each do
    @resource = Order.new
  end

  after :each do
    [$redis.scan_each(match: "type:locks*").to_a, $redis.scan_each(match: "resource:locks*").to_a].flatten.each do |x|
      $redis.del(x) 
    end
  end

  it 'has a version number' do
    expect(RedisResourceLocking::VERSION).not_to be nil
  end

  it 'does something useful' do
    admin = User.new
    resource = Order.new
    expect(true)

  end
end


class Order
  attr_reader :id

  def initialize(id=1)
    @id = id
  end

end

class User
  attr_reader :id

  def initialize(id=1)
    @id = id
  end

end
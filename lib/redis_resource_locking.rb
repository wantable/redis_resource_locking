require "redis_resource_locking/version"

module RedisResourceLocking
  # this works by creating 2 seperate redis objects and using a sorted list
  #   a sorted list has 2 values; one as a number that is used to sort the list and another that is the actual value stored in that position
  #
  #   object one is type:locks:{{resource_klass}}  
  #     this is used to know what objects are currently locked
  #     the value is the resource id, the sort value is when it expires
  #
  #   object two is resource:locks:{{resource_klass}}:{{resource_id}}
  #     this is used to know who has an object locked
  #     the value is the user id, the sort value is when it expires
  # 
  # the all we have to do is make sure all things that have timed out are expired before we access either list
  #   since they are all sorted by the expiry date all we need to do is expire everything that falls below the current time

  TIMEOUT = 600 # 10 minutes in seconds

  def lock_resource(resource_klass, resource_id, user_id, timeout=TIMEOUT)
    # expire everything first
    expire_resource(resource_klass, resource_id)

    next_expiry = Time.now + timeout
    t_key = type_key(resource_klass)
    r_key = resource_key(resource_klass, resource_id)
    $redis.zadd(t_key, next_expiry, resource_id)
    $redis.zadd(r_key, next_expiry, user_id)

    # set these sorted sets to expire automatically as well if they don't get updated before TIMEOUT
    $redis.expireat(t_key, next_expiry)
    $redis.expireat(r_key, next_expiry)
  end

  def eager_expire_resource(resource_klass, resource_id, user_id)
    # sometimes we want to expire a lock before the timeout; like when closing an object after editing
    $redis.zrem(type_key(resource_klass), resource_id)
    $redis.zrem(resource_key(resource_klass, resource_id), user_id)
  end

  def resource_locks(resource_klass, resource_id)
    # expire resource/user locks before checking them
    expire_resource(resource_klass, resource_id)
    $redis.zrange(resource_key(resource_klass, resource_id), 0, -1).map(&:to_i)
  end

  def resources_locked(resource_klass)
    # expire resource locks before checking them
    expire_type(resource_klass)
    $redis.zrange(type_key(resource_klass), 0, -1).map(&:to_i)
  end

  def lock_expires(resource_klass, resource_id, user_id)
    # to figure out when a lock expires just look at its sort value
    expire_resource(resource_klass, resource_id)
    
    integer_time = $redis.zscore(resource_key(resource_klass, resource_id), user_id)
    Time.at(integer_time) if integer_time
  end

  private

  def type_key(resource_klass)
    "type:locks:#{resource_klass.name.parameterize}"
  end

  def resource_key(resource_klass, resource_id)
    "resource:locks:#{resource_klass.name.parameterize}:#{resource_id}"
  end
  
  def expire_type(resource_klass, expiry=nil)
    expiry ||= Time.now.to_i
    # expire everything with a sort value less than now
    $redis.zremrangebyscore(type_key(resource_klass), 0, expiry)
  end

  def expire_resource(resource_klass, resource_id, expiry=nil)
    expiry ||= Time.now.to_i
    # expire everything with a sort value less than now
    $redis.zremrangebyscore(resource_key(resource_klass, resource_id), 0, expiry)

    # expire the types too!
    expire_type(resource_klass, expiry)
  end
end

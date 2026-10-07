-- Places one pixel. Redis runs a script start to finish with nothing in
-- between, so the cooldown check, the pixel write and the sequence number
-- are a single atomic step.
--
-- KEYS[1] board bitfield    ARGV[1] pixel index (y * width + x)
-- KEYS[2] sequence counter  ARGV[2] colour, 0 to 15
-- KEYS[3] cooldown key      ARGV[3] cooldown in ms (0 skips the cooldown)
--
-- Returns {1, seq} when placed, {0, ms_left} on cooldown, {-1, 0} when the
-- board is missing and must be rebuilt first.

if redis.call('EXISTS', KEYS[1]) == 0 then
  return {-1, 0}
end

local cooldown_ms = tonumber(ARGV[3])
if cooldown_ms > 0 then
  local remaining = redis.call('PTTL', KEYS[3])
  if remaining > 0 then
    return {0, remaining}
  end
  redis.call('SET', KEYS[3], '1', 'PX', cooldown_ms)
end

redis.call('BITFIELD', KEYS[1], 'SET', 'u4', '#' .. ARGV[1], ARGV[2])
return {1, redis.call('INCR', KEYS[2])}

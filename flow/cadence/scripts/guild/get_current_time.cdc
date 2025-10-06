/** * This script returns the timestamp of the latest sealed block on the Flow blockchain.
 * The timestamp is a UFix64 value representing the number of seconds since the Unix epoch (00:00:00 UTC on 1 January 1970).
*/
access(all) fun main(): UFix64 {
    return getCurrentBlock().timestamp
}
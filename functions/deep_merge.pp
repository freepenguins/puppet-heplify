# @summary Recursively merges two hashes.
#
# Keys in `$override` win. When both sides hold a hash for the same key the
# two are merged recursively; any other value, arrays included, is replaced.
#
# @api private
#
# @param base
#   Hash to merge into.
# @param override
#   Hash whose values take precedence.
#
# @return [Hash] The merged hash.
function heplify::deep_merge(Hash $base, Hash $override) >> Hash {
  $override.reduce($base) |Hash $memo, Tuple[Any, Any] $entry| {
    $key = $entry[0]
    $value = $entry[1]
    $merged = ($value =~ Hash and $memo[$key] =~ Hash) ? {
      true    => heplify::deep_merge($memo[$key], $value),
      default => $value,
    }
    $memo + { $key => $merged }
  }
}

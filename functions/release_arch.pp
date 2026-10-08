# @summary Maps a node architecture to the name used in sipcapture release assets.
#
# @api private
#
# @param architecture
#   The node's `os.architecture` fact, for example `x86_64` or `aarch64`.
# @param component
#   Name used in the error message when there is no release binary.
#
# @return [Enum['amd64', 'arm64']] The release architecture.
function heplify::release_arch(String[1] $architecture, String[1] $component) >> Enum['amd64', 'arm64'] {
  $architecture ? {
    /^(x86_64|amd64)$/  => 'amd64',
    /^(aarch64|arm64)$/ => 'arm64',
    default             => fail("${component}: no release binary for architecture ${architecture}"),
  }
}

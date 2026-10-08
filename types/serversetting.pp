# @summary A heplify-server setting value as written to its TOML file.
type Heplify::ServerSetting = Variant[String, Integer, Boolean, Array[Variant[String, Integer]]]

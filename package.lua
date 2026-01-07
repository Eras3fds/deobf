return {
  name = "prometheus-deobfuscator-bot",
  version = "1.0.0",
  description = "Discord bot for deobfuscating Prometheus-obfuscated Lua scripts",
  main = "bot.lua",
  dependencies = {
    "SinisterRectus/discordia"
  },
  files = {
    "**.lua",
    "!test*"
  }
}

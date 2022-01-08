require "./app"

map TreeStats.assets_prefix do
  run TreeStats.sprockets
end

map "/" do
  run TreeStats
end

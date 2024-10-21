-- Adjust inserters to allow for runtime changes
for _, inserter in pairs(data.raw["inserter"]) do
    inserter.allow_custom_vectors = true
end

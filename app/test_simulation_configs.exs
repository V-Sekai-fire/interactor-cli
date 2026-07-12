# Test script for simulation configurations
IO.puts("🧪 Testing Simulation Configurations via NIFs")
IO.puts("=" |> String.duplicate(50))

# Helper function to test a simulation setup
test_simulation_setup = fn name, setup_path ->
  IO.puts("\n📋 Testing #{name} simulation setup")

  case File.read(setup_path) do
    {:ok, content} ->
      case Jason.decode(content) do
        {:ok, config} ->
          IO.puts("✅ #{name} setup.json parsed successfully")

          # Extract key information
          garment_path = config["garment_mesh_path"]
          avatar_path = config["avatar_mesh_path"]

          IO.puts("   Garment mesh: #{garment_path}")
          IO.puts("   Avatar mesh: #{avatar_path}")

          # Test if referenced files exist (relative to setup.json directory)
          setup_dir = Path.dirname(setup_path)
          full_garment_path = Path.join(setup_dir, garment_path)
          full_avatar_path = Path.join(setup_dir, avatar_path)

          garment_exists = File.exists?(full_garment_path)
          avatar_exists = File.exists?(full_avatar_path)

          IO.puts("   Garment file exists: #{garment_exists}")
          IO.puts("   Avatar file exists: #{avatar_exists}")

          # Test mesh validation if files exist
          if garment_exists do
            case ClothFitCli.PolyFEM.validate_garment_mesh(full_garment_path) do
              {:ok, true} -> IO.puts("   ✅ Garment mesh validation passed")
              {:ok, false} -> IO.puts("   ⚠️  Garment mesh validation failed")
              {:error, reason} -> IO.puts("   ❌ Garment validation error: #{reason}")
            end
          end

          if avatar_exists do
            case ClothFitCli.PolyFEM.validate_avatar_mesh(full_avatar_path) do
              {:ok, true} -> IO.puts("   ✅ Avatar mesh validation passed")
              {:ok, false} -> IO.puts("   ⚠️  Avatar mesh validation failed")
              {:error, reason} -> IO.puts("   ❌ Avatar validation error: #{reason}")
            end
          end

        {:error, reason} ->
          IO.puts("❌ Failed to parse #{name} setup.json: #{reason}")
      end
    {:error, reason} ->
      IO.puts("❌ Failed to read #{name} setup.json: #{reason}")
  end
end

# Test all simulation configurations
simulation_configs = [
  {"foxgirl_skirt", "../garment-data/foxgirl_skirt/setup.json"},
  {"Goblin_Jacket", "../garment-data/Goblin_Jacket/setup.json"},
  {"Goblin_Jumpsuit", "../garment-data/Goblin_Jumpsuit/setup.json"},
  {"Trex_Jacket", "../garment-data/Trex_Jacket/setup.json"}
]

Enum.each(simulation_configs, fn {name, path} ->
  test_simulation_setup.(name, path)
end)

IO.puts("\n📋 Simulation Configuration Summary")
IO.puts("Tested #{length(simulation_configs)} simulation configurations")

IO.puts("\n🎉 Simulation configuration testing complete!")

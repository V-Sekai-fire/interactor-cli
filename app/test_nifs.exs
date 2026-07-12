# Test script for PolyFEM NIFs
IO.puts("🧪 Testing PolyFEM NIF Integration")
IO.puts("=" |> String.duplicate(50))

# Test 1: Error handling with non-existent file
IO.puts("\n📋 Test 1: Error handling")
case ClothFitCli.PolyFEM.validate_garment_mesh("/nonexistent/file.obj") do
  {:error, reason} ->
    IO.puts("✅ Error handling works: #{reason}")
  other ->
    IO.puts("❌ Unexpected result: #{inspect(other)}")
end

# Test 2: Load real garment file
IO.puts("\n📋 Test 2: Real garment validation")
garment_path = "../garment-data/assets/garments/Puffer_dense/garment.obj"
case ClothFitCli.PolyFEM.validate_garment_mesh(garment_path) do
  {:ok, true} ->
    IO.puts("✅ Garment mesh validation passed")
  {:ok, false} ->
    IO.puts("⚠️  Garment mesh validation failed")
  {:error, reason} ->
    IO.puts("❌ Error validating garment: #{reason}")
end

# Test 3: Load garment info
IO.puts("\n📋 Test 3: Garment metadata extraction")
case ClothFitCli.PolyFEM.load_garment_info(garment_path) do
  {:ok, info} ->
    IO.puts("✅ Garment info loaded:")
    IO.puts("   Vertices: #{info["vertex_count"]}")
    IO.puts("   Faces: #{info["face_count"]}")
    IO.puts("   Mesh type: #{info["mesh_type"]}")
  {:error, reason} ->
    IO.puts("❌ Error loading garment info: #{reason}")
end

# Test 4: Load avatar file
IO.puts("\n📋 Test 4: Avatar validation")
avatar_path = "../garment-data/assets/avatars/FoxGirl/avatar.obj"
case ClothFitCli.PolyFEM.validate_avatar_mesh(avatar_path) do
  {:ok, true} ->
    IO.puts("✅ Avatar mesh validation passed")
  {:ok, false} ->
    IO.puts("⚠️  Avatar mesh validation failed")
  {:error, reason} ->
    IO.puts("❌ Error validating avatar: #{reason}")
end

# Test 5: Load avatar info
IO.puts("\n📋 Test 5: Avatar metadata extraction")
case ClothFitCli.PolyFEM.load_avatar_info(avatar_path) do
  {:ok, info} ->
    IO.puts("✅ Avatar info loaded:")
    IO.puts("   Vertices: #{info["vertex_count"]}")
    IO.puts("   Faces: #{info["face_count"]}")
    IO.puts("   Surface area: #{Float.round(info["surface_area"], 2)}")
    IO.puts("   Is likely avatar: #{info["is_likely_avatar"]}")
  {:error, reason} ->
    IO.puts("❌ Error loading avatar info: #{reason}")
end

IO.puts("\n🎉 NIF testing complete!")

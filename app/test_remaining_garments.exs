# Test script for remaining garments
IO.puts("🧪 Testing Remaining Garments via NIFs")
IO.puts("=" |> String.duplicate(50))

# Test jumpsuit_dense garment
IO.puts("\n📋 Test 1: jumpsuit_dense garment validation")
jumpsuit_path = "../garment-data/assets/garments/jumpsuit_dense/garment.obj"

case ClothFitCli.PolyFEM.validate_garment_mesh(jumpsuit_path) do
  {:ok, true} ->
    IO.puts("✅ jumpsuit_dense mesh validation passed")
  {:ok, false} ->
    IO.puts("⚠️  jumpsuit_dense mesh validation failed")
  {:error, reason} ->
    IO.puts("❌ Error validating jumpsuit_dense: #{reason}")
end

# Test jumpsuit_dense info
IO.puts("\n📋 Test 2: jumpsuit_dense metadata extraction")
case ClothFitCli.PolyFEM.load_garment_info(jumpsuit_path) do
  {:ok, info} ->
    IO.puts("✅ jumpsuit_dense info loaded:")
    IO.puts("   Vertices: #{info["vertex_count"]}")
    IO.puts("   Faces: #{info["face_count"]}")
    IO.puts("   Mesh type: #{info["mesh_type"]}")
    IO.puts("   Bounding box: #{inspect(info["bounding_box"])}")
  {:error, reason} ->
    IO.puts("❌ Error loading jumpsuit_dense info: #{reason}")
end

# Test LCL_Skirt_DressEvening_003 garment
IO.puts("\n📋 Test 3: LCL_Skirt_DressEvening_003 garment validation")
skirt_path = "../garment-data/assets/garments/LCL_Skirt_DressEvening_003/garment.obj"

case ClothFitCli.PolyFEM.validate_garment_mesh(skirt_path) do
  {:ok, true} ->
    IO.puts("✅ LCL_Skirt_DressEvening_003 mesh validation passed")
  {:ok, false} ->
    IO.puts("⚠️  LCL_Skirt_DressEvening_003 mesh validation failed")
  {:error, reason} ->
    IO.puts("❌ Error validating LCL_Skirt_DressEvening_003: #{reason}")
end

# Test LCL_Skirt_DressEvening_003 info
IO.puts("\n📋 Test 4: LCL_Skirt_DressEvening_003 metadata extraction")
case ClothFitCli.PolyFEM.load_garment_info(skirt_path) do
  {:ok, info} ->
    IO.puts("✅ LCL_Skirt_DressEvening_003 info loaded:")
    IO.puts("   Vertices: #{info["vertex_count"]}")
    IO.puts("   Faces: #{info["face_count"]}")
    IO.puts("   Mesh type: #{info["mesh_type"]}")
    IO.puts("   Bounding box: #{inspect(info["bounding_box"])}")
  {:error, reason} ->
    IO.puts("❌ Error loading LCL_Skirt_DressEvening_003 info: #{reason}")
end

# Test all garments summary
IO.puts("\n📋 Test 5: All garments summary")
garments = [
  {"Puffer_dense", "../garment-data/assets/garments/Puffer_dense/garment.obj"},
  {"jumpsuit_dense", jumpsuit_path},
  {"LCL_Skirt_DressEvening_003", skirt_path}
]

IO.puts("Garment Summary:")
Enum.each(garments, fn {name, path} ->
  case ClothFitCli.PolyFEM.load_garment_info(path) do
    {:ok, info} ->
      IO.puts("  #{name}: #{info["vertex_count"]}v, #{info["face_count"]}f")
    {:error, _} ->
      IO.puts("  #{name}: ❌ Failed to load")
  end
end)

IO.puts("\n🎉 Remaining garments testing complete!")

# Test all available avatars
IO.puts("🧪 Testing All Avatar Files")
IO.puts("=" |> String.duplicate(40))

avatars = [
  "../garment-data/assets/avatars/FoxGirl/avatar.obj",
  "../garment-data/assets/avatars/Goblin/avatar.obj",
  "../garment-data/assets/avatars/T-rex/avatar.obj"
]

Enum.each(avatars, fn avatar_path ->
  avatar_name = Path.basename(Path.dirname(avatar_path))
  IO.puts("\n📋 Testing #{avatar_name} avatar:")

  case ClothFitCli.PolyFEM.validate_avatar_mesh(avatar_path) do
    {:ok, true} ->
      IO.puts("✅ Avatar mesh validation passed")
    {:ok, false} ->
      IO.puts("⚠️  Avatar mesh validation failed")
    {:error, reason} ->
      IO.puts("❌ Error validating avatar: #{reason}")
  end

  case ClothFitCli.PolyFEM.load_avatar_info(avatar_path) do
    {:ok, info} ->
      IO.puts("   Vertices: #{info["vertex_count"]}")
      IO.puts("   Faces: #{info["face_count"]}")
      bbox = info["bounding_box"]["size"]
      height_to_width = Enum.at(bbox, 1) / max(Enum.at(bbox, 0), Enum.at(bbox, 2))
      IO.puts("   Height/Width ratio: #{Float.round(height_to_width, 2)}")
    {:error, reason} ->
      IO.puts("❌ Error loading avatar info: #{reason}")
  end
end)

IO.puts("\n🎉 Avatar testing complete!")

# Test script for actual simulation execution
IO.puts("🧪 Testing Actual Simulation Execution via NIFs")
IO.puts("=" |> String.duplicate(60))

# Helper function to run a simulation test
test_simulation = fn name, setup_path, expected_duration ->
  IO.puts("\n📋 Testing #{name} simulation")
  IO.puts("Setup: #{setup_path}")

  # Create unique output directory
  timestamp = DateTime.utc_now() |> DateTime.to_unix()
  output_dir = "test_results/#{name}_#{timestamp}"

  IO.puts("Output: #{output_dir}")

  # Ensure output directory exists
  File.mkdir_p!(output_dir)

  # Record start time
  start_time = System.monotonic_time(:millisecond)

  # Run the simulation
  case ClothFitCli.PolyFEM.simulate_from_setup(setup_path, output_dir) do
    {:ok, result} ->
      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time
      duration_sec = duration_ms / 1000

      IO.puts("✅ #{name} simulation completed successfully!")
      IO.puts("   Duration: #{Float.round(duration_sec, 2)} seconds")
      IO.puts("   Result: #{inspect(result)}")

      # Check if output files were created
      case File.ls(output_dir) do
        {:ok, files} ->
          if Enum.empty?(files) do
            IO.puts("   ⚠️  No output files generated")
          else
            IO.puts("   📁 Output files (#{length(files)}):")
            Enum.each(files, fn file ->
              file_path = Path.join(output_dir, file)
              case File.stat(file_path) do
                {:ok, %File.Stat{size: size}} ->
                  IO.puts("      - #{file} (#{size} bytes)")
                {:error, _} ->
                  IO.puts("      - #{file}")
              end
            end)
          end
        {:error, reason} ->
          IO.puts("   ❌ Failed to list output files: #{reason}")
      end

      # Check if duration is reasonable
      if duration_sec > expected_duration do
        IO.puts("   ⚠️  Simulation took longer than expected (#{expected_duration}s)")
      else
        IO.puts("   ✅ Simulation completed within expected time")
      end

      {:ok, duration_sec}

    {:error, reason} ->
      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time
      duration_sec = duration_ms / 1000

      IO.puts("❌ #{name} simulation failed!")
      IO.puts("   Duration: #{Float.round(duration_sec, 2)} seconds")
      IO.puts("   Error: #{reason}")

      {:error, reason}
  end
end

# Test configurations with expected durations (in seconds)
simulation_configs = [
  {"foxgirl_skirt", "../garment-data/foxgirl_skirt/setup.json", 420},  # 7 minutes
  {"Goblin_Jacket", "../garment-data/Goblin_Jacket/setup.json", 420},
  {"Goblin_Jumpsuit", "../garment-data/Goblin_Jumpsuit/setup.json", 420},
  {"Trex_Jacket", "../garment-data/Trex_Jacket/setup.json", 420}
]

IO.puts("\n🚀 Starting simulation tests...")
IO.puts("Expected max duration per simulation: 7 minutes")
IO.puts("Total expected max time: #{length(simulation_configs) * 7} minutes")

# Run all simulations and collect results
results = Enum.map(simulation_configs, fn {name, path, expected_duration} ->
  result = test_simulation.(name, path, expected_duration)

  # Add a small delay between simulations
  Process.sleep(1000)

  {name, result}
end)

# Summary
IO.puts("\n📊 Simulation Test Summary")
IO.puts("=" |> String.duplicate(40))

total_time = 0
successful_count = 0
failed_count = 0

Enum.each(results, fn {name, result} ->
  case result do
    {:ok, duration} ->
      IO.puts("✅ #{name}: #{Float.round(duration, 2)}s")
      total_time = total_time + duration
      successful_count = successful_count + 1
    {:error, reason} ->
      IO.puts("❌ #{name}: #{reason}")
      failed_count = failed_count + 1
  end
end)

IO.puts("\nOverall Results:")
IO.puts("  Successful: #{successful_count}/#{length(simulation_configs)}")
IO.puts("  Failed: #{failed_count}/#{length(simulation_configs)}")
IO.puts("  Total time: #{Float.round(total_time, 2)} seconds (#{Float.round(total_time/60, 2)} minutes)")

if successful_count == length(simulation_configs) do
  IO.puts("\n🎉 All simulations completed successfully!")
  IO.puts("✅ Core simulation functionality is working!")
else
  IO.puts("\n⚠️  Some simulations failed. Check the errors above.")
end

IO.puts("\n🎉 Simulation testing complete!")

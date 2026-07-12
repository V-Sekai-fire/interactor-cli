defmodule ClothFitCliTest do
  use ExUnit.Case
  doctest ClothFitCli

  test "greets the world" do
    assert ClothFitCli.hello() == :world
  end
end

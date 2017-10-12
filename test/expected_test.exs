defmodule ExpectedTest do
  use ExUnit.Case
  doctest Expected

  test "greets the world" do
    assert Expected.hello() == :world
  end
end

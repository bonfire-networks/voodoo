defmodule VoodooTest do
  use ExUnit.Case
  doctest Voodoo

  test "greets the world" do
    assert Voodoo.hello() == :world
  end
end

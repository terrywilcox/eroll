defmodule ErollTest do
  use ExUnit.Case
  doctest Eroll

  test "greets the world" do
    assert Eroll.hello() == :world
  end
end

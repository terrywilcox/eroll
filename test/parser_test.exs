defmodule Eroll.ParserTest do
  use ExUnit.Case

  test "parse a simple roll" do
    roll = "3d6"
    assert {:ok, [{"roll", [3, 6]}], "", %{}, {1, 0}, String.length(roll)} == Eroll.Parser.roll(roll)
  end

  test "parse a roll without number of dice" do
    roll = "d12"
    assert {:ok, [{"roll", [1, 12]}], "", %{}, {1, 0}, String.length(roll)} == Eroll.Parser.roll(roll)
  end

  test "parse a roll with exploding" do
    roll = "5d10!"
    assert {:ok, [{"explode", [{"roll", [5, 10]}]}], "", %{}, {1, 0}, String.length(roll)} == Eroll.Parser.roll(roll)
  end

  test "parse a roll with exploding on a number" do
    roll = "5d10!3"
    assert {:ok, [{"explode", [{"roll", [5, 10]}, 3]}], "", %{}, {1, 0}, String.length(roll)} == Eroll.Parser.roll(roll)
  end

  test "parse a roll with keep" do
    roll = "5d10kh10"
    assert {:ok, [{"keep", [{"roll", [5, 10]}, "highest", 10]}], "", %{}, {1, 0}, String.length(roll)} == Eroll.Parser.roll(roll)
  end

  test "parse a roll with keep and unspecified number" do
    roll = "5d10kh"
    assert {:ok, [{"keep", [{"roll", [5, 10]}, "highest"]}], "", %{}, {1, 0}, String.length(roll)} == Eroll.Parser.roll(roll)
  end

  test "parse a roll with drop" do
    roll = "5d10dl10"
    assert {:ok, [{"drop", [{"roll", [5, 10]}, "lowest", 10]}], "", %{}, {1, 0}, String.length(roll)} == Eroll.Parser.roll(roll)
  end

  test "parse an exploding roll drop" do
    roll = "5d10!dl10"
    assert {:ok, [{"drop", [{"explode", [{"roll", [5, 10]}]}, "lowest", 10]}], "", %{}, {1, 0}, String.length(roll)} == Eroll.Parser.roll(roll)
  end

  test "parse a roll with target less than target number" do
    roll = "3d4<3"
    assert {:ok, [{"target_lt", [{"roll", [3, 4]}, 3]}], "", %{}, {1, 0}, String.length(roll)} == Eroll.Parser.roll(roll)
  end

  test "parse a roll with everything capitalized" do
    roll = "24D8!5DL7<3"
    assert {:ok, [{"target_lt", [{"drop", [{"explode", [{"roll", [24, 8]}, 5]}, "lowest", 7]}, 3]}], "", %{}, {1, 0}, String.length(roll)} == Eroll.Parser.roll(roll)
  end

  test "parse a roll with addition" do
    roll = "(2d12+1)"
    assert {:ok, [{"add", [{"roll", [2, 12]}, 1]}], "", %{}, {1, 0}, String.length(roll)} == Eroll.Parser.add_expr(roll)
  end

  test "parse a roll with variable" do
    roll = "(2d12+${ed})"
    assert {:ok, [{"add", [{"roll", [2, 12]}, {"variable", ["ed"]}]}], "", %{}, {1, 0}, String.length(roll)} == Eroll.Parser.add_expr(roll)
  end

  test "parse a roll with variable number of dice and sides" do
    roll = "${dice}d${sides}"
    assert {:ok, [{"roll", [{"variable", ["dice"]}, {"variable", ["sides"]}]}], "", %{}, {1, 0}, String.length(roll)} == Eroll.Parser.add_expr(roll)
  end

end



defmodule ErollTest do
  use ExUnit.Case
  doctest Eroll

  setup context do
    roll_list = Map.get(context, :roll_list, [2, 2, 2, 2, 2, 2, 2, 2, 2, 2])
    {:ok, agent} = Agent.start_link(fn -> roll_list end)
    random_fn = fn _ -> Agent.get_and_update(agent, fn [head | tail] -> {head, tail} end) end
    {:ok, agent: agent, random_fn: random_fn}
  end

  @tag roll_list: [3, 5, 2]
  test "evaluate a simple roll", context do
    roll = "3d6"
    assert 10 == Eroll.roll(roll, context)
  end

  @tag roll_list: [3, 5, 2, 9, 10, 10, 4]
  test "evaluate a roll with exploding", context do
    roll = "5d10!"
    assert 43 == Eroll.roll(roll, context)
  end

  @tag roll_list: [3, 5, 2, 9, 1, 3, 4]
  test "evaluate a roll with exploding on a number", context do
    roll = "5d10!3"
    assert 27 == Eroll.roll(roll, context)
  end

  @tag roll_list: [3, 5, 2, 9, 1]
  test "evaluate a roll with keep", context do
    roll = "5d10kh3"
    assert 17 == Eroll.roll(roll, context)
  end

  @tag roll_list: [3, 5, 2, 9, 1]
  test "evaluate a roll with keep more than all", context do
    roll = "5d10kh8"
    assert 20 == Eroll.roll(roll, context)
  end

  @tag roll_list: [3, 5, 2, 9, 1]
  test "evaluate a roll with drop", context do
    roll = "5d10dl3"
    assert 14 == Eroll.roll(roll, context)
  end

  @tag roll_list: [3, 5, 10, 9, 1, 10, 6]
  test "evaluate an exploding roll drop", context do
    roll = "5d10!dl3"
    assert 35 == Eroll.roll(roll, context)
  end

  @tag roll_list: [2, 5, 10]
  test "evaluate a roll with target less than target number", context do
    roll = "3d10<3"
    assert 1 == Eroll.roll(roll, context)
  end

  @tag roll_list: [3, 5, 10, 9, 1, 10, 6]
  test "evaluate an exploding roll drop with target", context do
    roll = "5d10!dl3>8"
    assert 3 == Eroll.roll(roll, context)
  end

  @tag roll_list: [3, 5]
  test "evaluate a roll with addition", context do
    roll = "2d12 + 1"
    assert 9 == Eroll.roll(roll, context)
  end

  @tag roll_list: [3, 5]
  test "evaluate a roll with variable", context do
    roll = "2d12 + ${ed}"
    new_context = Map.merge(%{"ed" => 2}, context)
    assert 10 == Eroll.roll(roll, new_context)
  end

  @tag roll_list: [3, 5]
  test "evaluate a roll with variable number of dice and sides", context do
    roll = "${dice}d${sides}"
    new_context = Map.merge(%{"dice" => 2, "sides" => 6}, context)
    assert 8 == Eroll.roll(roll, new_context)
  end

  @tag roll_list: [1, 5, 1, 4, 1, 6]
  test "evaluate an exploding roll keep with target with variables", context do
    roll = "3d6!${explode_target}kh${keep_number}>${target_number}"

    new_context =
      Map.merge(%{"explode_target" => 1, "keep_number" => 3, "target_number" => 5}, context)

    assert 2 == Eroll.roll(roll, new_context)
  end
end

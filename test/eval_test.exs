defmodule Eroll.EvaluateTest do
  use ExUnit.Case

  setup context do
    roll_list = Map.get(context, :roll_list, [2, 2, 2, 2, 2, 2, 2, 2, 2, 2])

    {:ok, agent} = Agent.start_link(fn -> roll_list end)

    random_fn = fn _ -> Agent.get_and_update(agent, fn [head | tail] -> {head, tail} end) end

    {:ok, agent: agent, random_fn: random_fn}
  end

  @tag roll_list: [3, 5, 2]
  test "evaluate a simple roll", context do
    roll = [{"roll", [3, 6]}]
    assert 10 == Eroll.Evaluator.evaluate(roll, context)
  end

  @tag roll_list: [3, 5, 2, 9, 10, 10, 4]
  test "evaluate a roll with exploding", context do
    roll = [{"explode", [{"roll", [5, 10]}]}]
    assert 43 == Eroll.Evaluator.evaluate(roll, context)
  end

  @tag roll_list: [3, 5, 2, 9, 1, 3, 4]
  test "evaluate a roll with exploding on a number", context do
    roll = [{"explode", [{"roll", [5, 10]}, 3]}]
    assert 27 == Eroll.Evaluator.evaluate(roll, context)
  end

  @tag roll_list: [3, 5, 2, 9, 1, 8, 4]
  test "evaluate a roll with exploding above a number", context do
    roll = [{"explode", [{"roll", [5, 10]}, "gte", 8]}]
    assert 32 == Eroll.Evaluator.evaluate(roll, context)
  end

  @tag roll_list: [3, 5, 7, 9, 4, 2, 4]
  test "evaluate a roll with exploding below a number", context do
    roll = [{"explode", [{"roll", [5, 10]}, "lte", 3]}]
    assert 34 == Eroll.Evaluator.evaluate(roll, context)
  end

  @tag roll_list: [3, 5, 2, 9, 1]
  test "evaluate a roll with keep", context do
    roll = [{"keep", [{"roll", [5, 10]}, "highest", 3]}]
    assert 17 == Eroll.Evaluator.evaluate(roll, context)
  end

  @tag roll_list: [3, 5, 2, 9, 1]
  test "evaluate a roll with keep no number", context do
    roll = [{"keep", [{"roll", [5, 10]}, "lowest"]}]
    assert 1 == Eroll.Evaluator.evaluate(roll, context)
  end

  @tag roll_list: [3, 5, 2, 9, 1]
  test "evaluate a roll with just keep number", context do
    roll = [{"keep", [{"roll", [5, 10]}, 3]}]
    assert 17 == Eroll.Evaluator.evaluate(roll, context)
  end

  @tag roll_list: [3, 5, 2, 9, 1]
  test "evaluate a roll with just keep", context do
    roll = [{"keep", [{"roll", [5, 10]}]}]
    assert 9 == Eroll.Evaluator.evaluate(roll, context)
  end

  @tag roll_list: [3, 5, 2, 9, 1]
  test "evaluate a roll with just drop", context do
    roll = [{"drop", [{"roll", [5, 10]}]}]
    assert 19 == Eroll.Evaluator.evaluate(roll, context)
  end

  @tag roll_list: [3, 5, 2, 9, 1]
  test "evaluate a roll with just drop number", context do
    roll = [{"drop", [{"roll", [5, 10]}, 3]}]
    assert 14 == Eroll.Evaluator.evaluate(roll, context)
  end

  @tag roll_list: [3, 5, 2, 9, 1]
  test "evaluate a roll with keep more than all", context do
    roll = [{"keep", [{"roll", [5, 10]}, "highest", 8]}]
    assert 20 == Eroll.Evaluator.evaluate(roll, context)
  end

  @tag roll_list: [3, 5, 2, 9, 1]
  test "evaluate a roll with drop", context do
    roll = [{"drop", [{"roll", [5, 10]}, "lowest", 3]}]
    assert 14 == Eroll.Evaluator.evaluate(roll, context)
  end

  @tag roll_list: [3, 5, 10, 9, 1, 10, 6]
  test "evaluate an exploding roll drop", context do
    roll = [{"drop", [{"explode", [{"roll", [5, 10]}]}, "lowest", 3]}]
    assert 35 == Eroll.Evaluator.evaluate(roll, context)
  end

  @tag roll_list: [2, 5, 10]
  test "evaluate a roll with target less than target number", context do
    roll = [{"target_lt", [{"roll", [3, 10]}, 3]}]
    assert 1 == Eroll.Evaluator.evaluate(roll, context)
  end

  @tag roll_list: [3, 5, 10, 9, 1, 10, 6]
  test "evaluate an exploding roll drop with target", context do
    roll = [{"target_gt", [{"drop", [{"explode", [{"roll", [5, 10]}]}, "lowest", 3]}, 8]}]
    assert 3 == Eroll.Evaluator.evaluate(roll, context)
  end

  @tag roll_list: [3, 5]
  @tag :focus
  test "evaluate a roll with addition", context do
    roll = [{"add", [{"roll", [2, 12]}, {"integer", [1]}]}]
    assert 9 == Eroll.Evaluator.evaluate(roll, context)
  end

  @tag roll_list: [3, 5]
  test "evaluate a roll with variable", context do
    roll = [{"add", [{"roll", [2, 12]}, {"variable", ["ed"]}]}]
    new_context = Map.merge(%{"ed" => 2}, context)
    assert 10 == Eroll.Evaluator.evaluate(roll, new_context)
  end

  @tag roll_list: [3, 5]
  test "evaluate a roll with variable number of dice and sides", context do
    roll = [{"roll", [{"variable", ["dice"]}, {"variable", ["sides"]}]}]
    new_context = Map.merge(%{"dice" => 2, "sides" => 6}, context)
    assert 8 == Eroll.Evaluator.evaluate(roll, new_context)
  end

  @tag roll_list: [3, 5]
  test "evaluate a roll with variable number of dice and sides and lookup function", context do
    roll = [{"roll", [{"variable", ["dice"]}, {"variable", ["sides"]}]}]
    lookup_context = %{"dice" => 2, "sides" => 6}
    lookup_function = fn variable_name -> Map.get(lookup_context, variable_name, variable_name) end
    new_context = Map.merge(%{"lookup_function" => lookup_function}, context)
    assert 8 == Eroll.Evaluator.evaluate(roll, new_context)
  end

  @tag roll_list: [1, 5, 1, 4, 1, 6]
  test "evaluate an exploding roll keep with target with variables", context do
    roll = [
      {"target_gt",
       [
         {"keep",
          [
            {"explode",
             [
               {"roll", [3, 6]},
               {"variable", ["explode_target"]}
             ]},
            "highest",
            {"variable", ["keep_number"]}
          ]},
         {"variable", ["target_number"]}
       ]}
    ]

    new_context = Map.merge(%{"explode_target" => 1, "keep_number" => 3, "target_number" => 5}, context)
    assert 2 == Eroll.Evaluator.evaluate(roll, new_context)
  end
end

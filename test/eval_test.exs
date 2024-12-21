defmodule Eroll.EvaluateTest do
  use ExUnit.Case

  setup context do
    roll_list = Map.get(context, :roll_list, [2, 2, 2, 2, 2, 2, 2, 2, 2, 2])
    {:ok, agent} = Agent.start_link(fn -> roll_list end, name: __MODULE__)
    {:ok, agent: agent}
  end

  def next_item do
    Agent.get_and_update(__MODULE__, fn [head | tail]  -> {head, tail} end)
  end

  @tag roll_list: [3, 5, 2]
  test "evaluate a simple roll" do
    random_fn = fn _ -> next_item() end
    roll = [{"roll", [3, 6]}]
    assert 10 == Eroll.Evaluator.evaluate(roll, %{random_fn: random_fn})
  end

  @tag roll_list: [3, 5, 2, 9, 10, 10, 4]
  test "evaluate a roll with exploding" do
    random_fn = fn _ -> next_item() end
    roll = [{"explode", [{"roll", [5, 10]}]}]
    assert 43 == Eroll.Evaluator.evaluate(roll, %{random_fn: random_fn})
  end

  @tag roll_list: [3, 5, 2, 9, 1, 3, 4]
  test "evaluate a roll with exploding on a number" do
    random_fn = fn _ -> next_item() end
    roll = [{"explode", [{"roll", [5, 10]}, 3]}]
    assert 27 == Eroll.Evaluator.evaluate(roll, %{random_fn: random_fn})
  end

  @tag roll_list: [3, 5, 2, 9, 1]
  test "evaluate a roll with keep" do
    random_fn = fn _ -> next_item() end
    roll = [{"keep", [{"roll", [5, 10]}, "highest", 3]}]
    assert 17 == Eroll.Evaluator.evaluate(roll, %{random_fn: random_fn})
  end

  @tag roll_list: [3, 5, 2, 9, 1]
  test "evaluate a roll with keep more than all" do
    random_fn = fn _ -> next_item() end
    roll = [{"keep", [{"roll", [5, 10]}, "highest", 8]}]
    assert 20 == Eroll.Evaluator.evaluate(roll, %{random_fn: random_fn})
  end

  @tag roll_list: [3, 5, 2, 9, 1]
  test "evaluate a roll with drop" do
    random_fn = fn _ -> next_item() end
    roll = [{"drop", [{"roll", [5, 10]}, "lowest", 3]}]
    assert 14 == Eroll.Evaluator.evaluate(roll, %{random_fn: random_fn})
  end

  @tag roll_list: [3, 5, 10, 9, 1, 10, 6]
  test "evaluate an exploding roll drop" do
    random_fn = fn _ -> next_item() end
    roll = [{"drop", [{"explode", [{"roll", [5, 10]}]}, "lowest", 3]}]
    assert 35 == Eroll.Evaluator.evaluate(roll, %{random_fn: random_fn})
  end

  @tag roll_list: [2, 5, 10]
  test "evaluate a roll with target less than target number" do
    random_fn = fn _ -> next_item() end
    roll = [{"target_lt", [{"roll", [3, 10]}, 3]}]
    assert 1 == Eroll.Evaluator.evaluate(roll, %{random_fn: random_fn})
  end

  @tag roll_list: [3, 5]
  test "evaluate a roll with addition" do
    random_fn = fn _ -> next_item() end
    roll = [{"add", [{"roll", [2, 12]}, 1]}]
    assert 9 == Eroll.Evaluator.evaluate(roll, %{random_fn: random_fn})
  end

  @tag roll_list: [3, 5]
  test "evaluate a roll with variable" do
    random_fn = fn _ -> next_item() end
    roll = [{"add", [{"roll", [2, 12]}, {"variable", ["ed"]}]}]
    context = %{"ed" => 2, random_fn: random_fn}
    assert 10 == Eroll.Evaluator.evaluate(roll, context)
  end

  @tag roll_list: [3, 5]
  test "evaluate a roll with variable number of dice and sides" do
    random_fn = fn _ -> next_item() end
    roll = [{"roll", [{"variable", ["dice"]}, {"variable", ["sides"]}]}]
    context = %{"dice" => 2, "sides" => 6, random_fn: random_fn}
    assert 8 == Eroll.Evaluator.evaluate(roll, context)
  end

end



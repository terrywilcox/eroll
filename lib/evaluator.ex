defmodule Eroll.Evaluator do

  def evaluate(roll) do
    evaluate(roll, %{})
  end

  def evaluate(roll, context) do
    case eval(roll, context) do
      %{rolls: rolls} -> sum(rolls)
      x -> x
    end
  end

  def eval(roll) do
    eval(roll, %{})
  end

  def eval([term], context) when is_tuple(term) do
    eval(term, context)
  end

  def eval({"roll", [n, s]}, context) do
    number_of_dice = eval(n, context)
    dice_sides = eval(s, context)
    rolls = roll_dice(number_of_dice, dice_sides)
    %{number_of_dice: number_of_dice,
      dice_sides: dice_sides,
      rolls: rolls}
  end

  def eval({"explode", [roll, target]}, context) do
    rolls = eval(roll, context)
    explode(rolls, target)
  end

  def eval({"explode", roll}, context) do
    rolls = eval(roll, context)
    target = rolls.dice_sides
    explode(rolls, target)
  end

  def eval({cmd, [roll, h_or_l, n]}, context) when cmd == "keep" or cmd == "drop"  do
    rolls = eval(roll, context)
    keep(rolls, cmd, h_or_l, n)
  end

  def eval({cmd, [roll, n]}, context) when is_integer(n) and cmd == "keep" or cmd == "drop" do
    eval({cmd, [roll, "highest", n]}, context)
  end

  def eval({cmd, [roll, a]}, context) when cmd == "keep" or cmd == "drop" do
    eval({cmd, [roll, a, 1]}, context)
  end

  def eval({cmd, [roll]}, context) when cmd == "keep" or cmd == "drop" do
    eval({cmd, [roll, "highest", 1]}, context)
  end

  def eval({"target_lt", [roll, target]}, context) do
    rolls = eval(roll, context)
    target_lt(rolls, target)
  end

  def eval({"target_gt", [roll, target]}, context) do
    rolls = eval(roll, context)
    target_gt(rolls, target)
  end

  def eval({"add", [l, r]}, context) do
    left = eval(l, context)
    right = eval(r, context)
    sum(left) + sum(right)
  end

  def eval({"subtract", [l, r]}, context) do
    left = eval(l, context)
    right = eval(r, context)
    sum(left) - sum(right)
  end

  def eval({"multiply", [l, r]}, context) do
    left = eval(l, context)
    right = eval(r, context)
    sum(left) * sum(right)
  end

  def eval({"divide", [l, r]}, context) do
    left = eval(l, context)
    right = eval(r, context)
    sum(left) / sum(right)
  end

  def eval({"variable", [v]}, context) do
    Map.get(context, v)
  end

  def eval(x, _context) do
    x
  end

  defp roll_dice(number_of_dice, dice_sides) do
    for n <- 1..number_of_dice, do: {n, random(dice_sides), "keep"}
  end

  defp count_exploders(rolls, target) do
    Enum.count(rolls, fn {_, value, keep} -> value == target and keep == "keep" end)
  end

  defp explode(roll, target) do
    initial_rolls = roll.rolls
    sides = roll.dice_sides

    number_of_explosions = count_exploders(initial_rolls, target)
    exploded_rolls = explode(number_of_explosions, target, sides, initial_rolls)
    reindex_rolls = exploded_rolls
      |> Enum.with_index(1)
      |> Enum.map(fn {{_, value, keep}, index} -> {index, value, keep} end)

    %{roll | rolls: reindex_rolls}
  end

  defp explode(0, _target, _sides, acc) do
    acc
  end

  defp explode(number_of_explosions, target, sides, acc) do
    rolls_from_explosions = roll_dice(number_of_explosions, sides)
    number_exploders = count_exploders(rolls_from_explosions, target)
    explode(number_exploders, target, sides, acc ++ rolls_from_explosions)
  end

  defp keep(roll, keep_or_drop, high_or_low, number) do
    existing_rolls = roll.rolls

    sorted_rolls = case high_or_low do
      "highest" -> Enum.sort_by(existing_rolls, fn {_, value, _} -> value end, :desc)
      "lowest" -> Enum.sort_by(existing_rolls, fn {_, value, _} -> value end)
    end

    {affected, unaffected} = Enum.split(sorted_rolls, number)

    {keep, drop} =
      case keep_or_drop do
        "keep" -> {affected, unaffected}
        "drop" -> {unaffected, affected}
      end

    to_drop = Enum.map(drop, fn{index, value, _} -> {index, value, "drop"} end)

    new_rolls = keep ++ to_drop
      |> Enum.sort_by(fn {index, _, _} -> index end)

    %{roll | rolls: new_rolls} 
  end

  defp target_gt(roll, target) do
    successes = Enum.count(roll.rolls, fn {_, value, keep} -> value >= target and keep == "keep" end)
    Map.put(roll, :successes, successes)
  end

  defp target_lt(roll, target) do
    successes = Enum.count(roll.rolls, fn {_, value, keep} -> value <= target and keep == "keep" end)
    Map.put(roll, :successes, successes)
  end

  defp sum(x) when is_integer(x) do
    x
  end

  defp sum(rolls) when is_list(rolls) do
    rolls
      |> Enum.filter(fn {_, _, keep} -> keep == "keep" end)
      |> Enum.map(fn {_, value, _} -> value end)
      |> Enum.sum
  end

  defp sum(%{} = roll) do
    sum(roll.rolls)
  end

  defp random(n) do
    :rand.uniform(n)
  end

end

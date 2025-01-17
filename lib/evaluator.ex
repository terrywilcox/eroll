defmodule Eroll.Evaluator do
  defstruct value: 0, dice_sides: 0, rolls: []
  alias Eroll.Evaluator

  def evaluate(roll) do
    evaluate(roll, %{})
  end

  def evaluate(roll, context) do
    %Evaluator{value: value, rolls: rolls} = eval(roll, context)

    case Map.get(context, "debug") do
      nil ->
        value

      _ ->
        {value, rolls}
    end
  end

  defp eval([term], context) when is_tuple(term) do
    eval(term, context)
  end

  defp eval({"roll", [n, s]}, context) do
    number_of_dice = value(eval(n, context))
    dice_sides = value(eval(s, context))

    rolls = roll_dice(number_of_dice, dice_sides, context)
    value = sum_rolls(rolls)

    %Evaluator{
      value: value,
      dice_sides: dice_sides,
      rolls: rolls
    }
  end

  defp eval({"explode", [roll, above_or_below, target]}, context) do
    rolls = eval(roll, context)
    target_number = value(eval(target, context))
    explode(rolls, target_number, above_or_below, context)
  end

  defp eval({"explode", [roll, target]}, context) do
    rolls = eval(roll, context)
    target_number = value(eval(target, context))
    explode(rolls, target_number, "equal", context)
  end

  defp eval({"explode", roll}, context) do
    %Evaluator{dice_sides: dice_sides} = rolls = eval(roll, context)
    explode(rolls, dice_sides, "equal", context)
  end

  defp eval({cmd, [roll, h_or_l, n]}, context) when cmd == "keep" or cmd == "drop" do
    rolls = eval(roll, context)
    number = value(eval(n, context))
    keep(rolls, cmd, h_or_l, number)
  end

  defp eval({cmd, [roll, n]}, context) when (is_integer(n) and cmd == "keep") or cmd == "drop" do
    high_or_low = case cmd do
      "keep" -> "highest"
      "drop" -> "lowest"
    end

    eval({cmd, [roll, high_or_low, n]}, context)
  end

  defp eval({cmd, [roll, high_or_low]}, context) when cmd == "keep" or cmd == "drop" do
    eval({cmd, [roll, high_or_low, 1]}, context)
  end

  defp eval({cmd, [roll]}, context) when cmd == "keep" or cmd == "drop" do
    high_or_low = case cmd do
      "keep" -> "highest"
      "drop" -> "lowest"
    end

    eval({cmd, [roll, high_or_low, 1]}, context)
  end

  defp eval({cmd, [roll]}, context) when cmd == "keep" or cmd == "drop" do
    eval({cmd, [roll, "highest", 1]}, context)
  end

  defp eval({"target_lt", [roll, target]}, context) do
    rolls = eval(roll, context)
    target_number = value(eval(target, context))
    target_lt(rolls, target_number)
  end

  defp eval({"target_gt", [roll, target]}, context) do
    rolls = eval(roll, context)
    target_number = value(eval(target, context))
    target_gt(rolls, target_number)
  end

  defp eval({operator, [l, r]}, context)
       when operator in ["add", "subtract", "multiply", "divide"] do
    left = eval(l, context)
    right = eval(r, context)
    value = merge_values(left, operator, right)
    rolls = merge_rolls(left, operator, right)
    %Evaluator{value: value, rolls: rolls}
  end

  defp eval({"variable", [v]}, context) do
    lookup_function = Map.get(context, "lookup_function", fn v -> Map.get(context, v, v) end)
    value = lookup_function.(v)
    %Evaluator{value: value, rolls: value}
  end

  defp eval({"integer", [v]}, _context) do
    %Evaluator{value: v, rolls: v}
  end

  defp eval(x, _context) when is_integer(x) do
    %Evaluator{value: x, rolls: x}
  end

  defp merge_rolls(%Evaluator{rolls: left_rolls}, operator, %Evaluator{rolls: right_rolls}) do
    [left_rolls, operator_symbol(operator), right_rolls]
  end

  defp merge_values(%Evaluator{} = left_term, operator, %Evaluator{} = right_term) do
    left = value(left_term)
    right = value(right_term)

    case operator do
      "add" -> left + right
      "subtract" -> left - right
      "multiply" -> left * right
      "divide" -> left / right
    end
  end

  defp roll_dice(number_of_dice, dice_sides, context) do
    for index <- 1..number_of_dice, do: {index, random(dice_sides, context), "keep"}
  end

  defp count_exploders(rolls, target, "equal") do
    Enum.count(rolls, fn {_, value, keep} -> value == target and keep == "keep" end)
  end

  defp count_exploders(rolls, target, "gte") do
    Enum.count(rolls, fn {_, value, keep} -> value >= target and keep == "keep" end)
  end

  defp count_exploders(rolls, target, "lte") do
    Enum.count(rolls, fn {_, value, keep} -> value <= target and keep == "keep" end)
  end

  defp explode(
         %Evaluator{rolls: rolls, dice_sides: sides} = roll,
         target,
         comparison,
         context
       ) do
    number_of_explosions = count_exploders(rolls, target, comparison)
    exploded_rolls = explode(number_of_explosions, target, comparison, sides, rolls, context)
    value = sum_rolls(exploded_rolls)

    reindex_rolls =
      exploded_rolls
      |> Enum.with_index(1)
      |> Enum.map(fn {{_, value, keep}, index} -> {index, value, keep} end)

    %{roll | value: value, rolls: reindex_rolls}
  end

  defp explode(0, _target, _sides, _comparison, acc, _context) do
    acc
  end

  defp explode(number_of_explosions, target, comparison, sides, acc, context) do
    rolls_from_explosions = roll_dice(number_of_explosions, sides, context)
    number_exploders = count_exploders(rolls_from_explosions, target, comparison)
    explode(number_exploders, target, comparison, sides, acc ++ rolls_from_explosions, context)
  end

  defp keep(
         %Evaluator{rolls: rolls} = roll,
         keep_or_drop,
         high_or_low,
         number
       ) do
    sorted_rolls =
      case high_or_low do
        "highest" -> Enum.sort_by(rolls, fn {_, value, _} -> value end, :desc)
        "lowest" -> Enum.sort_by(rolls, fn {_, value, _} -> value end)
      end

    {affected, unaffected} = Enum.split(sorted_rolls, number)

    {keep, drop} =
      case keep_or_drop do
        "keep" -> {affected, unaffected}
        "drop" -> {unaffected, affected}
      end

    to_drop = Enum.map(drop, fn {index, value, _} -> {index, value, "drop"} end)

    new_rolls =
      (keep ++ to_drop)
      |> Enum.sort_by(fn {index, _, _} -> index end)

    value = sum_rolls(new_rolls)

    %{roll | value: value, rolls: new_rolls}
  end

  defp target_gt(%Evaluator{rolls: rolls} = roll, target) do
    annotated =
      Enum.map(rolls, fn {index, value, keep} ->
        if value >= target and keep == "keep" do
          {index, value, keep, "success"}
        else
          {index, value, keep, "failure"}
        end
      end)

    successes =
      Enum.count(annotated, fn {_, _, _, success} -> success == "success" end)

    %{roll | value: successes, rolls: annotated}
  end

  defp target_lt(%Evaluator{rolls: rolls} = roll, target) do
    annotated =
      Enum.map(rolls, fn {index, value, keep} ->
        if value <= target and keep == "keep" do
          {index, value, keep, "success"}
        else
          {index, value, keep, "failure"}
        end
      end)

    successes =
      Enum.count(annotated, fn {_, _, _, success} -> success == "success" end)

    %{roll | value: successes, rolls: annotated}
  end

  defp sum_rolls(rolls) when is_list(rolls) do
    rolls
    |> Enum.filter(fn {_, _, keep} -> keep == "keep" end)
    |> Enum.map(fn {_, value, _} -> value end)
    |> Enum.sum()
  end

  defp random(n, %{random_fn: random_fn}) do
    random_fn.(n)
  end

  defp random(n, _context) do
    :rand.uniform(n)
  end

  defp value(%Evaluator{value: value}) do
    value
  end

  defp value(x) do
    x
  end

  defp operator_symbol("add"), do: "+"
  defp operator_symbol("subtract"), do: "-"
  defp operator_symbol("multiply"), do: "*"
  defp operator_symbol("divide"), do: "/"
end

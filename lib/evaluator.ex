defmodule Eroll.Evaluator do
  defstruct value: 0, description: "", number_of_dice: 0, dice_sides: 0, rolls: []
  alias Eroll.Evaluator

  def evaluate(roll) do
    evaluate(roll, %{})
  end

  def evaluate(roll, context) do
    case eval(roll, context) do
      eval_roll when is_map(eval_roll) ->
        sum(eval_roll)
      any ->
        any
    end
  end

  defp eval([term], context) when is_tuple(term) do
    eval(term, context)
  end

  defp eval({"roll", [n, s]}, context) do
    number_of_dice = value(eval(n, context))
    dice_sides = value(eval(s, context))

    rolls = roll_dice(number_of_dice, dice_sides, context)
    value = sum(rolls)
    description = "#{number_of_dice}d#{dice_sides}"

    %Evaluator{
      value: value,
      description: description,
      number_of_dice: number_of_dice,
      dice_sides: dice_sides,
      rolls: rolls
    }
  end

  defp eval({"explode", [roll, target]}, context) do
    rolls = eval(roll, context)
    target_number = value(eval(target, context))
    explode(rolls, target_number, context)
  end

  defp eval({"explode", roll}, context) do
    %Evaluator{dice_sides: dice_sides} = rolls = eval(roll, context)
    explode(rolls, dice_sides, context)
  end

  defp eval({cmd, [roll, h_or_l, n]}, context) when cmd == "keep" or cmd == "drop" do
    rolls = eval(roll, context)
    number = value(eval(n, context))
    keep(rolls, cmd, h_or_l, number)
  end

  defp eval({cmd, [roll, n]}, context) when (is_integer(n) and cmd == "keep") or cmd == "drop" do
    eval({cmd, [roll, "highest", n]}, context)
  end

  defp eval({cmd, [roll, a]}, context) when cmd == "keep" or cmd == "drop" do
    eval({cmd, [roll, a, 1]}, context)
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

  defp eval({"add", [l, r]}, context) do
    left = eval(l, context)
    right = eval(r, context)
    sum(left) + sum(right)
  end

  defp eval({"subtract", [l, r]}, context) do
    left = eval(l, context)
    right = eval(r, context)
    sum(left) - sum(right)
  end

  defp eval({"multiply", [l, r]}, context) do
    left = eval(l, context)
    right = eval(r, context)
    sum(left) * sum(right)
  end

  defp eval({"divide", [l, r]}, context) do
    left = eval(l, context)
    right = eval(r, context)
    sum(left) / sum(right)
  end

  defp eval({"variable", [v]}, context) do
    %Evaluator{value: Map.get(context, v, 0), description: "variable #{v}"}
  end

  defp eval({"integer", [v]}, _context) do
    v
  end

  defp eval(x, _context) do
    x
  end

  defp roll_dice(number_of_dice, dice_sides, context) do
    for index <- 1..number_of_dice, do: {index, random(dice_sides, context), "keep"}
  end

  defp count_exploders(rolls, target) do
    Enum.count(rolls, fn {_, value, keep} -> value == target and keep == "keep" end)
  end

  defp explode(
         %Evaluator{rolls: rolls, description: description, dice_sides: sides} = roll,
         target,
         context
       ) do
    number_of_explosions = count_exploders(rolls, target)
    exploded_rolls = explode(number_of_explosions, target, sides, rolls, context)
    value = sum(exploded_rolls)
    description = "#{description} explode on #{target}"

    reindex_rolls =
      exploded_rolls
      |> Enum.with_index(1)
      |> Enum.map(fn {{_, value, keep}, index} -> {index, value, keep} end)

    %{roll | value: value, rolls: reindex_rolls, description: description}
  end

  defp explode(0, _target, _sides, acc, _context) do
    acc
  end

  defp explode(number_of_explosions, target, sides, acc, context) do
    rolls_from_explosions = roll_dice(number_of_explosions, sides, context)
    number_exploders = count_exploders(rolls_from_explosions, target)
    explode(number_exploders, target, sides, acc ++ rolls_from_explosions, context)
  end

  defp keep(
         %Evaluator{rolls: rolls, description: description} = roll,
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

    value = sum(new_rolls)
    description = "#{description} #{keep_or_drop} #{high_or_low} #{number}"

    %{roll | value: value, rolls: new_rolls, description: description}
  end

  defp target_gt(%Evaluator{rolls: rolls, description: description} = roll, target) do
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

    description = "#{description} succeed on #{target} or more"

    %{roll | value: successes, rolls: annotated, description: description}
  end

  defp target_lt(%Evaluator{rolls: rolls, description: description} = roll, target) do
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

    description = "#{description} succeed on #{target} or less"

    %{roll | value: successes, rolls: annotated, description: description}
  end

  defp sum(value) do
    sum(value, [])
  end

  defp sum(%Evaluator{value: value} = _s, _) do
    value
  end

  defp sum(x, _) when is_integer(x) do
    x
  end

  defp sum(rolls, _) when is_list(rolls) do
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
end

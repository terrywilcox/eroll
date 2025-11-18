defmodule Eroll.Parser do
  import NimbleParsec

  # any positive integer
  unsigned_integer = integer(min: 1)

  # any integer
  signed_integer =
    optional(ascii_char([?-]))
    |> concat(integer(min: 1))
    |> reduce(:integer_value)

  # a variable of the form ${[a-zA-Z_-.]+}
  variable =
    ascii_char([?$])
    |> concat(ascii_char([?{]))
    |> concat(ascii_string([?a..?z, ?A..?Z, ?_, ?., ?-], min: 1))
    |> concat(ascii_char([?}]))
    |> reduce(:variable)

  # numbers or variables?
  const = [variable, signed_integer] |> choice()

  # roll values are positive integers or variables
  roll_value = [variable, unsigned_integer] |> choice()

  roll_d =
    ascii_char([?d, ?D])
    |> replace("roll")

  dice =
    optional(roll_value)
    |> concat(roll_d)
    |> concat(roll_value)
    |> reduce(:group)

  # handle the keep/drop highest/lowest stuff, all optional
  # kh3, kl3, dh3, dl3 or just k3 which is implicitly highest

  highest =
    ascii_char([?h, ?H])
    |> replace("highest")

  lowest =
    ascii_char([?l, ?L])
    |> replace("lowest")

  keep =
    ascii_char([?k, ?K])
    |> replace("keep")

  drop =
    ascii_char([?d, ?D])
    |> replace("drop")

  keep_term =
    optional(
      [keep, drop]
      |> choice()
      |> concat(optional(choice([highest, lowest])))
      |> concat(optional(roll_value))
      |> reduce(:group)
    )

  explode_gte = ascii_char([?>]) |> replace("gte")
  explode_lte = ascii_char([?<]) |> replace("lte")

  explode_target =
    optional([explode_gte, explode_lte] |> choice())
    |> concat(roll_value)

  explode =
    optional(
      ascii_char([?!])
      |> replace("explode")
      |> concat(optional(explode_target))
      |> reduce(:group)
    )

  target_gt =
    ascii_char([?>])
    |> replace("target_gt")
    |> concat(roll_value)

  target_lt =
    ascii_char([?<])
    |> replace("target_lt")
    |> concat(roll_value)

  target_number = optional([target_gt, target_lt] |> choice() |> reduce(:group))

  roll =
    dice
    |> concat(explode)
    |> concat(keep_term)
    |> concat(target_number)
    |> reduce(:postfix)

  ws = optional(ignore(ascii_char([?\s, ?\t]) |> times(min: 1)))

  # operators
  add =
    ws
    |> ascii_char([?+])
    |> concat(ws)
    |> replace("add")

  subtract =
    ws
    |> ascii_char([?-])
    |> concat(ws)
    |> replace("subtract")

  multiply =
    ws
    |> ascii_char([?*])
    |> concat(ws)
    |> replace("multiply")

  divide =
    ws
    |> ascii_char([?/])
    |> concat(ws)
    |> replace("divide")

  lparen = ascii_char([?(]) |> label("(")
  rparen = ascii_char([?)]) |> label(")")

  bracket_term = ignore(lparen) |> parsec(:expr) |> ignore(rparen)

  defcombinatorp(
    :primary,
    ws
    |> concat([bracket_term, roll, const] |> choice())
    |> concat(ws)
  )

  defparsecp(
    :term,
    parsec(:primary)
    |> repeat(
      [multiply, divide]
      |> choice()
      |> parsec(:primary)
    )
    |> reduce(:fold_infixl)
  )

  defparsec(
    :expr,
    parsec(:term)
    |> repeat(
      [add, subtract]
      |> choice()
      |> parsec(:term)
    )
    |> reduce(:fold_infixl)
  )

  defp variable([?$, ?{, name, ?}]) do
    {"variable", [name]}
  end

  defp integer_value([?-, value]) when is_integer(value) do
    {"integer", [-value]}
  end

  defp integer_value([_, value]) do
    {"integer", [value]}
  end

  defp integer_value([value]) do
    {"integer", [value]}
  end

  defp fold_infixl(acc) do
    acc
    |> Enum.reverse()
    |> Enum.chunk_every(2)
    |> List.foldr([], fn
      [l], [] -> l
      [r, op], l -> {op, [l, r]}
    end)
  end

  defp group(l) when is_list(l) do
    List.to_tuple(l)
  end

  defp postfix([{"roll", s} | more]) do
    postfix(more, {"roll", [1, s]})
  end

  defp postfix([{n, "roll", s} | more]) do
    postfix(more, {"roll", [n, s]})
  end

  defp postfix([], acc) do
    acc
  end

  defp postfix([{cmd, a, b} | more], acc) do
    postfix(more, {cmd, [acc, a, b]})
  end

  defp postfix([{cmd, a} | more], acc) do
    postfix(more, {cmd, [acc, a]})
  end

  defp postfix([{cmd} | more], acc) do
    postfix(more, {cmd, [acc]})
  end

  def parse(roll) do
    case expr(roll) do
      {:ok, result, _, _, _, _} ->
        result

      _ ->
        {:error, "parse error"}
    end
  end
end

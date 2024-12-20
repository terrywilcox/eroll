defmodule Eroll.Parser do
  import NimbleParsec

  # any positive integer
  pos_int = integer(min: 1)

  #any integer
  int = optional(ascii_char([?-])) |> concat(integer(min: 1))

  # a variable of the form ${[a-zA-Z_]+}
  variable = ascii_char([?$])
            |> concat(ascii_char([?{]))
            |> concat(ascii_string([?a..?z,?A..?Z,?_], min: 1))
            |> concat(ascii_char([?}]))
            |> reduce(:variable)

  # dice values are positive integers
  dice_value = [variable, pos_int] |> choice()

# numbers or variables?
  const = [variable, int] |> choice()

# handle the keep/drop highest/lowest stuff, all optional
# kh3, kl3, dh3, dl3 or just k3 which is implicitly highest

  highest = ascii_char([?h, ?H])
            |> replace("highest")

  lowest = ascii_char([?l, ?L])
            |> replace("lowest")

  keep = ascii_char([?k, ?K])
            |> replace("keep")

  drop = ascii_char([?d, ?D])
            |> replace("drop")

  keep_term = optional([keep, drop]
            |> choice()
            |> concat(optional(choice([highest, lowest])))
            |> concat(optional(dice_value))
            |> reduce(:group))

  roll_d = ascii_char([?d, ?D])
            |> replace("roll")

  explode = optional(ascii_char([?!])
            |> replace("explode")
            |> concat(optional(dice_value))
            |> reduce(:group))

  target_gt = ascii_char([?>])
            |> replace("target_gt")
            |> concat(dice_value)

  target_lt = ascii_char([?<])
            |> replace("target_lt")
            |> concat(dice_value)

  target = optional([target_gt, target_lt] |> choice() |> reduce(:group))

  dice = optional(dice_value) # this can be a variable or an expression
            |> concat(roll_d)
            |> concat(dice_value) # this can be a variable or expression
            |> reduce(:group)

  roll = dice # this can be a variable or an expression
            |> concat(explode)
            |> concat(keep_term)
            |> concat(target)
            |> reduce(:postfix)

  # operators
  add = ascii_char([?+])
            |> replace("add")
  subtract = ascii_char([?-])
            |> replace("subtract")
  multiply = ascii_char([?*])
            |> replace("multiply")
  divide = ascii_char([?/])
            |> replace("divide")

  lparen = ascii_char([?(]) |> label("(")
  rparen = ascii_char([?)]) |> label(")")
  whitespace = ascii_char([?\s, ?\t]) |> times(min: 1)

  defcombinatorp(
    :math_expr_factor,
      optional(ignore(whitespace)) |>
      concat( [ignore(lparen) |> parsec(:math_expr) |> ignore(rparen),
       roll,
       const
      ] |> choice()) |>
      concat(optional(ignore(whitespace)))
  )

  defparsecp(
    :math_expr_term,
      parsec(:math_expr_factor)
      |> repeat([multiply, divide]
        |> choice()
        |> parsec(:math_expr_factor)
      )
      |> reduce(:fold_infixl)
    )

  defparsec(
    :math_expr,
      parsec(:math_expr_term)
      |> repeat([add, subtract]
        |> choice()
        |> parsec(:math_expr_term))
      |> reduce(:fold_infixl)
    )

  defp variable([?$, ?{, name, ?}]) do
    {"variable", [name]}
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

  defp postfix [{"roll", s} | more] do
    postfix(more, {"roll", [1, s]})
   end

  defp postfix [{n, "roll", s} | more] do
    postfix(more, {"roll", [n, s]})
   end

  defp postfix [], acc do
    acc
   end
  defp postfix [{cmd, a, b} | more], acc do
    postfix(more, {cmd, [acc, a, b]})
   end
  defp postfix [{cmd, a} | more], acc do
    postfix(more, {cmd, [acc, a]})
   end
  defp postfix [{cmd} | more], acc do
    postfix(more, {cmd, [acc]})
   end

  defparsec :roll, roll, debug: true

  def parse(roll) do
    case math_expr(roll) do
      {:ok, result, _, _, _, _} ->
        result
      {:error, _} -> {:error, "parse error"}
    end
  end

end

defmodule Eroll.Preprocessor do
  def macro_regex do
    ~r/\?\{([a-zA-Z0-9_.\-]+)\}/
  end

  def inline_roll_regex do
    ~r/\[\[(.*?)\]\]/
  end

  def preprocess(roll, context) do
    macro_function = Map.get(context, "macro_function", fn(name) -> Map.get(context, name, name) end)
    inline_function = Map.get(context, "inline_function", fn(inline) -> Integer.to_string(Eroll.roll(inline, context)) end)
    new_roll = process_macros(roll, macro_function)
    process_inline_rolls(new_roll, inline_function)
  end

  defp process_macros(roll, macro_function) do
    macros = Regex.scan(macro_regex(), roll)
    process_macros(macros, roll, macro_function)
  end

  defp process_macros([], roll, _macro_function) do
    roll
  end

  defp process_macros([[full, name] | rest], roll, macro_function) do
    replacement = macro_function.(name)
    new_roll = String.replace(roll, full, replacement)
    process_macros(rest, new_roll, macro_function)
  end

  defp process_inline_rolls(roll, inline_function) do
    inline_rolls = Regex.scan(inline_roll_regex(), roll)
    process_inline_rolls(inline_rolls, roll, inline_function)
  end

  defp process_inline_rolls([], roll, _inline_function) do
    roll
  end

  defp process_inline_rolls([[full, inline] | rest], roll, inline_function) do
    replacement = inline_function.(inline)
    new_roll = String.replace(roll, full, replacement)
    process_inline_rolls(rest, new_roll, inline_function)
  end


end

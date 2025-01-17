defmodule Eroll.Preprocessor do
  def regex do
    ~r/\?\{([a-zA-Z0-9_.\-]+)\}/
  end

  def preprocess(roll, context) do
    macro_function = Map.get(context, "macro_function", fn(name) -> Map.get(context, name, name) end)
    process_macros(roll, macro_function)
  end

  defp process_macros(roll, macro_function) do
    macros = Regex.scan(regex(), roll)
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
end

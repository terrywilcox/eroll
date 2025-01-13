defmodule Eroll do
  def roll(term) do
    parsed = Eroll.Parser.parse(term)
    Eroll.Evaluator.eval(parsed)
  end
end

defmodule Eroll do
  def roll(term) do
    roll(term, %{})
  end

  def roll(term, context) do
    parsed = Eroll.Parser.parse(term)
    Eroll.Evaluator.evaluate(parsed, context)
  end
end

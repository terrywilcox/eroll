defmodule Eroll do
  def roll(term) do
    roll(term, %{})
  end

  def roll(term, context) do
    processed = Eroll.Preprocessor.preprocess(term, context)
    parsed = Eroll.Parser.parse(processed)
    Eroll.Evaluator.evaluate(parsed, context)
  end
end

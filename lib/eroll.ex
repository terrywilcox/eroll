defmodule Eroll do
  def roll(term) do
    roll(term, %{})
  end

  def roll(term, context) do
    processed = Eroll.Preprocessor.preprocess(term, context)
    case Eroll.Parser.parse(processed) do
      {:error, _} -> processed
      parsed -> Eroll.Evaluator.evaluate(parsed, context)
    end
  end
end

defmodule Eroll.PreprocessorTest do
  use ExUnit.Case

  test "preprocess a single macro with no value" do
    roll = "3d6?{macro}"

    assert "3d6macro" == Eroll.Preprocessor.preprocess(roll, %{})
  end

  test "preprocess a single macro with default lookup" do
    context = %{"macro" => "kh1"}
    roll = "3d6?{macro}"

    assert "3d6kh1" == Eroll.Preprocessor.preprocess(roll, context)
  end

  test "preprocess a single macro with lookup function" do
    context = %{"macro" => "kl1"}
    lookup_function = fn name -> Map.get(context, name, name) end

    roll = "3d6?{macro}"

    assert "3d6kl1" == Eroll.Preprocessor.preprocess(roll, %{"macro_function" => lookup_function})
  end

  test "preprocess multiple macros with default lookup" do
    context = %{"macro" => "kh1", "other_macro" => ">3"}
    roll = "3d6?{macro}?{other_macro}"

    assert "3d6kh1>3" == Eroll.Preprocessor.preprocess(roll, context)
  end

  test "preprocess multiple macros with lookup function" do
    context = %{"macro" => "kl1", "other_macro" => ">3"}
    lookup_function = fn name -> Map.get(context, name, name) end

    roll = "3d6?{macro}?{other_macro}"

    assert "3d6kl1>3" ==
             Eroll.Preprocessor.preprocess(roll, %{"macro_function" => lookup_function})
  end

  test "preprocess inline roll" do
    inline_function = fn _inline -> "3" end
    roll = "my dog has [[d4]] legs"

    assert "my dog has 3 legs" ==
             Eroll.Preprocessor.preprocess(roll, %{"inline_function" => inline_function})
  end

  test "preprocess multiple inline rolls" do
    inline_function = fn _inline -> "3" end
    roll = "my [[d6]] dogs have [[3d4]] legs"

    assert "my 3 dogs have 3 legs" ==
             Eroll.Preprocessor.preprocess(roll, %{"inline_function" => inline_function})
  end
end

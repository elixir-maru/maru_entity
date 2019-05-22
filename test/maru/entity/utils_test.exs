defmodule Maru.Entity.UtilsTest do
  use ExUnit.Case, async: false
  import Maru.Entity.Utils

  test "attr_match?" do
    assert attr_match?([:a], [:x, :a])
    assert attr_match?([:a, :b], [:a])
    assert attr_match?([:a, :b], a: [:b])
    assert attr_match?([:a, :b, :c], [:a])
    assert attr_match?([:a, :b, :c], a: [:b])
    assert attr_match?([:a, :b, :c], a: [:x, b: [:c]])

    refute attr_match?([:a], [:b])
    refute attr_match?([:a, :b], a: [:c, :d])
  end
end

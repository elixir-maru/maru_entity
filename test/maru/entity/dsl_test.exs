defmodule Maru.Entity.DSLTest do
  use ExUnit.Case

  defmodule EmptyEntity do
    use Maru.Entity.DSL
  end

  defmodule OneExposure do
    use Maru.Entity.DSL

    expose :id
  end

  defmodule TwoExposures do
    use Maru.Entity.DSL

    expose :id
    expose :title
  end

  defmodule AsExposure do
    use Maru.Entity.DSL

    expose :safe_id, as: :id
    expose :title
  end

  defmodule WithExposure do
    use Maru.Entity.DSL

    expose :author, with: OneExposure
  end

  defmodule BlockWithoutAs do
    use Maru.Entity.DSL

    expose :author, [], fn(_r, _opt) ->
      3
    end
  end

  test"has empty exposures" do
    assert EmptyEntity.exposures == []
  end

  describe "expose/1" do
    test "sets exposure" do
      assert OneExposure.exposures == [id: [callbacks: [], attr: :id, as: :id]]
    end

    test "sets two exposures" do
      assert TwoExposures.exposures == [id: [callbacks: [], attr: :id, as: :id], title: [callbacks: [], attr: :title, as: :title]]
    end
  end

  describe "expose/2" do
    test "sets as" do
      assert AsExposure.exposures == [id: [callbacks: [], attr: :safe_id, as: :id], title: [callbacks: [], attr: :title, as: :title]]
    end

    test "sets with" do
      assert WithExposure.exposures == [author: [callbacks: [], attr: :author, as: :author, with: OneExposure]]
    end

    test "sets as with block" do
      assert BlockWithoutAs.exposures == [author: [callbacks: [block: true], attr: :author, as: :author]]
    end
  end
end

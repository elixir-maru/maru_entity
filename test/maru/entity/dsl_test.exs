defmodule Maru.Entity.DSLTest do
  use Amrita.Sweet

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

  it "has empty exposures" do
    assert EmptyEntity.exposures == []
  end

  describe "expose/1" do
    it "sets exposure" do
      assert OneExposure.exposures == [id: [attr: :id, as: :id]]
    end

    it "sets two exposures" do
      assert TwoExposures.exposures == [id: [attr: :id, as: :id], title: [attr: :title, as: :title]]
    end
  end

  describe "expose/2" do
    it "sets as" do
      assert AsExposure.exposures == [id: [attr: :safe_id, as: :id], title: [attr: :title, as: :title]]
    end

    it "sets with" do
      assert WithExposure.exposures == [author: [as: :author, attr: :author, with: OneExposure]]
    end
  end
end

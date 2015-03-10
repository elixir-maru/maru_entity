defmodule PostEntity do
  use Maru.Entity
end

defmodule Maru.EntityTest do
  use Amrita.Sweet, async: false

  describe "present" do
    it "returns single object" do
      post = %{id: 1, title: "My title", body: "This is a <b>html body</b>"}
      assert PostEntity.serialize(post) == %{id: 1, title: "My title", content: "This is a <b>html body</b>"}
    end

    it "returns multiple objects" do
      post1 = %{id: 1, title: "My title", body: "This is a <b>html body</b>"}
      post2 = %{id: 2, title: "My other title", body: "<b>html body</b>"}
      expected = [%{id: 1, title: "My title", content: "This is a <b>html body</b>"},
                  %{id: 2, title: "My other title", content: "<b>html body</b>"}]

      assert PostEntity.serialize([post1, post2]) == expected
    end
  end
end

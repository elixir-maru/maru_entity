defmodule Maru.EntityTest do
  use Amrita.Sweet, async: false

  defmodule PostEntity do
    use Maru.Entity

    expose :id
    expose :title
    expose :body, as: :content
  end

  defmodule CommentEntity do
    use Maru.Entity

    expose :body
    expose :post, with: PostEntity
  end

  defmodule AuthorEntity do
    use Maru.Entity

    expose :name
    expose :posts, with: PostEntity
  end

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

    it "serializes stuff using with" do
      post = %{id: 2, title: "My other title", body: "<b>html body</b>"}
      comment = %{body: "<b>comment body</b>", post: post}
      expected = %{body: "<b>comment body</b>", post: %{id: 2, title: "My other title", content: "<b>html body</b>"}}

      assert CommentEntity.serialize(comment) == expected
      assert CommentEntity.serialize([comment]) == [expected]
    end

    it "serializes array using with" do
      post1 = %{id: 1, title: "My other title", body: "<b>html body</b>"}
      post2 = %{id: 2, title: "My another title", body: "text body"}
      author = %{name: "Teodor Pripoae", posts: [post1, post2]}
      expected = %{name: "Teodor Pripoae", posts: [%{id: 1, title: "My other title", content: "<b>html body</b>"},
                                                   %{id: 2, title: "My another title", content: "text body"}]}

      assert AuthorEntity.serialize(author) == expected
      assert AuthorEntity.serialize([author]) == [expected]
    end
  end
end

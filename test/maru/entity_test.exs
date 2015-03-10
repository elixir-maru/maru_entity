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

  defmodule IfCommentEntity do
    use Maru.Entity

    expose :body
    expose :post, with: PostEntity, if: fn(comment, _options) -> comment.post != nil end
  end

  defmodule UnlessCommentEntity do
    use Maru.Entity

    expose :body
    expose :post, with: PostEntity, unless: fn(comment, _options) -> comment.post == nil end
  end

  defmodule AuthorEntity do
    use Maru.Entity

    expose :name
    expose :posts, with: PostEntity

    expose :post_count, [as: :post_count], fn(author, _options) ->
      length(author.posts)
    end
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
      expected = %{name: "Teodor Pripoae",
                   post_count: 2,
                   posts: [%{id: 1, title: "My other title", content: "<b>html body</b>"},
                           %{id: 2, title: "My another title", content: "text body"}]}

      assert AuthorEntity.serialize(author) == expected
      assert AuthorEntity.serialize([author]) == [expected]
    end

    it "does not show post if nil " do
      comment1 = %{body: "body", post: nil}
      comment2 = %{body: "body", post: %{id: 3, title: "asdf", body: "a"}}

      assert IfCommentEntity.serialize(comment1) == %{body: "body"}
      assert IfCommentEntity.serialize(comment2) == %{body: "body", post: %{id: 3, title: "asdf", content: "a"}}
    end

    it "does not show post unless present " do
      comment1 = %{body: "body", post: nil}
      comment2 = %{body: "body", post: %{id: 3, title: "asdf", body: "a"}}

      assert UnlessCommentEntity.serialize(comment1) == %{body: "body"}
      assert UnlessCommentEntity.serialize(comment2) == %{body: "body", post: %{id: 3, title: "asdf", content: "a"}}
    end
  end
end

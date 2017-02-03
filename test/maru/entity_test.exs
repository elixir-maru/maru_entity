defmodule Maru.EntityTest do
  use ExUnit.Case, async: false

  defmodule PostEntity do
    use Maru.Entity

    expose :id
    expose :title
    expose :content, source: :body
  end

  defmodule CommentEntity do
    use Maru.Entity

    expose :body
    expose :post, using: Maru.EntityTest.PostEntity
  end

  defmodule IfCommentEntity do
    use Maru.Entity

    expose :body
    expose :post, using: Maru.EntityTest.PostEntity, if: fn(comment, _options) -> comment.post != nil end
  end

  defmodule UnlessCommentEntity do
    use Maru.Entity

    expose :body
    expose :post, using: Maru.EntityTest.PostEntity, unless: fn(comment, _options) -> comment.post == nil end
  end

  defmodule AuthorEntity do
    use Maru.Entity

    expose :name
    expose :posts, using: List[Maru.EntityTest.PostEntity]

    expose :post_count, [], fn(author, _options) ->
      length(author.posts)
    end
  end

  describe "present" do
    test "returns single object" do
      post = %{id: 1, title: "My title", body: "This is a <b>html body</b>"}
      assert PostEntity.serialize(post) == %{id: 1, title: "My title", content: "This is a <b>html body</b>"}
    end

    test "returns multiple objects" do
      post1 = %{id: 1, title: "My title", body: "This is a <b>html body</b>"}
      post2 = %{id: 2, title: "My other title", body: "<b>html body</b>"}
      expected = [%{id: 1, title: "My title", content: "This is a <b>html body</b>"},
                  %{id: 2, title: "My other title", content: "<b>html body</b>"}]

      assert PostEntity.serialize([post1, post2]) == expected
    end

    test "serializes stuff using with" do
      post = %{id: 2, title: "My other title", body: "<b>html body</b>"}
      comment = %{body: "<b>comment body</b>", post: post}
      expected = %{body: "<b>comment body</b>", post: %{id: 2, title: "My other title", content: "<b>html body</b>"}}

      assert CommentEntity.serialize(comment) == expected
      assert CommentEntity.serialize([comment]) == [expected]
    end

    test "serializes array using with" do
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

    test "does not show post if nil " do
      comment1 = %{body: "body", post: nil}
      comment2 = %{body: "body", post: %{id: 3, title: "asdf", body: "a"}}

      assert IfCommentEntity.serialize(comment1) == %{body: "body"}
      assert IfCommentEntity.serialize(comment2) == %{body: "body", post: %{id: 3, title: "asdf", content: "a"}}
    end

    test "does not show post unless present " do
      comment1 = %{body: "body", post: nil}
      comment2 = %{body: "body", post: %{id: 3, title: "asdf", body: "a"}}

      assert UnlessCommentEntity.serialize(comment1) == %{body: "body"}
      assert UnlessCommentEntity.serialize(comment2) == %{body: "body", post: %{id: 3, title: "asdf", content: "a"}}
    end

    test "batch helper for object" do
      defmodule PostEntity2 do
        use Maru.Entity

        expose :id
        expose :author, using: Maru.EntityTest.AuthorEntity2, batch: Maru.EntityTest.AuthorEntity2.BatchHelper
      end

      defmodule AuthorEntity2 do
        use Maru.Entity

        expose :id
        expose :name
      end

      defmodule AuthorEntity2.BatchHelper do
        def key(instance, _) do
          instance.author_id
        end

        def resolve(keys) do
          for id <- keys, into: %{} do
            {id, %{id: id, name: "Author#{id}"}}
          end
        end
      end

      posts = [%{id: 100, author_id: 1}, %{id: 110, author_id: 3}, %{id: 130, author_id: 7}]
      assert [
        %{id: 100, author: %{id: 1, name: "Author1"}},
        %{id: 110, author: %{id: 3, name: "Author3"}},
        %{id: 130, author: %{id: 7, name: "Author7"}},
      ] = PostEntity2.serialize(posts)
    end

    test "batch helper for list of objects" do
      defmodule PostEntity3 do
        use Maru.Entity

        expose :id
        expose :author, using: List[Maru.EntityTest.AuthorEntity3], batch: Maru.EntityTest.AuthorEntity3.BatchHelper
      end

      defmodule AuthorEntity3 do
        use Maru.Entity

        expose :id
        expose :name
      end

      defmodule AuthorEntity3.BatchHelper do
        def key(instance, _) do
          instance.author_id
        end

        def resolve(keys) do
          for id <- keys, into: %{} do
            {id, [%{id: id, name: "Author1_#{id}"}, %{id: id, name: "Author2_#{id}"}]}
          end
        end
      end

      posts = [%{id: 100, author_id: 1}, %{id: 110, author_id: 3}, %{id: 130, author_id: 7}]
      assert [
        %{id: 100, author: [%{id: 1, name: "Author1_1"}, %{id: 1, name: "Author2_1"}]},
        %{id: 110, author: [%{id: 3, name: "Author1_3"}, %{id: 3, name: "Author2_3"}]},
        %{id: 130, author: [%{id: 7, name: "Author1_7"}, %{id: 7, name: "Author2_7"}]},
      ] = PostEntity3.serialize(posts)
    end

    test "batch helper for non-object value" do
      defmodule PostEntity4 do
        use Maru.Entity

        expose :id
        expose :author, batch: Maru.EntityTest.AuthorEntity4.BatchHelper
      end

      defmodule AuthorEntity4.BatchHelper do
        def key(instance, _) do
          instance.author_id
        end

        def resolve(keys) do
          for id <- keys, into: %{} do
            {id, %{name: "Author#{id}"}}
          end
        end
      end

      posts = [%{id: 100, author_id: 1}, %{id: 110, author_id: 3}, %{id: 130, author_id: 7}]
      assert [
        %{id: 100, author: %{name: "Author1"}},
        %{id: 110, author: %{name: "Author3"}},
        %{id: 130, author: %{name: "Author7"}},
      ] = PostEntity4.serialize(posts)
    end


    test "exception" do
      defmodule PostEntity5 do
        use Maru.Entity

        expose :id
        expose :author, using: Maru.EntityTest.AuthorEntity5
      end

      defmodule AuthorEntity5 do
        use Maru.Entity

        expose :id, [], fn(_instance, _) ->
          raise "ERROR"
        end
      end

      post = %{id: 100, author_id: 1}
      assert_raise RuntimeError, "ERROR", fn ->
        PostEntity5.serialize(post)
      end
    end

    test "correct order under concurrency" do
      defmodule PostEntity6 do
        use Maru.Entity

        expose :id, [], fn(instance, _) ->
          id = Map.get(instance, :id)
          :timer.sleep(id * 100)
          id
        end
      end

      assert [%{id: 1}, %{id: 2}] = PostEntity6.serialize([%{id: 1}, %{id: 2}])
      assert [%{id: 2}, %{id: 1}] = PostEntity6.serialize([%{id: 2}, %{id: 1}])
    end

    test "custom max_concurrency" do
      defmodule PostEntity7 do
        use Maru.Entity

        expose :id, [], fn(instance, _) ->
          :timer.sleep(2)
          Map.get(instance, :id)
        end
      end

      posts = Enum.map(1..100, &%{id: &1})
      assert ^posts = PostEntity7.serialize(posts, %{}, [max_concurrency: 1])
      assert ^posts = PostEntity7.serialize(posts, %{}, [max_concurrency: 2])
      assert ^posts = PostEntity7.serialize(posts, %{}, [max_concurrency: 10])
      assert ^posts = PostEntity7.serialize(posts, %{}, [max_concurrency: 200])
    end

    test "middleman trap parent exit" do
      defmodule PostEntity8 do
        use Maru.Entity

        expose :id
        expose :author, using: Maru.EntityTest.AuthorEntity6
      end

      defmodule AuthorEntity6 do
        use Maru.Entity

        expose :id, [], fn(_instance, _) ->
          # worker should never trap exit in practice
          # this is for test only
          Process.flag(:trap_exit, true)
          send(:test_runner, :worker_ready)
          receive do
            {:EXIT, _pid, :kill} ->
              # expected kill of the middleman process
              send(:test_runner, :worker_killed)
              :ok
          end
        end
      end

      Process.register(self, :test_runner)
      wait = fn(msg) ->
        receive do
          ^msg ->
            :ok
        after
          1_000 ->
            raise {"TIMEOUT", msg}
        end
      end
      post = %{id: 100, author_id: 1}
      pid = Process.spawn(fn ->
              PostEntity8.serialize(post)
            end, [])
      wait.(:worker_ready)
      Process.exit(pid, :kill)
      wait.(:worker_killed)
    end

  end
end

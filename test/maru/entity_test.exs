defmodule Maru.EntityTest do
  use ExUnit.Case, async: false

  defmodule PostEntity do
    use Maru.Entity

    expose [:id, :title]
    expose :content, source: :body
  end

  defmodule CommentEntity do
    use Maru.Entity
    alias Maru.EntityTest.PostEntity

    expose :body
    expose :nested do
      expose :rename, source: :body
    end
    expose :post, using: PostEntity
  end

  defmodule IfCommentEntity do
    use Maru.Entity

    expose :body
    expose :post, using: Maru.EntityTest.PostEntity, if: fn comment, _options -> comment.post != nil end
  end

  defmodule UnlessCommentEntity do
    use Maru.Entity

    expose :body
    expose :post, using: Maru.EntityTest.PostEntity, unless: fn comment, _options -> comment.post == nil end
  end

  defmodule AuthorEntity do
    use Maru.Entity
    alias Maru.EntityTest.PostEntity

    expose :name
    expose :posts, using: List[PostEntity]

    expose :post_count, &do_post_count/2

    expose :option, [], fn(_, options) ->
      options[:option]
    end

    def do_post_count(author, _options) do
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
      expected = %{body: "<b>comment body</b>", post: %{id: 2, title: "My other title", content: "<b>html body</b>"}, nested: %{rename: "<b>comment body</b>"}}

      assert CommentEntity.serialize(comment) == expected
      assert CommentEntity.serialize([comment]) == [expected]
    end

    test "serializes array using with" do
      post1 = %{id: 1, title: "My other title", body: "<b>html body</b>"}
      post2 = %{id: 2, title: "My another title", body: "text body"}
      author = %{name: "Teodor Pripoae", posts: [post1, post2]}
      expected = %{name: "Teodor Pripoae",
                   option: 1,
                   post_count: 2,
                   posts: [%{id: 1, title: "My other title", content: "<b>html body</b>"},
                           %{id: 2, title: "My another title", content: "text body"}]}

      assert AuthorEntity.serialize(author, %{option: 1}) == expected
      assert AuthorEntity.serialize([author], %{option: 1}) == [expected]
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
        expose :name, [], fn instance, options ->
          "#{instance[:name]}_#{options[:option]}"
        end
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
        %{id: 100, author: %{id: 1, name: "Author1_x"}},
        %{id: 110, author: %{id: 3, name: "Author3_x"}},
        %{id: 130, author: %{id: 7, name: "Author7_x"}},
      ] = PostEntity2.serialize(posts, %{option: "x"})
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
        expose :option, [], fn(_, options) ->
          options[:option]
        end
      end

      defmodule AuthorEntity3.BatchHelper do
        def key(instance, _) do
          instance.author_id
        end

        def resolve(keys) do
          [_ | keys] = keys
          for id <- keys, into: %{} do
            {id, [%{id: id, name: "Author1_#{id}"}, %{id: id, name: "Author2_#{id}"}]}
          end
        end
      end

      posts = [%{id: 100, author_id: 1}, %{id: 110, author_id: 3}, %{id: 130, author_id: 7}]
      assert [
        %{id: 100, author: []},
        %{id: 110, author: [%{id: 3, name: "Author1_3", option: 1}, %{id: 3, name: "Author2_3", option: 1}]},
        %{id: 130, author: [%{id: 7, name: "Author1_7", option: 1}, %{id: 7, name: "Author2_7", option: 1}]},
      ] = PostEntity3.serialize(posts, %{option: 1})
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
        expose :author, using: Maru.EntityTest.AuthorEntity8
      end

      defmodule AuthorEntity8 do
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

      Process.register(self(), :test_runner)
      post = %{id: 100, author_id: 1}
      pid =
        Process.spawn(fn ->
          PostEntity8.serialize(post)
        end, [])
      assert_receive :worker_ready, 1_000
      Process.exit(pid, :kill)
      assert_receive :worker_killed, 1_000
    end

  end

  describe "test alias" do
    defmodule StructTest.AliasTest do
      defstruct [:alias_test]
    end

    defmodule AliasTestExtended do
      use Maru.Entity
      alias StructTest.AliasTest

      expose :alias_test, [], fn _instance, _options ->
        %AliasTest{alias_test: true}
      end
    end

    defmodule AliasTestEntity do
      use Maru.Entity

      extend AliasTestExtended
    end

    test "alias in do_function" do
      assert AliasTestEntity.serialize(%{}) == %{alias_test: %Maru.EntityTest.StructTest.AliasTest{alias_test: true}}
    end
  end

  describe "extend" do
    defmodule UserData do
      use Maru.Entity

      expose :name do
        expose :first_name
        expose :last_name
      end
      expose :address do
        expose :address1
        expose :address2
        expose :address_state
        expose :address_city
      end
      expose :email
      expose :phone
    end

    defmodule UserDataDetail do
      use Maru.Entity
      extend UserData

      expose :field1
    end

    defmodule MailingAddress do
      use Maru.Entity
      extend Maru.EntityTest.UserData, only: [
        :name, address: [:address1, :address2]
      ]
      expose :field2
    end

    defmodule BasicInfomation do
      use Maru.Entity
      extend Maru.EntityTest.UserData, except: [:address]
      expose :field3
    end

    test "only and except conflict" do
      assert_raise RuntimeError, ":only and :except conflict", fn ->
        defmodule OnlyAndExceptConflict do
          use Maru.Entity
          extend Maru.EntityTest.UserData, only: [:a], except: [:b]
        end
      end
    end

    test "extend" do
      assert [
        [:name], [:name, :first_name], [:name, :last_name],
        [:address], [:address, :address1], [:address, :address2], [:address, :address_state], [:address, :address_city],
        [:email], [:phone], [:field1],
      ] = Enum.map(UserDataDetail.__exposures__, & &1.attr_group)
    end

    test "only extend" do
      assert [
        [:name], [:name, :first_name], [:name, :last_name],
        [:address], [:address, :address1], [:address, :address2],
        [:field2],
      ] = Enum.map(MailingAddress.__exposures__, & &1.attr_group)
    end

    test "except extend" do
      assert [
        [:name], [:name, :first_name], [:name, :last_name],
        [:email], [:phone], [:field3],
      ] = Enum.map(BasicInfomation.__exposures__, & &1.attr_group)
    end
  end

  describe "before finish" do
    defmodule BeforeFinishTest do
      use Maru.Entity

      expose :foo

      def before_finish(item) do
        Enum.into(item, [])
      end
    end

    test "before finish" do
      assert [foo: 3] == BeforeFinishTest.serialize(%{foo: 3})
    end

    defmodule FooBatchHelper do
      def key(instance, _) do
        instance.id
      end

      def resolve(keys) do
        for id <- keys, into: %{} do
          {id, %{str_id: to_string(id)}}
        end
      end
    end

    defmodule FooBatch do
      use Maru.Entity

      expose :str_id

      def before_finish(item) do
        Enum.to_list(item)
      end
    end

    defmodule BeforeFinishBatchTest do
      use Maru.Entity

      expose :foo, using: FooBatch, batch: FooBatchHelper

      def before_finish(item) do
        Enum.to_list(item)
      end
    end

    test "before finish with batch" do
      assert [
        [foo: [str_id: "3"]], [foo: [str_id: "7"]], [foo: [str_id: "9"]]
      ] = BeforeFinishBatchTest.serialize([%{id: 3}, %{id: 7}, %{id: 9}])
    end

  end

  describe "erorr handler" do
    defmodule ErrorHandlerOneTest do
      use Maru.Entity

      expose :group do
        expose :id, fn _item, _options ->
          raise "parse id error"
        end
      end

      def handle_error([:group, :id], _, _) do
        {:ok, 900303}
      end
    end

    defmodule ErrorHandlerAllTest do
      use Maru.Entity

      expose :id, fn _item, _options ->
        raise "parse id error"
      end

      def handle_error([:id], _, _) do
        {:halt, nil}
      end
    end

    test "one field" do
      assert %{group: %{id: 900303}} == ErrorHandlerOneTest.serialize(%{id: 1})
    end

    test "all field" do
      assert is_nil(ErrorHandlerAllTest.serialize(%{id: 1}))
    end
  end

  describe "test function/1 function/2 function/3" do
    defmodule Function3Test do
      use Maru.Entity

      expose :foo, fn instance -> to_string(instance[:fooo]) end
      expose :bar, fn instance, options -> {instance[:bar], options} end
      expose :baz, fn _instance, _options, data -> is_nil(data[:foo]) end
      expose :qux, default: :D
    end

    test "do function" do
      assert %{
        foo: "1",
        bar: {3, %{a: 1}},
        baz: false,
        qux: :D,
      } = Function3Test.serialize(%{fooo: 1, bar: 3}, %{a: 1})
    end
  end

end

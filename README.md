Maru.Entity
==========

Elixir copy of [grape-entity](https://github.com/intridea/grape-entity) for serializing objects.

### Usage:

```elixir
defmodule PostEntity do
  use Maru.Entity

  expose :id
  expose :title
  expose :body, as: :content

  expose :disabled, if: fn(post, _options) -> post.is_disabled end
  expose :active, unless: fn(post, _options) -> post.is_disabled end
end

defmodule CommentEntity do
  use Maru.Entity

  expose :body
  expose :post, with: PostEntity, if: fn(comment, _options) -> comment.post != nil end
end

defmodule AuthorEntity do
  use Maru.Entity

  expose :name
  expose :posts, with: PostEntity

  expose :posts_count, [], fn(author, options) ->
    length(author.posts)
  end
end
```

MaruEntity
==========

Elixir copy of [grape-entity](https://github.com/intridea/grape-entity) for serializing objects.

### Usage:

```elixir
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
```

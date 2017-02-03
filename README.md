Maru.Entity
==========

> Concurrent serializer inspired by [grape-entity](https://github.com/intridea/grape-entity).

[![Build Status](https://img.shields.io/travis/elixir-maru/maru_entity.svg?style=flat-square)](https://travis-ci.org/elixir-maru/maru_entity)
[![Coveralls](https://img.shields.io/coveralls/elixir-maru/maru_entity.svg?style=flat-square)](https://coveralls.io/github/elixir-maru/maru_entity)
### Usage:

```elixir
defmodule PostEntity do
  use Maru.Entity

  expose :id
  expose :title
  expose :body, source: :content

  expose :disabled, if: fn(post, _options) -> post.is_disabled end
  expose :active, unless: fn(post, _options) -> post.is_disabled end

  expose :comments, using: List[PostEntity], fn(post, _options) ->
    query =
      from c in Comment,
        where: c.post_id == post.id,
        select: c
    Repo.all(query)
  end
end

defmodule CommentEntity do
  use Maru.Entity

  expose :id
  expose :body
  expose :author, using: AuthorEntity, batch: CommentAuthor.BatchHelper
end

defmodule AuthorEntity do
  use Maru.Entity

  expose :id
  expose :name, [], fn(author, _options) ->
    "#{author.first_name} #{author.last_name}"
  end
end

defmodule CommentAuthor.BatchHelper do
  def key(comment, _optiosn) do
    comment.author_id
  end

  def resolve(ids) do
    query =
      from a in Author,
        where: a.id in ids,
        select: a
    Repo.all(query) |> Map.new(&{&1.id, &1})
  end
end
```

## Changelog

## upgrade instructions from v0.1.x to v0.2.0
* replace `as` with `source`

    `expose :body, as: :content` should be `expose :content, source: :body`

* explicit declaration for instance list

    `expose :posts, with: PostEntity` should be `expose :posts, with: List[PostEntity]`


## v0.2.1-dev
* Enhancements
  * support nested exposure
  * support extend
* Bugfix
  * return `[]` instead of `nil` for batch  list

## v0.2.0 (2017-02-04)
* Enhancements
  * parallelizable serialize
  * solve the N + 1 Problem

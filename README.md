Delta
=====

[![Build Status][badge-github]][github-build]
[![Version][badge-version]][hexpm]
[![Downloads][badge-downloads]][hexpm]
[![License][badge-license]][github-license]


> Simple yet expressive format to describe documents' contents and changes 🗃


Deltas are a simple, yet expressive format that can be used to describe a document's contents and
changes. The format is a strict subset of `JSON`, is human readable, and easily parsible by machines.
Deltas can describe any document, includes all text and formatting information, without the ambiguity
and complexity of HTML.

See the [Documentation][docs].

<br>




## Installation

Add `delta` to your project dependencies in `mix.exs`:

```elixir
def deps do
  [{:delta, "~> 0.1.0"}]
end
```

<br>




## Contributing

 - [Fork][github-fork], Enhance, Send PR
 - Lock issues with any bugs or feature requests
 - Implement something from Roadmap
 - Spread the word :heart:

<br>




## License

This package is available as open source under the terms of the [MIT License][github-license].

<br>





[badge-github]:     https://github.com/slab/delta-elixir/actions/workflows/ci.yml/badge.svg
[badge-version]:    https://img.shields.io/hexpm/v/delta.svg
[badge-license]:    https://img.shields.io/hexpm/l/delta.svg
[badge-downloads]:  https://img.shields.io/hexpm/dt/delta.svg

[hexpm]:            https://hex.pm/packages/delta
[github-build]:     https://github.com/slab/delta-elixir/actions/workflows/ci.yml
[github-license]:   https://github.com/slab/delta-elixir/blob/master/LICENSE
[github-fork]:      https://github.com/slab/delta-elixir/fork

[docs]:             https://hexdocs.pm/delta

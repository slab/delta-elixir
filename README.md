Delta
=====

[![CI](https://github.com/slab/delta-elixir/actions/workflows/ci.yml/badge.svg)](https://github.com/slab/delta-elixir/actions/workflows/ci.yml)
[![Module Version](https://img.shields.io/hexpm/v/delta.svg)](https://hex.pm/packages/delta)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/delta/)
[![Total Download](https://img.shields.io/hexpm/dt/delta.svg)](https://hex.pm/packages/delta)
[![License](https://img.shields.io/hexpm/l/delta.svg)](https://github.com/slab/delta-elixir/blob/master/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/slab/delta-elixir.svg)](https://github.com/slab/delta-elixir/commits/master)


> Simple yet expressive format to describe documents' contents and changes 🗃


Deltas are a simple, yet expressive format that can be used to describe contents and changes.
The format is a strict subset of JSON, is human readable, and easily parsible by machines.
Deltas can describe any rich-text document, includes all text and formatting information,
without the ambiguity and complexity of HTML.

The Delta format is suitable for [Operational Transform](https://en.wikipedia.org/wiki/Operational_transformation) and can be used in real-time,
collaborative document editors (e.g. Slab, Google Docs). A walkthough of the motivation and
design thinking behind Deltas are on [Designing the Delta Format](https://quilljs.com/guides/designing-the-delta-format/).

See the [Documentation](https://hexdocs.pm/delta).

## Installation

Add `:delta` to your project dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:delta, "~> 0.1.1"}
  ]
end
```

## Usage

A Delta is made up of a list of operations, which describe changes to a document. These can be
`insert`, `delete` or `retain`. These operations do not take an index, but instead describe the
change at the current index. Retains are used to "keep" parts of the document.

### Quick Example

```elixir
alias Delta.Op

# Document with text "Gandalf the Grey", with "Gandalf" bolded
# and "Grey" in grey
delta = [
  Op.insert("Gandalf", %{"bold" => true}),
  Op.insert(" the "),
  Op.insert("Grey", %{"color" => "#ccc"}),
]

# Define change intended to be applied to above:
# Keep the first 12 characters, delete the next 4,
# and insert a white "White"
death = [
  Op.retain(12),
  Op.delete(4),
  Op.insert("White", %{"color" => "#fff"}),
]


# Applying the change:
Delta.compose(delta, death)
# => [
#   %{"insert" => "Gandalf", "attributes" => %{"bold" => true}},
#   %{"insert" => " the "},
#   %{"insert" => "White", "attributes" => %{"color" => "#fff"}},
# ]
```

## Operations

### Insert

Insert operations have an `insert` key defined. A String value represents inserting text. Any
other type represents inserting an embed (however only one level of object comparison will be
performed for equality).

In both cases of text and embeds, an optional `attributes` key can be defined with a `map` to
describe additional formatting information. Formats can be changed by the `retain` operation.

```elixir
# Insert a text
Op.insert("Some Text")

# Insert a bolded text
Op.insert("Bolded Text", %{"bold" => true})

# Insert a link
Op.insert("Google", %{"link" => "https://google.com"})

# Insert an embed
Op.insert(%{"image" => "https://app.com/logo.png"}, %{"alt" => "App Logo"})

# Insert another embed
Op.insert(%{"video" => "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}, %{"width" => 420, "height" => 315})
```

### Delete

Delete operations have a positive integer `delete` key defined representing the number of
characters to delete. All embeds have a length of 1.

```elixir
# Delete the next 10 characters
Op.delete(10)
```

### Retain

Retain operations have a positive integer `retain` key defined representing the number of
characters to keep (other libraries might use the name keep or skip). An optional `attributes`
key can be defined with a `map` to describe formatting changes to the character range. A
value of `nil` in the attributes map represents removal of that key.

Note: It is not necessary to retain the last characters of a document as this is implied.

```elixir
# Keep the next 5 characters
Op.retain(5)

# Keep and bold the next 5 characters
Op.retain(5, %{"bold" => true})

# Keep and unbold the next 5 characters
Op.retain(5, %{"bold" => nil})
```

## Operational Transform

Operational Transform (OT) is a technology for building collabortive experiences, and is
especially useful in application sharing and building real-time document editors that support
multi-user collaboration (e.g. Google Docs, Slab).

Delta supports OT out of the box and can be very useful in employing Operational Transform
techniques in Elixir. It supports the following properties:

### Compose

Returns a new Delta that is equivalent to applying the operations of one Delta, followed
by another Delta:

```elixir
a = [Op.insert("abc")]
b = [Op.retain(1), Op.delete(1)]

Delta.compose(a, b)
# => [%{"insert" => "ac"}]
```

### Transform

Transforms given delta against another's operations. This accepts an optional `priority`
argument (default: `false`), used to break ties. If `true`, the first delta takes priority
over other, that is, its actions are considered to happen "first."

```elixir
a = [Op.insert("a")]
b = [Op.insert("b"), Op.retain(5), Op.insert("c")]

Delta.transform(a, b, true)
# => [
#  %{"retain" => 1},
#  %{"insert" => "b"},
#  %{"retain" => 5},
#  %{"insert" => "c"},
# ]

Delta.transform(a, b)
# => [
#  %{"insert" => "b"},
#  %{"retain" => 6},
#  %{"insert" => "c"},
# ]
```

### Invert

Returns an inverted delta that has the opposite effect of against a base document delta.
That is `base |> Delta.compose(change) |> Delta.compose(inverted) == base`.

```elixir
base = [Op.insert("Hello\nWorld")]

change = [
  Op.retain(6, %{"bold" => true}),
  Op.delete(5),
  Op.insert("!"),
]

inverted = Delta.invert(change, base)
# => [
#   %{"retain" => 6, "attributes" => %{"bold" => nil}},
#   %{"insert" => "World"},
#   %{"delete" => 1},
# ]

base |> Delta.compose(change) |> Delta.compose(inverted) == base
# => true
```

## Contributing

 - [Fork](https://github.com/slab/delta-elixir/fork), enhance, and send PR
 - Lock issues with any bugs or feature requests
 - Implement something from Roadmap
 - Spread the word :heart:

## Copyright and License

Copyright (c) 2021 Slab

This work is free. You can redistribute it and/or modify it under the
terms of the MIT License. See the [LICENSE.md](./LICENSE.md) file for more details.

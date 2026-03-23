# Changelog

## v0.4.2 (2026-03-23)

### Enhancements

- Support retaining placeholder text with an embed retain in `Delta.compose/2` ([1ac46dd](https://github.com/slab/delta-elixir/commit/1ac46dd053c92fa4fce5fdaa1a85a0e616770d27))

## v0.4.1 (2024-11-28)

### Maintenances

- Address Elixir 1.17 warnings

## v0.4.0 (2024-04-22)

### Enhancements

- Add `Delta.diff/2`
- Add `Delta.Attr.diff/2`
- Add `c:Delta.EmbedHandler.diff/2`

### Bug Fixes

- Fix `Delta.split/2` when index goes beyond end of delta #12
- Fix `Delta.split/2` when splitter returns 0 index #13

## v0.3.0 (2022-09-19)

### Enhancements

- Add support for attributes in delete operations

## v0.2.0 (2022-05-30)

### Enhancements

- Add `Delta.slice_max/3`

# Changelog

## v0.4.0 (2024-04-22)

### Enhancements
  * Add `Delta.diff/2`
  * Add `Delta.Attr.diff/2`
  * Add `c:Delta.EmbedHandler.diff/2`

### Bug Fixes
  * Fix `Delta.split/2` when index goes beyond end of delta #12
  * Fix `Delta.split/2` when splitter returns 0 index #13

## v0.3.0 (2022-09-19)

### Enhancements
  * Add support for attributes in delete operations

## v0.2.0 (2022-05-30)

### Enhancements
  * Add `Delta.slice_max/3` 
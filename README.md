# ZenUI Arrow Pagination Patch

A small KOReader userpatch for [Zen UI](https://github.com/AnthonyGress/zen_ui.koplugin).

It replaces ZenUI's dot-based library pagination with a more KOReader-like footer:

```text
<<  <  Page 1 of 9  >  >>
```

## Why

ZenUI's dot pagination looks clean, but it can be hard to use when there are many pages. This patch keeps ZenUI's visual style while making pagination closer to KOReader's built-in menu behavior.

## Installation

Copy this file:

```text
2-zenui-arrow-pagination.lua
```

to KOReader's patches folder:

```text
/mnt/us/koreader/patches/2-zenui-arrow-pagination.lua
```

Then restart KOReader.

## Removal

Delete the patch file:

```text
/mnt/us/koreader/patches/2-zenui-arrow-pagination.lua
```

Then restart KOReader.

## Notes

This is an unofficial patch and is not part of ZenUI. It was made for users who prefer arrow-based navigation over dot pagination.


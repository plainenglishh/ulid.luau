# ulid.luau

A [Universally Unique Lexicographically Sortable Identifier](https://github.com/ulid/spec) generator for Luau.

## Installation

Simply copy and paste the contents of `lib/init.luau` into your project.

This project *should* work in the following runtimes:-

|Runtime|Supported|Has detectable CSPRNG|Has detectable ms-precise time function|
|-|-|-|-|
|Roblox|✅|❌|✅|
|[Lune](https://github.com/lune-org/lune)|✅|❌|✅|
|[Zune](https://github.com/Scythe-Technology/Zune)|✅|✅|✅|
|Pure Luau|✅|✅❌|❌|

## Usage

```lua
local ulid = require("./ulid").generator();

print(ulid()); --> 01BX5ZZKBKACTAV9WEVGEMMVS0
```

A list of generator options is as follows:-

|Option|Type|Default|Description|
|-|-|-|-|
|monotonic|`boolean`|`false`|Whether to use a monotonic generator, currently unsupported|
|dependencies|`{ prng: (min: number, max: number) -> number, time: () -> number }`|Runtime Dependent|Dictionary of functions to provide dependent functions|
|allow_insecure|`boolean`|`false`|Whether to suppress `insecure` errors|
|allow_imprecise|`boolean`|`false`|Whether to suppress `imprecise` errors|

## Contributing

Please feel free to submit pull requests, preferably stick to the same code style.

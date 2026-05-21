# Hanuman Language (ASCII notation)

Hanuman is a joke programming language inspired by the Japanese rock band Hanuman. Its keywords are lyrics from their songs — which means the full lyric-based syntax only makes sense if you understand Japanese and know the band's music.

**Hence, this README only covers the ASCII notation**, a shorthand syntax that works without any knowledge of Hanuman's lyrics.  

This document can be still interesting if you want to;
- create a new language based on lyrics
- create a new language using zig


## Core Concepts

Hanuman is inspired by Brainf**k. Internally it maintains:
- An array of 65536 signed 32-bit integers, all initialized to 0
- An index starting at 0

```
|0|0|0|0| ... |0|
 ↑
index = 0
```

**One instruction per line.** Lines starting with `#` are comments.

## Keywords

`N` is a positive integer or an element reference (see [Element References](#element-references)).

| ASCII | Description |
| --- | --- |
| `+N` | Add N to current element |
| `-N` | Subtract N from current element |
| `*N` | Multiply current element by N |
| `/N` | Divide current element by N |
| `%N` | Set current element to `(current value) mod N` |
| `_` | Set current element to 0 |
| `rand` | Set current element to a random value (-2^16 to 2^16) |
| `@N` | Move index to element N |
| `[` | Loop start (enter if current element ≠ 0) |
| `]` | Loop end |
| `?` | Start conditional (if current element ≠ 0) |
| `:` | Else branch |
| `;` | End conditional |
| `fn_{name}` | Define function named `name` |
| `end_fn` | End function definition |
| `call_{name}` | Call function named `name` |
| `pd` | Print current element as a number |
| `pu` | Print current element as a Unicode character |
| `echo "X"` | Print the string X |
| `cr` | Print a newline |

## Element References

Arithmetic operations and `@` support element references using `&N`, which reads the value at element N instead of using a literal number.

```
# Copy element 0's value into element 1
@1
+&0
```

Double references (`&&N`) are not supported and will cause a syntax error.

## Control Flow

### Loop

Enters the loop body only if the current element is non-zero. Loops until the element becomes 0.

```
# Print 5 down to 1
+5
[
    pd
    cr
    -1
]
```

### Conditional

All three parts (`?`, `:`, `;`) are required — even if one branch is empty.

```
%17
?
    echo "not divisible by 17"
    cr
:
    echo "divisible by 17"
    cr
;
```

### Functions

```
# Define
fn_hello
    echo "Hello World"
    cr
end_fn

# Call
call_hello
```

## Examples

### Hello World

```
echo "Hello World!"
```

### FizzBuzz (1 to 30)

```
# fizz function — @2 holds target num, @4 holds printed flag
fn_fizz
    @2
    _
    +&1
    %3
    ?
    :
        echo "fizz"
        @4
        +1
    ;
end_fn

# buzz function — @3 holds target num, @4 holds printed flag
fn_buzz
    @3
    _
    +&1
    %5
    ?
    :
        echo "buzz"
        @4
        +1
    ;
end_fn

# @0 counter, @1 current number
@1
+1
@0
+30
[
    @1
    call_fizz
    call_buzz
    @4
    ?
        cr
        @4
        _
    :
        @1
        pd
        cr
    ;
    @1
    +1
    @0
    -1
]
```

## Converting Between ASCII and Lyrics

The `hanuman` binary can convert between the two notations:

```
# Convert to lyrics
hanuman --to-lyrics program.hnmn

# Convert to ASCII
hanuman --to-ascii program.hnmn
```

Mixed notation in the same file is valid but not recommended.

## Installation

You can download a pre-built binary from the releases page.

Or, you can build from source with zig (v0.15):

```
$ make

# Verify installation
$ ./hanuman -v
```


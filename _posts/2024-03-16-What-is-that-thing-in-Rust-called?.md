---
title: What is that thing in Rust called?
description: Rust vocabulary that is impossible to google - a reference for those mysterious syntax elements and concepts.
categories: [Programming]
tags: [rust, syntax, reference, vocabulary]
---

A few years back, I heard [D.H.A.R.N.T.Z.](https://www.youtube.com/watch?v=feIeCR6oFNM) by Jazz Emu. Unfortunately, the song is about homophones, which makes it insanely hard to find online if you forgot the artists name and the exact spelling. I searched for months, trying various misremembered spellings "darnts", "dantz", "darnz", etc. Eventually, desparate and *hungry for funk*, I went on Reddit and made a post asking for help.

No answers, just the bot telling me the subreddit rules. A few days later, somebody sends some suggestions, but they were unfortunately wrong.

It took **6 months** of waiting, until a kind stranger came along, and finally granted me the answer, which led me back to Jazz Emu, and to the whole repertoire of amazing music which I might have otherwise missed (btw, LLMs do not help at all, had no luck with them with what I remebered of the song when I tried before writing this post).

Sometimes, programming can be a bit like that as well. You see some syntax or concept, but you don't know what it's called, and searching for it is impossible. This post is a reference for those mysterious Rust syntax elements and concepts that are hard to google, or remember.

## Syntax Elements

### "Turbofish" = `::<>`
The thing you use for explicit generic type parameters:

```rust
let numbers = Vec::<i32>::new();
let parsed = "42".parse::<i32>().unwrap();
```

### "Fat Arrow" = `=>`
Used in match arms and closures:

```rust
match value {
    Some(x) => println!("{}", x),
    None => println!("Nothing"),
}

let closure = |x| => x * 2; // also closures, can be hard to remember the word
```

### "Thin Arrow" = `->`
Function return type annotation:

```rust
fn add(a: i32, b: i32) -> i32 {
    a + b
}
```

### "Double Colon" = `::`
Path separator for modules, associated functions, and types:

```rust
std::collections::HashMap::new()
String::from("hello")
```

## Ownership & Borrowing

### "Borrow Checker"
The thing that makes you hate Rust at first, then love it:

```rust
let s1 = String::from("hello");
let s2 = &s1; // borrowing
// let s3 = s1; // error: value used after move
```

### "Lifetime Elision"
Why you don't always need to write lifetime parameters:

```rust
// This works without explicit lifetimes
fn first_word(s: &str) -> &str {
    s.split_whitespace().next().unwrap_or("")
}

// But this is what the compiler infers:
fn first_word_explicit<'a>(s: &'a str) -> &'a str {
    s.split_whitespace().next().unwrap_or("")
}
```

### "RAII" = Resource Acquisition Is Initialization
Why `Drop` gets called automatically:

```rust
{
    let file = File::open("data.txt")?; // acquired
    // use file
} // automatically dropped/closed here
```

## Pattern Matching

### "Irrefutable Patterns"
Patterns that always match:

```rust
let (x, y) = (1, 2); // always works
let Some(value) = maybe_value; // refutable - might panic!
```

### "Match Guards"
Extra conditions in match arms:

```rust
match number {
    x if x > 0 => "positive",
    x if x < 0 => "negative", 
    _ => "zero",
}
```

### "Destructuring"
Taking apart structs/enums in patterns:

```rust
struct Point { x: i32, y: i32 }

let p = Point { x: 0, y: 7 };
let Point { x, y } = p; // destructuring
```

## Traits & Generics

### "Blanket Implementations"
Implementing a trait for all types that satisfy certain bounds:

```rust
impl<T: Display> ToString for T {
    fn to_string(&self) -> String {
        // implementation
    }
}
```

### "Associated Types" vs "Generic Parameters"
```rust
// Associated type - one concrete type per implementation
trait Iterator {
    type Item;
    fn next(&mut self) -> Option<Self::Item>;
}

// Generic parameter - can be used with multiple types
trait From<T> {
    fn from(value: T) -> Self;
}
```

### "Higher-Ranked Trait Bounds" (HRTB)
The `for<'a>` syntax:

```rust
fn call_with_ref<F>(f: F) 
where 
    F: for<'a> Fn(&'a str) -> &'a str
{
    // f can work with any lifetime
}
```

## Macros

### "Declarative Macros" = `macro_rules!`
Pattern-based code generation:

```rust
macro_rules! vec {
    ( $( $x:expr ),* ) => {
        {
            let mut temp_vec = Vec::new();
            $(
                temp_vec.push($x);
            )*
            temp_vec
        }
    };
}
```

### "Procedural Macros"
The three types that run at compile time:
- **Derive macros**: `#[derive(Debug)]`
- **Attribute macros**: `#[my_attribute]`  
- **Function-like macros**: `my_macro!()`

## Memory Layout

### "Zero-Cost Abstractions"
High-level features that compile to the same assembly as hand-written low-level code:

```rust
// This iterator chain...
let sum: i32 = (0..1_000_000)
    .filter(|x| x % 2 == 0)
    .map(|x| x * x)
    .sum();

// ...compiles to roughly the same thing as:
let mut sum = 0;
for i in 0..1_000_000 {
    if i % 2 == 0 {
        sum += i * i;
    }
}
```

### "Fat Pointers"
Pointers that carry extra metadata:

```rust
let slice: &[i32] = &[1, 2, 3]; // pointer + length
let trait_obj: &dyn Display = &42; // pointer + vtable
```

## Error Handling

### "Railway-Oriented Programming"
Chaining operations that might fail:

```rust
let result = read_file("data.txt")?
    .parse::<i32>()?
    .checked_mul(2)
    .ok_or("overflow")?;
```

### "Error Propagation" = `?` operator
The thing that replaced `.unwrap()` everywhere:

```rust
// Instead of:
match some_operation() {
    Ok(value) => value,
    Err(e) => return Err(e),
}

// Just write:
some_operation()?
```

## Async/Await

### "Zero-Cost Futures"
Async functions compile to state machines:

```rust
async fn fetch_data() -> Result<String, Error> {
    let response = http_client.get("url").await?;
    Ok(response.text().await?)
}
```

### "Pin" and "Unpin"
The thing that makes self-referential futures work (and confuses everyone):

```rust
// Most types are Unpin (can be moved safely)
// Some futures are !Unpin (contain self-references)
let pinned = Box::pin(some_future);
```

## Tools That Are Better Than The Obvious Choice

### "`cargo-expand`" 
Better than trying to read macro output:
```bash
cargo install cargo-expand
cargo expand --lib my_module
```

### "`cargo-watch`"
Better than manually running cargo commands:
```bash
cargo install cargo-watch  
cargo watch -x test
```

### "`cargo-llvm-cov`"
What Rust coverage should be:
```bash
cargo install cargo-llvm-cov
cargo llvm-cov
```
---

Know any other impossible-to-google Rust terms? Let me know and I'll add them!

> **Pro tip**: When you see mysterious syntax, try searching for "rust [exact symbols]" - the Rust community is pretty good about using the actual symbols in documentation.
{: .prompt-tip }
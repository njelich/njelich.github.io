---
title: Wasmcov - WebAssembly Code Coverage the Hard Way
description: A deep dive into the engineering behind wasmcov, a Rust tool that brings LLVM code coverage to WebAssembly by cleverly working around the limitations of existing tooling.
categories: [Projects]
tags: [rust, webassembly, llvm, code-coverage, near-protocol, testing]
---

> "The best way to find out if you can trust somebody is to trust them." - Ernest Hemingway

Back in 2023, if you were working with WebAssembly and wanted code coverage reports, you were out of luck. The standard LLVM coverage tools simply didn't work with WASM binaries - `llvm-cov` would throw errors about missing coverage sections, and there was no clear path forward.

At that time [Bartosz Barwikowski](https://x.com/bbarwik) and I were each working on our own little obscure Rust WASM audits, and I had just found an issue that I thought should've been caught by automated testing, but instead found itself on my report. And that is how I found out about the above coverage situation.

And thus, over the next few weeks we built [wasmcov](https://github.com/hknio/wasmcov) - a tool that bridges this gap by implementing a clever workaround that transforms LLVM IR into object files that coverage tools can understand. Let's dive into how it works and why we had to build it this way.

## What is Wasmcov?

[Wasmcov](https://github.com/hknio/wasmcov) is a Rust library and CLI tool that enables LLVM-based code coverage for WebAssembly projects. It works by:

1. **Instrumenting** Rust code with LLVM coverage flags during compilation
2. **Capturing** coverage data at runtime from WASM modules
3. **Converting** LLVM IR files to object files that coverage tools can process
4. **Generating** HTML coverage reports using standard LLVM tooling

## The Core Problem: WASM vs LLVM Coverage

The fundamental issue is architectural. LLVM's coverage system expects object files with specific sections:

```bash
$ llvm-cov show --instr-profile=coverage.profdata our_binary.wasm
error: Failed to load coverage: 'our_binary.wasm': No coverage data found
```

WebAssembly binaries don't contain the `__llvm_covmap` section that `llvm-cov` needs. This section contains the mapping between source code locations and coverage counters. Without it, coverage tools can't generate reports.

## Architecture Overview

Wasmcov implements a multi-stage pipeline to work around this limitation:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Rust Source   │───►│   LLVM IR       │───►│   Object File   │
│   + Instr.      │    |   (.ll files)   │    │   (.o files)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Coverage Report │◄───│   llvm-cov      │◄───│ Runtime Coverage│
│   (HTML/JSON)   │    │                 │    │  (.profraw)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Key Components

1. **Build System** (`src/build.rs`) - Manages Rust compilation with coverage flags
2. **LLVM Tooling** (`src/llvm.rs`) - Interfaces with LLVM tools and version detection
3. **Runtime Integration** - Captures coverage data from WASM modules
4. **Report Generation** (`src/report.rs`) - Merges raw data and generates reports

## The LLVM IR to Object File Strategy

The core insight behind wasmcov is using LLVM IR as an intermediate representation. When Rust compiles to WASM with the right flags, it can emit both the WASM binary and LLVM IR:

```rust
// src/build.rs
pub fn get_build_flags() -> Vec<&'static str> {
    vec![
        "--emit=llvm-ir",        // Generate .ll files
        "-Cinstrument-coverage", // Add coverage instrumentation
        "-Clto=off",            // Disable LTO for better debugging
        "-Zlocation-detail=none", // Reduce debug info overhead
        "-Zno-profiler-runtime", // Don't link profiler runtime
    ]
}
```

The LLVM IR files contain all the coverage metadata that WASM binaries lack:

```llvm
; From tests/output/fibonacci-cov.ll
@__llvm_coverage_mapping = private constant { { i32, i32, i32, i32 }, [48 x i8] } 
{ { i32, i32, i32, i32 } { i32 0, i32 48, i32 0, i32 5 }, [48 x i8] 
c"\02%-x\DA\13\D2\CF\C8\CFM\D5\CF\CBO\CC\D0/O,\CEM\CE/\13,I-.)\D6O\CBL..." }, 
section "__llvm_covmap", align 8

@__profc_main = private global [3 x i64] zeroinitializer, 
section "__llvm_prf_cnts", comdat, align 8
```

## The WebAssembly Instruction Problem

Now, when you try to simply cross-compile this LLVM IR to a native object file, it fails because the IR contains WebAssembly-specific instructions that aren't valid in native object files. We resolve this by transforming the LLVM IR to remove these instructions while preserving the coverage metadata.

```rust
// src/build.rs
pub fn correct_ll_file(ll_file: &PathBuf, new_ll_file: &PathBuf) -> Result<(), anyhow::Error> {
    let mut ll_contents = String::new();
    File::open(&ll_file)?.read_to_string(&mut ll_contents)?;

    // Replace all function bodies with unreachable stubs
    let modified_ll_contents = Regex::new(r"(?ms)^(define[^\n]*\n).*?^}\s*$")
        .unwrap()
        .replace_all(&ll_contents, "${1}start:\n  unreachable\n}\n")
        .to_string();

    File::create(&new_ll_file)?.write_all(modified_ll_contents.as_bytes())?;
    Ok(())
}
```

This transformation:
1. **Preserves** all metadata sections needed for coverage
2. **Removes** WebAssembly-specific instructions 
3. **Replaces** function bodies with simple `unreachable` stubs
4. **Maintains** the original function signatures for mapping

The result is LLVM IR that can be compiled to a native object file while preserving coverage metadata.

## Runtime Coverage Data Pipeline Integration

For general WASM projects, wasmcov provides a capture function that users must integrate:

```rust
// From README.md example
#[cfg(target_family = "wasm")]
#[no_mangle]
pub unsafe extern "C" fn capture_coverage() {
    const BINARY_NAME: &str = env!("CARGO_PKG_NAME");
    let mut coverage = vec![];
    wasmcov::minicov::capture_coverage(&mut coverage).unwrap();
    // Store or transmit coverage data
}
```

This function uses the [`minicov`](https://github.com/Amanieu/minicov) library to extract LLVM profiling data from the WASM runtime.

### Data Merging

Raw coverage files are merged using LLVM's `llvm-profdata` tool:

```rust
// src/report.rs
pub fn merge_profraw_to_profdata(
    profraw_dir: &PathBuf, 
    profdata_path: &PathBuf, 
    extra_args: Vec<String>
) -> Result<()> {
    let profraw_files: Vec<String> = glob(profraw_dir.join("*.profraw").to_str().unwrap())?
        .filter_map(|entry| entry.ok())
        .map(|path| path.to_string_lossy().into_owned())
        .collect();

    let mut args = vec![
        "merge".to_string(),
        "-sparse".to_string(),  // Sparse format for efficiency
        "-o".to_string(),
        profdata_path.to_str().unwrap().to_string(),
    ];
    args.extend(extra_args);
    args.extend(profraw_files);

    run_command(
        &llvm::get_tooling()?.llvm_profdata,
        args.iter().map(AsRef::as_ref).collect::<Vec<&str>>().as_slice(),
        None,
    )?;
    
    Ok(())
}
```

## Report Generation

Finally, coverage reports are generated using `llvm-cov`:

```rust
// src/report.rs
pub fn generate_report(
    profdata_path: &PathBuf,
    object_file: &PathBuf,
    report_dir: &PathBuf,
    llvm_cov_args: &Vec<String>,
) -> Result<()> {
    let mut cov_args = vec![
        "show",
        "--instr-profile", profdata_path.to_str().unwrap(),
        object_file.to_str().unwrap(),
        "--output-dir", report_dir.to_str().unwrap(),
        "--show-instantiations=false",
        "--format=html",
        "-show-directory-coverage",
    ];
    cov_args.extend(llvm_cov_args.iter().map(AsRef::as_ref));
    
    run_command(&llvm::get_tooling()?.llvm_cov, cov_args.as_slice(), None)?;
    Ok(())
}
```

## Lessons Learned

### LLVM IR as a Universal Interface

The key insight was recognizing that LLVM IR contains all the metadata needed for coverage, even when the final binary format doesn't support it. This approach could work for other binary formats beyond WebAssembly.

### Version Compatibility is Critical

LLVM tools are notoriously sensitive to version mismatches. Building robust version detection and tool discovery was essential for reliability. We ended up adding a ton of logic to handle just the LLVM versioning and tool discovery across platforms.

### Workarounds Are Sometimes Necessary

It's not always possible to get a perfect solution. While the ideal approach would be an upstream modification to LLVM, this fix is still useful, and has been integrated by a number of teams, providing valuable coverage insights.

---

The complete source code is available on [GitHub](https://github.com/hknio/wasmcov) under the Apache 2.0 license. Feel free to explore, contribute, or use it in your own projects!
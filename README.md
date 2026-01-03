# Auto Build Libraries

A project for automatically building multiple libraries with cross-compilation support.

## Supported Libraries

- **libz (zlib)**: Data compression library.
- **bzip2**: Block-sorting compression algorithm library.
- **brotli**: General-purpose lossless compression algorithm library.
- **harfbuzz**: Text shaping engine library.
- **freetype**: FreeType is free software, a font rendering library.

## Getting Started

### 1. Git Submodule Setup

After cloning the project, initialize the submodules:

```bash
# Method 1: Use the automatic script
chmod +x setup_submodules.sh
./setup_submodules.sh

# Method 2: Manual execution
git submodule update --init --recursive
```

### 2. Building Libraries

#### Building libz (zlib)

**Cross-compilation (default)**:
```bash
chmod +x build_libz.sh
./build_libz.sh
```

**Native build only**:
```bash
./build_libz.sh --native
# or
./build_libz.sh -n
```

Built libraries are installed in the `install/libz/<target>/` directory.

etc...

**Note**: Build libz, bzip2, brotli, and harfbuzz before building freetype.


Cross-compilation is performed for the following target architectures, building both **shared libraries** and **static libraries** for each target:
- `aarch64-linux-gnu`
- `riscv64-linux-gnu`
- `x86_64-linux-gnu`
- `i386-linux-gnu`
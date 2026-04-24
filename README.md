# Steiner Chain Explorer

A fast, interactive 2D visualization of **Steiner's Porism**, written entirely in Rust using the `egui` framework.

This application mathematically models a Steiner chain: a set of $n$ mutually tangent circles bounded by two non-intersecting circles (one outer, one inner). It demonstrates Steiner's Porism, which states that if at least one closed chain of circles exists for a given pair of bounding circles, then an infinite number of such chains exist, and they can continuously "rotate" along the annular gap.

## Features
* **Real-time Animation:** Watch the circles fluidly grow and shrink as they traverse the tight and wide spaces between the eccentric boundaries.
* **Interactive Parameters:** * Adjust the number of circles ($n$) in the chain (from 3 to 24).
  * Adjust the eccentricity (offset) of the inner bounding circle.
* **Mathematical Foundation:** Instead of solving complex tangency equations for every frame, this engine computes a perfect concentric chain at the origin and applies a **Möbius transformation** in the complex plane to map the coordinates to the eccentric bounds. This ensures perfect geometric tangency at zero computational bottleneck.

## Installation & Running (Linux/Ubuntu)

Since this project uses native windowing and graphics rendering via `eframe`, you need a few standard graphical dependencies installed on your system.

### 1. Install Dependencies
Open your terminal and run:
```bash
sudo apt update
sudo apt install -y libxcb-render0-dev libxcb-shape0-dev libxcb-xfixes0-dev libxkbcommon-dev libssl-dev
```
 
### 2. Build and Run

Clone the repository and run it with cargo in release mode (for maximum performance):
Bash

```bash
git clone [https://github.com/YOUR_USERNAME/steiner_chain.git](https://github.com/YOUR_USERNAME/steiner_chain.git)
cd steiner_chain
cargo run --release
```

### Technologies Used

   Rust: Core systems language.

   egui: Immediate mode GUI library for the interface and 2D canvas rendering.

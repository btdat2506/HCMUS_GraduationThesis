The **Mesh** is Gemmini's core computational engine - a systolic array that performs matrix multiplication operations. It's implemented as a 2D grid of Processing Elements (PEs) organized in a hierarchical structure:

- The mesh consists of `Tiles`, and each tile contains multiple `PEs`
- Configured by `meshRows × meshColumns` tiles, where each tile has `tileRows × tileColumns` PEs

## Hierachical Relationship: MACs -> PE → Tile → Mesh -> MeshWithDelays

### **0. The MAC Unit - The Multiply-Accumulator Unit, or the FPU of Gemmini**


### **1. PE (Processing Element) - The Bottom Level**
- **Individual compute unit** that performs MAC operations
- **Function**: 
    - Single MAC operation: `out_c = in_c + (in_a × in_b)`

### **2. Tile - The Middle Level** 
- **2D array of PEs** arranged in `tileRows × tileColumns`
- **Function**: 
  - **Purely combinational** - no pipeline registers between PEs within a tile
  - Broadcasts inputs across PEs within the tile
  - Each tile is `tileRows × tileColumns` PEs

### **3. Mesh - The Top Level**
- **2D array of Tiles** arranged in `meshRows × meshColumns` 
- **Function**:
  - **Pipelined** - has pipeline registers between tiles
  - Controls the systolic dataflow across tiles
  - Each mesh is `meshRows × meshColumns` tiles

### **4. MeshWithDelays - The Wrapper**
- **Wrapper around Mesh** that adds:
  - Input buffering and scheduling
  - Transposer for different dataflows  
  - Tag tracking for multiple simultaneous operations
  - Banking and delay management

## Summarize: 
- **PEs**: Individual MAC units (fundamental compute)
- **Tiles**: Combinational arrays of PEs (no internal pipelining)  
- **Mesh**: Pipelined array of Tiles (systolic array behavior)
- **MeshWithDelays**: Control wrapper around Mesh (scheduling & coordination)

## **1. Why PE Level? (Individual MAC Units)**

**Function**: Single MAC operation `out_c = in_c + (in_a × in_b)`

**Why needed**: 
- **Fundamental compute primitive** - smallest meaningful unit
- **Data type flexibility** - can handle different bit widths (8-bit, 16-bit, etc.)
- **Dataflow flexibility** - supports both Weight-Stationary (WS) and Output-Stationary (OS) modes

## **2. Why Tile Level? (Combinational PE Arrays)**

**Key insight from code**:
```scala
// From Tile.scala - NO pipeline registers within tiles
pe.io.in_a := in_a  // Direct connection, no ShiftRegister
```

**Why combinational (no registers within tiles)?**
- **Minimize latency** within a tile for fast local operations
- **Reduce area/power** - registers are expensive in area and power
- **Timing closure** - smaller combinational blocks are easier to meet timing

**Why group PEs into tiles?**
- **Broadcast efficiency** - one signal can drive multiple PEs within a tile
- **Local data reuse** - PEs within a tile can share the same input data
- **Physical design** - tiles are natural units for placement and routing

## **3. Why Mesh Level? (Pipelined Tile Arrays)**

**Key insight from code**:
```scala
// From Mesh.scala - Pipeline registers BETWEEN tiles
tile.io.in_a := ShiftRegister(in_a, tile_latency+1)  // Registers between tiles!
```

**Why pipeline registers between tiles but not within tiles?**

### **Systolic Array Dataflow Requirements**:
- **Data must flow in waves** across the array
- **Each tile processes different data at different times**
- **Pipeline registers create the "systolic heartbeat"**

### **Performance Benefits**:
- **High throughput** - can process multiple matrix rows simultaneously
- **Scalability** - can make arrays arbitrarily large by adding more pipeline stages
- **Timing closure** - breaks long combinational paths

### **Why `tile_latency+1` delay?**
```scala
// From Mesh.scala
tile.io.in_a := ShiftRegister(in_a, tile_latency+1)
```
- **Accounts for tile's internal combinational delay**
- **Ensures data arrives at the right time** for systolic operation
- **Synchronizes with the systolic wavefront**

## **4. Why MeshWithDelays Level? (Control Wrapper)**

**Key insight from code**:
```scala
// From MeshWithDelays.scala - Complex control logic
val a_buf = RegEnable(io.a.bits, io.a.fire)  // Input buffering
val transposer = Module(new AlwaysOutTransposer(...))  // Matrix transpose
val tagq = Module(new TagQueue(...))  // Tag tracking
```

**Why separate from Mesh?**
- **Input/output buffering** - handles timing mismatches with external systems
- **Matrix transposition** - supports different dataflow modes (OS vs WS)
- **Multi-operation tracking** - can handle multiple simultaneous matrix multiplications
- **Banking and shifting** - optimizes memory bandwidth utilization

## **Design Trade-offs Summary**

| Level | Registers? | Purpose | Trade-off |
|-------|------------|---------|-----------|
| **PE** | Internal state only | Basic computation | Minimize complexity |
| **Tile** | **No** (combinational) | Fast local operations | Latency vs. Area |
| **Mesh** | **Yes** (between tiles) | Systolic dataflow | Throughput vs. Latency |
| **MeshWithDelays** | Yes (control logic) | System integration | Flexibility vs. Complexity |

## **Why This Specific Hierarchy?**

1. **Physical Design**: Tiles are natural units for physical placement
2. **Timing**: Combinational tiles + pipelined mesh balances latency and throughput  
3. **Scalability**: Can adjust `meshRows/meshColumns` vs `tileRows/tileColumns` for different performance/area targets
4. **Modularity**: Clean separation allows independent optimization of each level
5. **Systolic Requirements**: Pipeline registers at mesh level create the required data flow pattern

The hierarchy reflects **hardware design fundamentals**: start with simple compute units (PE), group them efficiently (Tile), create scalable arrays (Mesh), and add necessary control logic (MeshWithDelays).

---
# MAC Unit: The Multiply-Accumulator, or the Floating Point Unit (FPU) of Gemmini

In Gemmini, there is no dedicated FPU unit. 

Unlike traditional CPUs with a dedicated FPU, Gemmini integrates floating point operations **directly into the systolic array**:

Traditional CPU: [Integer ALU] [FPU] [Load/Store Unit]
Gemmini:         [PE + FP_Units] [PE + FP_Units] [PE + FP_Units] ... (distributed across mesh)

The MAC Unit itself is a floating point unit. 

The MAC Unit is an abstration layer of the Arithmetic.scala, which is the true FPU.

Instead of adding a separate FPU, Gemmini makes **every PE an FPU**, creating a massively parallel floating-point systolic array. This is why it's so effective for neural networks that require intensive floating-point matrix operations.

Gemmini does **not** have a centralized Floating Point Unit (FPU). Instead, it implements a **distributed floating point architecture** where arithmetic operations (including floating point) are spread across all Processing Elements (PEs) in the systolic array through the Arithmetic typeclass. The Arithmetic typeclass itself is the "FPU" abstraction layer.


#### **Code Components:**

**A. Arithmetic.scala - The "FPU" Abstraction Layer**
- **Purpose**: Provides floating point operations for the entire accelerator
- **Uses Berkeley HardFloat library**: High-performance IEEE 754 compliant FP units
- **Operations supported**:
  - Multiply: `MulRecFN`
  - Multiply-Add: `MulAddRecFN` 
  - Division: `DivSqrtRecFN_small`
  - Square Root: `DivSqrtRecFN_small`
  - Conversions: `RecFNToRecFN`, `INToRecFN`

**B. PE-Level Floating Point**
```scala
// From PE.scala - each PE can handle floating point MAC operations
val mac_unit = Module(new MacUnit(inputType, weightType, cType, outputType))
// MAC unit internally uses floating point arithmetic when configured with Float types
```

**C. Floating Point Configurations**
```scala
// From ConfigsFP.scala
val FP32DefaultConfig = GemminiArrayConfig[Float, Float, Float](
  inputType = Float(8, 24),      // FP32 inputs
  weightType = Float(8, 24),     // FP32 weights  
  accType = Float(8, 24),        // FP32 accumulator
  // ... mesh still uses same PE→Tile→Mesh hierarchy
)
```

They also show in the code that:
```scala
  // When creating PEs that support multiple dataflows, the
  // elaboration/synthesis tools often fail to consolidate and de-duplicate
  // MAC units. To force mac circuitry to be re-used, we create a "mac_unit"
  // module here which just performs a single MAC operation
  val mac_unit = Module(new MacUnit(inputType, weightType,
    if (df == Dataflow.WS) outputType else accType, outputType))
```

## **Available Operations in ArithmeticOps**

### **Core Arithmetic Operations**
1. **`*(t: T): T`** - Multiplication
2. **`mac(m1: T, m2: T): T`** - Multiply-Accumulate (returns `m1 * m2 + self`)
3. **`+(t: T): T`** - Addition  
4. **`-(t: T): T`** - Subtraction

### **Bitwise/Shift Operations**
5. **`>>(u: UInt): T`** - Rounding right shift (rounds away from 0)
6. **`>(t: T): Bool`** - Greater than comparison

### **Data Manipulation Operations**
7. **`withWidthOf(t: T): T`** - Resize to match width of another value
8. **`clippedToWidthOf(t: T): T`** - Resize with saturation
9. **`relu: T`** - ReLU activation function
10. **`zero: T`** - Zero value
11. **`identity: T`** - Identity/one value  
12. **`minimum: T`** - Minimum representable value

### **Advanced Operations (Optional)**
13. **`divider(...): Option[...]`** - Hardware divider interface
14. **`sqrt: Option[...]`** - Square root interface
15. **`reciprocal(...): Option[...]`** - Reciprocal calculation
16. **`mult_with_reciprocal(...): T`** - Multiply with precomputed reciprocal

## **Implemented Data Types**

### **1. UIntArithmetic (Unsigned Integers)**
- **Basic ops**: Standard unsigned arithmetic
- **Rounding shift**: Uses RISC-V vector fixed-point rounding
- **Clipping**: Saturates to maximum representable value
- **ReLU**: Pass-through (already non-negative)

### **2. SIntArithmetic (Signed Integers)**  
- **Basic ops**: Standard signed arithmetic
- **Rounding shift**: RISC-V compliant with sign handling
- **Clipping**: Saturates to min/max signed values
- **ReLU**: `Mux(self >= 0.S, self, 0.S)`
- **Advanced ops**: Implements divider, sqrt, reciprocal using HardFloat conversion

### **3. FloatArithmetic (IEEE 754 Floating Point)**
- **Format handling**: Supports both standard and recoded formats
- **HardFloat integration**: Uses Berkeley HardFloat library
- **All operations**: Full IEEE 754 compliant arithmetic
- **Format conversion**: Automatic recoding between formats

### **4. DummySIntArithmetic (Placeholder)**
- **No-op implementation**: All operations return `dontCare`
- **Used for**: Testing or placeholder configurations

## **Key Usage Patterns**

### **1. MAC Operation (Most Critical)**
This is the heart of systolic array computation:
```scala
override def mac(m1: Float, m2: Float): Float = {
  // Uses HardFloat MulAddRecFN for IEEE 754 compliance
  // Performs: m1 * m2 + self
}
```

### **2. Precision/Width Management**
```scala
override def withWidthOf(t: T): T        // Resize without saturation
override def clippedToWidthOf(t: T): T   // Resize with saturation
```

### **3. Activation Functions**
```scala
override def relu: T = Mux(self >= 0.S, self, 0.S)  // For SInt
override def relu: Float = // Complex float implementation with sign checking
```

### **4. Advanced Mathematical Operations**
The SInt implementation provides sophisticated operations:
- **Division**: Converts to float, uses HardFloat divider, converts back
- **Square root**: Similar float conversion approach
- **Reciprocal**: For optimization in transformer models

## **Real-World Usage in Gemmini**

Based on my previous analysis of the codebase:

### **Primary Usage: PE MAC Units**
```scala
// In PE.scala MacUnit
io.out_d := io.in_c.mac(io.in_a, io.in_b)
```

### **Secondary Usage: AccumulatorScale**
```scala
// Polynomial approximations for activation functions
val q_poly = qc.mac(q_clipped + qb, q_clipped + qb).withWidthOf(q)
```

### **Configuration-Dependent Usage**
- **Integer configs**: Use `UIntArithmetic` or `SIntArithmetic`
- **FP32 configs**: Use `FloatArithmetic` with `Float(8, 24)`
- **FP16 configs**: Use `FloatArithmetic` with `Float(5, 11)`
- **BFloat16 configs**: Use `FloatArithmetic` with `Float(8, 8)`

## **Design Philosophy**

The Arithmetic typeclass enables:
1. **Type polymorphism**: Same PE/Tile/Mesh code works with different data types
2. **Hardware efficiency**: Each type maps to optimal hardware implementation
3. **IEEE compliance**: Floating point operations use industry-standard HardFloat
4. **Extensibility**: Easy to add new data types (e.g., posits, custom formats)


## Why This Architecture?

#### **Performance Advantages:**
1. **Massive Parallelism**: 256 FP MAC units (in 16×16 config) operating simultaneously
2. **Memory Bandwidth**: FP operands read once, used across many PEs
3. **Reduced Data Movement**: FP computations happen close to data storage

#### **vs. Traditional FPU:**
| Traditional FPU | Gemmini FP |
|----------------|------------|
| 1-4 FP units | 16-256 FP units |
| Scalar operations | Matrix operations |
| Register-based | Scratchpad-based |
| General purpose | ML/AI optimized |

**It's not a traditional FPU, but rather:**
1. **Distributed FP Architecture**: FP units embedded in every PE
2. **Berkeley HardFloat**: Industry-standard IEEE 754 compliance
3. **Same Hierarchy**: PE→Tile→Mesh→MeshWithDelays, but FP-capable
4. **Self-Contained**: No dependency on CPU's FPU
5. **Massive Parallelism**: 100s of FP MAC units vs. 1-4 in traditional FPUs

### **Configuration and Usage**

Different Gemmini configurations instantiate different arithmetic types:
- **Integer configs**: Use `SIntArithmetic` or `UIntArithmetic`
- **FP32 configs**: Use `FloatArithmetic` with `Float(8, 24)`
- **FP16 configs**: Use `FloatArithmetic` with `Float(5, 11)` 
- **BFloat16 configs**: Use `FloatArithmetic` with `Float(8, 8)`

---
# Architectural Impact of Single PE per Tile and Multiple PEs per Tile

## **1. Single PE per Tile (Default: `tileRows=1, tileColumns=1`)**

**16×16 mesh with 1×1 tiles:**
- Number of tiles = 16 × 16 = **256 tiles**
- PEs per tile = 1 × 1 = **1 PE per tile**
- **Total PEs = 256 tiles × 1 PE/tile = 256 PEs**
- **MAC ops/cycle = 256 MAC operations**

```
Tile = [ PE ]
```
- **Structure**: Each tile contains exactly one PE
- **Operation**: Pure pass-through systolic operation
- **Pipeline**: Maximum pipeline depth between tiles
- **Timing**: Each PE operation is isolated and pipelined

## **2. Multiple PEs per Tile (e.g., `tileRows=4, tileColumns=4`)**
**4×4 mesh with 4×4 tiles:**
- Number of tiles = 4 × 4 = **16 tiles**  
- PEs per tile = 4 × 4 = **16 PEs per tile**
- **Total PEs = 16 tiles × 16 PEs/tile = 256 PEs**
- **MAC ops/cycle = 256 MAC operations**

```
Tile = [ PE  PE  PE  PE ]
       [ PE  PE  PE  PE ]
       [ PE  PE  PE  PE ]
       [ PE  PE  PE  PE ]
```
- **Structure**: Tile contains a 2D array of PEs operating combinationally
- **Operation**: Multiple MAC operations happen simultaneously within each tile
- **Pipeline**: Reduced pipeline depth between tiles, more computation per stage


## **Clock Frequency vs Throughput Tradeoff**
Based on the code extracted from ... 

```scala
val latency_per_pe = ((tile_latency + 1).toFloat / (tileRows min tileColumns)) max 1.0f
```

- **1×1 tiles**: `latency_per_pe = (tile_latency + 1) / 1 = full latency`
- **4×4 tiles**: `latency_per_pe = (tile_latency + 1) / 4 = reduced latency per PE`


**Single PE per Tile**:
- **Advantage**: Higher maximum clock frequency (shorter combinational paths)
- **Advantage**: Better pipeline parallelism
- **Disadvantage**: More pipeline stages needed for same total computation

**Multiple PEs per Tile**:
- **Advantage**: More computation per clock cycle
- **Advantage**: Fewer pipeline stages needed
- **Disadvantage**: Longer combinational paths → lower max frequency
- **Disadvantage**: Higher area and power per tile

## **System-Level Efficiency Implications**

### **1. Memory Bandwidth Requirements**
- **Single PE**: Higher pipeline depth requires more buffering
- **Multiple PEs**: Lower pipeline depth, less intermediate buffering needed

### **2. Area and Power**
- **Single PE**: More pipeline registers between tiles
- **Multiple PEs**: More combinational logic per tile, fewer pipeline stages


### **1. Pipeline Depth**
- **16×16 mesh (1×1 tiles)**: 16 pipeline stages between input and output
- **4×4 mesh (4×4 tiles)**: 4 pipeline stages between input and output

### **2. Critical Path Length**
- **1×1 tiles**: Short combinational path (single PE per tile)
- **4×4 tiles**: Long combinational path (16 PEs chained combinationally)

### **4. Frequency vs Latency Tradeoff**

**16×16 mesh with 1×1 tiles:**
- ✅ **Higher max clock frequency** (shorter combinational paths)
- ✅ **Better for real-time applications** (predictable timing)
- ❌ **Higher pipeline latency** (16 stages to traverse the mesh)

**4×4 mesh with 4×4 tiles:**
- ✅ **Lower pipeline latency** (4 stages to traverse the mesh)  
- ✅ **Better for batch processing** (lower end-to-end latency)
- ❌ **Lower max clock frequency** (longer combinational paths)


















### **Real-World Usage Patterns**

#### **Default Production Configs** (`tileRows=1, tileColumns=1`)
- Optimized for **high frequency operation**
- Good balance of performance and implementability
- Easier place & route in ASIC/FPGA

#### **Research/Experimental Configs** (larger tiles)
- Explore **throughput-optimized** designs
- Useful for understanding area/power/performance tradeoffs
- May be suitable for specific applications with different constraints, such as:
  - **Inference applications** where latency matters more than throughput
  - **Small batch sizes** where pipeline startup cost is significant

#### **Use Cases Where Larger Tiles may Struggles:**
1. **High-frequency applications** (limited by critical path)
2. **Large-scale deployment** (timing closure challenges)
3. **Power-constrained environments** (high instantaneous power)



The choice of PE count per tile fundamentally changes the system from:
- **Pipeline-optimized** (many small tiles) → Better for high-frequency, real-time applications
- **Throughput-optimized** (fewer large tiles) → Better for batch processing, power-constrained scenarios

The default `1×1` configuration represents the sweet spot for most practical deployments, while larger tile configurations serve as research vehicles for exploring the design space boundaries.

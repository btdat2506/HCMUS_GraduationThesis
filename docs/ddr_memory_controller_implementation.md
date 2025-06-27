# DDR Memory Controller Implementation

## Overview

The DDR memory controller subsystem on the VC707 FPGA board provides high-performance memory access to the RISC-V RocketChip through Xilinx's Memory Interface Generator (MIG) 7-Series IP. This subsystem implements a complete DDR3 SDRAM interface with advanced features including memory reset control, calibration sequencing, and AXI4 bus bridging.

## Hardware Architecture

### Component Hierarchy

The DDR memory controller subsystem consists of four primary hardware blocks:

1. **Xilinx MIG 7-Series Controller** (`mig_7series_0`)
   - Implements DDR3 SDRAM protocol and PHY interface
   - Provides AXI4 slave interface for memory transactions
   - Handles memory calibration and timing closure

2. **Memory Reset Control Module** (`mem_reset_control_0`)
   - Custom Verilog module managing reset sequencing
   - Coordinates calibration completion signaling
   - Provides system-wide memory status indication

3. **AXI SmartConnect** (`axi_smc_1`)
   - Single master-to-slave interconnect bridge
   - Clock domain crossing between system and memory clocks
   - Protocol adaptation and bus width matching

4. **DDR3 Physical Interface**
   - 64-bit data interface to external SODIMM
   - 15-bit address, 3-bit bank address
   - Differential clock and data strobe signals

### Memory Configuration

Based on the MIG project file (`DDR3-1Rx64-2GB.prj`), the DDR3 controller is configured as follows:

**Memory Device Specifications:**
- Memory Type: DDR3 SDRAM SODIMM (MT8KTF25664HZ-1G6)
- Capacity: 2GB (configurable 1GB, 2GB, 4GB, 8GB variants available)
- Data Width: 64-bit
- Voltage: 1.5V
- Organization: Single rank (1Rx64)

**Timing Parameters:**
- Operating Frequency: 800 MHz (400 MHz DDR)
- CAS Latency: 11
- Row Address: 15 bits (32K rows)
- Column Address: 10 bits (1K columns)  
- Bank Address: 3 bits (8 banks)
- Burst Length: 8 (fixed)

**Performance Characteristics:**
- Peak Bandwidth: 6.4 GB/s (64-bit × 800 MHz)
- Memory Interface Clock: 200 MHz input, 400 MHz internal
- AXI Interface: 512-bit data width, 31-bit address width
- AXI ID Width: 4 bits

## Bus Architecture and Connectivity

### AXI4 Interface Hierarchy

The memory subsystem implements a hierarchical AXI4 bus structure:

```
RocketChip (MEM_AXI4) → AXI SmartConnect → MIG Controller → DDR3 SODIMM
```

**RocketChip Memory Interface:**
- Bus Type: AXI4 Master  
- Data Width: Variable (64-bit standard, 256-bit wide bus configuration)
- Address Width: Variable (determined by configuration, up to 31-bit for 2GB)
- Clock Domain: System clock (variable, typically 100 MHz)

**AXI SmartConnect Configuration:**
- Type: `xilinx.com:ip:smartconnect:1.0`
- Masters: 1 (NUM_SI = 1)
- Slaves: 1 (to MIG controller)
- Clock Domains: 2 (NUM_CLKS = 2)
  - `aclk`: System clock domain
  - `aclk1`: Memory UI clock domain
- Data Width Conversion: Adapts RocketChip bus width (64/256-bit) to MIG interface (512-bit)

**MIG AXI4 Interface:**
- Bus Type: AXI4 Slave
- Data Width: 512-bit
- Address Width: 31-bit
- Burst Support: Full AXI4 burst transactions
- Clock Domain: UI clock (200 MHz)

### Memory Address Mapping

The DDR memory controller is mapped to the base of the physical address space:

```
Base Address: 0x00000000
Address Range: Configurable (1GB to 8GB)
Address Decoding: Full address space starting from 0x0
```

**Address Assignment (from TCL):**
```tcl
assign_bd_address -offset 0x00000000 -range $addr_range \
  -target_address_space [get_bd_addr_spaces RocketChip/MEM_AXI4] \
  [get_bd_addr_segs DDR/mig_7series_0/memmap/memaddr] -force
```

Where `$addr_range` is determined by the configured address width:
- Address bits determine maximum addressable space
- Actual memory size configured by project parameters
- Memory hole for MMIO preserved above 2GB boundary

## Clock and Reset Architecture

### Clock Domains

The memory subsystem operates across multiple clock domains:

**System Clock Domain (`AXI_clock`):**
- Source: `clk_wiz_0/clk_out1`
- Frequency: Variable (typically 100 MHz for VC707)
- Connected to: AXI SmartConnect system side, RocketChip

**Memory UI Clock Domain (`mem_ui_clk`):**
- Source: MIG controller internal MMCM
- Frequency: 200 MHz (UI clock)
- Connected to: AXI SmartConnect memory side, MIG controller

**DDR Reference Clock:**
- Source: 200 MHz differential input clock
- Connected to: MIG controller `sys_clk_i`
- Used for: DDR PHY timing and calibration

### Reset and Calibration Sequence

The memory reset control module (`mem_reset_control.v`) implements a sophisticated reset and calibration sequence:

**Reset Inputs:**
- `sys_reset`: System-wide reset from external reset button
- `clock_ok`: MMCM lock indication from clock wizard
- `AXI_reset`: System AXI reset (active low)

**Reset Outputs to MIG:**
- `sys_rst`: System reset to MIG (active high)
- `aresetn`: AXI reset to MIG (active low)
- `ui_clk_sync_rst`: UI clock synchronous reset

**Calibration Monitoring:**
- `init_calib_complete`: Memory calibration completion from MIG
- `mmcm_locked`: MIG MMCM lock status
- `mem_ok`: Overall memory subsystem ready indication

**Reset Sequence:**
1. System reset assertion holds MIG in reset
2. Clock wizard achieves lock (`clock_ok` asserted)
3. MIG reset released, calibration begins
4. MIG MMCM achieves lock
5. DDR calibration completes (`init_calib_complete`)
6. Memory subsystem ready (`mem_ok` asserted)

## Pin Assignment and Physical Interface

### DDR3 Signal Mapping

The DDR3 interface uses dedicated pins on the VC707 FPGA:

**Address and Command Signals:**
- `ddr3_addr[14:0]`: Row/column address (SSTL15)
- `ddr3_ba[2:0]`: Bank address (SSTL15)  
- `ddr3_cas_n`, `ddr3_ras_n`, `ddr3_we_n`: Command signals (SSTL15)
- `ddr3_cs_n[0]`: Chip select (SSTL15)
- `ddr3_cke[0]`: Clock enable (SSTL15)

**Clock Signals:**
- `ddr3_ck_p[0]`, `ddr3_ck_n[0]`: Differential memory clock (DIFF_SSTL15)

**Data Signals:**
- `ddr3_dq[63:0]`: Bidirectional data (SSTL15_T_DCI)
- `ddr3_dm[7:0]`: Data mask (SSTL15)
- `ddr3_dqs_p[7:0]`, `ddr3_dqs_n[7:0]`: Differential data strobe (DIFF_SSTL15_T_DCI)

**Control Signals:**
- `ddr3_odt[0]`: On-die termination control (SSTL15)
- `ddr3_reset_n`: Memory reset (LVCMOS15)

### IO Standards and Termination

**SSTL15 (Stub Series Terminated Logic 1.5V):**
- Used for address, command, and control signals
- 1.5V signaling with controlled impedance
- Provides reliable signaling at DDR3 speeds

**SSTL15_T_DCI (with Digitally Controlled Impedance):**
- Used for bidirectional data signals
- Automatic impedance matching
- Reduced reflection and improved signal integrity

**DIFF_SSTL15_T_DCI:**
- Used for differential clock and data strobe signals
- Differential signaling for maximum noise immunity
- DCI for impedance control

## Software Integration

### Linux Device Tree Configuration

The DDR memory is represented in the device tree as the main system memory:

```dts
memory {
    device_type = "memory";
    reg = <0x80000000 0x80000000>; // 2GB at base + 2GB offset
};
```

Note: The memory starts at 0x80000000 to leave space for memory-mapped peripherals in the lower 2GB of address space.

### Memory Performance Optimization

**AXI Burst Optimization:**
- MIG controller optimized for burst transactions
- Burst length up to 256 beats supported
- Write coalescing for improved efficiency

**Memory Controller Arbitration:**
- Read priority register-based arbitration
- Configurable read/write prioritization
- Bank management for parallel operations

**Caching Integration:**
- Compatible with RocketChip L1/L2 cache hierarchy
- Cache line size aligned with DDR burst boundaries
- Write-back and write-through policies supported

## Design Considerations and Trade-offs

### Performance vs. Area

**High-Performance Configuration:**
- 512-bit MIG AXI interface maximizes DDR bandwidth utilization
- 64-bit or 256-bit RocketChip system bus (configurable)
- Complex clock crossing increases resource usage
- Multiple memory channels (when configured) for parallel access

**Resource Optimization:**
- Single memory controller reduces FPGA resource usage
- Shared infrastructure with other subsystems
- Configurable memory size for different applications

### Power Management

**Dynamic Features:**
- Self-refresh mode during idle periods
- Power-down modes for unused banks
- Temperature-based refresh rate adjustment

**Static Optimization:**
- Voltage scaling to 1.5V for power efficiency
- Clock gating in unused portions
- Termination resistance optimization

### Signal Integrity

**Layout Considerations:**
- Matched trace lengths for data group signals
- Controlled impedance routing
- Ground plane integrity

**Calibration Features:**
- Write leveling for skew compensation
- Read capture calibration
- Periodic recalibration support

## Verification and Testing

### Built-in Test Features

**MIG Controller Diagnostics:**
- Built-in self-test (BIST) capability
- Pattern generators for memory validation
- Error detection and reporting

**System Integration Testing:**
- Memory stress testing through AXI interface
- Cross-clock domain verification
- Reset sequence validation

### Performance Monitoring

**AXI Performance Counters:**
- Transaction count monitoring
- Latency measurement capability
- Bandwidth utilization tracking

**Memory Controller Metrics:**
- Page hit/miss statistics
- Bank utilization analysis
- Refresh overhead measurement

## Conclusion

The DDR Memory Controller subsystem represents a critical component in the RISC-V FPGA SoC, providing high-performance memory access through a sophisticated interface combining Xilinx MIG IP with custom reset control logic. The implementation demonstrates careful attention to signal integrity, clock domain management, and system integration, resulting in a robust memory subsystem capable of supporting demanding computational workloads.

The hierarchical AXI4 bus architecture ensures clean separation between the processor interface and memory controller, while the configurable memory sizing provides flexibility for different application requirements. The integration with RocketChip's memory hierarchy and Linux support enables seamless operation of complex software stacks.

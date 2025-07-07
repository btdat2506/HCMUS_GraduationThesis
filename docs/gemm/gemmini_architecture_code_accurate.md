# Gemmini Architecture - Code-Accurate Variable Names

This diagram uses the actual variable names, class names, and function names from the Gemmini codebase.

```mermaid
flowchart TD
    %% External Interface
    CPU["CPU Core"]
    TLBus["TileLink Bus"]
    DRAM["DRAM/Memory"]
    
    %% Command Entry and Processing
    subgraph CommandFlow ["Command Processing"]
        CmdQueue["raw_cmd_q<br/>(Queue[GemminiCmd])<br/>entries: 2"]
        RawCmd["raw_cmd<br/>(Dequeued command)"]
        
        subgraph LoopUnrollers ["Loop Controllers"]
            LoopConv["LoopConv<br/>(conv_cmd)<br/>has_loop_conv"]
            LoopMatmul["LoopMatmul<br/>(loop_cmd)<br/>matmul operations"]
        end
        
        ReservationStation["reservation_station<br/>(ReservationStation)<br/>reservation_station_entries"]
    end
    
    %% Frontend and TLB
    Frontend["Frontend TLB<br/>(Address translation)<br/>Virtual → Physical"]
    
    %% Main Controller Infrastructure
    subgraph ControllerInfra ["Controller Infrastructure"]
        Controller["Main Controller<br/>(io.cmd interface)"]
        TilerController["tiler<br/>(TilerController)<br/>CISC mode"]
        ClockGating["gated_clock<br/>(Clock gating)<br/>clock_en_reg"]
        CounterController["counters<br/>(CounterController)<br/>nPerfCounter"]
    end
    
    %% Execution Controllers
    subgraph ExecutionUnits ["Execution Controllers"]
        LoadController["load_controller<br/>(LoadController)<br/>ld_queue_length"]
        StoreController["store_controller<br/>(StoreController)<br/>st operations"]
        ExController["ex_controller<br/>(ExecuteController)<br/>compute operations"]
    end
    
    %% Data Processing and Compute
    subgraph ComputePipeline ["Compute Pipeline"]
        Im2ColUnit["im2col<br/>(Im2Col)<br/>Image→Matrix transform"]
        MeshCore["mesh<br/>(Mesh[T])<br/>meshRows × meshColumns"]
        
        subgraph MeshDetail ["Systolic Array Detail"]
            TileArray["mesh: Seq[Seq[Tile]]<br/>tile(r)(c) at row r, col c<br/>PE array with dataflow"]
        end
        
        AccumulatorScale["accumulator & scaler<br/>(Post-processing)<br/>accType operations"]
    end
    
    %% Memory Subsystem
    subgraph MemorySystem ["Memory Subsystem"]
        Scratchpad["spad<br/>(Scratchpad)<br/>Local storage"]
        DMARead["DMA Read<br/>(mvin operations)<br/>DRAM → Scratchpad"]
        DMAWrite["DMA Write<br/>(mvout operations)<br/>Scratchpad → DRAM"]
    end
    
    %% Configuration and Debug
    subgraph SystemConfig ["System Configuration"]
        ConfigRegs["config registers<br/>(Configuration)<br/>System parameters"]
        PerfCounters["performance counters<br/>(event_io.collect)<br/>Monitoring"]
    end
    
    %% External connections
    CPU ==> TLBus
    TLBus ==> Frontend
    TLBus <==> DRAM
    
    %% Command flow path
    Frontend ==> CmdQueue
    CmdQueue ==> RawCmd
    RawCmd ==> LoopConv
    LoopConv ==> LoopMatmul
    LoopMatmul ==> ReservationStation
    
    %% Controller connections
    Controller ==> TilerController
    Controller ==> ReservationStation
    Controller ==> ClockGating
    ClockGating ==> LoadController
    ClockGating ==> StoreController
    ClockGating ==> ExController
    
    %% Reservation station to execution units
    ReservationStation ==> LoadController
    ReservationStation ==> StoreController
    ReservationStation ==> ExController
    
    %% Load path
    LoadController ==> DMARead
    LoadController ==> Im2ColUnit
    DMARead <==> Frontend
    DMARead ==> Scratchpad
    Im2ColUnit ==> Scratchpad
    
    %% Compute path
    ExController ==> MeshCore
    Scratchpad ==> MeshCore
    MeshCore ==> AccumulatorScale
    AccumulatorScale ==> Scratchpad
    
    %% Store path
    StoreController ==> DMAWrite
    Scratchpad ==> DMAWrite
    DMAWrite <==> Frontend
    
    %% Configuration and monitoring
    Controller <==> ConfigRegs
    LoadController ==> PerfCounters
    StoreController ==> PerfCounters
    ExController ==> PerfCounters
    ReservationStation ==> PerfCounters
    CounterController ==> PerfCounters
    
    %% Completion signals
    LoadController -.-> ReservationStation
    StoreController -.-> ReservationStation
    ExController -.-> ReservationStation
    
    %% Loop completion feedback
    ReservationStation -.-> LoopConv
    ReservationStation -.-> LoopMatmul
    
    %% Styling with actual variable name context
    classDef cpuStyle fill:#e1f5fe,stroke:#01579b,stroke-width:3px
    classDef memStyle fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef ctrlStyle fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef dataStyle fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef computeStyle fill:#ffebee,stroke:#b71c1c,stroke-width:3px
    classDef infraStyle fill:#f9f9f9,stroke:#424242,stroke-width:2px
    classDef queueStyle fill:#e8eaf6,stroke:#1a237e,stroke-width:2px
    
    class CPU cpuStyle
    class DRAM,Scratchpad,TLBus memStyle
    class Controller,TilerController,LoopConv,LoopMatmul ctrlStyle
    class LoadController,StoreController,ExController,DMARead,DMAWrite,Im2ColUnit dataStyle
    class MeshCore,TileArray,AccumulatorScale computeStyle
    class Frontend memStyle
    class ConfigRegs,PerfCounters,CounterController,ClockGating infraStyle
    class CmdQueue,RawCmd,ReservationStation queueStyle
```

## Key Variable Names and Types Used:

### Controllers (from Controller.scala):
- `load_controller: LoadController` - Manages memory load operations
- `store_controller: StoreController` - Manages memory store operations  
- `ex_controller: ExecuteController` - Manages compute operations
- `reservation_station: ReservationStation` - Instruction scheduling
- `tiler: TilerController` - CISC mode operations
- `counters: CounterController` - Performance monitoring

### Command Processing:
- `raw_cmd_q: Queue[GemminiCmd]` - Command queue with 2 entries
- `raw_cmd` - Dequeued command from queue
- `conv_cmd` - Output from LoopConv controller
- `loop_cmd` - Output from LoopMatmul controller

### Mesh and Compute:
- `mesh: Seq[Seq[Tile]]` - 2D array of tiles (from Mesh.scala)
- `tile(r)(c)` - Individual tile at row r, column c
- `meshRows`, `meshColumns` - Mesh dimensions
- `tileRows`, `tileColumns` - Tile dimensions

### Configuration Parameters:
- `reservation_station_entries` - Total reservation station size
- `reservation_station_entries_ld/ex/st` - Per-type queue sizes
- `ld_queue_length` - Load controller queue depth
- `block_rows = meshRows * tileRows` - Block dimensions
- `block_cols = meshColumns * tileColumns`

### Clock and Power:
- `gated_clock` - Clock gating for power management
- `clock_en_reg` - Clock enable register
- `withClock(gated_clock)` - Clock domain wrapping

### Performance Monitoring:
- `event_io.collect()` - Performance counter collection
- Various counter types for different operations

This version accurately reflects the actual implementation structure and naming conventions used in the Gemmini codebase.

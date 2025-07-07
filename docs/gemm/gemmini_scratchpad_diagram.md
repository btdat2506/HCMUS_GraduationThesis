# Gemmini Scratchpad Architecture Diagram

```mermaid
flowchart TB
    %% External interfaces
    DMA_READ[DMA Read Request]
    DMA_WRITE[DMA Write Request]
    EXE_READ[Execute Read Request]
    EXE_WRITE[Execute Write Request]
    EXT_MEM[External Memory]

    %% Main queue pipeline
    DMA_READ --> READ_ISSUE_Q[read_issue_q]
    DMA_WRITE --> WRITE_DISPATCH_Q[write_dispatch_q]
    
    %% Write pipeline queues
    WRITE_DISPATCH_Q --> WRITE_NORM_Q[write_norm_q]
    WRITE_NORM_Q --> WRITE_SCALE_Q[write_scale_q]  
    WRITE_SCALE_Q --> WRITE_ISSUE_Q[write_issue_q]

    %% DMA components
    READ_ISSUE_Q --> STREAM_READER[StreamReader]
    WRITE_ISSUE_Q --> STREAM_WRITER[StreamWriter]
    
    %% TileLink infrastructure  
    STREAM_READER --> TL_XBAR[TL Crossbar]
    STREAM_WRITER --> TL_XBAR
    TL_XBAR --> TL_BUFFER[TL Buffer]
    TL_BUFFER --> EXT_MEM

    %% Zero writer path
    READ_ISSUE_Q --> ZERO_WRITER[ZeroWriter]
    ZERO_WRITER --> ZERO_PIX_REP[ZeroWriter PixelRepeater]

    %% Scaling and processing units
    STREAM_READER --> VSM_SPAD[VectorScalarMultiplier<br/>SPAD]
    STREAM_READER --> VSM_ACC[VectorScalarMultiplier<br/>ACC]
    
    VSM_SPAD --> PIX_REP_SPAD[PixelRepeater<br/>SPAD]
    VSM_ACC --> PIX_REP_ACC[PixelRepeater<br/>ACC]

    %% Memory banks
    subgraph SPAD_BANKS[Scratchpad Banks]
        SPAD_0[(ScratchpadBank 0)]
        SPAD_1[(ScratchpadBank 1)]
        SPAD_N[(ScratchpadBank N)]
    end

    subgraph ACC_BANKS[Accumulator Banks]
        ACC_0[(AccumulatorMem 0)]
        ACC_1[(AccumulatorMem 1)]
        ACC_N[(AccumulatorMem N)]
    end

    %% Read/Write pipelines for banks
    subgraph SPAD_PIPELINE[SPAD Pipeline]
        DMA_READ_PIPE[dma_read_pipe]
        EX_READ_PIPE[ex_read_pipe]
    end

    %% Connections to SPAD banks
    PIX_REP_SPAD --> SPAD_BANKS
    ZERO_PIX_REP --> SPAD_BANKS
    EXE_READ --> SPAD_BANKS
    EXE_WRITE --> SPAD_BANKS
    SPAD_BANKS --> SPAD_PIPELINE
    SPAD_PIPELINE --> STREAM_WRITER

    %% Accumulator processing units
    subgraph ACC_PROCESSING[Accumulator Processing]
        ACC_NORM[Normalizer Unit]
        ACC_SCALE[AccumulatorScale Unit]
        ACC_ADDERS[AccPipeShared<br/>Adders]
    end

    %% Connections to ACC banks
    PIX_REP_ACC --> ACC_BANKS
    ACC_BANKS --> ACC_NORM
    ACC_NORM --> ACC_SCALE
    ACC_SCALE --> STREAM_WRITER
    ACC_SCALE --> EXE_READ
    
    %% Accumulator adder connections
    ACC_BANKS --> ACC_ADDERS
    ACC_ADDERS --> ACC_BANKS

    %% Execute controller connections
    EXE_READ --> ACC_BANKS
    EXE_WRITE --> ACC_BANKS

    %% Additional control flows
    WRITE_DISPATCH_Q -.-> SPAD_BANKS
    WRITE_DISPATCH_Q -.-> ACC_BANKS
    WRITE_NORM_Q -.-> ACC_NORM
    WRITE_SCALE_Q -.-> ACC_SCALE

    %% Styling
    classDef memoryBank fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef processor fill:#f3e5f5,stroke:#4a148c,stroke-width:2px  
    classDef queue fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef dma fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef external fill:#ffebee,stroke:#b71c1c,stroke-width:2px

    class SPAD_0,SPAD_1,SPAD_N,ACC_0,ACC_1,ACC_N memoryBank
    class VSM_SPAD,VSM_ACC,PIX_REP_SPAD,PIX_REP_ACC,ACC_NORM,ACC_SCALE,ACC_ADDERS,ZERO_WRITER,ZERO_PIX_REP processor
    class READ_ISSUE_Q,WRITE_DISPATCH_Q,WRITE_NORM_Q,WRITE_SCALE_Q,WRITE_ISSUE_Q,DMA_READ_PIPE,EX_READ_PIPE queue
    class STREAM_READER,STREAM_WRITER,TL_XBAR,TL_BUFFER dma
    class DMA_READ,DMA_WRITE,EXE_READ,EXE_WRITE,EXT_MEM external
```

## Key Components and Data Flow

### **Memory Hierarchy:**
- **ScratchpadBanks**: Store input data (weights, activations) 
- **AccumulatorMem**: Store partial sums and final results with accumulation capability

### **Data Movement Engines:**
- **StreamReader/Writer**: Handle DMA between external memory and internal banks
- **VectorScalarMultiplier**: Apply scaling transformations to data
- **PixelRepeater**: Handle pixel repetition for convolution optimizations

### **Control Pipeline:**
- **Queue Chain**: `write_dispatch_q → write_norm_q → write_scale_q → write_issue_q`
- **Processing Chain**: `Normalizer → AccumulatorScale → Output`

### **Dual Access Paths:**
1. **DMA Path**: External Memory ↔ StreamReader/Writer ↔ Banks
2. **Execute Path**: Processing Elements ↔ Direct Bank Access

### **Key Features:**
- **Bank arbitration** between DMA and Execute controller access
- **Pipelined operations** with multiple queue stages  
- **Data transformation** integrated into the data movement path
- **Shared accumulator adders** for efficient accumulation operations

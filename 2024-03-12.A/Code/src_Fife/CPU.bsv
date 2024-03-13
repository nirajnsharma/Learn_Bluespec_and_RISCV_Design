// Copyright (c) 2023-2024 Bluespec, Inc.  All Rights Reserved.
// Author: Rishiyur S. Nikhil

package CPU;

// ****************************************************************
// Top-level of pipelined CPU (5+ stages)
// * Instantiates stages and connects the forward and backward flows.
// * Lifts IMem and DMem connections up to next level up.

// ****************************************************************
// Imports from bsc libraries

import FIFOF       :: *;
import Connectable :: *;

// ----------------
// Imports from 'vendor' libs

import Cur_Cycle  :: *;
import Semi_FIFOF :: *;

// ----------------
// Local imports

import Utils       :: *;
import Mem_Req_Rsp :: *;

// Stages
import Inter_Stage :: *;
import CPU_IFC     :: *;

import S1_Fetch      :: *;
import S2_Decode     :: *;
import S3_RR_RW      :: *;
import S4_EX_Control :: *;
import S4_EX_Int     :: *;
import S5_Retire     :: *;

// ****************************************************************

String cpu_name = "Fife v0.7 2024-03-01";

// ****************************************************************

(* synthesize *)
module mkCPU (CPU_IFC);
   // ================================================================
   // STATE
   Reg #(File) rg_flog <- mkReg (InvalidFile);


   Fetch_IFC       stage_F          <- mkFetch;
   Decode_IFC      stage_D          <- mkDecode;
   RR_RW_IFC       stage_RR_RW      <- mkRR_RW;
   EX_Control_IFC  stage_EX_Control <- mkEX_Control;  // Branch, JAL, JALR
   EX_Int_IFC      stage_EX_Int     <- mkEX_Int;      // Integer ops
   Retire_IFC      stage_Retire     <- mkRetire;

   // ----------------
   // Forward flow connections

   // Fetch->Decode->RR-Dispatch, and direct path RR-Dispatch->Retire
   mkConnection (stage_F.fo_Fetch_to_Decode,  stage_D.fi_Fetch_to_Decode);
   mkConnection (stage_D.fo_Decode_to_RR,     stage_RR_RW.fi_Decode_to_RR);
   mkConnection (stage_RR_RW.fo_RR_to_Retire, stage_Retire.fi_RR_to_Retire);

   // RR-Dispatch->various EX
   mkConnection (stage_RR_RW.fo_RR_to_EX_Control,
		 stage_EX_Control.fi_RR_to_EX_Control);
   mkConnection (stage_RR_RW.fo_RR_to_EX_Int,
		 stage_EX_Int.fi_RR_to_EX_Int);

   // Various EX->Retire
   mkConnection (stage_EX_Control.fo_EX_Control_to_Retire,
		 stage_Retire.fi_EX_Control_to_Retire);
   mkConnection (stage_EX_Int.fo_EX_Int_to_Retire,
		 stage_Retire.fi_EX_Int_to_Retire);

   // ----------------
   // Backward flow connections

   // Fetch<-Retire (redirection)
   mkConnection (stage_Retire.fo_Fetch_from_Retire, stage_F.fi_Fetch_from_Retire);
   // RR-Dispatch<-Retire (register writeback)
   mkConnection (stage_Retire.fo_RW_from_Retire, stage_RR_RW.fi_RW_from_Retire);

   // ================================================================
   // BEHAVIOR: all behavior is inside the above modules
   // ================================================================
   // INTERFACE

   method Action init (Initial_Params initial_params);
      rg_flog <= initial_params.flog;

      stage_F.init (initial_params);
      stage_D.init (initial_params);
      stage_RR_RW.init (initial_params);
      stage_EX_Control.init (initial_params);
      stage_EX_Int.init (initial_params);
      stage_Retire.init (initial_params);
   endmethod

   interface fo_IMem_req = stage_F.fo_Fetch_to_IMem;
   interface fi_IMem_rsp = stage_D.fi_IMem_to_Decode;

   interface fo_DMem_S_req    = stage_RR_RW.fo_DMem_S_req;
   interface fi_DMem_S_rsp    = stage_Retire.fi_DMem_S_rsp;
   interface fo_DMem_S_commit = stage_Retire.fo_DMem_S_commit;

   interface fo_DMem_req = stage_Retire.fo_DMem_req;
   interface fi_DMem_rsp = stage_Retire.fi_DMem_rsp;
endmodule


// ****************************************************************

endpackage

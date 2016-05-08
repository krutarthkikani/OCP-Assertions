`timescale 1ns/1ps

`define MCMD_IDLE  3'b000
`define MCMD_READ  3'b010
`define MCMD_WRITE 3'b001
`define MCMD_WRC   3'b110
`define DATA_VALID_RESP 2'b01
`define REQ_FAILED_RESP 2'b10
`define ERR_RESP        2'b11

module ocpmon(Clk_i, MReset_ni, MCmd_i, MAddr_i, MByteEn_i,
              SCmdAccept_i, MData_i, SResp_i, SData_i);

    input            Clk_i;
    input            MReset_ni;
    input  [2:0]     MCmd_i;
    input  [15:0]    MAddr_i;
    input  [3:0]     MByteEn_i;
    input            SCmdAccept_i;
    input  [31:0]    MData_i;
    input  [1:0]     SResp_i;
    input  [31:0]    SData_i;
    reg    [2:0]     iMCmd;
    reg    [15:0]    iMAddr;

      integer req_num,resp_num;

    default clocking cb @(posedge Clk_i);
    endclocking

      always @ (posedge Clk_i)
      begin
        if (!MReset_ni)
        begin
          req_num <= 0;
          resp_num <= 0;
        end
        else 
        begin
          if ( (SCmdAccept_i) && (MCmd_i === `MCMD_READ))
          req_num <= req_num + 1;
         else if (( SResp_i === `DATA_VALID_RESP) || ( SResp_i === `REQ_FAILED_RESP) || (SResp_i === `ERR_RESP))
          resp_num <= resp_num + 1;
        end
      end
    //
    // Add properties and assertions here
    //
    property valid_after_reset;
      MReset_ni |-> MCmd_i !== 3'bxxx;	
    endproperty

    COMPLIANCE_1_1_1: assert property(valid_after_reset) 
                                                else $display("COMPLIANCE_1.1.1 FAILED");

    property request_valid;
      (MCmd_i !== `MCMD_IDLE) |-> (( MAddr_i !== 16'hxxxx) && 
                              (SCmdAccept_i !== 1'bx) && 
                                 (MByteEn_i !== 4'hx)) throughout (MCmd_i !== `MCMD_IDLE);
    endproperty

    COMPLIANCE_1_1_2: assert property(request_valid) 
                                                else $display("COMPLIANCE_1.1.2 FAILED");

    property request_hold_addr;
      integer master_addr;
      disable iff (!MReset_ni)
  ( ((MCmd_i !==`MCMD_IDLE) && !SCmdAccept_i),master_addr = MAddr_i) |-> SCmdAccept_i[->1]##0 
                                                                                 (master_addr === MAddr_i);
    endproperty
    
    COMPLIANCE_1_2_3_ADDR: assert property(request_hold_addr) 
                             else $display("COMPLIANCE_1.2.3 REQUEST_HOLD FAILED FOR ADDRESS ");

    property request_hold_cmd;
      integer master_cmd;
      disable iff (!MReset_ni)
  (((MCmd_i !==`MCMD_IDLE) && !SCmdAccept_i),master_cmd = MCmd_i) |->  SCmdAccept_i[->1]##0
                                                                       (master_cmd === MCmd_i);

    endproperty
    
    COMPLIANCE_1_2_3_CMD: assert property(request_hold_cmd) 
                            else $display("COMPLIANCE_1.2.3 REQUEST_HOLD FAILED FOR COMMAND ");

    property request_hold_data;
      integer master_data;
      disable iff (!MReset_ni)
  ( ((MCmd_i !==`MCMD_IDLE) && !SCmdAccept_i),master_data = MData_i) |-> SCmdAccept_i[->1]##0 
                                                                                 (master_data === MData_i);
    endproperty
    
    COMPLIANCE_1_2_3_DATA: assert property(request_hold_data) 
                             else $display("COMPLIANCE_1.2.3 REQUEST_HOLD FAILED FOR DATA ");

    property request_hold_mbyte_en;
      integer master_byteen;
      disable iff (!MReset_ni)
  ( ((MCmd_i !==`MCMD_IDLE) && !SCmdAccept_i),master_byteen = MByteEn_i) |-> SCmdAccept_i[->1]##0 
                                                                                 (master_byteen === MByteEn_i);
    endproperty
    
    COMPLIANCE_1_2_3_BYTE_EN: assert property(request_hold_mbyte_en) 
                                else $display("COMPLIANCE_1.2.3 REQUEST_HOLD FAILED FOR BYTE_EN ");

 
    property request_value_Mcmd;
      (MCmd_i !== `MCMD_IDLE) |-> (( MCmd_i === `MCMD_WRITE) || 
                                   ( MCmd_i === `MCMD_READ));
    endproperty

    COMPLIANCE_1_2_4: assert property(request_value_Mcmd) 
                        else $display("COMPLIANCE_1.2.4 REQUEST VALUE MCMD FAILED");
 
    property Maddr_word_alligned;
      (MCmd_i !== `MCMD_IDLE) |-> ( MAddr_i[1:0] === 2'b00);
    endproperty

    COMPLIANCE_1_2_5: assert property(Maddr_word_alligned) 
                        else $display("COMPLIANCE_1.2.5 MADDR IS  NOT WORD ALLIGNED");

    property fail_response_only_for_wrc;
       (SResp_i === `REQ_FAILED_RESP) |-> (MCmd_i == `MCMD_WRC );
    endproperty

    COMPLIANCE_1_2_18: assert property(fail_response_only_for_wrc)
                        else $display("COMPLIANCE_1_2_18 FAILED"); 


// Only one thread is supported so following response should be of same request
    property xfer_phase_order_resp_before_req_begin;
     integer num;
     ( ( SResp_i === `DATA_VALID_RESP) ||
       ( SResp_i === `REQ_FAILED_RESP) || 
       ( SResp_i === `ERR_RESP)) |=> (req_num >= resp_num)  ;
    endproperty

    COMPLIANCE_1_4_3: assert property(xfer_phase_order_resp_before_req_begin) 
                        else $display("COMPLIANCE_1.4.3 TRANSFER PHASE ORDER RESPONSE BEFORE REQUEST BEGIN");

     property MReset_ni_signal_valid;
        1'b1 |-> ((MReset_ni !== 1'bx) && (MReset_ni !== 1'bz) );
     endproperty

     COMPLIANCE_1_6_1: assert property(MReset_ni_signal_valid)
                         else $display("COMPLIANCE_1.6.1 FAILED");
      
     property MReset_ni_signal_hold_16_cycle;
        $fell(MReset_ni) |-> !MReset_ni[*16:$];
     endproperty

     COMPLIANCE_1_6_3: assert property(MReset_ni_signal_hold_16_cycle)
                         else $display("COMPLIANCE_1.6.3 FAILED");

endmodule


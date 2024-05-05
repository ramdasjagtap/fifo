`timescale 1ns / 1ps

// transaction class
class transaction;
    rand bit oper;
    bit rd,wr;
    bit [7:0] data_in;
    bit [7:0] data_out;
    bit full,empty;
    
    constraint oper_ctrl {
        oper dist { 1:/50, 0: / 50};        // write and read 50%
    }
endclass

class generator;
    transaction tr;
    mailbox #(transaction) mbx;
    
    int count = 0;
    int i = 0;
    
    event next;         // know when to send next transaction.
    event done;        // completion of requested transaction
    
    function new(mailbox #(transaction) mbx);
            this.mbx = mbx;
            tr = new();
     endfunction;
     
     task run();
        repeat  (count)
            begin
                assert(tr.randomize) else $error("Randomization failed");
                i++;
                mbx.put(tr);
                $display("[GEN] : oper : %d iteration : %d ",tr.oper,i);
                @(next);
            end
            ->done;
          endtask;
          
endclass

class driver;
        virtual fifo_if fif;
        mailbox #(transaction) mbx;
        transaction datac;
        event next;
        
        function new(mailbox #(transaction)mbx);
                this.mbx = mbx;
        endfunction
        
        // reset DUT
        task reset ();
               fif.rst <= 1'b1;
               fif.wr <= 1'b0;
               fif.rd <= 1'b0;
               fif.data_in <= 'h0;
               repeat (5) @(posedge fif.clock);
               fif.rst <= 1'b0;
               $display("[DRV] : DUT RESET DONE ");
               $display("--------------------------------------------------------------------------------------------------------");
        endtask
        
       // writing into fifo
       task write();
        @(posedge fif.clock);
        fif.rst <= 1'b0;
        fif.rd <= 1'b0;
        fif.wr <= 1'b1;
        fif.data_in <= $urandom_range('h0,'hFF);
        @(posedge fif.clock);
        fif.wr <= 1'b0;
        $display("[DRV] : DATA WRITE data : %d ",fif.data_in);
        @(posedge fif.clock);
       endtask
       
         // reading from fifo
            task read();
             @(posedge fif.clock);
             fif.rst <= 1'b0;
             fif.rd <= 1'b1;
             fif.wr <= 1'b0;
             @(posedge fif.clock);
             fif.rd <= 1'b0;
             $display("[DRV] : DATA READ");
             @(posedge fif.clock);
            endtask
            
          task run();
                forever 
                    begin
                            mbx.get(datac);
                            if(datac.oper == 1'b1)
                              write();
                           else
                              read();
                    end
          endtask  
endclass

class monitor;
        virtual fifo_if fif;
        mailbox #(transaction) mbx;
        transaction tr;
        
        function new(mailbox #(transaction) mbx);
            this.mbx = mbx;
        endfunction
        
        task run();
            tr = new();
              forever
                begin
                     repeat (2) @(posedge fif.clock);
                     tr.wr = fif.wr;
                     tr.rd = fif.rd;
                     tr.data_in = fif.data_in;
                     tr.full = fif.full;
                     tr.empty = fif.empty;
                     @(posedge fif.clock);
                     tr.data_out = fif.data_out;
                     
                     mbx.put(tr);
                     $display("[MON] : wr = %b | rd  = %b | din = %d  | dout = %d | full = %b | empty = %b",tr.wr,tr.rd,tr.data_in,tr.data_out,tr.full,tr.empty);
                end
        endtask
endclass

class scoreboard;
    mailbox #(transaction) mbx;
     transaction tr;
     
     event next;
     
     bit [7:0] din[$];
     bit [7:0] temp;
     int err = 0;
     
     function new(mailbox #(transaction) mbx);
            this.mbx = mbx;
     endfunction
     
     task run();
            forever 
                begin
                    mbx.get(tr);
                    $display("[SCO] : wr = %b | rd =%b |din = %d | dout = %d | full = %b | empty = %b",tr.wr,tr.rd,tr.data_in,tr.data_out,tr.full,tr.empty);
                    
                     if(tr.wr == 1'b1)
                       begin
                            if(tr.full == 1'b0)
                              begin
                                    din.push_front(tr.data_in);
                                    $display("[SCO] : DATA STORED IN QUEUE = %d ",tr.data_in);
                              end
                           else begin
                                $display("[SCO] : FIFO is full ");
                           end
                           $display("-------------------------------------------------------------------------------------------------------------------------------");
                       end
                       
                       if(tr.rd == 1'b1)
                        begin
                                if(tr.empty == 1'b0)
                                        begin
                                                temp = din.pop_back();
                                                if(tr.data_out == temp)
                                                    $display("[SCO] : DATA MATCH ");
                                               else begin
                                                    $error("[SCO] : DATA MISMATCHED");
                                                    err ++;
                                               end
                                        end
                                 else begin
                                 $display("[SCO] : FIFO IS EMPTY");
                                 end
                                $display(" ------------------------------------------------------------------------------------------------------ ");
                        end
                       ->next;
                end
     endtask
endclass

class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;
    
    mailbox #(transaction) gdmbx;       // GENERATOR -> DRIVER
    mailbox #(transaction)msmbx;       // MONITOR -> SCOREBOARD
    
    event nextgs;
    
    virtual fifo_if fif;
    
    function new(virtual fifo_if fif);
            gdmbx = new();
            gen = new(gdmbx);
            drv = new(gdmbx);
            
            msmbx = new();
            mon = new(msmbx);
            sco = new(msmbx);
            
            this.fif = fif;
            
            drv.fif = this.fif;
            mon.fif = this.fif;
            
            gen.next = nextgs;
            sco.next = nextgs;
    endfunction
    
    task pre_test();
        drv.reset();
    endtask
    
    task test();
        fork 
            gen.run();
            drv.run();
            mon.run();
            sco.run();
            join_any  
    endtask
    
    task post_test();
            wait(gen.done.triggered);
            $display("--------------------------------------------------------------------------------------------------------");
            $display("ERROR count : %d ",sco.err);
            $display("---------------------------------------------------------------------------------------------------------");
            $finish();
    endtask
    
    task run();
            pre_test();
            test();
            post_test();
    endtask
endclass

module testbench();

 fifo_if fif();
 
fifo_sv DUT(fif);


initial
    begin
            fif.clock <= 1'b0;
    end
    
  always #10 fif.clock <= ~fif.clock;
  
  environment env;
  
  initial
    begin
       env = new(fif);
       env.gen.count = 10;
       env.run();
    end
    
    
    initial
       begin
           $dumpfile("dump.vcd");
           $dumpvars; 
       end
endmodule

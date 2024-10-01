library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

--interfaccia componente
entity project_reti_logiche is
    port(
        i_clk   : in std_logic;
        i_rst   : in std_logic;
        i_start : in std_logic;
        i_add   : in std_logic_vector(15 downto 0);
        i_k     : in std_logic_vector(9 downto 0);
        
        o_done  : out std_logic;
        
        o_mem_addr  : out std_logic_vector(15 downto 0);
        i_mem_data  : in std_logic_vector(7 downto 0);
        o_mem_data  : out std_logic_vector(7 downto 0);
        o_mem_we  : out std_logic;
        o_mem_en  : out std_logic
        
    );
end project_reti_logiche;

architecture project_reti_logiche_arch of project_reti_logiche is

    type state is(reset, start, read, write, done, processing, calc);
    signal current_state : state:=reset;                    --stato corrente
    signal next_state: state:=reset;                        --stato prossimo
    signal counter: integer range 0 to 1024:= 0;            --contatore utilizzato per capire se si è arrivati alla fine
    signal counter_next: integer range 0 to 1024:= 0;       --contatore che incrementa quanto è necessario
    signal write_confidence: std_logic := '0';              --variabile utilizzata per capire se in quel momento bisogna riscrivere il numero o la confidence
    signal write_confidence_next: std_logic := '0';         --variabile next
    signal confidence: std_logic_vector(4 downto 0 ):= "11111";     --variabile di affidabilità
    signal confidence_next: std_logic_vector(4 downto 0 ):= "11111";    --affidabilità prossima
    signal last_value: std_logic_vector(7 downto 0) := "00000000";      --memorizza l'ultimo valore diverso da 0
    signal last_value_next: std_logic_vector(7 downto 0) := "00000000"; --l'ultimo valore next
    signal cycle : std_logic_vector(10 downto 0) := "00000000000";      --numero di cicli totali
    signal addr : std_logic_vector(15 downto 0) := "0000000000000000";  --variabile utilizzata per memorizzare l'indirizzo di memora da visitare
    signal addr_next: std_logic_vector(15 downto 0) := "0000000000000000";--addr pross
    signal first: std_logic := '0';                 --variabile utilizzata per verificare il caso estremo 
    signal first_next: std_logic := '0';
    
    
begin
    --primo processo
    process(i_clk, i_rst)
    begin
        if i_rst = '1' then      --se i_rst viene alzato tutto torna nello stato di reset
           current_state <= reset;
                          
           
        elsif rising_edge(i_clk) then       --tutti i segnali si aggiornano con i segnali precedentemente elaborati
            current_state <= next_state;
            counter <= counter_next;
            write_confidence <= write_confidence_next;
            confidence <= confidence_next;
            last_value <= last_value_next;
            o_mem_addr <= addr_next;
            addr <= addr_next;  
            first <= first_next;          
        end if;
    end process;
    
    --secondo processo: FSM
    process(current_state, i_start, i_mem_data ,i_k,i_add)
    begin    
        o_mem_en         <= '0';
		o_mem_we         <= '0';
		o_done        <= '0';
		o_mem_data <= (others => '0');
		next_state <= current_state;
		if i_k(9)='0' then                                    --calcolo del numero totale di inidirizzi da visitare
		  cycle <= '0' & std_logic_vector(unsigned(i_k) sll 1);   --sarà il doppio di i_k quindi un shift left
		else                                                      --per evitare il problema di overflow si è deciso questa strategia
		  cycle <= '1' & std_logic_vector(unsigned(i_k) sll 1);  
		end if;   
		counter_next <= counter;
        write_confidence_next <= write_confidence;
        confidence_next <= confidence;
        last_value_next <= last_value;
        addr_next <= addr;
        first_next <= first;
    
    case current_state is
        
        when reset =>                   --stato di reset
            counter_next <= 0;
            last_value_next <= "00000000";
            write_confidence_next <= '0';
            
            if i_start = '0' then       --finchè i_start non passa a 1, si rimane sempre in questo stato
				next_state <= reset;	
            elsif i_start = '1' then    --quando  i_start passa a 1, si passa allo stato di start
                next_state <= start;
            end if;   
            
				
		when start =>                    --stato di start
		  
		  o_done <= '0';
		  next_state <= calc;
		  
		when calc =>                      --stato di calcolo indirizzo
		  
		  addr_next <=std_logic_vector(unsigned(i_add)+ counter);     --per calcolare il prossimo indirizzo sommo il counter all'inidirizzo iniziale
		  next_state <= read;
		          
	    when read =>                       --stato di lettura
	       o_mem_en <= '1';
		   o_mem_we <= '0';           
           next_state <= processing;
            
        when processing =>                  --stato di processing
            counter_next <= counter+1;      --il counter viene incrementato
            next_state <= write;   
            if addr = i_add and i_mem_data = "00000000" then    --gestione del caso particolare in cui la sequenza inizia con degli 0
                first_next <= '1';
            elsif i_mem_data /= "00000000" then
                first_next <= '0';
            end if;
             
            
        when WRITE =>                       --stato di scrittura
        o_mem_we <= '1';
        o_mem_en <= '1';
        
        if first = '1' then                 --gestione del caso particolare in cui la sequenza inizia con degli 0
	             o_mem_data <= "00000000";
	    else                                --casi generali
            if write_confidence = '0' then  --se si tratta di un indirizzo nella quale è presente una parola
                
	           if i_mem_data /= "00000000" then    --se la parola è diversa da 0
	               o_mem_data <= i_mem_data;
	               last_value_next <= i_mem_data;
	               confidence_next <= "11111";
	                   
	           else                                --parola uguale a 0
	               o_mem_data <= last_value; 
	               if to_integer(unsigned(confidence))>0 then      --confidence decrementata finchè è maggiore di 0
	                   confidence_next <= std_logic_vector(unsigned(confidence) - 1);
	               end if;
	           end if;
	           write_confidence_next <= '1';
	       else                            --se si tratta di un indirizzo nella quale bisogna scrivere il valore di credibilità
	           o_mem_data <= "000" & confidence;
	            write_confidence_next <= '0';    
	       end if; 
	    end if;           
            
            next_state <= calc;
            if counter >= to_integer(unsigned(cycle)) then          --stabilisco se ho finito di gestire tutte le parole
                next_state <= done;
            end if;    
            
        when DONE =>                                            --stato di fine
                o_mem_we   <= '0';
				o_mem_en   <= '0';
				o_done <= '1';
				if i_start = '0' then                           --vado allo stato di reset solo se i_start passa a 0
                        next_state <= reset;
                        o_done <= '0';
                else 
                    next_state <= done;        
                end if;			  
            
          end case;
     end process;          
end project_reti_logiche_arch;

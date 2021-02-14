Die Software ist unter Atmel Studio 7.0 entwickelt und kompiliert.
Teile der Software sind aus Platz- und Geschwindigkeitsgründen in Assembler geschrieben. 
Ich hoffe die Kommentare sind verständlich.

Mit Optimierung -Os kompilieren, sonst passt der Code nicht ins Flash. 

Fuses: Interner Oszillator, Kein Clock-Div, Brown_Out_Detection 4V3.

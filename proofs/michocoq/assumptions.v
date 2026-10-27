(* Print what purchase_p5 rests on. Expected: nothing (Closed under the
   global context); C.get_contract_type is a module parameter, not an axiom. *)
Require Import Gam.purchase_p5.
Module C. Parameter get_contract_type : Michocoq.comparable.smart_contract_address_constant -> option Michocoq.entrypoints.entrypoint_tree. End C.
Module G := gam C.
Print Assumptions G.purchase_p5.

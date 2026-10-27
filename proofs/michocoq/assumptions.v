(* Print what purchase_p5 and its non-vacuity witness rest on. run.sh
   expects only Coq's primitive-integer axioms, Mi-Cho-Coq's abstract
   BLS12-381 operations, and (for purchase_p5) the module parameter
   C.get_contract_type below, standing for any chain context. *)
Require Import Gam.purchase_p5 Gam.purchase_witness.
Module C. Parameter get_contract_type : Michocoq.comparable.smart_contract_address_constant -> option Michocoq.entrypoints.entrypoint_tree. End C.
Module G := gam C.
Print Assumptions G.purchase_p5.
Print Assumptions purchase_witness.purchase_p5_not_vacuous.

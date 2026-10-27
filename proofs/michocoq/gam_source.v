(* Parse and typecheck out/gam.prove.tz inside Coq. Running Mi-Cho-Coq's
   verified parser and typer by computation means the contract the proofs
   are about is exactly the text in gam_prove_string.v. *)
Require Import Michocoq.main Michocoq.syntax Michocoq.error.
Require Import Gam.gam_prove_string.

Definition contract_file_M := main.contract_file_M gam_prove_string.gam_prove_s 500.

Definition contract_file := Eval vm_compute in (error.extract contract_file_M I).

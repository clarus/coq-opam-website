Require Import Coq.Lists.List.
Require Import FunctionNinjas.All.
Require Import Io.All.
Require Import ListString.All.

Import ListNotations.
Import C.Notations.

Module Trace.
  Inductive t (A : Type) :=
  | Ret : t A
  | Call : A -> t A
  | Let : t A -> t A -> t A
  | Join : t A -> t A -> t A
  | First : t A + t A -> t A.
  Arguments Call {A} _.
  Arguments Let {A} _ _.
  Arguments Join {A} _ _.
  Arguments First {A} _.

  Definition height (lines : list LString.t) : nat :=
    List.length lines.

  Fixpoint width (lines : list LString.t) : nat :=
    match lines with
    | [] => 0
    | line :: lines => max (List.length line) (width lines)
    end.

  Fixpoint merge (width : nat) (lines_x lines_y : list LString.t)
    : list LString.t :=
    match (lines_x, lines_y) with
    | (_, []) => lines_x
    | ([], line_y :: lines_y) =>
      (LString.repeat (LString.s " ") width ++ line_y) ::
      merge width lines_x lines_y
    | (line_x :: lines_x, line_y :: lines_y) =>
      let missing_spaces := width - List.length line_x in
      (line_x ++ LString.repeat (LString.s " ") missing_spaces ++ line_y) ::
      merge width lines_x lines_y
    end.

  Fixpoint to_string {A : Type} (a_to_string : A -> LString.t) (trace : t A)
    : list LString.t :=
    match trace with
    | Ret => [LString.s "."]
    | Call a => [a_to_string a]
    | Let trace_x trace_y =>
      let lines_x := to_string a_to_string trace_x in
      let lines_y := to_string a_to_string trace_y in
      merge (width lines_x + 1) lines_x lines_y
    | Join trace_x trace_y =>
      let lines_x := to_string a_to_string trace_x in
      let lines_y := to_string a_to_string trace_y in
      lines_x ++ lines_y
    | First (inl trace) =>
      merge 6 [LString.s "left"] (to_string a_to_string trace)
    | First (inr trace) =>
      merge 6 [LString.s "right"] (to_string a_to_string trace)
    end.
End Trace.

Fixpoint run {E : Effect.t} {A : Type} (x : C.t E A)
  : C.t E (A * Trace.t {c : Effect.command E & Effect.answer E c}) :=
  match x with
  | C.Ret _ x => ret (x, Trace.Ret _)
  | C.Call c =>
    let! a := call E c in
    ret (a, Trace.Call (existT _ c a))
  | C.Let _ _ x f =>
    let! x := run x in
    let (x, trace_x) := x in
    let! y := run (f x) in
    let (y, trace_y) := y in
    ret (y, Trace.Let trace_x trace_y)
  | C.Join _ _ x y =>
    let! xy := join (run x) (run y) in
    match xy with
    | ((x, trace_x), (y, trace_y)) => ret ((x, y), Trace.Join trace_x trace_y)
    end
  | C.First _ _ x y =>
    let! xy := first (run x) (run y) in
    match xy with
    | inl (x, trace_x) => ret (inl x, Trace.First (inl trace_x))
    | inr (y, trace_y) => ret (inr y, Trace.First (inr trace_y))
    end
  end.

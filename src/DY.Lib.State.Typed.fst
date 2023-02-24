module DY.Lib.State.Typed

open Comparse
open DY.Core
open DY.Lib.Comparse.Glue
open DY.Lib.State.Labeled

noeq
type typed_session_pred (a:Type) {|parseable_serializeable bytes a|} = {
  pred: crypto_predicates -> trace -> principal -> nat -> a -> prop;
  pred_later:
    cpreds:crypto_predicates ->
    tr1:trace -> tr2:trace ->
    prin:principal -> sess_id:nat -> content:a ->
    Lemma
    (requires pred cpreds tr1 prin sess_id content /\ tr1 <$ tr2)
    (ensures pred cpreds tr2 prin sess_id content)
  ;
  pred_knowable:
    cpreds:crypto_predicates ->tr:trace -> prin:principal -> sess_id:nat -> content:a ->
    Lemma
    (requires pred cpreds tr prin sess_id content)
    (ensures is_well_formed _ (is_knowable_by cpreds (principal_state_label prin sess_id) tr) content)
  ;
}

val typed_session_pred_to_session_pred:
  #a:Type -> {|parseable_serializeable bytes a|} ->
  typed_session_pred a -> session_pred
let typed_session_pred_to_session_pred #a #ps_a tspred =
  {
    pred = (fun cpreds tr prin sess_id content_bytes ->
      match parse a content_bytes with
      | None -> False
      | Some content -> tspred.pred cpreds tr prin sess_id content
    );
    pred_later = (fun cpreds tr1 tr2 prin sess_id content_bytes ->
      let Some content = parse a content_bytes in
      tspred.pred_later cpreds tr1 tr2 prin sess_id content
    );
    pred_knowable = (fun cpreds tr prin sess_id content_bytes ->
      let Some content = parse a content_bytes in
      tspred.pred_knowable cpreds tr prin sess_id content;
      serialize_parse_inv_lemma a content_bytes;
      serialize_wf_lemma a (is_knowable_by cpreds (principal_state_label prin sess_id) tr) content
    );
  }

val has_typed_session_pred:
  #a:Type -> {|parseable_serializeable bytes a|} ->
  preds:protocol_predicates -> string -> typed_session_pred a ->
  prop
let has_typed_session_pred #a #ps_a preds label spred =
  has_session_pred preds label (typed_session_pred_to_session_pred spred)

val typed_state_was_set:
  #a:Type -> {|parseable_serializeable bytes a|} ->
  trace -> string -> principal -> nat -> a ->
  prop
let typed_state_was_set #a #ps_a tr label prin sess_id content =
  labeled_state_was_set tr label prin sess_id (serialize _ content)

val set_typed_state:
  #a:Type -> {|parseable_serializeable bytes a|} ->
  string -> principal -> nat -> a -> crypto unit
let set_typed_state label prin sess_id content =
  set_labeled_state label prin sess_id (serialize _ content)

val get_typed_state:
  #a:Type -> {|parseable_serializeable bytes a|} ->
  string -> principal -> nat -> crypto (option a)
let get_typed_state #a label prin sess_id =
  let*? content_bytes = get_labeled_state label prin sess_id in
  match parse a content_bytes with
  | None -> return None
  | Some content -> return (Some content)

val set_typed_state_invariant:
  #a:Type -> {|parseable_serializeable bytes a|} ->
  preds:protocol_predicates ->
  label:string -> spred:typed_session_pred a ->
  prin:principal -> sess_id:nat -> content:a -> tr:trace ->
  Lemma
  (requires
    spred.pred preds.crypto_preds tr prin sess_id content /\
    trace_invariant preds tr /\
    has_typed_session_pred preds label spred
  )
  (ensures (
    let ((), tr_out) = set_typed_state label prin sess_id content tr in
    trace_invariant preds tr_out /\
    typed_state_was_set tr_out label prin sess_id content
  ))
  [SMTPat (set_typed_state label prin sess_id content tr);
   SMTPat (trace_invariant preds tr);
   SMTPat (has_typed_session_pred preds label spred)]
let set_typed_state_invariant #a #ps_a preds label spred prin sess_id content tr =
  parse_serialize_inv_lemma #bytes a content

val get_typed_state_invariant:
  #a:Type -> {|parseable_serializeable bytes a|} ->
  preds:protocol_predicates ->
  label:string -> spred:typed_session_pred a ->
  prin:principal -> sess_id:nat -> tr:trace ->
  Lemma
  (requires
    trace_invariant preds tr /\
    has_typed_session_pred preds label spred
  )
  (ensures (
    let (opt_content, tr_out) = get_typed_state label prin sess_id tr in
    tr == tr_out /\ (
      match opt_content with
      | None -> True
      | Some content -> (
        spred.pred preds.crypto_preds tr prin sess_id content
      )
    )
  ))
  [SMTPat (get_typed_state #a label prin sess_id tr);
   SMTPat (trace_invariant preds tr);
   SMTPat (has_typed_session_pred preds label spred)]
let get_typed_state_invariant #a #ps_a preds label spred prin sess_id tr = ()

val typed_state_was_set_implies_pred:
  #a:Type -> {|parseable_serializeable bytes a|} ->
  preds:protocol_predicates -> tr:trace ->
  label:string -> spred:typed_session_pred a ->
  prin:principal -> sess_id:nat -> content:a ->
  Lemma
  (requires
    typed_state_was_set tr label prin sess_id content /\
    trace_invariant preds tr /\
    has_typed_session_pred preds label spred
  )
  (ensures spred.pred preds.crypto_preds tr prin sess_id content)
  [SMTPat (typed_state_was_set tr label prin sess_id content);
   SMTPat (trace_invariant preds tr);
   SMTPat (has_typed_session_pred preds label spred);
  ]
let typed_state_was_set_implies_pred #a #ps_a preds tr label spred prin sess_id content =
  parse_serialize_inv_lemma #bytes a content;
  ()

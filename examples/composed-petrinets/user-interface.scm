; This program and the accompanying materials are made available under the
; terms of the MIT license (X11 license) which accompanies this distribution.

; Author: C. Bürger

#!r6rs

(library
 (composed-petrinets user-interface)
 (export initialise-petrinet-language petrinet: compose-petrinets:
         run-petrinet! interpret-petrinet!
         assert-marking assert-enabled
         (rename (ap:transition: transition:)
                 (ap:exception: exception:)
                 (ap:fire-transition! fire-transition!)
                 (ap:petrinets-exception? petrinets-exception?)))
 (import (rnrs) (racr core) (prefix (atomic-petrinets user-interface) ap:)
         (composed-petrinets analyses))
 
 ;;; Syntax:
 
 (define-syntax petrinet: ; REDEFINITION: add name & ports
   (syntax-rules ()
     ((_ name (inport ...) (outport ...)
         ((place start-marking ...) ...)
         transition ... )
      (let ((net
             (:AtomicPetrinet
              'name
              (list (:Place 'place (:Token start-marking) ...)
                    ...)
              (list transition
                    ...)
              (list (:Inport 'inport) ... (:Outport 'outport) ...))))
        (unless (=valid? net)
          (ap:exception: "Cannot construct Petri net; The net is not well-formed."))
        net))))
 
 (define-syntax compose-petrinets:
   (syntax-rules ()
     ((_ net1 net2 ((out-net out-port) (in-net in-port)) ...)
      (let ((net* (:ComposedNet
                   net1 net2
                   (:Glueing (cons 'out-net 'out-port) (cons 'in-net 'in-port)) ...)))
        (unless (=valid? net*)
          (rewrite-subtree (->Net1 net*) (create-ast-bud))
          (rewrite-subtree (->Net2 net*) (create-ast-bud))
          (ap:exception: "Cannot compose Petri nets; The composed net is not well-formed."))
        net*))))
 
 ;;; Execution:
 
 (define (run-petrinet! petrinet) ; REDEFINITION: consider subnets
   (unless (=valid? petrinet)
     (ap:exception: "Cannot run Petri Net; The given net is not well-formed."))
   (let ((enabled? ((=subnet-iter petrinet) (lambda (name n) (find =enabled? (=transitions n))))))
     (when enabled?
       (ap:fire-transition! enabled?)
       (run-petrinet! petrinet))))
 
 ;;; REPL Interpreter:
 
 (define (interpret-petrinet! net) ; REDEFINITION: consider subnets
   (unless (=valid? net)
     (ap:exception: "Cannot interpret Petri Net; The given net is not well-formed."))
   (when
       ((=subnet-iter net)
        (lambda (name n)
          (display "======>> ") (display name) (display " <<======\n")
          (ap:interpret-petrinet! n)))
     (interpret-petrinet! net)))
 
 ;;; Testing:

 (define (assert-marking net . marking) ; REDEFINITION: consider subnets
   (for-each (lambda (m) (ap:assert-marking (=find-subnet net (car m)) (cdr m))) marking))

 (define (assert-enabled net . enabled) ; REDEFINITION: consider subnets
   (for-each (lambda (e) (ap:assert-enabled (=find-subnet net (car e)) (cdr e))) enabled))
 
 ;;; Initialisation:
 
 (define (initialise-petrinet-language) ; REDEFINITION: initialise composed Petri net language
   (when (= (specification->phase pn) 1)
     (specify-analyses)
     (compile-ag-specifications pn))))
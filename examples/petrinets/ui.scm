; This program and the accompanying materials are made available under the
; terms of the MIT license (X11 license) which accompanies this distribution.

; Author: C. Bürger

#!r6rs

(library
 (petrinets ui)
 (export
  make-petrinet
  make-transition
  compose-petrinets
  petrinets-exception?
  throw-petrinets-exception)
 (import (rnrs) (racr) (petrinets ast))
 
 (define-condition-type petrinets-exception &violation make-petrinets-exception petrinets-exception?)
 
 (define throw-petrinets-exception
   (lambda (message)
     (raise-continuable
      (condition
       (make-petrinets-exception)
       (make-message-condition message)))))
 
 (define initialize-places
   (lambda (petrinet)
     (ast-for-each-child
      (lambda (i transition)
        (for-each
         (lambda (arc)
           (unless (att-value 'place arc)
             (rewrite-add
              (ast-child 'Place* petrinet)
              (create-ast
               petrinet-spec
               'Place
               (list
                (ast-child 'place arc)
                (create-ast-list (list)))))))
         (append
          (ast-children (ast-child 'In transition))
          (ast-children (ast-child 'Out transition)))))
      (ast-child 'Transition* petrinet))))
 
 (define-syntax make-petrinet
   (lambda (x)
     (define identifier-list?
       (lambda (l)
         (for-all identifier? l)))
     (syntax-case x ()
       ((_ name (inport ...) (outport ...) ((place start-marking ...) ...) transition ... )
        (and
         (identifier? #'name)
         (identifier-list? #'(inport ...))
         (identifier-list? #'(outport ...))
         (identifier-list? #'(place ...)))
        #`(let ((pn
                 (create-ast
                  petrinet-spec
                  'AtomicPetrinet
                  (list
                   #f
                   'name
                   (create-ast-list
                    (list
                     (create-ast
                      petrinet-spec
                      'Place
                      (list
                       'place
                       (create-ast-list
                        (list
                         (create-ast petrinet-spec 'Token (list start-marking)) ...)))) ...))
                   (create-ast-list
                    (list
                     transition ...))
                   (create-ast-list
                    (list
                     (create-ast petrinet-spec 'InPort (list 'inport)) ...
                     (create-ast petrinet-spec 'OutPort (list 'outport)) ...))))))
            ; Initialize the places without explicit start marking:
            (initialize-places pn)
            ; Ensure, that the petrinet is well-formed:
            (unless (att-value 'well-formed? pn)
              (throw-petrinets-exception "Cannot construct Petrinet; The Petrinet is not well-formed."))
            ; Return the constructed Petrinet:
            pn)))))
 
 (define-syntax make-transition
   (lambda (x)
     (define identifier-list?
       (lambda (l)
         (for-all identifier? l)))
     (syntax-case x ()
       ((k name ((input-place (variable matching-condition) ...) ...) ((output-place to-produce ...) ...))
        (and
         (identifier? #'name)
         (identifier-list? #'(variable ... ...))
         (identifier-list? #'(input-place ...))
         (identifier-list? #'(output-place ...)))
        #`(create-ast
           petrinet-spec
           'Transition
           (list
            'name
            (create-ast-list
             (list
              (create-ast
               petrinet-spec
               'Arc
               (list
                'input-place
                (list
                 (lambda (variable)
                   matching-condition) ...))) ...))
            (create-ast-list
             (list
              (create-ast
               petrinet-spec
               'Arc
               (list
                'output-place
                (lambda (variable ... ...)
                  (list to-produce ...)))) ...))))))))
 
 (define-syntax compose-petrinets
   (lambda (x)
     (syntax-case x ()
       ((_ net1 net2 (((out-net out-port) (in-net in-port)) ...))
        (for-all identifier? #'(out-net ... out-port ... in-net ... in-port ...))
        #'(begin
            (rewrite-terminal 'issubnet net1 #t)
            (rewrite-terminal 'issubnet net2 #t)
            (create-ast
             petrinet-spec
             'ComposedPetrinet
             (list
              #f
              net1
              net2
              (create-ast-list
               (list
                (create-ast
                 petrinet-spec
                 'Glueing
                 (list
                  (cons 'out-net 'out-port)
                  (cons 'in-net 'in-port))) ...))))))))))
;;;;------------------------------------------------------------------
;;;; 
;;;;    Copyright (C) 2001-2004, 
;;;;    Department of Computer Science, University of Troms�, Norway.
;;;; 
;;;;    For distribution policy, see the accompanying file COPYING.
;;;; 
;;;; Filename:      environment.lisp
;;;; Description:   
;;;; Author:        Frode Vatvedt Fjeld <frodef@acm.org>
;;;; Created at:    Sat Oct 20 00:41:57 2001
;;;;                
;;;; $Id: environment.lisp,v 1.1 2004/01/13 11:05:05 ffjeld Exp $
;;;;                
;;;;------------------------------------------------------------------

(require :muerte/basic-macros)
(provide :muerte/environment)

(in-package muerte)

(defun pprint-clumps (stream clumps &optional colon at)
  "A clump is the quantity of 8 bytes."
  (declare (ignore colon at))
  (cond
   ((< clumps 64)
    (format stream "~D bytes" (* clumps 8)))
   ((< clumps #x20000)
    (format stream "~D.~D KB"
	    (truncate clumps 128)
	    (truncate (* 10 (rem clumps 128)) 128)))
   (t (format stream "~D.~D MB"
	      (truncate clumps (* 128 1024))
	      (truncate (* 10 (rem clumps #x20000)) #x20000)))))

(defun room (&optional x)
  (declare (ignore x))
  (let ((clumps (malloc-cons-pointer)))
    (format t "Heap used: ~D clumps = ~/muerte:pprint-clumps/." clumps clumps))
  (values))

(defparameter *trace-level* 0)
(defparameter *trace-escape* nil)
(defvar *trace-map* nil)

(defun function-name-symbol (function-name)
  (etypecase function-name
    (symbol
     function-name)
    ((cons (eql setf) (cons symbol null))
     (gethash (cadr function-name)
	      (get-global-property :setf-namespace)))))

(defun match-caller (name)
  (do ((frame (stack-frame-uplink (current-stack-frame))
	      (stack-frame-uplink frame)))
      ((not (plusp frame)))
    (let ((f (stack-frame-funobj frame)))
      (cond
       ((not (typep f 'function))
	(return nil))
       ((equal name (funobj-name f))
	(return t))
       ((and (consp (funobj-name f)) (eq 'method (car (funobj-name f)))
	     (equal name (second (funobj-name f))))
	(return t))
       ((equal name 'eval)
	(return nil))))))

(defun trace-wrapper (&edx function-name-symbol &rest args)
  (declare (dynamic-extent args))
  (check-type function-name-symbol symbol)
  (let ((map (assoc function-name-symbol *trace-map*
		    :key #'function-name-symbol)))
    (assert map ()
      "~S is not traced!?" function-name-symbol)
    (let ((function-name (car map))
	  (function (cadr map))
	  (callers (caddr map)))
      (cond
       ((or *trace-escape*
	    (and (not (eq t callers))
		 (notany 'match-caller callers)))
	(apply function args))
       (t (let ((*trace-escape* t))
	    (fresh-line *trace-output*)
	    (dotimes (i *trace-level*)
	      (write-string "  " *trace-output*))
	    (format *trace-output* "~D: (~S~{ ~S~})~%"
		    *trace-level* function-name args))
	  (let ((result (let ((*trace-level* (1+ *trace-level*)))
			  (multiple-value-list (apply function args))))
		(*trace-escape* t))
	    (fresh-line *trace-output*)
	    (dotimes (i *trace-level*)
	      (write-string "  " *trace-output*))
	    (format *trace-output* "~D: => ~:S~%" *trace-level* result)
	    (values-list result)))))))

(defun do-trace (function-name &key (callers t))
  (when (assoc function-name *trace-map* :test #'equal)
    (do-untrace function-name))
  (let ((function-symbol (function-name-symbol function-name)))
    (assert (fboundp function-symbol) (function-name)
      "Can't trace undefined function ~S." function-name)
    (push (list function-name
		(symbol-function function-symbol)
		callers)
	  *trace-map*)
    (setf (symbol-function function-symbol)
      #'trace-wrapper))
  (values))

(defun do-untrace (name)
  (let ((map (assoc name *trace-map*)))
    (assert map () "~S is not traced." name)
    (let ((function-name-symbol (function-name-symbol name))
	  (function (cadr map)))
      (unless (eq (symbol-function function-name-symbol)
		  #'trace-wrapper)
	(warn "~S was traced, but not fbound to trace-wrapper." name))
      (setf (symbol-function function-name-symbol)
	function)
      (setf *trace-map*
	(delete name *trace-map* :key 'car))))
  (values))

(defmacro time (form)
  `(let ((start-mem (malloc-cons-pointer)))
     (multiple-value-bind (start-time-lo start-time-hi)
	 (read-time-stamp-counter)
       (multiple-value-prog1
	   ,form
	 (multiple-value-bind (end-time-lo end-time-hi)
	     (read-time-stamp-counter)
	   (let ((clumps (- (malloc-cons-pointer) start-mem))
		 (delta-hi (- end-time-hi start-time-hi))
		 (delta-lo (- end-time-lo start-time-lo)))
	     (if (< delta-hi #x1f)
		 (format t "~&;; CPU cycles: ~D.~%;; Space used: ~D clumps = ~/muerte:pprint-clumps/.~%"
			 (+ (ash delta-hi 24) delta-lo) clumps clumps)
	       (format t "~&;; CPU cycles: ~D000.~%;; Space used: ~D clumps = ~/muerte:pprint-clumps/.~%"
		       (+ (ash delta-hi 14) (ash delta-lo -10)) clumps clumps))))))))

(defun describe (object &optional stream)
  (describe-object object (output-stream-designator stream))
  (values))
  

(defmethod describe-object (object stream)
  (format stream "Don't know how to describe ~S." object))

(defmethod describe-object ((object function) stream)
  (let ((arglist (funobj-lambda-list object)))
    (format stream "The function ~S takes arglist ~:A."
	    (funobj-name object)
	    arglist)))

